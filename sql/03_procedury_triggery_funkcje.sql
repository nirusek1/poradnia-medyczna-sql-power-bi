/*
====================================================================
PLIK: 03_procedury_triggery_funkcje.sql

ZAKRES: Procedury operacyjne, funkcje i triggery diagnoz.
====================================================================
*/

USE PoradniaDB;
GO


/*
====================================================================
I. PROCEDURY SKŁADOWANE
====================================================================
*/


/*
--------------------------------------------------------------------
PROCEDURA: sp_DodajPlatnosc
--------------------------------------------------------------------

Dla umówionej i nieopłaconej konsultacji lub kontroli pobiera
cenę z Cennik, dodaje płatność i ustawia status opłacona.
Płatność musi poprzedzać realizację wizyty. Teleporady są
opłacane automatycznie w sp_ZarejestrujWizyte.
--------------------------------------------------------------------
*/

CREATE PROCEDURE sp_DodajPlatnosc
    @WizytaID INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @StatusWizytyID INT;
    DECLARE @StatusPlatnosciID INT;
    DECLARE @TypWizytyID INT;

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT
            @StatusWizytyID = StatusWizytyID,
            @StatusPlatnosciID = StatusPlatnosciID,
            @TypWizytyID = TypWizytyID
        FROM dbo.Wizyta WITH (UPDLOCK, HOLDLOCK)
        WHERE WizytaID = @WizytaID;

        IF @StatusWizytyID IS NULL
            THROW 50001, 'Wizyta o podanym ID nie istnieje.', 1;

        IF EXISTS (
            SELECT 1 FROM dbo.Platnosc WHERE WizytaID = @WizytaID
        )
            THROW 50002, 'Platnosc dla tej wizyty juz istnieje.', 1;

        IF @StatusWizytyID <> 1
           OR @StatusPlatnosciID <> 1
           OR @TypWizytyID = 3
            THROW 50003,
                'Oplacic mozna tylko umowiona, nieoplacona konsultacje lub kontrole.', 1;

        IF NOT EXISTS (
            SELECT 1
            FROM dbo.Wizyta w
            JOIN dbo.Cennik c ON w.TypWizytyID = c.TypWizytyID
            WHERE w.WizytaID = @WizytaID
        )
            THROW 50004, 'Brak ceny dla wskazanego typu wizyty.', 1;

        INSERT INTO dbo.Platnosc (WizytaID, Kwota, DataPlatnosci)
        SELECT w.WizytaID, c.Kwota, SYSDATETIME()
        FROM dbo.Wizyta w
        JOIN dbo.Cennik c ON w.TypWizytyID = c.TypWizytyID
        WHERE w.WizytaID = @WizytaID;

        IF @@ROWCOUNT <> 1
            THROW 50023, 'Nie udalo sie dodac platnosci do wizyty.', 1;

        UPDATE dbo.Wizyta
        SET StatusPlatnosciID = 2
        WHERE WizytaID = @WizytaID
          AND StatusWizytyID = 1
          AND StatusPlatnosciID = 1;

        IF @@ROWCOUNT <> 1
            THROW 50024, 'Nie udalo sie zaktualizowac statusu platnosci.', 1;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO



/*
--------------------------------------------------------------------
PROCEDURA: sp_DodajPacjenta
--------------------------------------------------------------------

Dodaje pacjenta po kontroli unikalności PESEL, płci,
pełnoletności i obecności co najmniej jednej formy kontaktu.
Format danych kontaktowych weryfikują ograniczenia tabeli.
--------------------------------------------------------------------
*/

CREATE OR ALTER PROCEDURE sp_DodajPacjenta
    @Imie NVARCHAR(50),
    @Nazwisko NVARCHAR(80),
    @PESEL NVARCHAR(MAX),
    @DataUrodzenia DATE,
    @Plec CHAR(1),
    @Adres NVARCHAR(200),
    @Telefon NVARCHAR(20) = NULL,
    @Email NVARCHAR(100) = NULL
AS
BEGIN

