/*
 5 podstawowych scenariuszy integralnosci diagnoz, opisanych w podrozdziale 3.2.
 Uruchomienie w kopii bazy PoradniaDB_test. Zmiany sa wycofywane.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

IF DB_NAME() <> N'PoradniaDB_test'
    THROW 54001, N'Wybierz testowa kopie bazy o nazwie PoradniaDB_test w SSMS.', 1;
IF @@TRANCOUNT <> 0
    THROW 54002, N'Uruchom skrypt w nowym oknie bez aktywnej transakcji.', 1;

-- Weryfikacja wszystkich wymaganych mechanizmow przed testami.
IF EXISTS (
    SELECT 1 FROM (VALUES
      (N'trg_Diagnoza_Specjalizacja', N'Diagnoza', N'UPDATE'),
      (N'trg_Diagnoza_Status', N'Diagnoza', N'UPDATE'),
      (N'trg_Wizyta_DiagnozaIntegralnosc', N'Wizyta', N'UPDATE'),
      (N'trg_SpecjalizacjaICD10_Integralnosc', N'SpecjalizacjaICD10', N'DELETE'),
      (N'trg_SpecjalizacjaICD10_Integralnosc', N'SpecjalizacjaICD10', N'UPDATE')
    ) req(TriggerName, TableName, EventName)
    WHERE NOT EXISTS (
        SELECT 1
        FROM sys.triggers t
        JOIN sys.trigger_events e ON e.object_id = t.object_id
        WHERE t.name = req.TriggerName
          AND t.parent_id = OBJECT_ID(N'dbo.' + req.TableName, N'U')
          AND t.is_disabled = 0
          AND e.type_desc = req.EventName
    )
)
    THROW 54003, N'Brak wymaganego aktywnego wyzwalacza lub obslugi UPDATE/DELETE. Najpierw wdroz poprawki.', 1;

CREATE TABLE #Wyniki (
    TestNr INT NOT NULL PRIMARY KEY,
    Scenariusz NVARCHAR(120) NOT NULL,
    Wynik NVARCHAR(20) NOT NULL,
    OtrzymanyBlad INT NULL,
    Szczegoly NVARCHAR(500) NOT NULL
);

DECLARE @WizytaID INT, @DrugaWizytaID INT, @ICD10ID INT,
        @NowyICD10ID INT, @SpecjalizacjaID INT, @InnaSpecjalizacjaID INT,
        @LekarzID INT, @Err INT, @Msg NVARCHAR(500);

/* T1. Nieprawidlowy kod ICD-10: oczekiwany THROW 50018. */
SET @WizytaID = NULL; SET @NowyICD10ID = NULL;
SELECT TOP (1) @WizytaID = d.WizytaID, @NowyICD10ID = ic.ICD10ID
FROM dbo.Diagnoza d
JOIN dbo.Wizyta w ON w.WizytaID = d.WizytaID
CROSS JOIN dbo.ICD10 ic
WHERE ic.ICD10ID <> d.ICD10ID
  AND NOT EXISTS (
      SELECT 1 FROM dbo.SpecjalizacjaICD10 si
      WHERE si.SpecjalizacjaID = w.SpecjalizacjaID
        AND si.ICD10ID = ic.ICD10ID
  )
ORDER BY d.WizytaID, ic.ICD10ID;
IF @WizytaID IS NULL
    INSERT #Wyniki VALUES (1, N'Nieprawidlowy kod ICD-10', N'BRAK DANYCH', NULL, N'Brak pary diagnoza - kod niezgodny.');
ELSE
BEGIN
    BEGIN TRY
        BEGIN TRAN;
        UPDATE dbo.Diagnoza SET ICD10ID = @NowyICD10ID WHERE WizytaID = @WizytaID;
        ROLLBACK;
        INSERT #Wyniki VALUES (1, N'Nieprawidlowy kod ICD-10', N'BLAD', NULL, N'Niepoprawna zmiana nie zostala odrzucona.');
    END TRY
    BEGIN CATCH
        SELECT @Err=ERROR_NUMBER(), @Msg=ERROR_MESSAGE();
        IF @@TRANCOUNT > 0 ROLLBACK;
        INSERT #Wyniki VALUES (1, N'Nieprawidlowy kod ICD-10', IIF(@Err=50018,N'OK',N'BLAD'), @Err, @Msg);
    END CATCH
END;

/* T2. Diagnoza do niezrealizowanej wizyty bez diagnozy: THROW 50019.
   Dobieramy kod ICD-10 zgodny ze specjalizacja docelowej wizyty,
   aby naruszyc tylko regule statusu. */
