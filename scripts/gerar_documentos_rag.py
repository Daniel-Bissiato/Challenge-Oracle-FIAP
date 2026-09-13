"""
Gerador de documentos para a base de conhecimento RAG do chatbot.

Lê os CSVs que já estão no banco Oracle e gera 4 conjuntos de documentos,
cada um em formato (texto, metadados), prontos para embeddar e carregar
numa tabela tipo:

    CREATE TABLE documentos_rag (
        id            NUMBER GENERATED ALWAYS AS IDENTITY,
        texto         CLOB,
        categoria     VARCHAR2(50),
        metadados     JSON,
        embedding     VECTOR,
        PRIMARY KEY (id)
    );

Saída: um CSV por categoria em ./output/, cada um com colunas
[texto, categoria, metadados_json]. O passo de gerar o embedding em si
(chamada à API) fica fora deste script de propósito -- aqui só preparamos
o TEXTO e os METADADOS, que é a parte que depende dos dados de vocês.

Categorias geradas:
  1. entidade_hospital   -> a partir de cnes_leitos_2023_2025.csv
  2. entidade_diagnostico -> a partir de cid10_dicionario_completo.csv
  3. resumo_uf_ano       -> a partir de dataset_unificado_uf_2023_2025.csv
  4. resumo_obitos_mes   -> a partir de obitos_sih_mensal_uf_2023_2025.csv
"""

import json
import unicodedata
from pathlib import Path

import pandas as pd

IN_DIR = Path(".")
OUT_DIR = Path("output")
OUT_DIR.mkdir(exist_ok=True)

MESES_PT = {
    1: "janeiro", 2: "fevereiro", 3: "março", 4: "abril", 5: "maio", 6: "junho",
    7: "julho", 8: "agosto", 9: "setembro", 10: "outubro", 11: "novembro", 12: "dezembro",
}


def fmt_num(valor: float, casas: int = 0) -> str:
    """Formata número no padrão BR: milhar com ponto, decimal com vírgula."""
    txt = f"{valor:,.{casas}f}"
    txt = txt.replace(",", "§").replace(".", ",").replace("§", ".")
    return txt


def fmt_brl(valor: float) -> str:
    return f"R$ {fmt_num(valor, 2)}"


def normalizar(texto: str) -> str:
    """Remove acentos e baixa a caixa -- útil pra dedupe de nomes, não pro texto final."""
    if not isinstance(texto, str):
        return ""
    sem_acento = unicodedata.normalize("NFKD", texto).encode("ascii", "ignore").decode("ascii")
    return sem_acento.strip().upper()


# ---------------------------------------------------------------------------
# 1. DICIONÁRIO DE ENTIDADES: HOSPITAIS
# ---------------------------------------------------------------------------
def gerar_entidades_hospital(path_csv: str) -> pd.DataFrame:
    df = pd.read_csv(path_csv, dtype={"CNES": str})

    # NOME_ESTABELECIMENTO tem 2 nulos no dataset -- descarta essas linhas,
    # não dá pra gerar um documento de entidade sem nome.
    df = df.dropna(subset=["NOME_ESTABELECIMENTO"])

    # ACHADO IMPORTANTE: 750 dos 7.686 CNES têm mais de um NOME_ESTABELECIMENTO
    # ao longo do tempo (ex: hospital que mudou de nome ou teve variação de
    # cadastro entre competências). Isso é OURO pro RAG -- cada nome histórico
    # vira um sinônimo de busca, sem precisar catalogar variações manualmente.
    # Ex.: CNES 2078015 aparece registrado como
    #   "HC DA FMUSP HOSPITAL DAS CLINICAS SAO PAULO"
    # que é exatamente o caso que travava no Select AI.
    grupos = df.groupby("CNES")

    registros = []
    for cnes, grupo in grupos:
        nomes = grupo["NOME_ESTABELECIMENTO"].drop_duplicates().tolist()
        # nome mais recente (maior COMP) = nome "oficial" pra usar no SQL
        nome_oficial = grupo.sort_values("COMP").iloc[-1]["NOME_ESTABELECIMENTO"]
        # outros nomes que já apareceram = sinônimos de busca
        sinonimos = [n for n in nomes if n != nome_oficial]

        ultima_linha = grupo.sort_values("COMP").iloc[-1]
        municipio = ultima_linha["MUNICIPIO"]
        uf = ultima_linha["UF"]
        nome_uf = ultima_linha["NOME_UF"]
        tipo_unidade = ultima_linha["DS_TIPO_UNIDADE"]
        natureza = ultima_linha["DESC_NATUREZA_JURIDICA"]
        porte = ultima_linha["PORTE"]
        desabilitado = bool(ultima_linha["DESABILITADO"])

        texto_partes = [
            f"Estabelecimento de saúde: {nome_oficial}.",
            f"Código CNES: {cnes}.",
            f"Localização: {municipio}, {nome_uf} ({uf}).",
            f"Tipo de unidade: {tipo_unidade}. Natureza jurídica: {natureza}. Porte: {porte}.",
        ]
        if sinonimos:
            texto_partes.append(
                "Também já foi registrado nos cadastros com o(s) nome(s): "
                + "; ".join(sinonimos) + "."
            )
        if desabilitado:
            texto_partes.append("Atenção: este estabelecimento consta como desabilitado no CNES.")

        texto = " ".join(texto_partes)

        metadados = {
            "categoria": "entidade_hospital",
            "cnes": cnes,
            "nome_oficial_tabela": nome_oficial,  # valor exato pra usar no WHERE do SQL
            "uf": uf,
            "municipio": municipio,
            "desabilitado": desabilitado,
        }

        registros.append({"texto": texto, "categoria": "entidade_hospital",
                           "metadados_json": json.dumps(metadados, ensure_ascii=False)})

    return pd.DataFrame(registros)


