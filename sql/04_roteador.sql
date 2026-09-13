--------------------------------------------------------------------------------
-- ROTEADOR: decide se a pergunta vai pra SQL puro, RAG puro, ou híbrido
--------------------------------------------------------------------------------
-- Pré-requisitos: GENAI_PROFILE (NL2SQL, da Aula 07) e as funções já criadas
-- VB_BUSCAR_CONTEXTO, VB_RESOLVER_HOSPITAL, VB_RESOLVER_DIAGNOSTICO
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- 1. CLASSIFICADOR
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION VB_CLASSIFICAR_PERGUNTA(
    p_pergunta IN VARCHAR2
) RETURN VARCHAR2
IS
    v_resposta CLOB;
    v_prompt   CLOB;
BEGIN
    v_prompt := 'Classifique a pergunta abaixo em UMA destas categorias, respondendo SOMENTE no formato "TIPO|ENTIDADE" (sem explicação, sem markdown, sem aspas):

- SQL| -> pede número exato, soma, média ou contagem agregada, sem mencionar nome de hospital nem diagnóstico específico
- RAG| -> pergunta conceitual, sobre significado, contexto ou tendência geral
- HIBRIDO_HOSPITAL|<nome do hospital mencionado> -> pede dado específico de um hospital mencionado pelo nome
- HIBRIDO_DIAGNOSTICO|<descrição do diagnóstico mencionado> -> pede dado específico de um diagnóstico mencionado por nome/sintoma (não por código CID)

Exemplos:
Pergunta: "quantas internações SP teve em 2024?"
Resposta: SQL|

Pergunta: "o que significa taxa de permanência?"
Resposta: RAG|

Pergunta: "quantas internações teve no Hospital das Clínicas do FMUSP?"
Resposta: HIBRIDO_HOSPITAL|Hospital das Clínicas do FMUSP

Pergunta: "quantos casos de diarreia foram registrados?"
Resposta: HIBRIDO_DIAGNOSTICO|diarreia

Pergunta a classificar: "' || p_pergunta || '"
Resposta:';

    v_resposta := DBMS_CLOUD_AI.GENERATE(
        prompt       => v_prompt,
        action       => 'chat',
        profile_name => 'GENAI_PROFILE'
    );

    RETURN TRIM(REPLACE(v_resposta, CHR(10), ''));
END;
/

--------------------------------------------------------------------------------
-- 2. ROTEADOR -- a função que o chatbot chama de verdade
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION VB_ROTEADOR(
    p_pergunta IN VARCHAR2
) RETURN CLOB
IS
    v_classificacao      VARCHAR2(4000);
    v_tipo               VARCHAR2(50);
    v_entidade           VARCHAR2(500);
    v_pos_pipe           NUMBER;
    v_resposta           CLOB;
    v_contexto           CLOB;
    v_codigo             VARCHAR2(20);
    v_pergunta_reescrita VARCHAR2(4000);
BEGIN
    v_classificacao := VB_CLASSIFICAR_PERGUNTA(p_pergunta);
    v_pos_pipe := INSTR(v_classificacao, '|');

    IF v_pos_pipe = 0 THEN
        RETURN 'Não consegui classificar a pergunta (resposta inesperada: ' || v_classificacao || ')';
    END IF;

    v_tipo     := SUBSTR(v_classificacao, 1, v_pos_pipe - 1);
    v_entidade := TRIM(SUBSTR(v_classificacao, v_pos_pipe + 1));

    IF v_tipo = 'SQL' THEN
        ----------------------------------------------------------------
        v_resposta := DBMS_CLOUD_AI.GENERATE(
            prompt => p_pergunta, action => 'narrate', profile_name => 'GENAI_PROFILE'
        );

    ELSIF v_tipo = 'RAG' THEN
        ----------------------------------------------------------------
        v_contexto := VB_BUSCAR_CONTEXTO(p_pergunta, NULL, 3);
        v_resposta := DBMS_CLOUD_AI.GENERATE(
            prompt => 'Com base no contexto abaixo, responda a pergunta de forma direta e objetiva.' || CHR(10) ||
                       'Contexto:' || CHR(10) || v_contexto || CHR(10) ||
                       'Pergunta: ' || p_pergunta,
            action => 'chat', profile_name => 'GENAI_PROFILE'
        );

    ELSIF v_tipo = 'HIBRIDO_HOSPITAL' THEN
        ----------------------------------------------------------------
        v_codigo := VB_RESOLVER_HOSPITAL(v_entidade);
        v_pergunta_reescrita := REPLACE(p_pergunta, v_entidade, 'hospital com CNES ' || v_codigo);
        v_resposta := DBMS_CLOUD_AI.GENERATE(
            prompt => v_pergunta_reescrita, action => 'narrate', profile_name => 'GENAI_PROFILE'
        );

    ELSIF v_tipo = 'HIBRIDO_DIAGNOSTICO' THEN
        ----------------------------------------------------------------
        v_codigo := VB_RESOLVER_DIAGNOSTICO(v_entidade);
        v_pergunta_reescrita := REPLACE(p_pergunta, v_entidade, 'diagnóstico com código CID ' || v_codigo);
        v_resposta := DBMS_CLOUD_AI.GENERATE(
            prompt => v_pergunta_reescrita, action => 'narrate', profile_name => 'GENAI_PROFILE'
        );

    ELSE
        v_resposta := 'Categoria não reconhecida: ' || v_tipo;
    END IF;

    RETURN v_resposta;
END;
/

--------------------------------------------------------------------------------
-- 3. TESTES -- rodem um de cada vez, para não estourar 40 chamadas/min
--------------------------------------------------------------------------------

SELECT VB_ROTEADOR('Quantas internações SP teve em 2024?') FROM dual;

-- SELECT VB_ROTEADOR('O que significa taxa de permanência hospitalar?') FROM dual;

-- SELECT VB_ROTEADOR('Quantas internações teve no Hospital das Clínicas do FMUSP?') FROM dual;

-- SELECT VB_ROTEADOR('Quantos casos de diarreia foram registrados?') FROM dual;

--------------------------------------------------------------------------------
-- FIM
--------------------------------------------------------------------------------