IF @PESEL IS NULL
   OR DATALENGTH(@PESEL) <> 22
   OR @PESEL COLLATE Latin1_General_100_BIN2 LIKE N'%[^0-9]%'
BEGIN
    THROW 50032, 'Numer PESEL musi skladac sie dokladnie z 11 cyfr.', 1;
END;

IF EXISTS (
    SELECT 1
    FROM Pacjent
    WHERE PESEL = @PESEL
)
    THROW 50005, 'Pacjent z podanym numerem PESEL juz istnieje.', 1;

IF @Plec NOT IN ('K','M')
    THROW 50006, 'Niepoprawna wartosc pola Plec.', 1;

IF @DataUrodzenia > DATEADD(YEAR,-18,GETDATE())
    THROW 50007, 'Pacjent musi miec co najmniej 18 lat.', 1;

IF @Telefon IS NULL AND @Email IS NULL
    THROW 50008, 'Nalezy podac przynajmniej telefon lub email.', 1;

INSERT INTO Pacjent
(Imie, Nazwisko, PESEL, DataUrodzenia, Plec, Adres, Telefon, Email)
VALUES
(@Imie, @Nazwisko, @PESEL, @DataUrodzenia, @Plec, @Adres, @Telefon, @Email);

END;
GO



/*
--------------------------------------------------------------------
PROCEDURA: sp_ZarejestrujWizyte
--------------------------------------------------------------------

Sprawdza pacjenta, lekarza, specjalizację, typ i cenę wizyty
oraz termin i brak kolizji w harmonogramie lekarza.
Tworzy wizytę ze statusem umówiona; dla teleporady
dodaje przedpłatę i nadaje status płatności opłacona.
--------------------------------------------------------------------
*/

CREATE OR ALTER PROCEDURE sp_ZarejestrujWizyte
    @PacjentID INT,
    @LekarzID INT,
    @SpecjalizacjaID INT,
    @DataWizyty DATETIME2(0),
    @TypWizytyID INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @DataUtworzenia DATETIME2(0) = GETDATE();
    DECLARE @WizytaID INT;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (
            SELECT 1
            FROM Pacjent
            WHERE PacjentID = @PacjentID
        )
            THROW 50009, 'Pacjent o podanym ID nie istnieje.', 1;

        IF NOT EXISTS (
            SELECT 1
            FROM Lekarz
            WHERE LekarzID = @LekarzID
        )
            THROW 50010, 'Lekarz o podanym ID nie istnieje.', 1;

        IF NOT EXISTS (
            SELECT 1
            FROM LekarzSpecjalizacja
            WHERE LekarzID = @LekarzID
              AND SpecjalizacjaID = @SpecjalizacjaID
        )
            THROW 50011, 'Lekarz nie posiada wskazanej specjalizacji.', 1;

        IF NOT EXISTS (
            SELECT 1
            FROM TypWizyty
            WHERE TypWizytyID = @TypWizytyID
        )
            THROW 50012, 'Typ wizyty o podanym ID nie istnieje.', 1;

        IF NOT EXISTS (
            SELECT 1
            FROM Cennik
            WHERE TypWizytyID = @TypWizytyID
        )
            THROW 50004, 'Brak ceny dla wskazanego typu wizyty.', 1;

        IF @DataWizyty IS NULL OR @DataWizyty <= @DataUtworzenia
			THROW 50013, 'Nieprawidlowa data wizyty.', 1;

        IF EXISTS (
            SELECT 1
            FROM Wizyta
            WHERE LekarzID = @LekarzID
              AND DataWizyty = @DataWizyty
			  AND StatusWizytyID <> 3
        )
            THROW 50014, 'Lekarz ma juz zaplanowana wizyte w tym terminie.', 1;

        INSERT INTO Wizyta
        (PacjentID, LekarzID, SpecjalizacjaID, DataWizyty, DataUtworzenia, StatusWizytyID, StatusPlatnosciID, TypWizytyID)
        VALUES
        (@PacjentID,
         @LekarzID,
         @SpecjalizacjaID,
         @DataWizyty,
         @DataUtworzenia,
         1,
         CASE
             WHEN @TypWizytyID = 3 THEN 2
             ELSE 1
         END,
         @TypWizytyID);

        SET @WizytaID = SCOPE_IDENTITY();

        IF @TypWizytyID = 3
        BEGIN
            INSERT INTO Platnosc (
                WizytaID,
                Kwota,
                DataPlatnosci
            )
            SELECT
                @WizytaID,
                Kwota,
                @DataUtworzenia
            FROM Cennik
            WHERE TypWizytyID = @TypWizytyID;

            IF @@ROWCOUNT <> 1
                THROW 50023, 'Nie udalo sie dodac platnosci do wizyty.', 1;
        END;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
