--------------------------------------------------------------------------------
-- RAG DO CHATBOT DE SAÚDE -- 03. ÍNDICE VETORIAL E FUNÇÕES DE BUSCA
--------------------------------------------------------------------------------

CREATE VECTOR INDEX VB_RAG_IDX ON VB_RAG_DOCS (embedding)
ORGANIZATION INMEMORY NEIGHBOR GRAPH
DISTANCE COSINE;

--------------------------------------------------------------------------------
-- Busca semântica genérica (para perguntas conceituais/abertas)
--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION VB_BUSCAR_CONTEXTO(
    p_pergunta   IN VARCHAR2,
    p_categoria  IN VARCHAR2 DEFAULT NULL,  -- filtra por categoria, ou NULL para buscar em tudo
    p_top_n      IN NUMBER DEFAULT 3
) RETURN CLOB
IS
    v_params CLOB := '{
        "provider": "cohere", "credential_name": "COHERE_CRED",
        "url": "https://api.cohere.ai/v1/embed",
        "model": "embed-multilingual-v3.0", "input_type": "search_query"
    }';
    v_embedding VECTOR;
    v_resultado CLOB := '';
BEGIN
    v_embedding := DBMS_VECTOR.UTL_TO_EMBEDDING(p_pergunta, JSON(v_params));

    FOR rec IN (
        SELECT texto
        FROM VB_RAG_DOCS
        WHERE (p_categoria IS NULL OR categoria = p_categoria)
        ORDER BY VECTOR_DISTANCE(embedding, v_embedding, COSINE)
        FETCH FIRST p_top_n ROWS ONLY
    ) LOOP
        v_resultado := v_resultado || rec.texto || CHR(10) || CHR(10);
    END LOOP;

    RETURN v_resultado;
END;
/

--------------------------------------------------------------------------------
-- Resolução de entidade: nome de hospital mencionado -> CNES exato
-- (resolve o problema original: "Hospital das Clínicas do FMUSP" não batia
-- com o nome cadastrado no CNES_LEITOS)
--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION VB_RESOLVER_HOSPITAL(
    p_nome_mencionado IN VARCHAR2
) RETURN VARCHAR2
IS
    v_params CLOB := '{
        "provider": "cohere", "credential_name": "COHERE_CRED",
        "url": "https://api.cohere.ai/v1/embed",
        "model": "embed-multilingual-v3.0", "input_type": "search_query"
    }';
    v_embedding VECTOR;
    v_cnes      VARCHAR2(20);
BEGIN
    v_embedding := DBMS_VECTOR.UTL_TO_EMBEDDING(p_nome_mencionado, JSON(v_params));

    SELECT JSON_VALUE(metadados, '$.cnes')
    INTO v_cnes
    FROM VB_RAG_DOCS
    WHERE categoria = 'entidade_hospital'
    ORDER BY VECTOR_DISTANCE(embedding, v_embedding, COSINE)
    FETCH FIRST 1 ROWS ONLY;

    RETURN v_cnes;
END;
/

--------------------------------------------------------------------------------
-- Resolução de entidade: descrição de diagnóstico mencionada -> código CID-10
--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION VB_RESOLVER_DIAGNOSTICO(
    p_descricao_mencionada IN VARCHAR2
) RETURN VARCHAR2
IS
    v_params CLOB := '{
        "provider": "cohere", "credential_name": "COHERE_CRED",
        "url": "https://api.cohere.ai/v1/embed",
        "model": "embed-multilingual-v3.0", "input_type": "search_query"
    }';
    v_embedding VECTOR;
    v_codigo    VARCHAR2(20);
BEGIN
    v_embedding := DBMS_VECTOR.UTL_TO_EMBEDDING(p_descricao_mencionada, JSON(v_params));

    SELECT JSON_VALUE(metadados, '$.codigo_cid')
    INTO v_codigo
    FROM VB_RAG_DOCS
    WHERE categoria = 'entidade_diagnostico'
    ORDER BY VECTOR_DISTANCE(embedding, v_embedding, COSINE)
    FETCH FIRST 1 ROWS ONLY;

    RETURN v_codigo;
END;
/

--------------------------------------------------------------------------------
-- IMPORTANTE: nunca chame VB_RESOLVER_* dentro do WHERE de uma query contra
-- uma tabela grande (ex: BASE_CONHECIMENTO_CHATBOT_V2, ~2,5M linhas) -- o
-- Oracle pode reavaliar a function por linha, disparando dezenas de chamadas
-- à Cohere numa única query e estourando o limite de 40/min. Sempre resolva
-- a entidade PRIMEIRO, guarde numa variável, e só então filtre com o valor
-- já pronto. Exemplo de uso correto:
--------------------------------------------------------------------------------
-- DECLARE
--     v_codigo VARCHAR2(20);
--     v_total  NUMBER;
-- BEGIN
--     v_codigo := VB_RESOLVER_DIAGNOSTICO('infecção intestinal por diarreia');
--     SELECT SUM(TOTAL_INTERNACOES) INTO v_total
--     FROM base_conhecimento_chatbot_v2
--     WHERE DIAG_PRINC = v_codigo;
-- END;
-- /

--------------------------------------------------------------------------------
-- Testes
--------------------------------------------------------------------------------
SELECT VB_BUSCAR_CONTEXTO('Hospital das Clínicas do FMUSP', 'entidade_hospital', 3) FROM dual;
