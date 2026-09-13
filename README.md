<div align="center">

# 🏥 Vitallis

### Inteligência de dados para lotação hospitalar no Brasil

**Challenge Oracle — FIAP** · Grupo **Data Forge**


**[🔗 Acessar a aplicação (Painel)](http://vitallisdashboard.netlify.app)** . **[🔗 Acessar a aplicação (ChatBot)](https://sparkly-babka-2bba96.netlify.app/)** · **[📊 Notebook da AED](https://github.com/Daniel-Bissiato/Challenge-Oracle-FIAP/tree/main/notebooks)** · **[📖 Dicionário de dados](docs/dicionario_de_dados.md)**

</div>

<br>

> O Vitallis transforma dados públicos de saúde do Brasil — hoje fragmentados em bases distintas do governo — em inteligência acionável para dois públicos: **gestores públicos de saúde**, que precisam decidir onde investir em capacidade hospitalar, e **cidadãos**, que precisam entender a estrutura de atendimento disponível em sua região.

<div align="center">

</div>

---

## Índice

- [O Problema](#-o-problema)
- [A Solução](#-a-solução)
- [Arquitetura](#-arquitetura)
- [Stack Tecnológica](#-stack-tecnológica)
- [Fontes de Dados](#-fontes-de-dados)
- [Principais Indicadores e Achados](#-principais-indicadores-e-achados)
- [Estrutura do Repositório](#-estrutura-do-repositório)
- [Como Executar](#-como-executar-o-pipeline-de-etl)
- [Limitações e Próximos Passos](#-limitações-e-próximos-passos)
- [Equipe](#-equipe)

---

## 🩺 O Problema

A lotação hospitalar é um problema estrutural e recorrente no sistema de saúde brasileiro. A distribuição de leitos entre os estados é extremamente desigual, e a ausência de visibilidade sobre onde a pressão sobre o sistema é maior leva a decisões de investimento baseadas em urgência pontual, não em critério objetivo — com custo direto para pacientes, gestores e para o sistema como um todo.

## 💡 A Solução

O Vitallis integra quatro bases públicas de saúde — cobrindo os **27 estados brasileiros entre 2023 e 2025** — em uma plataforma com quatro módulos complementares:

<div align="center">

| Módulo | Descrição |
|:---|:---|
| 📊 **Visão Geral** | Painel executivo com KPIs de capacidade e demanda hospitalar por estado/ano |
| 🗺️ **Perfil de Atendimento** | Exploração territorial com mapa interativo para localizar hospitais específicos |
| 📈 **Previsão SP** | Prova de conceito de ML (XGBoost) para antecipar demanda de leitos-dia em SP |
| 💬 **Central de Decisão** | Perguntas em linguagem natural, roteadas entre SQL exata (Select AI) e busca vetorial (RAG) |

</div>

## 🏗️ Arquitetura

```
┌──────────────────┐     ┌───────────────┐     ┌──────────────────────────┐
│  Fontes Públicas  │ ──▶ │  ETL (Python)  │ ──▶ │  Oracle AI Database 26ai  │
│ CNES · IBGE · SIH │     │    pandas      │     │  (dados + IA generativa)  │
└──────────────────┘     └───────────────┘     └────────────┬─────────────┘
                                                             │
                                             ┌───────────────┴───────────────┐
                                             │      Roteador de Intenção      │
                                             │  (classifica cada pergunta)    │
                                             └───────────────┬───────────────┘
                                    ┌─────────────────────────┼─────────────────────────┐
                                    ▼                          ▼                         ▼
                          SQL exata (Select AI)      RAG vetorial (DBMS_VECTOR)       Híbrido
                                    │                          │              (resolvedor de entidade
                                    └────────────┬─────────────┘                CNES / CID-10)
                                                 ▼
                                   Backend exposto via ORDS / PAR
                                                 ▼
                              Dashboard web (HTML/JS) — hospedado no Netlify
```

## 🧰 Stack Tecnológica

<div align="center">

| Camada | Tecnologia |
|:---|:---|
| ETL / Análise | Python, pandas |
| Banco de dados e IA | Oracle AI Database 26ai |
| NL2SQL | Select AI |
| RAG / Busca semântica | `DBMS_VECTOR`, embeddings Cohere (`embed-multilingual-v3.0`) |
| Modelagem preditiva (POC) | XGBoost |
| Backend | ORDS / PAR |
| Frontend | HTML, JavaScript — hospedado no Netlify |

</div>

## 🗂️ Fontes de Dados

Todas as fontes são públicas, cobrindo os 27 estados brasileiros entre 2023 e 2025:

| Fonte | Conteúdo | Granularidade original |
|:---|:---|:---|
| **CNES Leitos** (DATASUS) | Leitos existentes/SUS, UTI, por estabelecimento | Hospital, mensal |
| **População** (IBGE) | Projeções de população por estado | UF, anual |
| **SIH Internações** (DATASUS/TabNet) | Internações, dias de permanência, valor gasto | UF, mensal |
| **Óbitos Hospitalares** (SIH/TabNet) | Óbitos ocorridos durante internação SUS | UF, mensal |

Além disso, uma base documental com mais de **10 mil documentos indexados** (dados hospitalares de São Paulo, tabela CID-10 e conteúdo conceitual) alimenta a busca semântica da Central de Decisão.

## 📈 Principais Indicadores e Achados

A Análise Exploratória de Dados (AED) completa está documentada no notebook.

<div align="center">

| Indicador | Valor | Leitura |
|:---:|:---:|:---|
| Leitos per capita × Internações/leito | **r = -0,56** | Indicador central de pressão hospitalar, usado para priorização de investimento |
| Mortalidade hospitalar × Gasto médio | **r = 0,67** | Correlação forte, **não causal** — reflete provável complexidade dos casos |
| Diferença entre estados (leitos/10k hab.) | **2,2x** | Desigualdade estrutural entre o estado mais e o menos servido |
| Modelo preditivo (XGBoost, SP) | **R² ≈ 0,85** | Exploratório — **sem validação independente confirmada** |

</div>

## 📁 Estrutura do Repositório

```
├── data/
│   ├── raw/                # Arquivos brutos das fontes públicas (CNES, IBGE, SIH, Óbitos)
│   └── processed/          # Datasets tratados e unificados (saída do ETL)
├── etl/
│   └── etl_lotacao_hospitalar.py   # Pipeline de ETL (Extract, Transform, Load)
├── notebooks/
│   └── EC_Sprint_3_ChallengeOracle_DataForge_ML.ipynb   # AED completa
├── docs/
│   ├── dicionario_de_dados.md
│   └── Data-Forge-solucao-final.pptx
└── README.md
```

> Ajuste esta árvore para refletir a organização real do repositório, se tiver divergido durante o desenvolvimento.

## ⚙️ Como Executar o Pipeline de ETL

```bash
# Clonar o repositório
git clone INSIRA_AQUI_O_LINK_DO_REPOSITORIO
cd vitallis

# Instalar dependências
pip install pandas numpy

# Executar o pipeline (gera os datasets processados em data/processed/)
python etl/etl_lotacao_hospitalar.py
```

O script lê os arquivos brutos de `data/raw/`, valida consistência (duplicatas, inconsistências lógicas), corrige um erro comum de agregação temporal na base de leitos, e gera os datasets finais unificados, incluindo `dataset_unificado_uf_2023_2025.csv`.

## 🚧 Limitações e Próximos Passos

- A população do IBGE está disponível apenas em nível **estadual**, restringindo taxas per capita a essa granularidade.
- O CNES reflete **capacidade instalada**, não ocupação em tempo real — não há, nas fontes atuais, um indicador direto de "lotação agora".
- Os óbitos analisados são **hospitalares** (SIH), não mortalidade geral da população.
- Estados-polo (ex: Distrito Federal) concentram atendimento de populações vizinhas, inflando suas taxas per capita.
- A resolução de siglas/apelidos institucionais (ex: "HC da USP") ainda é frágil em buscas puramente vetoriais.

**Próximos passos:** camada de correspondência exata por sigla antes do fallback vetorial; expansão do modelo preditivo e da base de conhecimento para além de São Paulo; validação independente formal do modelo preditivo antes de uso em produção.

## 👥 Equipe

<div align="center">

Grupo **Data Forge** — FIAP · Vitallis

| Nome | LinkedIn |
|:---|:---:|
| Daniel Gomes Bissiato | https://www.linkedin.com/in/daniel-bissiato-b13a14344/ |
| Vinícius Barreto de Oliveira | https://www.linkedin.com/in/vin%C3%ADciusbarreto/ |
| Vitor Luiz Souza Costa | https://www.linkedin.com/in/vitor-l-souza-costa-3206b1406/ |

</div>
