# RAG do Chatbot Hospitalar
 
## Pré-requisitos
 
Antes de rodar qualquer script desta pasta, é preciso ter:
 
1. **Autonomous Database em versão 23ai ou superior** (o tipo `VECTOR` não
   existe em 19c/21c — se o banco estiver em versão anterior, é preciso
   fazer upgrade in-place pelo console OCI antes de continuar).
2. **Credencial `COHERE_CRED`** já criada (`DBMS_CLOUD.CREATE_CREDENTIAL`)
   com uma chave de API da Cohere, e ACL de rede liberada para
   `api.cohere.com`.
3. **Profile `GENAI_PROFILE`** já criado (NL2SQL) — usado pelo
   roteador (`04_roteador.sql`) para os caminhos `SQL` e `RAG`.
4. As tabelas base já carregadas no banco via **Database Actions → Data
   Load**, a partir dos CSVs em `/data` (`cnes_leitos_2023_2025.csv`,
   `dataset_unificado_uf_2023_2025.csv`, `obitos_sih_mensal_uf_2023_2025.csv`,
   `cid10_dicionario_completo.csv`): `BASE_CONHECIMENTO_CHATBOT_V2`,
   `CNES_LEITOS`, `CID10_DICIONARIO`, `DATASET_UNIFICADO`,
   `IBGE_POPULACAO_UF`, `LEITOS_POPULACAO_UF` e `OBITOS_SIH_MENSAL` —
   usadas por `sql/00_comments_tabelas.sql` e pelos scripts Python
   (`scripts/gerar_documentos_rag.py`) para gerar os documentos do RAG.
5. A view `HOSPITAIS_UNICOS` já criada (via `CREATE OR REPLACE VIEW`, não
   por Data Load — ver `sql/05_correcao_view_hospitais_unicos.sql`) —
   usada por `sql/00_comments_tabelas.sql`.
 
## Ordem de execução
 
0. Rodar `sql/00_comments_tabelas.sql` — aplica os `COMMENT ON TABLE/COLUMN`
   nas tabelas base (`BASE_CONHECIMENTO_CHATBOT_V2`, `CNES_LEITOS`,
   `CID10_DICIONARIO`, etc.) e em `VB_RAG_DOCS`. Precisa rodar antes de
   qualquer uso do `GENAI_PROFILE`, já que é isso que o Select AI lê para
   entender o schema.
1. `python scripts/gerar_documentos_rag.py` — gera os CSVs de documentos
   (hospitais de SP, CID-10, resumos) a partir dos dados de `/data`.
2. `python scripts/gerar_conceituais.py` — gera o CSV de documentos
   conceituais (escritos à mão, sem dependência de dado bruto).
3. Carregar os 5 CSVs resultantes via **Database Actions → Data Load**, em
   tabelas de staging (`*_STG_*`) — ver comentário no topo de
   `sql/01_tabela_e_carga_rag.sql` para os nomes esperados.
4. Rodar os scripts SQL em ordem: `01` → `02` → `03` → `04`.
   `05_correcao_view_hospitais_unicos.sql` só é necessário se o banco de
   destino também tiver essa view com o mesmo bug (ver seção de achados
   abaixo) — não é parte do fluxo normal de carga.
 
## O problema
 
O chatbot (usuário Cidadão) usa Select AI (NL2SQL) para responder perguntas em
linguagem natural traduzindo-as em SQL. Isso funciona bem para perguntas
estruturadas ("quantas internações SP teve em 2024?"), mas falha quando a
pergunta menciona uma entidade (hospital, diagnóstico) por um nome que não
bate exatamente com o valor cadastrado na tabela -- por exemplo, "Hospital
das Clínicas do FMUSP" não retornava nada, porque o cadastro real (CNES) tem
o nome como "HC DA FMUSP HOSPITAL DAS CLINICAS SAO PAULO".
 
## A solução: RAG híbrido
 
Em vez de tentar tornar o SQL "flexível" (impossível, já que SQL exige
igualdade exata), usamos busca semântica (RAG) só para **resolver a entidade
mencionada para seu identificador exato**, e daí usamos esse identificador
numa consulta SQL normal. RAG explica/identifica; SQL busca o número.
 
