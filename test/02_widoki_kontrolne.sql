/*
 Testy negatywne T1-T5 z tabeli 9, podrozdzial 3.3.
 T4 dostosowano do aktualnego ograniczenia CHECK.
 Wszystkie zmiany w transakcjach sa wycofywane.
*/
USE PoradniaDB_test;
GO
SET NOCOUNT ON;
IF @@TRANCOUNT <> 0
    THROW 51080, 'Uruchom skrypt bez aktywnej transakcji.', 1;
GO

-- T1: Zrealizowana wizyta bez diagnozy.
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @WizytaT1 INT;
    SELECT TOP (1) @WizytaT1 = w.WizytaID
    FROM dbo.Wizyta AS w
    INNER JOIN dbo.Diagnoza AS d ON d.WizytaID = w.WizytaID
    WHERE w.StatusWizytyID = 2
    ORDER BY w.WizytaID;

    IF @WizytaT1 IS NULL
        THROW 51001, 'T1: Brak zrealizowanej wizyty z diagnoza.', 1;

    DELETE FROM dbo.Diagnoza WHERE WizytaID = @WizytaT1;

    SELECT 'T1: Brak diagnozy' AS Test, @WizytaT1 AS WizytaID,
           CASE WHEN EXISTS (SELECT 1 FROM dbo.vw_WizytaBezDiagnozy
                             WHERE WizytaID = @WizytaT1)
                THEN 'ZGODNY: wykryto' ELSE 'NIEZGODNY: nie wykryto' END AS Wynik;
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    SELECT 'T1: Brak diagnozy' AS Test, 'BLAD TESTU' AS Wynik,
           ERROR_NUMBER() AS NumerBledu, ERROR_MESSAGE() AS Komunikat;
END CATCH;
GO

-- T2: Wizyta oznaczona jako oplacona, ale bez rekordu platnosci.
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @WizytaT2 INT;
    SELECT TOP (1) @WizytaT2 = w.WizytaID
    FROM dbo.Wizyta AS w
    INNER JOIN dbo.Platnosc AS p ON p.WizytaID = w.WizytaID
    WHERE w.StatusPlatnosciID = 2
    ORDER BY w.WizytaID;

    IF @WizytaT2 IS NULL
        THROW 51002, 'T2: Brak oplaconej wizyty z platnoscia.', 1;

    DELETE FROM dbo.Platnosc WHERE WizytaID = @WizytaT2;

    SELECT 'T2: Brak platnosci' AS Test, @WizytaT2 AS WizytaID,
           CASE WHEN EXISTS (SELECT 1 FROM dbo.vw_WizytaBezPlatnosci
                             WHERE WizytaID = @WizytaT2)
                THEN 'ZGODNY: wykryto' ELSE 'NIEZGODNY: nie wykryto' END AS Wynik;
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    SELECT 'T2: Brak platnosci' AS Test, 'BLAD TESTU' AS Wynik,
           ERROR_NUMBER() AS NumerBledu, ERROR_MESSAGE() AS Komunikat;
END CATCH;
GO

-- T3: Kwota platnosci rozna od biezacej ceny w cenniku.
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @PlatnoscT3 INT;
    SELECT TOP (1) @PlatnoscT3 = p.PlatnoscID
    FROM dbo.Platnosc AS p
    INNER JOIN dbo.Wizyta AS w ON w.WizytaID = p.WizytaID
    INNER JOIN dbo.Cennik AS c ON c.TypWizytyID = w.TypWizytyID
    WHERE p.Kwota = c.Kwota
    ORDER BY p.PlatnoscID;

    IF @PlatnoscT3 IS NULL
        THROW 51003, 'T3: Brak platnosci zgodnej z cennikiem.', 1;

    UPDATE dbo.Platnosc SET Kwota = Kwota + 1.00
    WHERE PlatnoscID = @PlatnoscT3;

    SELECT 'T3: Kwota niezgodna z cennikiem' AS Test,
           @PlatnoscT3 AS PlatnoscID,
           CASE WHEN EXISTS (SELECT 1 FROM dbo.vw_PlatnoscNiezgodnaZCennikiem
                             WHERE PlatnoscID = @PlatnoscT3)
                THEN 'ZGODNY: wykryto' ELSE 'NIEZGODNY: nie wykryto' END AS Wynik;
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    SELECT 'T3: Kwota niezgodna z cennikiem' AS Test, 'BLAD TESTU' AS Wynik,
           ERROR_NUMBER() AS NumerBledu, ERROR_MESSAGE() AS Komunikat;
