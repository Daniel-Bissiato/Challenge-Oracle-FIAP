# Dicionário de Dados — Challenge Lotação Hospitalar

Este documento descreve as duas tabelas finais processadas pelo grupo, resultantes da integração de quatro bases públicas: **CNES Leitos**, **IBGE População**, **SIH Internações** e **Óbitos Hospitalares (DATASUS/TabNet)**.

---

## 1. `cnes_leitos_2023_2025.csv` — nível hospital (estabelecimento)

**Granularidade:** 1 linha = 1 estabelecimento de saúde (CNES) em um determinado mês/ano.
**Chave primária:** `CNES` + `COMP` (ou `CNES` + `ANO_REF` + mês de `COMP`).
**Linhas:** 255.843
**Fonte:** CNES Leitos (DATASUS), arquivos `Leitos_2023.csv`, `Leitos_2024.csv`, `Leitos_2025.csv`.

| Coluna | Tipo | Descrição | Observações |
|---|---|---|---|
| `COMP` | datetime | Competência (mês/ano de referência do dado) | Convertido de `AAAAMM` para data |
| `ANO_REF` | int | Ano de referência, extraído do arquivo de origem | Usado para agregações anuais |
| `REGIAO` | texto | Região geográfica do Brasil (Norte, Nordeste, etc.) | |
| `UF` | texto | Sigla do estado (2 letras) | Chave de junção com `NOME_UF` via dicionário de siglas |
| `NOME_UF` | texto | Nome completo do estado | Derivado de `UF`, usado para juntar com bases do IBGE/SIH |
| `MUNICIPIO` | texto | Nome do município do estabelecimento | Sem código IBGE padronizado em 2023/2024 (ver limitações) |
| `CO_IBGE` | texto | Código IBGE do município | **Somente presente em 2025** — ausente nos demais anos |
| `CNES` | texto | Código nacional do estabelecimento de saúde | Identificador único do hospital |
| `NOME_ESTABELECIMENTO` | texto | Nome do hospital/unidade de saúde | |
| `TP_GESTAO` | texto | Tipo de gestão (municipal, estadual, etc.) | |
| `CO_TIPO_UNIDADE` | texto (categórico) | Código do tipo de unidade | Numérico na origem, tratado como categórico |
| `DS_TIPO_UNIDADE` | texto | Descrição do tipo de unidade (ex: Hospital Geral) | |
| `NATUREZA_JURIDICA` | texto (categórico) | Código da natureza jurídica | |
| `DESC_NATUREZA_JURIDICA` | texto | Descrição da natureza jurídica (pública, privada, etc.) | |
| `CO_CEP` | texto | CEP do estabelecimento | Tratado como texto para preservar zeros à esquerda |
| `LEITOS_EXISTENTES` | int | Total de leitos existentes no estabelecimento | Variável-chave da análise |
| `LEITOS_SUS` | int | Total de leitos disponíveis para o SUS | Subconjunto de `LEITOS_EXISTENTES` |
| `UTI_TOTAL_EXIST` | int | Total de leitos de UTI existentes (todos os tipos) | |
| `UTI_TOTAL_SUS` | int | Total de leitos de UTI disponíveis ao SUS | |
| `UTI_ADULTO_EXIST` / `_SUS` | int | Leitos de UTI adulto (existentes / SUS) | |
| `UTI_PEDIATRICO_EXIST` / `_SUS` | int | Leitos de UTI pediátrica | |
| `UTI_NEONATAL_EXIST` / `_SUS` | int | Leitos de UTI neonatal | |
| `UTI_QUEIMADO_EXIST` / `_SUS` | int | Leitos de UTI para queimados | |
| `UTI_CORONARIANA_EXIST` / `_SUS` | int | Leitos de UTI coronariana | |
| `DESABILITADO` | booleano | Indica se o estabelecimento está desabilitado | Derivado de `MOTIVO_DESABILITACAO` (100% nula na origem) |
| `PORTE` | texto (categórico) | Classificação de porte: Pequeno (≤20), Médio (21-100), Grande (>100) | Derivado de `LEITOS_EXISTENTES` |

