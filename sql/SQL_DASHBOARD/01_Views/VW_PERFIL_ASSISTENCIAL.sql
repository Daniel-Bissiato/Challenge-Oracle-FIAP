CREATE OR REPLACE FORCE EDITIONABLE VIEW "ADMIN"."VW_PERFIL_ASSISTENCIAL" ("NOME_UF", "ANO", "TOTAL_INTERNACOES", "INTERNACOES_POR_LEITO", "LEITOS_POR_10K_HAB", "MEDIA_PERMANENCIA_ANO", "UTI_SUS_100K", "INDICE_PRESSAO_ASSISTENCIAL", "PERFIL_ASSISTENCIAL") DEFAULT COLLATION "USING_NLS_COMP"  AS 
  WITH BASE AS (
    SELECT
        D.NOME_UF,
        D.ANO,
        D.TOTAL_INTERNACOES,
        D.INTERNACOES_POR_LEITO,
        D.LEITOS_POR_10K_HAB,
        D.MEDIA_PERMANENCIA_ANO,
        I.UTI_SUS_100K
    FROM ADMIN.DATASET_UNIFICADO_UF_2023_2025 D
    LEFT JOIN ADMIN.VW_INDICADORES_TERRITORIAIS I
        ON I.NOME_UF = D.NOME_UF
       AND I.ANO = D.ANO
),
RANKS AS (
    SELECT
        B.*,
        PERCENT_RANK() OVER (
            PARTITION BY ANO
            ORDER BY TOTAL_INTERNACOES
        ) AS R_DEMANDA,
        PERCENT_RANK() OVER (
            PARTITION BY ANO
            ORDER BY INTERNACOES_POR_LEITO
        ) AS R_PRESSAO,
        PERCENT_RANK() OVER (
            PARTITION BY ANO
            ORDER BY MEDIA_PERMANENCIA_ANO
        ) AS R_PERMANENCIA,
        PERCENT_RANK() OVER (
            PARTITION BY ANO
            ORDER BY LEITOS_POR_10K_HAB
        ) AS R_CAPACIDADE,
        PERCENT_RANK() OVER (
            PARTITION BY ANO
            ORDER BY UTI_SUS_100K
        ) AS R_UTI
    FROM BASE B
),
SCORES AS (
    SELECT
        R.*,
        (
            0.35 * R_PRESSAO
          + 0.30 * R_DEMANDA
          + 0.20 * R_PERMANENCIA
          - 0.20 * R_CAPACIDADE
          - 0.15 * R_UTI
        ) AS SCORE_BRUTO
    FROM RANKS R
),
ESCALA AS (
    SELECT
        S.*,
        MIN(SCORE_BRUTO) OVER (
            PARTITION BY ANO
        ) AS MIN_SCORE,
        MAX(SCORE_BRUTO) OVER (
            PARTITION BY ANO
        ) AS MAX_SCORE
    FROM SCORES S
)
SELECT
    NOME_UF,
    ANO,
    TOTAL_INTERNACOES,
    INTERNACOES_POR_LEITO,
    LEITOS_POR_10K_HAB,
    MEDIA_PERMANENCIA_ANO,
    UTI_SUS_100K,
    ROUND(
        CASE
            WHEN MAX_SCORE = MIN_SCORE THEN 50
            ELSE (
                (SCORE_BRUTO - MIN_SCORE)
                / NULLIF(MAX_SCORE - MIN_SCORE, 0)
            ) * 100
        END,
        2
    ) AS INDICE_PRESSAO_ASSISTENCIAL,
    CASE
        WHEN MAX_SCORE = MIN_SCORE
            THEN 'Pressão Assistencial Intermediária'
        WHEN (
            (SCORE_BRUTO - MIN_SCORE)
            / NULLIF(MAX_SCORE - MIN_SCORE, 0)
        ) * 100 < 33.3333
            THEN 'Baixa Pressão Assistencial'
        WHEN (
            (SCORE_BRUTO - MIN_SCORE)
            / NULLIF(MAX_SCORE - MIN_SCORE, 0)
        ) * 100 < 66.6667
            THEN 'Pressão Assistencial Intermediária'
        ELSE 'Alta Pressão Assistencial'
    END AS PERFIL_ASSISTENCIAL
FROM ESCALA;
