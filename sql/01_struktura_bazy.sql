/*
====================================================================
PROJEKT: Baza danych prywatnej poradni specjalistycznej
BAZA DANYCH: PoradniaDB
PLIK: 01_struktura_bazy.sql

ZAKRES: Tabele, klucze, ograniczenia integralności i indeksy.
====================================================================
*/

SET ANSI_NULLS ON;
GO

SET QUOTED_IDENTIFIER ON;
GO

IF DB_ID('PoradniaDB') IS NULL
BEGIN
    CREATE DATABASE PoradniaDB;
END
GO

USE PoradniaDB;
GO



/*
====================================================================
I. TABELE SŁOWNIKOWE
====================================================================
*/

CREATE TABLE Rola (
    RolaID INT IDENTITY(1,1) PRIMARY KEY,
    Nazwa NVARCHAR(50) NOT NULL UNIQUE
);
GO

CREATE TABLE StatusWizyty (
    StatusWizytyID INT IDENTITY(1,1) PRIMARY KEY,
    Nazwa NVARCHAR(50) NOT NULL UNIQUE
);
GO

CREATE TABLE StatusPlatnosci (
    StatusPlatnosciID INT IDENTITY(1,1) PRIMARY KEY,
    Nazwa NVARCHAR(50) NOT NULL UNIQUE
);
GO

CREATE TABLE TypWizyty (
    TypWizytyID INT IDENTITY(1,1) PRIMARY KEY,
    Nazwa NVARCHAR(50) NOT NULL UNIQUE
);
GO

CREATE TABLE Specjalizacja (
    SpecjalizacjaID INT IDENTITY(1,1) PRIMARY KEY,
    Nazwa NVARCHAR(100) NOT NULL UNIQUE
);
GO

CREATE TABLE ICD10 (
    ICD10ID INT IDENTITY(1,1) PRIMARY KEY,
    Kod VARCHAR(10) NOT NULL UNIQUE,
    Nazwa NVARCHAR(255) NOT NULL
);
GO



/*
====================================================================
II. TABELA POMOCNICZA
====================================================================

Tabela przechowująca cennik wizyt medycznych przypisany do typu
wizyty.
====================================================================
*/

CREATE TABLE Cennik (
    TypWizytyID INT PRIMARY KEY,
    Kwota DECIMAL(10,2) NOT NULL,

    CONSTRAINT FK_Cennik_TypWizyty 
        FOREIGN KEY (TypWizytyID)    
        REFERENCES TypWizyty(TypWizytyID),

    CONSTRAINT CK_Cennik_Kwota
        CHECK (Kwota > 0)
);
GO



/*
====================================================================
III. TABELE GŁÓWNE
====================================================================

Podstawowe encje systemu: pacjenci, użytkownicy systemu oraz lekarze.
====================================================================
*/

/*
--------------------------------------------------------------------
TABELA: Pacjent
--------------------------------------------------------------------

Unikalny PESEL, dozwolone wartości płci i wiek co najmniej 18 lat.
Walidacja PESEL, telefonu i e-maila; wymagany telefon lub e-mail.
--------------------------------------------------------------------
*/

CREATE TABLE Pacjent (
    PacjentID INT IDENTITY(1,1) PRIMARY KEY,
    Imie NVARCHAR(50) NOT NULL,
    Nazwisko NVARCHAR(80) NOT NULL,
    PESEL CHAR(11) NOT NULL UNIQUE,
    DataUrodzenia DATE NOT NULL,
    Plec CHAR(1) NOT NULL,
    Adres NVARCHAR(200) NOT NULL,
    Telefon NVARCHAR(20) NULL,
    Email NVARCHAR(100) NULL,

    CONSTRAINT CK_Pacjent_Plec
        CHECK (Plec IN ('K','M')),

    CONSTRAINT CK_Pacjent_DataUrodzenia
        CHECK (DataUrodzenia >= '19000101'
            AND DataUrodzenia <= CAST(DATEADD(YEAR, -18, GETDATE()) AS DATE)),

    CONSTRAINT CK_Pacjent_PESEL_Dlugosc
        CHECK (LEN(PESEL) = 11),

    CONSTRAINT CK_Pacjent_PESEL_Cyfry
        CHECK (PESEL NOT LIKE '%[^0-9]%'),

    CONSTRAINT CK_Pacjent_Telefon_Format
        CHECK (Telefon IS NULL
            OR (Telefon NOT LIKE '%[^0-9]%' AND LEN(Telefon) BETWEEN 9 AND 15)),

    CONSTRAINT CK_Pacjent_Email_Format
        CHECK (Email IS NULL
            OR (Email LIKE '%_@_%._%' AND Email NOT LIKE '% %')),

    CONSTRAINT CK_Pacjent_Min_Jeden_Kontakt
        CHECK (Email IS NOT NULL OR Telefon IS NOT NULL)
);
GO


/*
--------------------------------------------------------------------
TABELA: Uzytkownik
--------------------------------------------------------------------

HasloHash przeznaczone do przechowywania skrótu hasła.
Walidacja formatu telefonu i e-maila.
--------------------------------------------------------------------
*/