**Colunas descartadas na limpeza (irrelevantes ao problema de negócio):** `RAZAO_SOCIAL`, `NO_LOGRADOURO`, `NU_ENDERECO`, `NO_COMPLEMENTO`, `NO_BAIRRO`, `NU_TELEFONE`, `NO_EMAIL`.

---

## 2. `dataset_unificado_uf_2023_2025.csv` — nível UF/ano

**Granularidade:** 1 linha = 1 estado (UF) em 1 ano.
**Chave primária:** `CO_UF_IBGE` + `Ano`.
**Linhas:** 81 (27 UFs × 3 anos)
**Fontes:** CNES Leitos (agregado), IBGE População, SIH Internações, Óbitos Hospitalares (DATASUS/TabNet).

| Coluna | Tipo | Descrição | Fonte | Observações |
|---|---|---|---|---|
| `NOME_UF` | texto | Nome do estado | IBGE | Chave de junção entre as fontes |
| `CO_UF_IBGE` | texto | Código IBGE do estado (2 dígitos) | IBGE | |
| `Ano` | int | Ano de referência | Todas | 2023, 2024 ou 2025 |
| `Leitos existentes` | float | Total de leitos existentes na UF | CNES | Agregado a partir do snapshot do último mês do ano (evita duplicação por soma mensal) |
| `Leitos SUS` | float | Total de leitos disponíveis ao SUS na UF | CNES | Idem acima |
| `Leitos UTI total` | float | Total de leitos de UTI na UF | CNES | Idem acima |
| `Qtd hospitais` | float | Quantidade de estabelecimentos distintos (CNES únicos) | CNES | |
| `População residente` | float | População estimada da UF no ano | IBGE (Projeções de População) | Nível estadual apenas — não há dado municipal nesta fonte |
| `TOTAL_INTERNACOES` | float | Total de internações no ano | SIH | Soma dos 12 meses |
| `TOTAL_OBITOS_SIH` | float | Total de óbitos ocorridos durante internação SUS no ano | SIH | **Não é mortalidade geral da população** — apenas óbitos hospitalares registrados no SIH |
| `VALOR_TOTAL_SIH` | float | Valor total gasto com internações no ano (R$) | SIH | Soma dos 12 meses |
| `MEDIA_PERMANENCIA_ANO` | float | Tempo médio de permanência hospitalar (dias) | SIH | Média simples das médias mensais (simplificação — o ideal seria média ponderada por internações/mês) |
| `LEITOS_POR_10K_HAB` | float | Leitos existentes por 10 mil habitantes | Derivada | `(Leitos existentes / População residente) × 10000` |
| `INTERNACOES_POR_LEITO` | float | Internações por leito existente no ano | Derivada | Proxy de pressão/utilização do sistema |
| `TAXA_MORTALIDADE_HOSPITALAR` | float | Taxa de óbito entre internados (%) | Derivada | `(TOTAL_OBITOS_SIH / TOTAL_INTERNACOES) × 100` |
| `GASTO_MEDIO_INTERNACAO` | float | Gasto médio por internação (R$) | Derivada | `VALOR_TOTAL_SIH / TOTAL_INTERNACOES` |

---

## 3. Relação entre as duas tabelas (chaves de integração)

- `cnes_leitos_2023_2025.csv` e `dataset_unificado_uf_2023_2025.csv` se conectam via **`NOME_UF` (ou `CO_UF_IBGE`) + `Ano`/`ANO_REF`** — ou seja, é possível agregar a tabela hospital-level para o nível UF/ano e comparar com o dataset já unificado (foi o processo de auditoria realizado pelo grupo).
- Não existe, nas fontes atuais, uma chave direta de `CNES` para `SIH`/`Óbitos`/`IBGE` — essas três fontes só estão disponíveis agregadas por UF, o que impede join em nível de hospital individual. Essa é uma limitação documentada na conclusão da AED.

## 4. Convenções gerais

- Datas no padrão `AAAA-MM-DD` (ou apenas ano, quando anual).
- Valores monetários em Reais (R$), sem correção de inflação entre os anos.
- Textos em UTF-8, sem acentuação corrompida.
- Nulos: ausentes das tabelas finais (tratados/removidos na etapa de limpeza); ausência de linha para uma UF/ano indica falha de correspondência a ser investigada, não deve ocorrer nas versões atuais.


