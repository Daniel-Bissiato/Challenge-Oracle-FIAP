CREATE OR REPLACE FORCE EDITIONABLE VIEW "ADMIN"."VW_SIMULACAO_SUBUTILIZACAO" ("NOME_UF", "ANO", "PERFIL_ASSISTENCIAL", "INDICE_PRESSAO_ASSISTENCIAL", "TOTAL_INTERNACOES", "LEITOS_SUS_CNES", "LEITOS_POR_10K_HAB", "UTI_SUS_100K", "INTERNACOES_POR_LEITO", "PONTO_PRESSAO", "PONTO_DEMANDA", "PONTO_LEITOS", "PONTO_UTI", "SCORE_SUBUTILIZACAO", "SCORE_CAPACIDADE", "CENARIO_SUBUTILIZACAO", "RANK_MAIOR_CAPACIDADE", "RANK_MENOR_CAPACIDADE") DEFAULT COLLATION "USING_NLS_COMP"  AS 
  WITH BASE AS (
    SELECT
        NOME_UF,
        ANO,
        PERFIL_ASSISTENCIAL,
        INDICE_PRESSAO_ASSISTENCIAL,
        TOTAL_INTERNACOES,
        LEITOS_SUS_CNES,
        LEITOS_POR_10K_HAB,
        UTI_SUS_100K,
        INTERNACOES_POR_LEITO
    FROM ADMIN.VW_PERFIL_ATENDIMENTO
),

LIMITES AS (
    SELECT
        ANO,

        PERCENTILE_CONT(0.50)
            WITHIN GROUP (
                ORDER BY INDICE_PRESSAO_ASSISTENCIAL
            ) AS MED_PRESSAO,

        PERCENTILE_CONT(0.50)
            WITHIN GROUP (
                ORDER BY INTERNACOES_POR_LEITO
            ) AS MED_DEMANDA_LEITO,

        PERCENTILE_CONT(0.50)
            WITHIN GROUP (
                ORDER BY LEITOS_POR_10K_HAB
            ) AS MED_LEITOS_10K,

        PERCENTILE_CONT(0.50)
            WITHIN GROUP (
                ORDER BY UTI_SUS_100K
            ) AS MED_UTI_100K

    FROM BASE
    GROUP BY ANO
),

PONTOS AS (
    SELECT
        B.NOME_UF,
        B.ANO,
        B.PERFIL_ASSISTENCIAL,
        B.INDICE_PRESSAO_ASSISTENCIAL,
        B.TOTAL_INTERNACOES,
        B.LEITOS_SUS_CNES,
        B.LEITOS_POR_10K_HAB,
        B.UTI_SUS_100K,
        B.INTERNACOES_POR_LEITO,

        CASE
            WHEN B.INDICE_PRESSAO_ASSISTENCIAL < L.MED_PRESSAO
            THEN 1
            ELSE 0
        END AS PONTO_PRESSAO,

        CASE
            WHEN B.INTERNACOES_POR_LEITO < L.MED_DEMANDA_LEITO
            THEN 1
            ELSE 0
        END AS PONTO_DEMANDA,

        CASE
            WHEN B.LEITOS_POR_10K_HAB > L.MED_LEITOS_10K
            THEN 1
            ELSE 0
        END AS PONTO_LEITOS,

        CASE
            WHEN B.UTI_SUS_100K > L.MED_UTI_100K
            THEN 1
            ELSE 0
        END AS PONTO_UTI

    FROM BASE B

    INNER JOIN LIMITES L
        ON L.ANO = B.ANO
),

SCORES AS (
    SELECT
        P.*,

        (
            P.PONTO_PRESSAO
            + P.PONTO_DEMANDA
            + P.PONTO_LEITOS
            + P.PONTO_UTI
        ) AS SCORE_SUBUTILIZACAO

    FROM PONTOS P
),

CLASSIFICACAO AS (
    SELECT
        S.*,

        /*
        Nome amigável utilizado pelo dashboard / Select AI.

        É o mesmo score analítico da oportunidade de capacidade,
        variando de 0 a 4.

        Não representa percentual de capacidade.
        */
        S.SCORE_SUBUTILIZACAO AS SCORE_CAPACIDADE,

        CASE
            WHEN S.SCORE_SUBUTILIZACAO = 4
                THEN 'SUBUTILIZACAO ELEVADA'

            WHEN S.SCORE_SUBUTILIZACAO = 3
                THEN 'SUBUTILIZACAO PROVAVEL'

            WHEN S.SCORE_SUBUTILIZACAO = 2
                THEN 'ATENCAO'

            ELSE 'SEM SINAL RELEVANTE'
        END AS CENARIO_SUBUTILIZACAO

    FROM SCORES S
)

SELECT
    C.NOME_UF,
    C.ANO,
    C.PERFIL_ASSISTENCIAL,
    C.INDICE_PRESSAO_ASSISTENCIAL,
    C.TOTAL_INTERNACOES,
    C.LEITOS_SUS_CNES,
    C.LEITOS_POR_10K_HAB,
    C.UTI_SUS_100K,
    C.INTERNACOES_POR_LEITO,

    C.PONTO_PRESSAO,
    C.PONTO_DEMANDA,
    C.PONTO_LEITOS,
    C.PONTO_UTI,

    C.SCORE_SUBUTILIZACAO,
    C.SCORE_CAPACIDADE,
    C.CENARIO_SUBUTILIZACAO,

    /*
    1 = maior oportunidade/capacidade relativa no ano.

    Critério:
    1. Score maior
    2. Mais leitos por 10 mil
    3. Mais UTI por 100 mil
    */
    ROW_NUMBER() OVER (
        PARTITION BY C.ANO
        ORDER BY
            C.SCORE_CAPACIDADE DESC,
            C.LEITOS_POR_10K_HAB DESC,
            C.UTI_SUS_100K DESC,
            C.NOME_UF ASC
    ) AS RANK_MAIOR_CAPACIDADE,

    /*
    1 = menor oportunidade/capacidade relativa no ano.

    Critério:
    1. Score menor
    2. Menos leitos por 10 mil
    3. Menos UTI por 100 mil
    */
    ROW_NUMBER() OVER (
        PARTITION BY C.ANO
        ORDER BY
            C.SCORE_CAPACIDADE ASC,
            C.LEITOS_POR_10K_HAB ASC,
            C.UTI_SUS_100K ASC,
            C.NOME_UF ASC
    ) AS RANK_MENOR_CAPACIDADE

FROM CLASSIFICACAO C;
