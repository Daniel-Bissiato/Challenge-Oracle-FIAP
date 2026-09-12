--------------------------------------------------------------------------------
-- CORREÇÃO -- VIEW HOSPITAIS_UNICOS INFLAVA SOMAS EM JOIN
--------------------------------------------------------------------------------
-- SINTOMA: "Quantas internações SP teve em 2024?" via NL2SQL (Select AI)
-- retornava 3.036.256, mas a mesma pergunta batida contra a tabela já
-- processada dataset_unificado_uf.csv dava 2.801.472 -- uma diferença de
-- ~235 mil internações (8,4%).
--
-- CAUSA RAIZ: a view HOSPITAIS_UNICOS usava:
--
--     SELECT DISTINCT CNES, NOME_ESTABELECIMENTO, UF, MUNICIPIO
--     FROM ADMIN.CNES_LEITOS
--
-- CNES_LEITOS tem uma linha por hospital POR MÊS (competência). 750 dos
-- 7.686 hospitais do Brasil mudaram de NOME_ESTABELECIMENTO em algum
-- momento entre 2023-2025 (ex: variação de cadastro do próprio Hospital
-- das Clínicas da FMUSP). Como o DISTINCT considera a combinação inteira
-- de colunas, cada nome diferente que um CNES já teve virava uma linha
-- "única" própria -- ou seja, a view NÃO garantia 1 linha por hospital,
-- apesar do nome sugerir isso.
--
-- Ao fazer INNER JOIN dessa view com a tabela de fatos por CNES, cada
-- hospital com nome duplicado teve suas internações contadas mais de uma
-- vez (uma vez por linha duplicada que batia no join).
--
-- IMPACTO MEDIDO: 115 hospitais de SP apareciam duplicados na view (8
-- deles triplicados), totalizando 123 linhas "extras" -- suficiente para
-- explicar a diferença de ~235 mil internações encontrada.
--------------------------------------------------------------------------------

CREATE OR REPLACE FORCE EDITIONABLE VIEW "ADMIN"."HOSPITAIS_UNICOS"
    ("CNES", "NOME_ESTABELECIMENTO", "UF", "MUNICIPIO") AS
SELECT CNES, NOME_ESTABELECIMENTO, UF, MUNICIPIO
FROM (
    SELECT CNES, NOME_ESTABELECIMENTO, UF, MUNICIPIO,
           ROW_NUMBER() OVER (PARTITION BY CNES ORDER BY COMP DESC) AS rn
    FROM ADMIN.CNES_LEITOS
)
WHERE rn = 1;

COMMENT ON TABLE "ADMIN"."HOSPITAIS_UNICOS" IS
'View com EXATAMENTE um hospital por linha (um CNES = uma linha, usando o
nome mais recente por COMP). Use esta view para JOIN com nome do
estabelecimento -- CNES_LEITOS tem múltiplas linhas por hospital
(competência/mês) e pode ter mais de um NOME_ESTABELECIMENTO histórico
por CNES; um DISTINCT simples não deduplica de verdade nesse caso.';

--------------------------------------------------------------------------------
-- Validação pós-correção
--------------------------------------------------------------------------------
-- Deve retornar total_linhas = cnes_distintos = 1092
SELECT COUNT(*) AS total_linhas, COUNT(DISTINCT CNES) AS cnes_distintos
FROM HOSPITAIS_UNICOS
WHERE UPPER(UF) = 'SP';
