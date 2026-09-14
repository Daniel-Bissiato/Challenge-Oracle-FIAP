CREATE OR REPLACE FORCE EDITIONABLE VIEW "ADMIN"."VW_OES_PRIORIZACAO" ("NOME_UF", "ANO", "INDICE_PRESSAO_ASSISTENCIAL", "TOTAL_INTERNACOES", "INTERNACOES_POR_LEITO", "LEITOS_POR_10K_HAB", "UTI_SUS_100K", "SCORE_SOBRECARGA", "CENARIO_SOBRECARGA", "RANK_PRESSAO", "SCORE_CAPACIDADE", "CENARIO_CAPACIDADE", "RANK_MAIOR_CAPACIDADE", "RANK_MENOR_CAPACIDADE", "PONTO_PRESSAO_SOBRECARGA", "PONTO_DEMANDA_SOBRECARGA", "PONTO_LEITOS_SOBRECARGA", "PONTO_UTI_SOBRECARGA", "VARIACAO_PRESSAO_ANUAL", "VARIACAO_PRESSAO_PERIODO", "PONTOS_PRESSAO", "PONTOS_SOBRECARGA", "PONTOS_DEMANDA", "PONTOS_LEITOS", "PONTOS_UTI", "PONTOS_CAPACIDADE", "PONTOS_TENDENCIA", "SCORE_PRIORIDADE", "NIVEL_PRIORIDADE", "RANK_PRIORIDADE", "FATORES_RISCO", "FATORES_ATENUANTES", "FATORES_PRIORIZACAO", "JUSTIFICATIVA_PRIORIDADE", "CONTROLE_COBIT", "REGRA_OES") DEFAULT COLLATION "USING_NLS_COMP"  AS 
  WITH BASE AS (
    SELECT
        NOME_UF,
        ANO,

        INDICE_PRESSAO_ASSISTENCIAL,
        TOTAL_INTERNACOES,
        INTERNACOES_POR_LEITO,
        LEITOS_POR_10K_HAB,
        UTI_SUS_100K,

        SCORE_SOBRECARGA,
        CENARIO_SOBRECARGA,
        RANK_PRESSAO,

        SCORE_CAPACIDADE,
        CENARIO_CAPACIDADE,
        RANK_MAIOR_CAPACIDADE,
        RANK_MENOR_CAPACIDADE,

        PONTO_PRESSAO_SOBRECARGA,
        PONTO_DEMANDA_SOBRECARGA,
        PONTO_LEITOS_SOBRECARGA,
        PONTO_UTI_SOBRECARGA,

        VARIACAO_PRESSAO_ANUAL,
        VARIACAO_PRESSAO_PERIODO

    FROM ADMIN.VW_INTELIGENCIA_ASSISTENCIAL
),

COMPONENTES AS (
    SELECT
        B.*,

        CASE
            WHEN RANK_PRESSAO <= 5 THEN 2
            ELSE 0
        END AS PONTOS_PRESSAO,

        CASE
            WHEN SCORE_SOBRECARGA >= 3 THEN 2
            ELSE 0
        END AS PONTOS_SOBRECARGA,

        CASE
            WHEN PONTO_DEMANDA_SOBRECARGA = 1 THEN 1
            ELSE 0
        END AS PONTOS_DEMANDA,

        CASE
            WHEN PONTO_LEITOS_SOBRECARGA = 1 THEN 1
            ELSE 0
        END AS PONTOS_LEITOS,

        CASE
            WHEN PONTO_UTI_SOBRECARGA = 1 THEN 1
            ELSE 0
        END AS PONTOS_UTI,

        CASE
            WHEN RANK_MENOR_CAPACIDADE <= 5 THEN 2
            ELSE 0
        END AS PONTOS_CAPACIDADE,

        CASE
            WHEN VARIACAO_PRESSAO_ANUAL >= 10 THEN 2
            WHEN VARIACAO_PRESSAO_ANUAL >= 3 THEN 1
            WHEN VARIACAO_PRESSAO_ANUAL <= -10 THEN -1
            ELSE 0
        END AS PONTOS_TENDENCIA

    FROM BASE B
),

SCORE AS (
    SELECT
        C.*,

        (
            PONTOS_PRESSAO
          + PONTOS_SOBRECARGA
          + PONTOS_DEMANDA
          + PONTOS_LEITOS
          + PONTOS_UTI
          + PONTOS_CAPACIDADE
          + PONTOS_TENDENCIA
        ) AS SCORE_PRIORIDADE

    FROM COMPONENTES C
),

CLASSIFICACAO AS (
    SELECT
        S.*,

        CASE
            WHEN SCORE_PRIORIDADE >= 8 THEN 'PRIORIDADE_MUITO_ALTA'
            WHEN SCORE_PRIORIDADE >= 6 THEN 'PRIORIDADE_ALTA'
            WHEN SCORE_PRIORIDADE >= 4 THEN 'PRIORIDADE_MODERADA'
            ELSE 'PRIORIDADE_BAIXA'
        END AS NIVEL_PRIORIDADE

    FROM SCORE S
),

