CREATE OR REPLACE FORCE EDITIONABLE VIEW "ADMIN"."VW_EVOLUCAO_PERFIL_ASSISTENCIAL" ("PERFIL_ASSISTENCIAL", "QTD_UFS_2023", "QTD_UFS_2025", "VARIACAO_UFS", "TENDENCIA") DEFAULT COLLATION "USING_NLS_COMP"  AS 
  WITH CONTAGEM AS (
    SELECT
        PERFIL_ASSISTENCIAL,
        ANO,
        COUNT(*) AS QTD_UFS
    FROM ADMIN.VW_PERFIL_ASSISTENCIAL
    WHERE ANO IN (2023, 2025)
    GROUP BY
        PERFIL_ASSISTENCIAL,
        ANO
)

SELECT
    PERFIL_ASSISTENCIAL,

    NVL(
        MAX(CASE
            WHEN ANO = 2023 THEN QTD_UFS
        END),
        0
    ) AS QTD_UFS_2023,

    NVL(
        MAX(CASE
            WHEN ANO = 2025 THEN QTD_UFS
        END),
        0
    ) AS QTD_UFS_2025,

    NVL(
        MAX(CASE
            WHEN ANO = 2025 THEN QTD_UFS
        END),
        0
    )
    -
    NVL(
        MAX(CASE
            WHEN ANO = 2023 THEN QTD_UFS
        END),
        0
    ) AS VARIACAO_UFS,

    CASE
        WHEN
            NVL(MAX(CASE
                WHEN ANO = 2025 THEN QTD_UFS
            END), 0)
            >
            NVL(MAX(CASE
                WHEN ANO = 2023 THEN QTD_UFS
            END), 0)
        THEN 'CRESCENTE'

        WHEN
            NVL(MAX(CASE
                WHEN ANO = 2025 THEN QTD_UFS
            END), 0)
            <
            NVL(MAX(CASE
                WHEN ANO = 2023 THEN QTD_UFS
            END), 0)
        THEN 'DECRESCENTE'

        ELSE 'ESTAVEL'
    END AS TENDENCIA

FROM CONTAGEM

GROUP BY
    PERFIL_ASSISTENCIAL;