END CATCH;
GO

-- T4: Wizyta stacjonarna anulowana bez wplaty otrzymuje status "Zwrot".
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @WizytaT4 INT;
    SELECT TOP (1) @WizytaT4 = w.WizytaID
    FROM dbo.Wizyta AS w
    WHERE w.StatusWizytyID = 3
      AND w.TypWizytyID IN (1, 2)
      AND w.StatusPlatnosciID = 1
      AND NOT EXISTS (SELECT 1 FROM dbo.Platnosc AS p WHERE p.WizytaID = w.WizytaID)
    ORDER BY w.WizytaID;

    IF @WizytaT4 IS NULL
        THROW 51004, 'T4: Brak anulowanej nieoplaconej wizyty stacjonarnej.', 1;

    UPDATE dbo.Wizyta SET StatusPlatnosciID = 3
    WHERE WizytaID = @WizytaT4;

    SELECT 'T4: Zwrot bez wplaty' AS Test, @WizytaT4 AS WizytaID,
           CASE WHEN EXISTS (SELECT 1 FROM dbo.vw_NiespojnoscStatusow
                             WHERE WizytaID = @WizytaT4)
                THEN 'ZGODNY: wykryto' ELSE 'NIEZGODNY: nie wykryto' END AS Wynik;
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    SELECT 'T4: Zwrot bez wplaty' AS Test, 'BLAD TESTU' AS Wynik,
           ERROR_NUMBER() AS NumerBledu, ERROR_MESSAGE() AS Komunikat;
END CATCH;
GO

-- T5: Niepoprawny status anulowanej wizyty powinien byc zablokowany
-- przez CK_Wizyta_StatusLogiczny.
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @WizytaT5 INT;
    SELECT TOP (1) @WizytaT5 = WizytaID
    FROM dbo.Wizyta
    WHERE StatusWizytyID = 3
    ORDER BY WizytaID;

    IF @WizytaT5 IS NULL
        THROW 51006, 'T5: Brak anulowanej wizyty do testu CHECK.', 1;

    UPDATE dbo.Wizyta SET StatusPlatnosciID = 2
    WHERE WizytaID = @WizytaT5;

    SELECT 'T5: Odrzucenie przez CHECK' AS Test,
           'NIEZGODNY: baza zaakceptowala zabroniony status' AS Wynik;
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    DECLARE @NumerBleduT5 INT = ERROR_NUMBER();
    DECLARE @KomunikatT5 NVARCHAR(4000) = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    SELECT 'T5: Odrzucenie przez CHECK' AS Test,
           CASE WHEN @NumerBleduT5 = 547 AND @KomunikatT5 LIKE '%CK_Wizyta_StatusLogiczny%'
                THEN 'ZGODNY: CHECK odrzucil zmiane'
                WHEN @NumerBleduT5 BETWEEN 51000 AND 51099
                THEN 'BRAK DANYCH DO TESTU'
                ELSE 'DO ANALIZY: inny blad niz oczekiwany CHECK'
           END AS Wynik,
           @NumerBleduT5 AS NumerBledu,
           @KomunikatT5 AS Komunikat;
END CATCH;
GO

-- Po testach wszystkie celowe modyfikacje powinny byc wycofane.
-- Ponizszy odczyt nie zmienia bazy.
SELECT 'vw_WizytaBezDiagnozy' AS Widok, COUNT_BIG(*) AS LiczbaWierszy
FROM dbo.vw_WizytaBezDiagnozy
UNION ALL
SELECT 'vw_WizytaBezPlatnosci', COUNT_BIG(*) FROM dbo.vw_WizytaBezPlatnosci
UNION ALL
SELECT 'vw_NiespojnoscStatusow', COUNT_BIG(*) FROM dbo.vw_NiespojnoscStatusow
UNION ALL
SELECT 'vw_PlatnoscNiezgodnaZCennikiem', COUNT_BIG(*) FROM dbo.vw_PlatnoscNiezgodnaZCennikiem
UNION ALL
SELECT 'vw_WiecejNiz1Wizyta', COUNT_BIG(*) FROM dbo.vw_WiecejNiz1Wizyta;
GO

-- Koncowa kontrola liczebnosci i transakcji.
SELECT
    (SELECT COUNT(*) FROM dbo.Wizyta) AS Wizyty,
    (SELECT COUNT(*) FROM dbo.Platnosc) AS Platnosci,
    (SELECT COUNT(*) FROM dbo.Diagnoza) AS Diagnozy,
    @@TRANCOUNT AS OtwarteTransakcje;
GO