CREATE TABLE Uzytkownik (
    UzytkownikID INT IDENTITY(1,1) PRIMARY KEY,
    Imie NVARCHAR(50) NOT NULL,
    Nazwisko NVARCHAR(80) NOT NULL,
    Email NVARCHAR(100) NOT NULL UNIQUE,
    Telefon NVARCHAR(20) NULL,
    HasloHash VARBINARY(256) NOT NULL,
    RolaID INT NOT NULL,

    CONSTRAINT FK_Uzytkownik_Rola
        FOREIGN KEY (RolaID) 
        REFERENCES Rola(RolaID),

	CONSTRAINT CK_Uzytkownik_Telefon_Format
    CHECK (Telefon IS NULL
        OR (Telefon NOT LIKE '%[^0-9]%' AND LEN(Telefon) BETWEEN 9 AND 15)),

	CONSTRAINT CK_Uzytkownik_Email_Format
    CHECK (Email LIKE '%_@_%._%' AND Email NOT LIKE '% %')
);
GO


/*
--------------------------------------------------------------------
TABELA: Lekarz
--------------------------------------------------------------------

Relacja jeden-do-jednego z kontem użytkownika; unikalny numer PWZ.
--------------------------------------------------------------------
*/

CREATE TABLE Lekarz (
    LekarzID INT IDENTITY(1,1) PRIMARY KEY,
    UzytkownikID INT NOT NULL UNIQUE,
    NrPWZ NVARCHAR(20) NOT NULL UNIQUE,

    CONSTRAINT FK_Lekarz_Uzytkownik
        FOREIGN KEY (UzytkownikID)
        REFERENCES Uzytkownik(UzytkownikID)
);
GO



/*
====================================================================
IV. TABELE RELACYJNE
====================================================================

Tabele realizujące relacje wiele-do-wielu pomiędzy encjami
systemu (lekarz – specjalizacja, specjalizacja – ICD-10).
====================================================================
*/

CREATE TABLE LekarzSpecjalizacja (
    LekarzID INT NOT NULL,
    SpecjalizacjaID INT NOT NULL,

    CONSTRAINT PK_LekarzSpecjalizacja
        PRIMARY KEY (LekarzID, SpecjalizacjaID),

    CONSTRAINT FK_LS_Lekarz
        FOREIGN KEY (LekarzID) 
        REFERENCES Lekarz(LekarzID),

    CONSTRAINT FK_LS_Specjalizacja
        FOREIGN KEY (SpecjalizacjaID) 
        REFERENCES Specjalizacja(SpecjalizacjaID)
);
GO


CREATE TABLE SpecjalizacjaICD10 (
    SpecjalizacjaID INT NOT NULL,
    ICD10ID INT NOT NULL,

    CONSTRAINT PK_SpecjalizacjaICD10
        PRIMARY KEY (SpecjalizacjaID, ICD10ID),

    CONSTRAINT FK_SpecjalizacjaICD10_Specjalizacja
        FOREIGN KEY (SpecjalizacjaID)
        REFERENCES Specjalizacja(SpecjalizacjaID),

    CONSTRAINT FK_SpecjalizacjaICD10_ICD10
        FOREIGN KEY (ICD10ID)
        REFERENCES ICD10(ICD10ID)
);
GO



/*
====================================================================
V. TABELE OPERACYJNE
====================================================================

Encje operacyjne systemu: wizyty, diagnozy oraz płatności.
====================================================================
*/

/*
--------------------------------------------------------------------
TABELA: Wizyta
--------------------------------------------------------------------

Unikalny indeks filtrowany (LekarzID, DataWizyty) blokuje kolizje
wizyt nieanulowanych, a po anulowaniu zwalnia termin do ponownej rezerwacji.
Termin: poniedziałek–piątek, 08:00–15:30, co 30 minut.
DataUtworzenia musi poprzedzać DataWizyty.
Klucz złożony wymusza przypisanie lekarza do specjalizacji.
CHECK blokuje wybrane niedozwolone połączenia typu wizyty,
statusu wizyty i statusu płatności, w tym realizację bez opłaty.
--------------------------------------------------------------------
*/