\`\`\`
Pergunta em linguagem natural
        |
        v
  Classificador (LLM)  -->  SQL | RAG | HIBRIDO_HOSPITAL | HIBRIDO_DIAGNOSTICO
        |
        +-- SQL puro -------------------> Select AI / NL2SQL (GENAI_PROFILE)
        |
        +-- RAG puro -------------------> VB_BUSCAR_CONTEXTO -> LLM (contexto + pergunta)
        |
        +-- Híbrido --------------------> VB_RESOLVER_HOSPITAL/DIAGNOSTICO
                                           (nome ambíguo -> CNES/CID exato)
                                                  |
                                                  v
                                           pergunta reescrita com o identificador
                                           exato -> Select AI / NL2SQL
\`\`\`
 
## Base de conhecimento (VB_RAG_DOCS)
 
3.444 documentos, cada um com texto + metadados (JSON) + embedding
(vetor de 1024 dimensões, `embed-multilingual-v3.0` via Cohere):
 
| Categoria             | Qtd   | Fonte                                    | Metadados chave         |
|------------------------|------:|-------------------------------------------|--------------------------|
| `entidade_hospital`    | 1.092 | `cnes_leitos_2023_2025.csv` (filtro SP)   | `cnes`, `nome_oficial_tabela`, `uf`, `municipio` |
| `entidade_diagnostico` | 2.176 | `cid10_dicionario_completo.csv`           | `codigo_cid`             |
| `resumo_uf_ano`        |    81 | `dataset_unificado_uf_2023_2025.csv`      | `uf_nome`, `ano`         |
| `resumo_obitos_mes`    |    81 | `obitos_sih_mensal_uf_2023_2025.csv`      | `uf_nome`, `ano`         |
| `conceitual`           |    14 | escrito à mão (definições de indicadores) | `topico`                 |
 
Gerados por `/scripts/gerar_documentos_rag.py` e `/scripts/gerar_conceituais.py`.
 
**Escopo de hospitais restrito a SP**: o dataset nacional de hospitais tem
7.686 CNES; embedar todos exigiria muito mais que o limite de 1.000
chamadas/mês da chave trial da Cohere, e o projeto já é focado em SP (única
UF com dados a nível hospitalar completos). O CID-10 completo (2.176
códigos) foi mantido porque já é pequeno e cobre 100% dos códigos que têm
descrição disponível -- **7.315 dos 9.491 códigos que aparecem na base de
fatos não têm descrição no dicionário CID usado** (provavelmente por serem
subcategorias de 4 dígitos mais específicas); isso é uma limitação conhecida
dos dados de origem, não do RAG.
 
## Achados durante a construção (vale para a apresentação)
 
1. **Duplicação de nome no CNES**: 750 dos 7.686 hospitais têm mais de um
   `NOME_ESTABELECIMENTO` ao longo do tempo (ex: o próprio Hospital das
   Clínicas da FMUSP). Isso motivou o RAG guardar nomes históricos como
   sinônimos de busca, além do nome oficial mais recente.
 
2. **Bug de duplicação em JOIN (view `HOSPITAIS_UNICOS`)**: um `SELECT
   DISTINCT` que não deduplicava de fato (por causa do ponto 1 acima) estava
   inflando somas de internações por hospital em ~8% quando usado em JOIN.
   Diagnosticado comparando a mesma pergunta contra duas fontes independentes
   e confirmado via `action => 'showsql'` do Select AI. Ver
   `/sql/05_correcao_view_hospitais_unicos.sql` para a correção e a análise
   completa.
 
3. **Nunca chamar função que faz chamada de API dentro do `WHERE` de uma
   query contra tabela grande** -- o otimizador pode reavaliar a function por
   linha, multiplicando chamadas externas e estourando rate limit. Sempre
   resolver a entidade antes, numa variável, e só then filtrar.
 
4. **Ambiguidade genuína em siglas**: "HC da USP" pode se referir tanto ao
   Hospital das Clínicas da FMUSP quanto ao Hospital Universitário da USP
   (duas entidades reais e distintas) -- o resolvedor pega a correspondência
   semântica mais próxima, que nem sempre é a intenção do usuário quando a
   sigla é ambígua. Melhoria futura: retornar os top-N candidatos e pedir
   confirmação quando a distância entre o 1º e o 2º colocado for pequena.
 
## Limite de cota da Cohere (chave trial)
 
A chave trial da Cohere usada via credencial `COHERE_CRED` tem dois limites:
- **1.000 chamadas/mês** (por conta -- não reseta criando uma chave nova na
  mesma conta)
- **40 chamadas/minuto**
 
Para embedar os 3.444 documentos iniciais, foi necessário alternar entre
várias contas trial ao longo do processo. Para uso em produção (ou para
reprocessar a base do zero), recomenda-se solicitar uma chave de produção da
Cohere para a equipe/turma.
 
### Se o job de embeddings travar no meio (troubleshooting)
 
`sql/02_gerar_embeddings.sql` já retoma sozinho de onde parou (a condição
`WHERE embedding IS NULL` cobre isso), então rodar o mesmo bloco de novo é
sempre seguro. Passos quando travar:
 
1. Confira `VB_ERROS_EMBEDDING` — se o erro mencionar `1000 API calls /
   month`, é o teto mensal da conta; se mencionar `40 API calls / minute`,
   é só esperar 1-2 minutos e rodar de novo.
2. Se for o teto mensal: crie uma nova credencial (`DBMS_CLOUD.CREATE_CREDENTIAL`)
   apontando para uma chave de outra conta Cohere trial, troque o
   `credential_name` dentro do `v_params` do job, e rode de novo — ele
   completa só o que falta.
3. Rode o job dentro do Scheduler (como já está no script), nunca direto no
   SQL Worksheet — sessões interativas do navegador têm timeout e o processo
   cai no meio sem avisar, mesmo parecendo "travado" na tela.
