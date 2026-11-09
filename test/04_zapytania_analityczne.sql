/*
 Pomiar wydajnosci (tabela 10): 360 wizyt, 36/360 wierszy wynikowych,
 trzy pomiary dla kazdego zapytania.
*/
USE PoradniaDB_test;
GO
SET NOCOUNT ON;
GO

-- Sprawdzenie wielkosci probki.
SELECT COUNT(*) AS Wizyty_I_VI_2025
FROM dbo.vw_FactWizyty
WHERE DataWizyty >= '20250101' AND DataWizyty < '20250701';
GO

-- Uruchomienie wstepne obu zapytan, poza pomiarami wlasciwymi.
SET STATISTICS TIME OFF;
GO

PRINT 'A - URUCHOMIENIE WSTEPNE';

SELECT f.Rok, f.Miesiac, f.SpecjalizacjaID, f.Specjalizacja,
       COUNT(*) AS LiczbaWizyt
FROM dbo.vw_FactWizyty AS f
WHERE f.DataWizyty >= '20250101'
  AND f.DataWizyty < '20250701'
GROUP BY f.Rok, f.Miesiac, f.SpecjalizacjaID, f.Specjalizacja
ORDER BY f.Rok, f.Miesiac, f.SpecjalizacjaID;
GO

PRINT 'B - URUCHOMIENIE WSTEPNE';

SELECT f.*
FROM dbo.vw_FactWizyty AS f
WHERE f.DataWizyty >= '20250101'
  AND f.DataWizyty < '20250701'
ORDER BY f.WizytaID;
GO

-- Zapytanie A: 6 miesiecy x 6 specjalizacji (oczekiwane 36 grup dla danych pracy).
-- Zapytanie B: szczegoly wszystkich 360 wizyt w I polroczu.
SET STATISTICS TIME ON;
GO

PRINT 'A - TRZY POMIARY WLASCIWE';
DECLARE @PowtorzenieA INT = 1;
WHILE @PowtorzenieA <= 3
BEGIN
    PRINT CONCAT('A - pomiar ', @PowtorzenieA);
    SELECT f.Rok, f.Miesiac, f.SpecjalizacjaID, f.Specjalizacja,
           COUNT(*) AS LiczbaWizyt
    FROM dbo.vw_FactWizyty AS f
    WHERE f.DataWizyty >= '20250101' AND f.DataWizyty < '20250701'
    GROUP BY f.Rok, f.Miesiac, f.SpecjalizacjaID, f.Specjalizacja
    ORDER BY f.Rok, f.Miesiac, f.SpecjalizacjaID;
    SET @PowtorzenieA += 1;
END;
GO

PRINT 'B - TRZY POMIARY WLASCIWE';
DECLARE @PowtorzenieB INT = 1;
WHILE @PowtorzenieB <= 3
BEGIN
    PRINT CONCAT('B - pomiar ', @PowtorzenieB);
    SELECT f.*
    FROM dbo.vw_FactWizyty AS f
    WHERE f.DataWizyty >= '20250101' AND f.DataWizyty < '20250701'
    ORDER BY f.WizytaID;
    SET @PowtorzenieB += 1;
END;
GO

SET STATISTICS TIME OFF;
GO
