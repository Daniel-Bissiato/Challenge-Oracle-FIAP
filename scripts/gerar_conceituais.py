import csv
import json

documentos = [
    ("internacoes", "Internações (SIH/SUS)",
     "Internação é o registro de um paciente admitido em um hospital pelo Sistema Único de Saúde (SUS) para tratamento, "
     "captado pelo Sistema de Informações Hospitalares (SIH). Cada internação gera uma Autorização de Internação Hospitalar "
     "(AIH), que registra o diagnóstico principal (código CID-10), o hospital (CNES), a duração e o valor gasto. O total de "
     "internações de uma UF num período é a soma dessas AIHs aprovadas para pacientes atendidos pelo SUS naquele local e tempo."),

    ("obitos_hospitalares", "Óbito hospitalar (óbitos SIH)",
     "Óbito hospitalar é o falecimento de um paciente durante uma internação registrada no SIH/SUS. É contado a partir do "
     "campo de motivo de saída (alta, óbito, transferência, etc.) de cada AIH. Não inclui óbitos ocorridos fora do ambiente "
     "hospitalar ou em atendimentos não financiados pelo SUS. É a base para calcular a taxa de mortalidade hospitalar."),

    ("taxa_mortalidade_hospitalar", "Taxa de mortalidade hospitalar",
     "A taxa de mortalidade hospitalar é a proporção de internações que terminaram em óbito, calculada como "
     "(óbitos hospitalares / total de internações) x 100, expressa em percentual. É um indicador de gravidade dos casos "
     "atendidos e de qualidade assistencial, mas deve ser interpretada com cautela: hospitais que recebem casos mais graves "
     "ou de maior complexidade (como hospitais de referência) tendem a ter taxas mais altas mesmo prestando bom atendimento."),

    ("permanencia_media", "Permanência média (tempo de internação)",
     "A permanência média é o número médio de dias que os pacientes ficam internados, calculada dividindo o total de "
     "dias de internação pelo número de internações no período. Permanências muito longas podem indicar casos mais "
     "complexos ou ineficiências assistenciais; permanências muito curtas podem indicar alta precoce ou casos de menor "
     "complexidade. É um indicador de uso de recursos hospitalares, não de qualidade clínica isoladamente."),

    ("leitos_por_10k_hab", "Leitos por 10 mil habitantes",
     "Leitos por 10 mil habitantes é um indicador de capacidade instalada da rede hospitalar, calculado como "
     "(número total de leitos / população residente) x 10.000. Permite comparar a disponibilidade de infraestrutura "
     "hospitalar entre regiões com populações de tamanhos diferentes. A Organização Mundial da Saúde costuma citar uma "
     "referência de cerca de 25 leitos por 10 mil habitantes como parâmetro mínimo recomendado, mas esse número varia "
     "bastante conforme o perfil epidemiológico e o nível de desenvolvimento de cada região."),

    ("gasto_medio_internacao", "Gasto médio por internação",
     "O gasto médio por internação é o valor total pago pelo SUS em internações num período dividido pelo número de "
     "internações, representando o custo médio de cada AIH aprovada. Esse valor é definido pela tabela de procedimentos "
     "do SUS (SIGTAP), que remunera cada procedimento hospitalar por um valor fixo, e pode variar bastante conforme a "
     "complexidade dos procedimentos realizados na região."),

    ("valor_total_sih", "Valor total de internações (SIH)",
     "O valor total de internações é a soma de todos os valores pagos pelo SUS em AIHs aprovadas num período e local, "
     "conforme os valores da tabela SIGTAP de procedimentos hospitalares. Esse valor reflete o gasto público federal "
     "com internações, não incluindo gastos com atendimentos ambulatoriais, medicamentos de uso contínuo fora do "
     "período de internação, ou custos assumidos por planos de saúde privados."),

    ("cnes", "CNES (Cadastro Nacional de Estabelecimentos de Saúde)",
     "O CNES é o cadastro oficial do Ministério da Saúde que identifica de forma única cada estabelecimento de saúde "
     "no Brasil, público ou privado, com um código numérico. É usado para vincular internações, leitos e outros "
     "registros do SUS a um hospital específico. Um mesmo estabelecimento pode ter seu nome cadastral alterado ao "
     "longo do tempo, mas mantém o mesmo código CNES, que é o identificador estável para cruzar dados entre bases."),

    ("sih_sus", "SIH/SUS (Sistema de Informações Hospitalares)",
     "O SIH/SUS é o sistema de informação do Ministério da Saúde que registra as internações hospitalares financiadas "
     "pelo SUS em todo o Brasil, através das Autorizações de Internação Hospitalar (AIH). É a principal fonte de dados "
     "sobre internações, óbitos hospitalares, diagnósticos e gastos hospitalares públicos no país, disponibilizada "
     "publicamente pelo DATASUS."),

    ("cid10", "CID-10 (Classificação Internacional de Doenças)",
     "O CID-10 é o sistema internacional de códigos usado para classificar diagnósticos médicos, mantido pela "
     "Organização Mundial da Saúde. Cada código (como A09, para diarreia e gastroenterite de origem infecciosa "
     "presumível) representa uma categoria diagnóstica específica. No SIH/SUS, toda internação registra um "
     "diagnóstico principal em CID-10, permitindo análises epidemiológicas por tipo de doença ou causa de internação."),

    ("diagnostico_principal", "Diagnóstico principal (DIAG_PRINC)",
     "O diagnóstico principal é o motivo clínico que levou à internação, registrado em código CID-10 em cada AIH do "
     "SIH/SUS. É o diagnóstico usado para fins de faturamento e estatística, mesmo quando o paciente apresenta outras "
     "condições associadas durante a internação. É a partir desse campo que se calculam estatísticas de internação "
     "por tipo de doença, como número de casos de uma condição específica numa UF ou período."),

    ("porte_hospitalar", "Porte hospitalar",
     "O porte de um hospital, conforme classificação do CNES, indica seu tamanho aproximado (pequeno, médio ou "
     "grande), geralmente relacionado ao número de leitos e à complexidade de serviços oferecidos. Hospitais de "
     "grande porte costumam ter mais especialidades médicas e atender casos mais complexos, o que pode influenciar "
     "indicadores como taxa de mortalidade hospitalar e permanência média quando comparados a hospitais menores."),

    ("natureza_juridica", "Natureza jurídica dos estabelecimentos",
     "A natureza jurídica classifica o estabelecimento de saúde conforme seu regime administrativo: público (mantido "
     "por governo federal, estadual ou municipal), privado (com ou sem fins lucrativos) ou filantrópico (entidade sem "
     "fins lucrativos, geralmente de cunho religioso ou beneficente, que presta serviços ao SUS mediante convênio). "
     "Hospitais filantrópicos são comuns na rede SUS brasileira e incluem muitos hospitais universitários e de ensino."),

    ("fonte_dados", "Fonte dos dados (DATASUS/TabNet)",
     "Os dados usados neste projeto têm origem no DATASUS, o departamento de informática do SUS, através do sistema "
     "TabNet, que disponibiliza publicamente informações de internações (SIH), estabelecimentos de saúde (CNES) e "
     "outros indicadores de saúde pública. Os dados cobrem o período de 2023 a 2025, com maior granularidade "
     "(nível hospitalar) disponível para o estado de São Paulo; outros estados apresentam mais lacunas de dados."),
]

with open("output/rag_conceitual.csv", "w", newline="", encoding="utf-8") as f:
    writer = csv.writer(f)
    writer.writerow(["texto", "categoria", "metadados_json"])
    for slug, titulo, corpo in documentos:
        texto = f"{titulo}: {corpo}"
        metadados = json.dumps({"categoria": "conceitual", "topico": slug}, ensure_ascii=False)
        writer.writerow([texto, "conceitual", metadados])

print(f"{len(documentos)} documentos conceituais salvos em output/rag_conceitual.csv")