CREATE TABLE Wizyta (
    WizytaID INT IDENTITY(1,1) PRIMARY KEY,
    PacjentID INT NOT NULL,
    LekarzID INT NOT NULL,
    DataWizyty DATETIME2(0) NOT NULL,
    DataUtworzenia DATETIME2(0) NOT NULL,
    StatusWizytyID INT NOT NULL,
    StatusPlatnosciID INT NOT NULL,
    TypWizytyID INT NOT NULL,
	SpecjalizacjaID INT NOT NULL,

    CONSTRAINT FK_Wizyta_Pacjent
        FOREIGN KEY (PacjentID) 
        REFERENCES Pacjent(PacjentID),

    CONSTRAINT FK_Wizyta_StatusWizyty
        FOREIGN KEY (StatusWizytyID) 
        REFERENCES StatusWizyty(StatusWizytyID),

    CONSTRAINT FK_Wizyta_StatusPlatnosci
        FOREIGN KEY (StatusPlatnosciID) 
        REFERENCES StatusPlatnosci(StatusPlatnosciID),

    CONSTRAINT FK_Wizyta_TypWizyty
        FOREIGN KEY (TypWizytyID) 
        REFERENCES TypWizyty(TypWizytyID),

	CONSTRAINT FK_Wizyta_LekarzSpecjalizacja
		FOREIGN KEY (LekarzID, SpecjalizacjaID)
		REFERENCES LekarzSpecjalizacja(LekarzID, SpecjalizacjaID),

    CONSTRAINT CK_Wizyta_Daty
        CHECK (DataUtworzenia < DataWizyty),

	CONSTRAINT CK_Wizyta_DzienRoboczy
		CHECK (DATEDIFF(DAY, '19000101', CAST(DataWizyty AS DATE)) % 7
			BETWEEN 0 AND 4),

    CONSTRAINT CK_Wizyta_Interwal30Min
        CHECK (DATEPART(MINUTE, DataWizyty) IN (0,30)
			AND DATEPART(SECOND, DataWizyty) = 0),

    CONSTRAINT CK_Wizyta_GodzinyPracy
        CHECK (DATEPART(HOUR, DataWizyty) BETWEEN 8 AND 15),

    CONSTRAINT CK_Wizyta_StatusLogiczny
        CHECK (
            NOT (StatusWizytyID = 3 AND StatusPlatnosciID = 2)
            AND NOT (StatusWizytyID = 2 AND StatusPlatnosciID <> 2)
            AND NOT (StatusWizytyID = 1 AND StatusPlatnosciID = 3)
        ),

    CONSTRAINT CK_Wizyta_Typ_StatusPlatnosci
        CHECK (NOT (TypWizytyID = 3 AND StatusPlatnosciID = 1))
);
GO


/*
--------------------------------------------------------------------
TABELA: Diagnoza
--------------------------------------------------------------------

Maksymalnie jedno rozpoznanie ICD-10 na wizytę (UNIQUE WizytaID).
Zgodność ze specjalizacją i statusem wizyty sprawdzają triggery
przy dodawaniu diagnozy.
--------------------------------------------------------------------
*/

CREATE TABLE Diagnoza (
    DiagnozaID INT IDENTITY(1,1) PRIMARY KEY,
    WizytaID INT NOT NULL UNIQUE,
    ICD10ID INT NOT NULL,
    OpisDodatkowy NVARCHAR(500) NULL,

    CONSTRAINT FK_Diagnoza_Wizyta
        FOREIGN KEY (WizytaID) 
        REFERENCES Wizyta(WizytaID),

    CONSTRAINT FK_Diagnoza_ICD10
        FOREIGN KEY (ICD10ID) 
        REFERENCES ICD10(ICD10ID)
);
GO


/*
--------------------------------------------------------------------
TABELA: Platnosc
--------------------------------------------------------------------

Maksymalnie jedna płatność na wizytę (UNIQUE WizytaID).
Kwota zapisuje wartość świadczenia w chwili rozliczenia,
niezależnie od późniejszych zmian w tabeli Cennik.
--------------------------------------------------------------------
*/

CREATE TABLE Platnosc (
    PlatnoscID INT IDENTITY(1,1) PRIMARY KEY,
    WizytaID INT NOT NULL UNIQUE,
    Kwota DECIMAL(10,2) NOT NULL,
    DataPlatnosci DATETIME2(0) NOT NULL,

    CONSTRAINT FK_Platnosc_Wizyta
        FOREIGN KEY (WizytaID) 
        REFERENCES Wizyta(WizytaID),

    CONSTRAINT CK_Platnosc_Kwota
        CHECK (Kwota > 0)
);
GO



/*
====================================================================
VI. INDEKSY
====================================================================
*/

CREATE INDEX IX_Wizyta_DataWizyty
ON Wizyta (DataWizyty);

CREATE INDEX IX_Wizyta_Pacjent_Data
ON Wizyta(PacjentID, DataWizyty);

CREATE INDEX IX_Wizyta_Specjalizacja_Data
ON Wizyta (SpecjalizacjaID, DataWizyty);

CREATE INDEX IX_Diagnoza_ICD10ID
ON Diagnoza (ICD10ID);

CREATE INDEX IX_Platnosc_DataPlatnosci
ON Platnosc(DataPlatnosci);


/*
--------------------------------------------------------------------
INDEKS: UX_Wizyta_AktywneTerminy
--------------------------------------------------------------------

Zapewnia unikalność terminu dla wizyt nieanulowanych.
Wizyty o statusie Anulowana (3) nie blokują ponownej
rezerwacji terminu, ale pozostają w historii poradni.
--------------------------------------------------------------------
*/

CREATE UNIQUE NONCLUSTERED INDEX UX_Wizyta_AktywneTerminy
ON dbo.Wizyta (LekarzID, DataWizyty)
WHERE StatusWizytyID <> 3;
GO