GO



/*
--------------------------------------------------------------------
PROCEDURA: sp_AnulujWizyte
--------------------------------------------------------------------

Anuluje wyłącznie wizytę umówioną.
Dla wizyty nieopłaconej zachowuje status nieopłacona.
Dla wizyty opłaconej (także stacjonarnej) ustawia status zwrot,
zachowując rekord Platnosc. Nie wykonuje faktycznego przelewu zwrotnego.
--------------------------------------------------------------------
*/

CREATE PROCEDURE sp_AnulujWizyte
    @WizytaID INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @StatusWizytyID INT;
    DECLARE @StatusPlatnosciID INT;

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT
            @StatusWizytyID = StatusWizytyID,
            @StatusPlatnosciID = StatusPlatnosciID
        FROM dbo.Wizyta WITH (UPDLOCK, HOLDLOCK)
        WHERE WizytaID = @WizytaID;

        IF @StatusWizytyID IS NULL
            THROW 50001, 'Wizyta o podanym ID nie istnieje.', 1;

        IF @StatusWizytyID = 2
            THROW 50015, 'Nie mozna anulowac wizyty zrealizowanej.', 1;

        IF @StatusWizytyID = 3
            THROW 50016, 'Wizyta jest juz anulowana.', 1;

        IF @StatusPlatnosciID = 2 AND NOT EXISTS (
            SELECT 1 FROM dbo.Platnosc WHERE WizytaID = @WizytaID
        )
            THROW 50027, 'Wizyta oznaczona jako oplacona nie ma rekordu platnosci.', 1;

        IF @StatusPlatnosciID = 1 AND EXISTS (
            SELECT 1 FROM dbo.Platnosc WHERE WizytaID = @WizytaID
        )
            THROW 50028, 'Nieoplacona wizyta ma niezgodny rekord platnosci.', 1;

        IF @StatusPlatnosciID NOT IN (1, 2)
            THROW 50029, 'Niepoprawny status platnosci dla umowionej wizyty.', 1;

        UPDATE dbo.Wizyta
        SET StatusWizytyID = 3,
            StatusPlatnosciID = CASE
                WHEN @StatusPlatnosciID = 2 THEN 3
                ELSE 1
            END
        WHERE WizytaID = @WizytaID AND StatusWizytyID = 1;

        IF @@ROWCOUNT <> 1
            THROW 50022, 'Nie udalo sie anulowac wizyty.', 1;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO



/*
--------------------------------------------------------------------
PROCEDURA: sp_ZrealizujWizyte
--------------------------------------------------------------------

Potwierdza opłaconą wizytę umówioną po nadejściu jej terminu
oraz zapisuje diagnozę ICD-10 w jednej transakcji.
Zgodność diagnozy ze specjalizacją i statusem wizyty kontrolują
triggery tabeli Diagnoza.
--------------------------------------------------------------------
*/

