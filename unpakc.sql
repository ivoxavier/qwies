SELECT * FROM shippingdev.manifest;



WITH RECURSIVE numbers AS (
  -- 1. Cria uma tabela temporária de números (de 1 a 100 neste caso).
  --    Isto assume que não terá mais de 100 IDs numa única string.
  SELECT 1 AS n
  UNION ALL
  SELECT n + 1 FROM numbers WHERE n < 100
)
SELECT
  m.id AS manifest_id,
  -- 3. Extrai o n-ésimo ID da string.
  --    A função SUBSTRING_INDEX é usada duas vezes para isolar cada ID.
  SUBSTRING_INDEX(SUBSTRING_INDEX(m.shipIDs, ',', n.n), ',', -1) AS shipID
FROM
  manifest m
-- 2. Junta a tabela manifest com a nossa tabela de números.
--    A condição do JOIN garante que só criamos tantas linhas quantos forem os IDs na string.
JOIN
  numbers n ON CHAR_LENGTH(m.shipIDs) - CHAR_LENGTH(REPLACE(m.shipIDs, ',', '')) >= n.n - 1
WHERE
  m.id = 1; -- <--- Altere este ID para o manifesto que quer ver


-- ====================================================================
-- Versão da consulta para ver o resultado para TODAS as linhas da
-- tabela manifest de uma só vez.
-- ====================================================================

WITH RECURSIVE numbers AS (
  SELECT 1 AS n
  UNION ALL
  SELECT n + 1 FROM numbers WHERE n < 100
)
SELECT
  m.id AS manifest_id,
  SUBSTRING_INDEX(SUBSTRING_INDEX(m.shipIDs, ',', n.n), ',', -1) AS shipID
FROM
  manifest m
JOIN
  numbers n ON CHAR_LENGTH(m.shipIDs) - CHAR_LENGTH(REPLACE(m.shipIDs, ',', '')) >= n.n - 1
ORDER BY
  m.id, CAST(shipID AS UNSIGNED);


