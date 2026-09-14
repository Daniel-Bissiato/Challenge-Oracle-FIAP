CREATE OR REPLACE FORCE EDITIONABLE VIEW "ADMIN"."VW_PERFIL_ASSISTENCIAL_V2" ("NOME_UF", "ANO", "TOTAL_INTERNACOES", "INTERNACOES_POR_LEITO", "LEITOS_POR_10K_HAB", "MEDIA_PERMANENCIA_ANO", "LEITOS_UTI_TOTAL", "INDICE_PRESSAO_ASSISTENCIAL", "PERFIL_ASSISTENCIAL") DEFAULT COLLATION "USING_NLS_COMP"  AS 
  WITH BASE AS (
    SELECT
        NOME_UF,
        ANO,
        TOTAL_INTERNACOES,
        INTERNACOES_POR_LEITO,
        LEITOS_POR_10K_HAB,
        MEDIA_PERMANENCIA_ANO,
        LEITOS_UTI_TOTAL
    FROM ADMIN.DATASET_UNIFICADO_UF_2023_2025
),
RANKS AS (
    SELECT
        BASE.*,

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
            ORDER BY LEITOS_UTI_TOTAL
        ) AS R_UTI

    FROM BASE
),
SCORES AS (
    SELECT
        RANKS.*,

        (
            0.35 * R_PRESSAO
            + 0.30 * R_DEMANDA
            + 0.20 * R_PERMANENCIA
            - 0.20 * R_CAPACIDADE
            - 0.15 * R_UTI
        ) AS SCORE_BRUTO

    FROM RANKS
),
ESCALA AS (
    SELECT
        SCORES.*,

        MIN(SCORE_BRUTO) OVER (
            PARTITION BY ANO
        ) AS MIN_SCORE,

        MAX(SCORE_BRUTO) OVER (
            PARTITION BY ANO
        ) AS MAX_SCORE

    FROM SCORES
)
SELECT
    NOME_UF,
    ANO,
    TOTAL_INTERNACOES,
    INTERNACOES_POR_LEITO,
    LEITOS_POR_10K_HAB,
    MEDIA_PERMANENCIA_ANO,
    LEITOS_UTI_TOTAL,

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
        WHEN MAX_SCORE = MIN_SCORE THEN
            'Pressão Assistencial Intermediária'

        WHEN (
            (SCORE_BRUTO - MIN_SCORE)
            / NULLIF(MAX_SCORE - MIN_SCORE, 0)
        ) * 100 < 33.3333 THEN
            'Baixa Pressão Assistencial'

        WHEN (
            (SCORE_BRUTO - MIN_SCORE)
            / NULLIF(MAX_SCORE - MIN_SCORE, 0)
        ) * 100 < 66.6667 THEN
            'Pressão Assistencial Intermediária'

        ELSE
            'Alta Pressão Assistencial'
    END AS PERFIL_ASSISTENCIAL

FROM ESCALA;