CREATE PROCEDURE sp_ZrealizujWizyte
    @WizytaID INT,
    @ICD10ID INT,
    @OpisDodatkowy NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @StatusWizytyID INT;
    DECLARE @StatusPlatnosciID INT;
    DECLARE @DataWizyty DATETIME2(0);

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT
            @StatusWizytyID = StatusWizytyID,
            @StatusPlatnosciID = StatusPlatnosciID,
            @DataWizyty = DataWizyty
        FROM Wizyta WITH (UPDLOCK, HOLDLOCK)
        WHERE WizytaID = @WizytaID;

        IF @StatusWizytyID IS NULL
            THROW 50001, 'Wizyta o podanym ID nie istnieje.', 1;

        IF @StatusWizytyID <> 1
            THROW 50020, 'Zrealizowac mozna tylko wizyte umowiona.', 1;

        IF @DataWizyty > SYSDATETIME()
            THROW 50021, 'Nie mozna zrealizowac wizyty przed jej terminem.', 1;

        IF @StatusPlatnosciID <> 2 OR NOT EXISTS (
            SELECT 1 FROM dbo.Platnosc WHERE WizytaID = @WizytaID
        )
            THROW 50027, 'Przed realizacja wizyty wymagana jest zarejestrowana platnosc.', 1;

        IF NOT EXISTS (
            SELECT 1
            FROM ICD10
            WHERE ICD10ID = @ICD10ID
        )
            THROW 50025, 'Wskazany kod ICD10 nie istnieje.', 1;

        UPDATE Wizyta
        SET StatusWizytyID = 2
        WHERE WizytaID = @WizytaID
          AND StatusWizytyID = 1
          AND StatusPlatnosciID = 2
          AND DataWizyty <= SYSDATETIME();

        IF @@ROWCOUNT <> 1
            THROW 50022, 'Nie udalo sie zmienic statusu wizyty.', 1;

        INSERT INTO Diagnoza (WizytaID, ICD10ID, OpisDodatkowy)
        VALUES (@WizytaID, @ICD10ID, @OpisDodatkowy);

        IF @@ROWCOUNT <> 1
            THROW 50026, 'Nie udalo sie dodac diagnozy do wizyty.', 1;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
GO



/*
--------------------------------------------------------------------
PROCEDURA: sp_SprawdzDostepnoscLekarza
--------------------------------------------------------------------

Sprawdza istnienie lekarza oraz dostępność przyszłego terminu. 
Pozostałe wyniki zwraca zgodnie z zasadami tabeli Wizyta: dni robocze (pon.–pt.),
godziny rozpoczęcia 08:00–15:30 i interwał 30 minut.
Termin jest zajęty wyłącznie przez wizyty nieanulowane.
Anulowanie wizyty zwalnia termin do ponownej rezerwacji.
Nie uwzględnia indywidualnych grafików lekarzy.
--------------------------------------------------------------------
*/

CREATE OR ALTER PROCEDURE sp_SprawdzDostepnoscLekarza
    @LekarzID INT,
    @DataWizyty DATETIME2(0)
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (
        SELECT 1
        FROM Lekarz
        WHERE LekarzID = @LekarzID
    )
        THROW 50010, 'Lekarz o podanym ID nie istnieje.', 1;

    IF @DataWizyty IS NULL
        THROW 50013, 'Nieprawidlowa data wizyty.', 1;

    SELECT
        CASE
            WHEN @DataWizyty <= SYSDATETIME()
                THEN N'Termin w przeszłości'

            -- Niezależnie od ustawienia DATEFIRST: 1900-01-01 był poniedziałkiem.
            WHEN DATEDIFF(DAY, '19000101', CAST(@DataWizyty AS DATE)) % 7
                 NOT BETWEEN 0 AND 4
                THEN N'Termin poza dniami pracy'

            WHEN DATEPART(HOUR, @DataWizyty) NOT BETWEEN 8 AND 15
                THEN N'Termin poza godzinami pracy'

            WHEN DATEPART(MINUTE, @DataWizyty) NOT IN (0, 30)
                 OR DATEPART(SECOND, @DataWizyty) <> 0
                THEN N'Nieprawidłowy interwał terminu'

            WHEN EXISTS (
                SELECT 1
                FROM Wizyta
                WHERE LekarzID = @LekarzID
                  AND DataWizyty = @DataWizyty
				  AND StatusWizytyID <> 3
            )
                THEN N'Termin zajęty'

            ELSE N'Termin dostępny'
        END AS Status;
END;
GO




/*
--------------------------------------------------------------------
PROCEDURA: sp_HistoriaPacjenta
--------------------------------------------------------------------

Zwraca dane z vw_HistoriaWizytPacjenta dla wskazanego
pacjenta, malejąco według DataWizyty.
--------------------------------------------------------------------
*/