SET @WizytaID = NULL; SET @DrugaWizytaID = NULL;
SELECT TOP (1) @WizytaID=d.WizytaID, @DrugaWizytaID=w2.WizytaID
FROM dbo.Diagnoza d
CROSS JOIN dbo.Wizyta w2
WHERE w2.StatusWizytyID <> 2
  AND w2.WizytaID <> d.WizytaID
  AND NOT EXISTS (SELECT 1 FROM dbo.Diagnoza dx WHERE dx.WizytaID=w2.WizytaID)
  AND EXISTS (
      SELECT 1
      FROM dbo.SpecjalizacjaICD10 si
      WHERE si.SpecjalizacjaID = w2.SpecjalizacjaID
        AND si.ICD10ID = d.ICD10ID
  )
ORDER BY d.WizytaID, w2.WizytaID;
IF @WizytaID IS NULL
    INSERT #Wyniki VALUES (2, N'Diagnoza dla niezrealizowanej wizyty', N'BRAK DANYCH', NULL, N'Brak docelowej wizyty niezrealizowanej bez diagnozy, o specjalizacji zgodnej z istniejacym kodem ICD-10.');
ELSE
BEGIN
    BEGIN TRY
        BEGIN TRAN;
        UPDATE dbo.Diagnoza SET WizytaID=@DrugaWizytaID WHERE WizytaID=@WizytaID;
        ROLLBACK;
        INSERT #Wyniki VALUES (2, N'Diagnoza dla niezrealizowanej wizyty', N'BLAD', NULL, N'Niepoprawne przypisanie nie zostalo odrzucone.');
    END TRY
    BEGIN CATCH
        SELECT @Err=ERROR_NUMBER(), @Msg=ERROR_MESSAGE();
        IF @@TRANCOUNT > 0 ROLLBACK;
        INSERT #Wyniki VALUES (2, N'Diagnoza dla niezrealizowanej wizyty', IIF(@Err=50019,N'OK',N'BLAD'), @Err, @Msg);
    END CATCH
END;

/* T3. Zmiana statusu zrealizowanej wizyty z diagnoza: THROW 50030. */
SET @WizytaID = NULL;
SELECT TOP (1) @WizytaID=w.WizytaID
FROM dbo.Wizyta w
JOIN dbo.Diagnoza d ON d.WizytaID=w.WizytaID
WHERE w.StatusWizytyID=2
ORDER BY w.WizytaID;
IF @WizytaID IS NULL
    INSERT #Wyniki VALUES (3, N'Zmiana statusu wizyty z diagnoza', N'BRAK DANYCH', NULL, N'Brak zrealizowanej wizyty z diagnoza.');
ELSE
BEGIN
    BEGIN TRY
        BEGIN TRAN;
        UPDATE dbo.Wizyta SET StatusWizytyID=1 WHERE WizytaID=@WizytaID;
        ROLLBACK;
        INSERT #Wyniki VALUES (3, N'Zmiana statusu wizyty z diagnoza', N'BLAD', NULL, N'Niepoprawna zmiana statusu nie zostala odrzucona.');
    END TRY
    BEGIN CATCH
        SELECT @Err=ERROR_NUMBER(), @Msg=ERROR_MESSAGE();
        IF @@TRANCOUNT > 0 ROLLBACK;
        INSERT #Wyniki VALUES (3, N'Zmiana statusu wizyty z diagnoza', IIF(@Err=50030,N'OK',N'BLAD'), @Err, @Msg);
    END CATCH
END;

/* T4. Zmiana specjalizacji na niezgodna z diagnoza: THROW 50030.
   W razie potrzeby tworzymy w tej samej transakcji tymczasowe przypisanie
   specjalizacji do lekarza (takze zostanie cofniete). */
SET @WizytaID=NULL; SET @InnaSpecjalizacjaID=NULL; SET @LekarzID=NULL;
SELECT TOP (1)
  @WizytaID=w.WizytaID, @InnaSpecjalizacjaID=s.SpecjalizacjaID, @LekarzID=w.LekarzID
FROM dbo.Wizyta w
JOIN dbo.Diagnoza d ON d.WizytaID=w.WizytaID
CROSS JOIN dbo.Specjalizacja s
WHERE w.StatusWizytyID=2
  AND s.SpecjalizacjaID<>w.SpecjalizacjaID
  AND NOT EXISTS (
      SELECT 1 FROM dbo.SpecjalizacjaICD10 si
      WHERE si.SpecjalizacjaID=s.SpecjalizacjaID AND si.ICD10ID=d.ICD10ID
  )
