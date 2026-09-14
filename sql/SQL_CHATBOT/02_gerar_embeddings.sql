--------------------------------------------------------------------------------
-- RAG DO CHATBOT DE SAÚDE -- 02. GERAÇÃO DE EMBEDDINGS
--------------------------------------------------------------------------------
-- Roda como job do Scheduler (não trava a sessão do navegador) e retoma
-- sozinho de onde parou (WHERE embedding IS NULL), inclusive se a chave
-- Cohere bater no limite de 1.000 chamadas/mês ou 40/min no meio do processo.
--
-- ATENÇÃO -- limite conhecido da chave trial da Cohere:
--   - 1.000 chamadas / mês (por conta, não por chave)
--   - 40 chamadas / minuto
-- Se bater o limite mensal, é preciso uma credencial nova (nova conta Cohere)
-- para continuar. Se bater o limite por minuto, basta esperar ~1-2 minutos.
--------------------------------------------------------------------------------

CREATE TABLE VB_ERROS_EMBEDDING (
    id        NUMBER,
    erro      VARCHAR2(4000),
    data_erro TIMESTAMP DEFAULT SYSTIMESTAMP
);

BEGIN
    DBMS_SCHEDULER.CREATE_JOB(
        job_name        => 'VB_JOB_EMBEDDINGS',
        job_type        => 'PLSQL_BLOCK',
        job_action       => q'[
            DECLARE
                v_params  CLOB := '{
                    "provider"        : "cohere",
                    "credential_name" : "COHERE_CRED",
                    "url"             : "https://api.cohere.ai/v1/embed",
                    "model"           : "embed-multilingual-v3.0",
                    "input_type"      : "search_document"
                }';
                v_embedding VECTOR;
                v_contador  NUMBER := 0;
                v_msg_erro  VARCHAR2(4000);
            BEGIN
                FOR rec IN (
                    SELECT id, texto FROM VB_RAG_DOCS
                    WHERE embedding IS NULL
                    ORDER BY id
                ) LOOP
                    BEGIN
                        v_embedding := DBMS_VECTOR.UTL_TO_EMBEDDING(rec.texto, JSON(v_params));
                        UPDATE VB_RAG_DOCS SET embedding = v_embedding WHERE id = rec.id;
                        v_contador := v_contador + 1;
                        IF MOD(v_contador, 50) = 0 THEN
                            COMMIT;
                        END IF;
                    EXCEPTION
                        WHEN OTHERS THEN
                            v_msg_erro := SQLERRM;
                            INSERT INTO VB_ERROS_EMBEDDING (id, erro) VALUES (rec.id, v_msg_erro);
                            COMMIT;
                    END;
                END LOOP;
                COMMIT;
            END;
        ]',
        enabled         => TRUE,
        auto_drop       => FALSE
    );
END;
/

-- Acompanhamento (rodar em aba separada enquanto o job processa):
SELECT COUNT(*) AS ja_feito FROM VB_RAG_DOCS WHERE embedding IS NOT NULL;
SELECT COUNT(*) AS sem_embedding FROM VB_RAG_DOCS WHERE embedding IS NULL;

-- Ver os erros registrados (diagnóstico de rate limit / cota):
SELECT erro, COUNT(*) FROM VB_ERROS_EMBEDDING GROUP BY erro ORDER BY COUNT(*) DESC;