CREATE PROCEDURE sp_HistoriaPacjenta
    @PacjentID INT
AS
BEGIN

IF NOT EXISTS (
    SELECT 1
    FROM Pacjent
    WHERE PacjentID = @PacjentID
)
    THROW 50009, 'Pacjent o podanym ID nie istnieje.', 1;

SELECT *
FROM vw_HistoriaWizytPacjenta
WHERE PacjentID = @PacjentID
ORDER BY DataWizyty DESC;

END;
GO



/*
--------------------------------------------------------------------
PROCEDURA: sp_RaportMiesieczny
--------------------------------------------------------------------

Wizyty zrealizowane liczy według daty wizyty;
przychód to suma wszystkich zarejestrowanych wpłat
w miesiącu według daty płatności, niezależnie od statusu wizyty.
Parametry: rok i miesiąc (1–12).
--------------------------------------------------------------------
*/

CREATE PROCEDURE sp_RaportMiesieczny
    @Rok INT,
    @Miesiac INT
AS
BEGIN

IF @Miesiac NOT BETWEEN 1 AND 12
    THROW 50017, 'Miesiac musi miec wartosc od 1 do 12.', 1;

DECLARE @DataOd DATE = DATEFROMPARTS(@Rok, @Miesiac, 1);
DECLARE @DataDo DATE = DATEADD(MONTH, 1, @DataOd);

SELECT
    (SELECT COUNT(*)
     FROM Wizyta w
     WHERE w.StatusWizytyID = 2
          AND w.DataWizyty >= @DataOd
          AND w.DataWizyty < @DataDo
    ) AS LiczbaWizyt,

    (SELECT COALESCE(SUM(p.Kwota), 0)
     FROM Platnosc p
     WHERE p.DataPlatnosci >= @DataOd
       AND p.DataPlatnosci < @DataDo
    ) AS Przychod;

END;
GO



/*
--------------------------------------------------------------------
PROCEDURA: sp_StatystykaLekarza
--------------------------------------------------------------------

Liczba zrealizowanych wizyt lekarza i suma przypisanych
do nich kwot, bez ograniczenia dat wizyt lub płatności.
--------------------------------------------------------------------
*/

CREATE PROCEDURE sp_StatystykaLekarza
    @LekarzID INT
AS
BEGIN

IF NOT EXISTS (
    SELECT 1
    FROM Lekarz
    WHERE LekarzID = @LekarzID
)
    THROW 50010, 'Lekarz o podanym ID nie istnieje.', 1;

SELECT
    COUNT(*) AS LiczbaWizyt,
    COALESCE(SUM(p.Kwota), 0) AS Przychod
FROM Wizyta w
LEFT JOIN Platnosc p ON w.WizytaID = p.WizytaID
WHERE 
    w.LekarzID = @LekarzID
    AND w.StatusWizytyID = 2;

END;
GO



/*
====================================================================
II. FUNKCJE UŻYTKOWNIKA
====================================================================
*/


/*
--------------------------------------------------------------------
FUNKCJA: fn_WiekPacjenta
--------------------------------------------------------------------

Wiek w pełnych latach na dzień wykonania funkcji (GETDATE);
odrębny od wieku liczonego na stałą datę w Power BI.
--------------------------------------------------------------------
*/

CREATE FUNCTION fn_WiekPacjenta (@DataUrodzenia DATE)
RETURNS INT
AS
BEGIN
RETURN DATEDIFF(YEAR, @DataUrodzenia, GETDATE())
       - CASE 
            WHEN DATEADD(YEAR, DATEDIFF(YEAR, @DataUrodzenia, GETDATE()), @DataUrodzenia) > GETDATE()
            THEN 1 ELSE 0
         END

END;
GO



/*
FUNKCJA: fn_LiczbaWizytPacjenta
--------------------------------------------------------------------

Liczba wszystkich wizyt wskazanego pacjenta, niezależnie
od statusu i daty wizyty.
--------------------------------------------------------------------
*/