## 5. `base_conhecimento_chatbot_v2.csv` — nível hospital/diagnóstico/mês

**Granularidade:** 1 linha = 1 hospital (CNES) + 1 diagnóstico (CID-10) + 1 mês/ano.
**Chave primária:** `CNES` + `DIAG_PRINC` + `ANO` + `MES`.
**Fonte:** SIH/SUS (DATASUS), agregado por estabelecimento e diagnóstico principal.

| Coluna                    | Tipo   | Descrição                                              | Observações                                        |
|----------------------------|--------|----------------------------------------------------------|------------------------------------------------------|
| `CNES`                     | texto  | Código do estabelecimento de saúde                        | Junta com `cnes_leitos` / view `HOSPITAIS_UNICOS`    |
| `DIAG_PRINC`                | texto  | Código CID-10 do diagnóstico principal da internação       | Junta com `cid10_dicionario_completo`; **nem todo código aqui tem descrição no dicionário CID (ver observação abaixo)** |
| `ANO` / `MES`               | int    | Ano e mês de referência                                    |                                                       |
| `Total_Internacoes`         | int    | Total de internações naquele CNES/diagnóstico/mês            |                                                       |
| `Total_Obitos_Internos`     | int    | Total de óbitos hospitalares naquele CNES/diagnóstico/mês    |                                                       |
| `Media_Dias_Internado`      | float  | Média de dias de internação                                |                                                       |

**Observação importante**: essa tabela **não tem coluna de UF** — para
filtrar por estado é necessário fazer JOIN com `cnes_leitos`/`HOSPITAIS_UNICOS`
pelo `CNES`. **Atenção**: a versão original da view `HOSPITAIS_UNICOS` tinha um
bug de deduplicação que inflava somas em JOIN (ver `/sql/05_correcao_view_hospitais_unicos.sql`
para o diagnóstico e a correção).

Dos 9.491 códigos `DIAG_PRINC` distintos usados nesta tabela, apenas 2.176
têm descrição correspondente em `cid10_dicionario_completo.csv` — os demais
7.315 (provavelmente variações de 4 dígitos mais específicas) ficam sem
tradução textual. Limitação conhecida da fonte de dados do dicionário CID.

---

## 6. `cid10_dicionario_completo.csv` — dicionário de códigos CID-10

**Granularidade:** 1 linha = 1 código CID-10.
**Chave primária:** `CODIGO`.
**Linhas:** 2.176
**Fonte:** tabela de referência CID-10 (OMS/DATASUS).

| Coluna          | Tipo  | Descrição                          |
|------------------|-------|---------------------------------------|
| `CODIGO`         | texto | Código CID-10 (ex: `A09`)             |
| `DESCRICAO_CID`  | texto | Descrição textual do diagnóstico      |

---

## 7. `VB_RAG_DOCS` — base de conhecimento do RAG (chatbot)

**Granularidade:** 1 linha = 1 documento textual indexado para busca semântica.
**Linhas:** 3.444
**Gerado por:** `/scripts/gerar_documentos_rag.py` e `/scripts/gerar_conceituais.py`
**Documentação completa da arquitetura:** ver `/docs/rag.md`

| Coluna       | Tipo             | Descrição                                                    |
|---------------|------------------|------------------------------------------------------------------|
| `id`          | number           | Identificador sequencial                                          |
| `texto`       | varchar2(4000)   | Texto do documento (o que é embedado e retornado como contexto)  |
| `categoria`   | varchar2(50)     | `entidade_hospital`, `entidade_diagnostico`, `resumo_uf_ano`, `resumo_obitos_mes` ou `conceitual` |
| `metadados`   | json             | Campos estruturados para filtro/resolução (ex: `cnes`, `codigo_cid`) |
| `embedding`   | vector(1024)     | Embedding via Cohere `embed-multilingual-v3.0`                    |

Hospitais restritos ao estado de SP (1.092 dos 7.686 CNES nacionais) — ver
justificativa de escopo em `/docs/rag.md`.