# ---------------------------------------------------------------------------
# 2. DICIONÁRIO DE ENTIDADES: DIAGNÓSTICOS (CID-10)
# ---------------------------------------------------------------------------
def gerar_entidades_diagnostico(path_csv: str) -> pd.DataFrame:
    df = pd.read_csv(path_csv, dtype={"CODIGO": str})
    df = df.dropna(subset=["CODIGO", "DESCRICAO_CID"])
    df = df.drop_duplicates(subset=["CODIGO"])  # 0 duplicatas encontradas, mas fica a garantia

    registros = []
    for _, row in df.iterrows():
        codigo = row["CODIGO"].strip()
        descricao = row["DESCRICAO_CID"].strip()

        texto = f"Diagnóstico CID-10 código {codigo}: {descricao}."

        metadados = {
            "categoria": "entidade_diagnostico",
            "codigo_cid": codigo,  # valor exato pra usar no WHERE DIAG_PRINC = :codigo
        }

        registros.append({"texto": texto, "categoria": "entidade_diagnostico",
                           "metadados_json": json.dumps(metadados, ensure_ascii=False)})

    return pd.DataFrame(registros)


# ---------------------------------------------------------------------------
# 3. RESUMOS NARRATIVOS: UF x ANO
# ---------------------------------------------------------------------------
def gerar_resumos_uf_ano(path_csv: str) -> pd.DataFrame:
    df = pd.read_csv(path_csv)
    df = df.sort_values(["NOME_UF", "Ano"])

    registros = []
    for uf_nome, grupo in df.groupby("NOME_UF"):
        grupo = grupo.sort_values("Ano")
        anterior = None
        for _, row in grupo.iterrows():
            ano = int(row["Ano"])
            internacoes = row["TOTAL_INTERNACOES"]
            obitos = row["TOTAL_OBITOS_SIH"]
            valor_total = row["VALOR_TOTAL_SIH"]
            permanencia = row["MEDIA_PERMANENCIA_ANO"]
            leitos_10k = row["LEITOS_POR_10K_HAB"]
            taxa_mortalidade = row["TAXA_MORTALIDADE_HOSPITALAR"]
            gasto_medio = row["GASTO_MEDIO_INTERNACAO"]
            qtd_hospitais = row["Qtd hospitais"]
            populacao = row["População residente"]

            texto_partes = [
                f"Em {ano}, o estado de {uf_nome} registrou {fmt_num(internacoes)} internações "
                f"pelo SUS, com {fmt_num(obitos)} óbitos hospitalares registrados no SIH "
                f"(taxa de mortalidade hospitalar de {fmt_num(taxa_mortalidade, 2)}%).",
                f"O valor total gasto com internações foi de {fmt_brl(valor_total)}, "
                f"com gasto médio de {fmt_brl(gasto_medio)} por internação.",
                f"A permanência média foi de {fmt_num(permanencia, 1)} dias.",
                f"O estado contava com {qtd_hospitais:.0f} hospitais e "
                f"{fmt_num(leitos_10k, 1)} leitos por 10 mil habitantes, para uma população "
                f"estimada de {fmt_num(populacao)} habitantes.",
            ]

            # comparativo com o ano anterior, quando existir
            if anterior is not None:
                var_internacoes = (internacoes - anterior["TOTAL_INTERNACOES"]) / anterior["TOTAL_INTERNACOES"] * 100
                sinal = "aumento" if var_internacoes >= 0 else "queda"
                texto_partes.append(
                    f"Em relação a {int(anterior['Ano'])}, houve {sinal} de "
                    f"{fmt_num(abs(var_internacoes), 1)}% no número de internações."
                )

            texto = " ".join(texto_partes)

            metadados = {
                "categoria": "resumo_uf_ano",
                "uf_nome": uf_nome,
                "co_uf_ibge": int(row["CO_UF_IBGE"]),
                "ano": ano,
            }

            registros.append({"texto": texto, "categoria": "resumo_uf_ano",
                               "metadados_json": json.dumps(metadados, ensure_ascii=False)})

            anterior = row

    return pd.DataFrame(registros)


