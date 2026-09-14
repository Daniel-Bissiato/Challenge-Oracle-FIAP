--------------------------------------------------------------------------------
-- COMMENTS DAS TABELAS -- necessários para o Select AI (NL2SQL) entender o
-- schema corretamente. Rodar ANTES de criar/usar o GENAI_PROFILE.
--
-- Este script é reprodutível do zero: contém TODOS os comments do projeto,
-- tanto os que já estavam aplicados no banco quanto os que faltavam
-- (levantado via USER_TAB_COMMENTS / USER_COL_COMMENTS em 2026-09-13).
-- Troque o schema "ADMIN" pelo seu, se necessário.
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- BASE_CONHECIMENTO_CHATBOT_V2 (a tabela em uso -- já tinha tabela e todas
-- as 7 colunas comentadas no banco, reproduzido aqui como está)
--------------------------------------------------------------------------------
COMMENT ON TABLE "ADMIN"."BASE_CONHECIMENTO_CHATBOT_V2" IS
'Internações, óbitos (internos e externos) e tempo médio de internação, agregados por hospital (CNES), diagnóstico principal (CID-10), ano e mês (2023-2025). ESCOPO: apenas hospitais do estado de São Paulo. REGRAS OBRIGATÓRIAS: (1) Para somar internações, use SEMPRE SUM(TOTAL_INTERNACOES) -- NUNCA COUNT(). (2) Para achar "o mais comum", sempre GROUP BY e ORDER BY SUM(TOTAL_INTERNACOES) DESC. (3) Para nome do hospital, JOIN obrigatório com ADMIN.HOSPITAIS_UNICOS. (4) Para nome da doença, JOIN obrigatório com ADMIN.CID10_DICIONARIO.';

COMMENT ON COLUMN "ADMIN"."BASE_CONHECIMENTO_CHATBOT_V2"."CNES" IS
'Código CNES do estabelecimento. Esta tabela NÃO contém o nome do hospital. Para obter o nome, é OBRIGATÓRIO fazer JOIN com ADMIN.CNES_LEITOS usando CNES_LEITOS.CNES = BASE_CONHECIMENTO_CHATBOT_V2.CNES.';

COMMENT ON COLUMN "ADMIN"."BASE_CONHECIMENTO_CHATBOT_V2"."DIAG_PRINC" IS
'Código CID-10 do diagnóstico principal -- NÃO é o nome da doença. Para o nome, faça JOIN com ADMIN.CID10_DICIONARIO.';

COMMENT ON COLUMN "ADMIN"."BASE_CONHECIMENTO_CHATBOT_V2"."ANO" IS
'Ano de referência (2023, 2024 ou 2025).';

COMMENT ON COLUMN "ADMIN"."BASE_CONHECIMENTO_CHATBOT_V2"."MES" IS
'Mês de referência (1 a 12).';

COMMENT ON COLUMN "ADMIN"."BASE_CONHECIMENTO_CHATBOT_V2"."TOTAL_INTERNACOES" IS
'Total de internações desse diagnóstico, nesse hospital, nesse mês.';

COMMENT ON COLUMN "ADMIN"."BASE_CONHECIMENTO_CHATBOT_V2"."TOTAL_OBITOS_INTERNOS" IS
'Total de óbitos (internos e externos) associados a esse diagnóstico, nesse hospital, nesse mês.';

COMMENT ON COLUMN "ADMIN"."BASE_CONHECIMENTO_CHATBOT_V2"."MEDIA_DIAS_INTERNADO" IS
'Média de dias de permanência hospitalar para esse diagnóstico, nesse hospital, nesse mês.';

--------------------------------------------------------------------------------
-- CID10_DICIONARIO (tabela e colunas em branco -- tudo novo)
--------------------------------------------------------------------------------
COMMENT ON TABLE "ADMIN"."CID10_DICIONARIO" IS
'Dicionário de referência CID-10 (OMS/DATASUS). 1 linha = 1 código CID-10. Cobre 2.176 dos 9.491 códigos que aparecem em BASE_CONHECIMENTO_CHATBOT -- nem todo DIAG_PRINC tem descrição aqui (limitação conhecida da fonte).';

COMMENT ON COLUMN "ADMIN"."CID10_DICIONARIO"."CODIGO" IS
'Código CID-10 (ex: A09). Usado para JOIN com BASE_CONHECIMENTO_CHATBOT.DIAG_PRINC.';

COMMENT ON COLUMN "ADMIN"."CID10_DICIONARIO"."DESCRICAO_CID" IS
'Descrição textual (nome da doença/condição) correspondente ao código CID-10.';

--------------------------------------------------------------------------------
-- CNES_LEITOS (já tinha quase tudo; faltavam NOME_UF e PORTE)
--------------------------------------------------------------------------------
COMMENT ON COLUMN "ADMIN"."CNES_LEITOS"."NOME_UF" IS
'Nome completo do estado por extenso (ex: São Paulo), não a sigla (SP).';

COMMENT ON COLUMN "ADMIN"."CNES_LEITOS"."PORTE" IS
'Classificação de porte do estabelecimento, derivada de LEITOS_EXISTENTES: Pequeno (até 20 leitos), Médio (21 a 100) ou Grande (mais de 100).';

--------------------------------------------------------------------------------
-- HOSPITAIS_UNICOS (view já tinha comment de tabela; colunas em branco)
--------------------------------------------------------------------------------
COMMENT ON COLUMN "ADMIN"."HOSPITAIS_UNICOS"."CNES" IS
'Código CNES do estabelecimento -- chave única desta view (um CNES = uma linha).';

COMMENT ON COLUMN "ADMIN"."HOSPITAIS_UNICOS"."NOME_ESTABELECIMENTO" IS
'Nome oficial mais recente do hospital (usando a competência/COMP mais recente), já deduplicado.';

