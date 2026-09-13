--------------------------------------------------------------------------------
-- RAG DO CHATBOT DE SAÚDE -- 01. TABELA E CARGA DOS DOCUMENTOS
--------------------------------------------------------------------------------
-- Pré-requisito: credencial COHERE_CRED (ou equivalente) já criada e com ACL
-- para api.cohere.com liberada (ver Aula 07 do curso).
--
-- Os 3.444 documentos de origem (hospitais de SP, CID-10, resumos UF/ano,
-- resumos mensais de óbitos, conceituais) são gerados pelos scripts em
-- /scripts/gerar_documentos_rag.py e /scripts/gerar_conceituais.py, a partir
-- dos CSVs já processados em /data.
--
-- Troque o prefixo VB pelo seu, se for recriar do zero em outro schema.
--------------------------------------------------------------------------------

CREATE TABLE VB_RAG_DOCS (
    id          NUMBER GENERATED ALWAYS AS IDENTITY,
    texto       VARCHAR2(4000),          -- limite do DBMS_VECTOR.UTL_TO_EMBEDDING
    categoria   VARCHAR2(50),
    metadados   JSON,
    embedding   VECTOR(1024, FLOAT32),   -- dimensão do embed-multilingual-v3.0
    PRIMARY KEY (id)
);

--------------------------------------------------------------------------------
-- Carga: os CSVs gerados pelos scripts Python são importados via
-- Database Actions -> Data Load (arrastar e soltar) em tabelas de staging
-- (VB_STG_HOSPITAL, VB_STG_DIAGNOSTICO, VB_STG_RESUMO_UF, VB_STG_OBITOS,
-- VB_STG_CONCEITUAL), e depois consolidados aqui:
--------------------------------------------------------------------------------

INSERT INTO VB_RAG_DOCS (texto, categoria, metadados)
SELECT texto, categoria, JSON(metadados_json) FROM VB_STG_HOSPITAL
UNION ALL
SELECT texto, categoria, JSON(metadados_json) FROM VB_STG_DIAGNOSTICO
UNION ALL
SELECT texto, categoria, JSON(metadados_json) FROM VB_STG_RESUMO_UF
UNION ALL
SELECT texto, categoria, JSON(metadados_json) FROM VB_STG_OBITOS
UNION ALL
SELECT texto, categoria, JSON(metadados_json) FROM VB_STG_CONCEITUAL;

COMMIT;

-- Conferência: deve somar 3.444 documentos
-- (1.092 hospitais SP + 2.176 CID-10 + 81 resumo_uf_ano + 81 resumo_obitos_mes + 14 conceitual)
SELECT categoria, COUNT(*) FROM VB_RAG_DOCS GROUP BY categoria;
