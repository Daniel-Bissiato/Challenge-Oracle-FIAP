CREATE OR REPLACE EDITIONABLE PROCEDURE "ADMIN"."PRC_OES_VALIDAR_CONSULTA" (
    P_PERGUNTA     IN  VARCHAR2,
    P_INTENCAO     IN  VARCHAR2,

    P_STATUS       OUT VARCHAR2,
    P_REGRA        OUT VARCHAR2,
    P_MOTIVO       OUT VARCHAR2
)
AUTHID DEFINER
AS
    V_PERGUNTA VARCHAR2(32767);
    V_INTENCAO VARCHAR2(200);
BEGIN

    V_PERGUNTA := TRIM(P_PERGUNTA);
    V_INTENCAO := UPPER(TRIM(P_INTENCAO));

    /* =========================
       1. VALIDAÇÃO BÁSICA
       ========================= */

    IF V_PERGUNTA IS NULL THEN
        P_STATUS := 'BLOQUEADO';
        P_REGRA  := 'PERGUNTA_VAZIA';
        P_MOTIVO := 'A consulta não contém uma pergunta válida.';
        RETURN;
    END IF;


    /* =========================
       2. REGRAS DSS05 CADASTRADAS
       ========================= */

    FOR R IN (
        SELECT
            CODIGO_REGRA,
            PADRAO,
            ACAO
        FROM ADMIN.OES_POLITICA_CONSULTA
        WHERE ATIVA = 'S'
          AND TIPO_REGRA = 'BLOQUEIO'
          AND PADRAO IS NOT NULL
    )
    LOOP

        IF REGEXP_LIKE(
            V_PERGUNTA,
            R.PADRAO,
            'i'
        )
        THEN

            P_STATUS := 'BLOQUEADO';
            P_REGRA  := R.CODIGO_REGRA;
            P_MOTIVO :=
                'A consulta foi bloqueada por uma política de segurança DSS05.';

            RETURN;

        END IF;

    END LOOP;


    /* =========================
       3. ESCOPO OFICIAL
       DATA FORGE
       ========================= */

    IF V_INTENCAO NOT IN (
        'DIAGNOSTICO',
        'SOBRECARGA',
        'CAPACIDADE',
        'COMPARACAO',
        'PRIORIZACAO',
        'REALOCACAO',
        'RISCO',
        'CAUSA',
        'EXPLICACAO',
        'EVOLUCAO',
        'OBITOS',
        'MORTALIDADE',
        'HOSPITAL',
        'CNES'
    )
    THEN

        P_STATUS := 'FORA_ESCOPO';
        P_REGRA  := 'ESCOPO_ANALITICO';
        P_MOTIVO :=
            'A intenção identificada não pertence ao escopo analítico autorizado do Data Forge.';

        RETURN;

    END IF;


    /* =========================
       4. CONSULTA AUTORIZADA
       ========================= */

    P_STATUS := 'PERMITIDO';
    P_REGRA  := 'DSS05_VALIDADO';
    P_MOTIVO :=
        'Consulta validada pelas políticas de segurança e escopo do Data Forge.';

END;;