COMMENT ON COLUMN "ADMIN"."HOSPITAIS_UNICOS"."MUNICIPIO" IS
'Nome do município do estabelecimento (referente à competência mais recente).';

COMMENT ON COLUMN "ADMIN"."HOSPITAIS_UNICOS"."UF" IS
'Sigla da Unidade Federativa do estabelecimento (referente à competência mais recente).';

--------------------------------------------------------------------------------
-- LEITOS_POPULACAO_UF (tabela já tinha comment; colunas em branco)
--------------------------------------------------------------------------------
COMMENT ON COLUMN "ADMIN"."LEITOS_POPULACAO_UF"."ANO_REF" IS
'Ano de referência do registro.';

COMMENT ON COLUMN "ADMIN"."LEITOS_POPULACAO_UF"."CO_UF_IBGE" IS
'Código IBGE da Unidade Federativa.';

COMMENT ON COLUMN "ADMIN"."LEITOS_POPULACAO_UF"."NOME_UF" IS
'Nome completo do estado por extenso.';

COMMENT ON COLUMN "ADMIN"."LEITOS_POPULACAO_UF"."POPULACAO" IS
'População residente estimada na UF, no ano.';

COMMENT ON COLUMN "ADMIN"."LEITOS_POPULACAO_UF"."QTD_ESTABELECIMENTOS" IS
'Quantidade de estabelecimentos de saúde (CNES distintos) na UF, no ano.';

COMMENT ON COLUMN "ADMIN"."LEITOS_POPULACAO_UF"."TOTAL_LEITOS_EXISTENTES" IS
'Total de leitos existentes (todos os tipos) na UF, no ano.';

COMMENT ON COLUMN "ADMIN"."LEITOS_POPULACAO_UF"."TOTAL_LEITOS_SUS" IS
'Total de leitos disponíveis para o SUS na UF, no ano.';

COMMENT ON COLUMN "ADMIN"."LEITOS_POPULACAO_UF"."LEITOS_POR_10K_HAB" IS
'Indicador: leitos existentes por 10 mil habitantes -- (TOTAL_LEITOS_EXISTENTES / POPULACAO) x 10000.';

--------------------------------------------------------------------------------
-- OBITOS_SIH_MENSAL (tabela já tinha comment; colunas em branco)
--------------------------------------------------------------------------------
COMMENT ON COLUMN "ADMIN"."OBITOS_SIH_MENSAL"."ANO_REF" IS
'Ano de referência do registro.';

COMMENT ON COLUMN "ADMIN"."OBITOS_SIH_MENSAL"."MES_REF" IS
'Mês de referência do registro (1 a 12).';

COMMENT ON COLUMN "ADMIN"."OBITOS_SIH_MENSAL"."CO_UF_IBGE" IS
'Código IBGE da Unidade Federativa.';

COMMENT ON COLUMN "ADMIN"."OBITOS_SIH_MENSAL"."NOME_UF" IS
'Nome completo do estado por extenso.';

COMMENT ON COLUMN "ADMIN"."OBITOS_SIH_MENSAL"."OBITOS" IS
'Total de óbitos hospitalares (registrados no SIH/SUS) na UF, no mês de referência.';

--------------------------------------------------------------------------------
-- VB_RAG_DOCS (tabela e colunas em branco -- tudo novo)
-- Não é consultada pelo Select AI (NL2SQL); é a base da busca vetorial (RAG).
-- Comment mantido por completude/documentação, não por exigência do NL2SQL.
--------------------------------------------------------------------------------
COMMENT ON TABLE "ADMIN"."VB_RAG_DOCS" IS
'Base de conhecimento do RAG do chatbot: 3.444 documentos textuais indexados para busca semântica (embeddings), usados para resolver entidades ambíguas (nome de hospital, diagnóstico) e responder perguntas conceituais. Ver /docs/rag.md.';

COMMENT ON COLUMN "ADMIN"."VB_RAG_DOCS"."ID" IS
'Identificador sequencial do documento.';

COMMENT ON COLUMN "ADMIN"."VB_RAG_DOCS"."TEXTO" IS
'Texto do documento -- é o que é embedado e retornado como contexto pela busca RAG.';

COMMENT ON COLUMN "ADMIN"."VB_RAG_DOCS"."CATEGORIA" IS
'Categoria do documento: entidade_hospital, entidade_diagnostico, resumo_uf_ano, resumo_obitos_mes ou conceitual.';

COMMENT ON COLUMN "ADMIN"."VB_RAG_DOCS"."METADADOS" IS
'Campos estruturados em JSON usados para filtro/resolução de entidade (ex: cnes, codigo_cid).';

COMMENT ON COLUMN "ADMIN"."VB_RAG_DOCS"."EMBEDDING" IS
'Vetor de 1024 dimensões gerado via Cohere embed-multilingual-v3.0, usado na busca por similaridade de cosseno (VECTOR_DISTANCE).';

--------------------------------------------------------------------------------
-- Conferência: lista tudo que ficou sem comment de coluna (deveria vir vazio
-- ou só com colunas técnicas/irrelevantes pro Select AI)
--------------------------------------------------------------------------------
SELECT table_name, column_name
FROM USER_COL_COMMENTS
WHERE table_name IN (
    'BASE_CONHECIMENTO_CHATBOT_V2', 'CID10_DICIONARIO', 'CNES_LEITOS',
    'DATASET_UNIFICADO', 'IBGE_POPULACAO_UF',
    'LEITOS_POPULACAO_UF', 'OBITOS_SIH_MENSAL', 'VB_RAG_DOCS',
    'HOSPITAIS_UNICOS'
)
AND (comments IS NULL OR comments = '')
ORDER BY table_name, column_name;
