/*
 Porownanie indeksow (rozdzial 3.3): 20.06.2025, odczyty logiczne.
*/
USE PoradniaDB_test;
GO
SET NOCOUNT ON;
SET STATISTICS IO ON;
GO

PRINT 'WARIANT A: wymuszony skan tabeli/indeksu klastrowego, INDEX(0)';
SELECT w.WizytaID, w.DataWizyty
FROM dbo.Wizyta AS w WITH (INDEX(0))
WHERE w.DataWizyty >= '20250620'
  AND w.DataWizyty <  '20250621'
OPTION (RECOMPILE);
GO

PRINT 'WARIANT B: dostep wybrany przez optymalizator - bez podpowiedzi indeksowej';
SELECT w.WizytaID, w.DataWizyty
FROM dbo.Wizyta AS w
WHERE w.DataWizyty >= '20250620'
  AND w.DataWizyty <  '20250621'
OPTION (RECOMPILE);
GO

SET STATISTICS IO OFF;
GO