RANKING AS (
    SELECT
        C.*,

        ROW_NUMBER() OVER (
            PARTITION BY ANO
            ORDER BY
                SCORE_PRIORIDADE DESC,
                RANK_PRESSAO ASC,
                RANK_MENOR_CAPACIDADE ASC,
                NOME_UF ASC
        ) AS RANK_PRIORIDADE

    FROM CLASSIFICACAO C
)

SELECT
    R."NOME_UF",R."ANO",R."INDICE_PRESSAO_ASSISTENCIAL",R."TOTAL_INTERNACOES",R."INTERNACOES_POR_LEITO",R."LEITOS_POR_10K_HAB",R."UTI_SUS_100K",R."SCORE_SOBRECARGA",R."CENARIO_SOBRECARGA",R."RANK_PRESSAO",R."SCORE_CAPACIDADE",R."CENARIO_CAPACIDADE",R."RANK_MAIOR_CAPACIDADE",R."RANK_MENOR_CAPACIDADE",R."PONTO_PRESSAO_SOBRECARGA",R."PONTO_DEMANDA_SOBRECARGA",R."PONTO_LEITOS_SOBRECARGA",R."PONTO_UTI_SOBRECARGA",R."VARIACAO_PRESSAO_ANUAL",R."VARIACAO_PRESSAO_PERIODO",R."PONTOS_PRESSAO",R."PONTOS_SOBRECARGA",R."PONTOS_DEMANDA",R."PONTOS_LEITOS",R."PONTOS_UTI",R."PONTOS_CAPACIDADE",R."PONTOS_TENDENCIA",R."SCORE_PRIORIDADE",R."NIVEL_PRIORIDADE",R."RANK_PRIORIDADE",

    /* =========================
       FATORES QUE AUMENTAM RISCO
       ========================= */
    RTRIM(
          CASE
              WHEN PONTOS_PRESSAO > 0
              THEN 'alta pressão assistencial | '
              ELSE ''
          END

       || CASE
              WHEN PONTOS_SOBRECARGA > 0
              THEN 'sobrecarga estrutural elevada | '
              ELSE ''
          END

       || CASE
              WHEN PONTOS_DEMANDA > 0
              THEN 'demanda elevada | '
              ELSE ''
          END

       || CASE
              WHEN PONTOS_LEITOS > 0
              THEN 'baixa disponibilidade relativa de leitos | '
              ELSE ''
          END

       || CASE
              WHEN PONTOS_UTI > 0
              THEN 'baixa disponibilidade relativa de UTI | '
              ELSE ''
          END

       || CASE
              WHEN PONTOS_CAPACIDADE > 0
              THEN 'baixa capacidade relativa | '
              ELSE ''
          END

       || CASE
              WHEN PONTOS_TENDENCIA = 2
              THEN 'forte piora anual da pressão | '
              WHEN PONTOS_TENDENCIA = 1
              THEN 'piora anual da pressão | '
              ELSE ''
          END,

        ' |'
    ) AS FATORES_RISCO,

    /* =========================
       FATORES QUE ATENUAM RISCO
       ========================= */
    RTRIM(
        CASE
            WHEN PONTOS_TENDENCIA = -1
            THEN 'forte melhora anual da pressão | '
            ELSE ''
        END,
        ' |'
    ) AS FATORES_ATENUANTES,

    /* Mantido para compatibilidade */
    RTRIM(
          CASE
              WHEN PONTOS_PRESSAO > 0
              THEN 'alta pressão assistencial | '
              ELSE ''
          END

       || CASE
              WHEN PONTOS_SOBRECARGA > 0
              THEN 'sobrecarga estrutural elevada | '
              ELSE ''
          END

       || CASE
              WHEN PONTOS_DEMANDA > 0
              THEN 'demanda elevada | '
              ELSE ''
          END

       || CASE
              WHEN PONTOS_LEITOS > 0
              THEN 'baixa disponibilidade relativa de leitos | '
              ELSE ''
          END

       || CASE
              WHEN PONTOS_UTI > 0
              THEN 'baixa disponibilidade relativa de UTI | '
              ELSE ''
          END

       || CASE
              WHEN PONTOS_CAPACIDADE > 0
              THEN 'baixa capacidade relativa | '
              ELSE ''
          END

       || CASE
              WHEN PONTOS_TENDENCIA = 2
              THEN 'forte piora anual da pressão | '
              WHEN PONTOS_TENDENCIA = 1
              THEN 'piora anual da pressão | '
              WHEN PONTOS_TENDENCIA = -1
              THEN 'forte melhora anual da pressão | '
              ELSE ''
          END,

        ' |'
    ) AS FATORES_PRIORIZACAO,

    'Pressão: posição '
        || RANK_PRESSAO
        || ' de 27; capacidade desfavorável: posição '
        || RANK_MENOR_CAPACIDADE
        || ' de 27; score de sobrecarga: '
        || SCORE_SOBRECARGA
        || '/4; variação anual da pressão: '
        || ROUND(VARIACAO_PRESSAO_ANUAL, 2)
        || '.'
        AS JUSTIFICATIVA_PRIORIDADE,

    'APO12' AS CONTROLE_COBIT,

    'MITIGACAO_VIES_MULTIFATORIAL' AS REGRA_OES

FROM RANKING R;