ORDER BY CASE WHEN EXISTS (
      SELECT 1 FROM dbo.LekarzSpecjalizacja ls
      WHERE ls.LekarzID=w.LekarzID AND ls.SpecjalizacjaID=s.SpecjalizacjaID
    ) THEN 0 ELSE 1 END, w.WizytaID, s.SpecjalizacjaID;
IF @WizytaID IS NULL
    INSERT #Wyniki VALUES (4, N'Zmiana specjalizacji niezgodna z diagnoza', N'BRAK DANYCH', NULL, N'Brak odpowiedniego wariantu specjalizacji.');
ELSE
BEGIN
    BEGIN TRY
        BEGIN TRAN;
        IF NOT EXISTS (
            SELECT 1 FROM dbo.LekarzSpecjalizacja
            WHERE LekarzID=@LekarzID AND SpecjalizacjaID=@InnaSpecjalizacjaID
        )
            INSERT dbo.LekarzSpecjalizacja(LekarzID,SpecjalizacjaID)
            VALUES (@LekarzID,@InnaSpecjalizacjaID);
        UPDATE dbo.Wizyta SET SpecjalizacjaID=@InnaSpecjalizacjaID WHERE WizytaID=@WizytaID;
        ROLLBACK;
        INSERT #Wyniki VALUES (4, N'Zmiana specjalizacji niezgodna z diagnoza', N'BLAD', NULL, N'Niepoprawna zmiana specjalizacji nie zostala odrzucona.');
    END TRY
    BEGIN CATCH
        SELECT @Err=ERROR_NUMBER(), @Msg=ERROR_MESSAGE();
        IF @@TRANCOUNT > 0 ROLLBACK;
        INSERT #Wyniki VALUES (4, N'Zmiana specjalizacji niezgodna z diagnoza', IIF(@Err=50030,N'OK',N'BLAD'), @Err, @Msg);
    END CATCH
END;

/* T5. Usuniecie wykorzystywanego mapowania: THROW 50031. */
SET @SpecjalizacjaID=NULL; SET @ICD10ID=NULL;
SELECT TOP (1) @SpecjalizacjaID=w.SpecjalizacjaID, @ICD10ID=d.ICD10ID
FROM dbo.Wizyta w
JOIN dbo.Diagnoza d ON d.WizytaID=w.WizytaID
JOIN dbo.SpecjalizacjaICD10 si ON si.SpecjalizacjaID=w.SpecjalizacjaID AND si.ICD10ID=d.ICD10ID
ORDER BY w.WizytaID;
IF @SpecjalizacjaID IS NULL
    INSERT #Wyniki VALUES (5, N'Usuniecie uzywanego mapowania ICD-10', N'BRAK DANYCH', NULL, N'Brak mapowania wykorzystywanego przez diagnoze.');
ELSE
BEGIN
    BEGIN TRY
        BEGIN TRAN;
        DELETE FROM dbo.SpecjalizacjaICD10
        WHERE SpecjalizacjaID=@SpecjalizacjaID AND ICD10ID=@ICD10ID;
        ROLLBACK;
        INSERT #Wyniki VALUES (5, N'Usuniecie uzywanego mapowania ICD-10', N'BLAD', NULL, N'Usuniecie nie zostalo odrzucone.');
    END TRY
    BEGIN CATCH
        SELECT @Err=ERROR_NUMBER(), @Msg=ERROR_MESSAGE();
        IF @@TRANCOUNT > 0 ROLLBACK;
        INSERT #Wyniki VALUES (5, N'Usuniecie uzywanego mapowania ICD-10', IIF(@Err=50031,N'OK',N'BLAD'), @Err, @Msg);
    END CATCH
END;

SELECT TestNr, Scenariusz, Wynik, OtrzymanyBlad, Szczegoly
FROM #Wyniki
ORDER BY TestNr;

SELECT
    COUNT(*) AS LiczbaTestow,
    SUM(CASE WHEN Wynik=N'OK' THEN 1 ELSE 0 END) AS Zaliczone,
    SUM(CASE WHEN Wynik=N'BLAD' THEN 1 ELSE 0 END) AS Niezaliczone,
    SUM(CASE WHEN Wynik=N'BRAK DANYCH' THEN 1 ELSE 0 END) AS Nieprzeprowadzone
FROM #Wyniki;

DROP TABLE #Wyniki;