CREATE FUNCTION fn_LiczbaWizytPacjenta (@PacjentID INT)
RETURNS INT
AS
BEGIN

DECLARE @Liczba INT;

SELECT @Liczba = COUNT(*)
FROM Wizyta
WHERE PacjentID = @PacjentID;

RETURN @Liczba;

END;
GO



/*
====================================================================
III. TRIGGERY
====================================================================
*/


/*
--------------------------------------------------------------------
TRIGGER: trg_Diagnoza_Specjalizacja
--------------------------------------------------------------------

AFTER INSERT, UPDATE: odrzuca rozpoznanie ICD-10 nieprzypisane
do specjalizacji wskazanej w wizycie.
--------------------------------------------------------------------
*/

CREATE OR ALTER TRIGGER trg_Diagnoza_Specjalizacja
ON Diagnoza
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN Wizyta w
            ON i.WizytaID = w.WizytaID
        LEFT JOIN SpecjalizacjaICD10 si
            ON si.SpecjalizacjaID = w.SpecjalizacjaID
           AND si.ICD10ID = i.ICD10ID
        WHERE si.ICD10ID IS NULL
    )
        THROW 50018, 'Kod ICD10 jest niezgodny ze specjalizacja przypisana do wizyty.', 1;

END;
GO



/*
--------------------------------------------------------------------
TRIGGER: trg_Diagnoza_Status
--------------------------------------------------------------------

AFTER INSERT, UPDATE: odrzuca diagnozę przypisaną do wizyty
o statusie innym niż zrealizowana.
--------------------------------------------------------------------
*/

CREATE OR ALTER TRIGGER trg_Diagnoza_Status
ON Diagnoza
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN Wizyta w
            ON i.WizytaID = w.WizytaID
        WHERE w.StatusWizytyID <> 2
    )
        THROW 50019, 'Diagnoza moze byc przypisana tylko do wizyty zrealizowanej.', 1;

END;
GO



/*
------------------------------------------------------------
TRIGGER: trg_Wizyta_DiagnozaIntegralnosc
------------------------------------------------------------

AFTER UPDATE: kontroluje zgodnosc istniejacych
diagnoz ze statusem i specjalizacja wizyty.
------------------------------------------------------------
*/

CREATE OR ALTER TRIGGER trg_Wizyta_DiagnozaIntegralnosc
ON dbo.Wizyta
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN dbo.Diagnoza d
            ON d.WizytaID = i.WizytaID
        WHERE i.StatusWizytyID <> 2
           OR NOT EXISTS (
                SELECT 1
                FROM dbo.SpecjalizacjaICD10 si
                WHERE si.SpecjalizacjaID = i.SpecjalizacjaID
                  AND si.ICD10ID = d.ICD10ID
           )
    )
    BEGIN
        THROW 50030,
            'Zmiana wizyty narusza zgodnosc diagnozy.',
            1;
    END;
END;
GO



/*
------------------------------------------------------------
TRIGGER: trg_SpecjalizacjaICD10_Integralnosc
------------------------------------------------------------

AFTER UPDATE, DELETE: zabezpiecza powiazania
specjalizacji z kodami ICD-10 wykorzystywane
przez istniejace diagnozy.
------------------------------------------------------------
*/

CREATE OR ALTER TRIGGER trg_SpecjalizacjaICD10_Integralnosc
ON dbo.SpecjalizacjaICD10
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM deleted old
        JOIN dbo.Wizyta w
            ON w.SpecjalizacjaID = old.SpecjalizacjaID
        JOIN dbo.Diagnoza d
            ON d.WizytaID = w.WizytaID
           AND d.ICD10ID = old.ICD10ID
        WHERE NOT EXISTS (
            SELECT 1
            FROM dbo.SpecjalizacjaICD10 si
            WHERE si.SpecjalizacjaID = w.SpecjalizacjaID
              AND si.ICD10ID = d.ICD10ID
        )
    )
    BEGIN
        THROW 50031,
            'Zmiana mapowania ICD10 narusza zgodnosc diagnoz.',
            1;
    END;
END;
GO