# ---------------------------------------------------------------------------
# 4. RESUMOS NARRATIVOS: ÓBITOS MENSAIS POR UF
# ---------------------------------------------------------------------------
def gerar_resumos_obitos_mes(path_csv: str) -> pd.DataFrame:
    df = pd.read_csv(path_csv)
    df = df.sort_values(["NOME_UF", "ANO_REF", "MES_REF"])

    registros = []
    for (uf_nome, ano), grupo in df.groupby(["NOME_UF", "ANO_REF"]):
        grupo = grupo.sort_values("MES_REF")
        meses_txt = ", ".join(
            f"{MESES_PT[int(m)]}: {int(o)}"
            for m, o in zip(grupo["MES_REF"], grupo["OBITOS"])
        )
        total_ano = grupo["OBITOS"].sum()

        texto = (
            f"Óbitos hospitalares registrados no SIH em {uf_nome} durante {int(ano)}, "
            f"por mês: {meses_txt}. Total de óbitos no ano: {int(total_ano)}."
        )

        metadados = {
            "categoria": "resumo_obitos_mes",
            "uf_nome": uf_nome,
            "co_uf_ibge": int(grupo["CO_UF_IBGE"].iloc[0]),
            "ano": int(ano),
        }

        registros.append({"texto": texto, "categoria": "resumo_obitos_mes",
                           "metadados_json": json.dumps(metadados, ensure_ascii=False)})

    return pd.DataFrame(registros)


# ---------------------------------------------------------------------------
def main():
    print("Gerando dicionário de entidades: hospitais...")
    df_hospitais = gerar_entidades_hospital(IN_DIR / "cnes_leitos_2023_2025__1_.csv")
    df_hospitais.to_csv(OUT_DIR / "rag_entidade_hospital.csv", index=False)
    print(f"  -> {len(df_hospitais)} documentos ({df_hospitais['texto'].str.contains('nome(s):', regex=False).sum()} com sinônimos)")

    print("Gerando dicionário de entidades: diagnósticos CID-10...")
    df_cid = gerar_entidades_diagnostico(IN_DIR / "cid10_dicionario_completo__1_.csv")
    df_cid.to_csv(OUT_DIR / "rag_entidade_diagnostico.csv", index=False)
    print(f"  -> {len(df_cid)} documentos")

    print("Gerando resumos narrativos UF x ano...")
    df_resumo_uf = gerar_resumos_uf_ano(IN_DIR / "dataset_unificado_uf_2023_2025__1_.csv")
    df_resumo_uf.to_csv(OUT_DIR / "rag_resumo_uf_ano.csv", index=False)
    print(f"  -> {len(df_resumo_uf)} documentos")

    print("Gerando resumos mensais de óbitos por UF...")
    df_resumo_obitos = gerar_resumos_obitos_mes(IN_DIR / "obitos_sih_mensal_uf_2023_2025__1_.csv")
    df_resumo_obitos.to_csv(OUT_DIR / "rag_resumo_obitos_mes.csv", index=False)
    print(f"  -> {len(df_resumo_obitos)} documentos")

    total = len(df_hospitais) + len(df_cid) + len(df_resumo_uf) + len(df_resumo_obitos)
    print(f"\nTotal de documentos gerados: {total}")
    print(f"Arquivos salvos em: {OUT_DIR.resolve()}")


if __name__ == "__main__":
    main()
