/*
====================================================================
PLIK: 02_widoki.sql

ZAKRES: Widoki kontrolne i analityczne, w tym źródło FactWizyta.
====================================================================
*/


USE PoradniaDB;
GO


/*
====================================================================
I. WIDOKI KONTROLNE
====================================================================
*/


/*
--------------------------------------------------------------------
WIDOK: vw_WizytaBezDiagnozy

Wizyty o statusie zrealizowana bez rekordu w tabeli Diagnoza.
--------------------------------------------------------------------
*/

CREATE VIEW vw_WizytaBezDiagnozy AS
SELECT *
FROM Wizyta w
WHERE w.StatusWizytyID = 2
AND NOT EXISTS (
    SELECT 1 FROM Diagnoza d WHERE d.WizytaID = w.WizytaID
);
GO



/*
--------------------------------------------------------------------
WIDOK: vw_WizytaBezPlatnosci

Wizyty ze statusem płatności opłacona lub zwrot bez rekordu w Platnosc.
--------------------------------------------------------------------
*/

CREATE VIEW vw_WizytaBezPlatnosci AS
SELECT *
FROM Wizyta w
WHERE w.StatusPlatnosciID IN (2, 3)
AND NOT EXISTS (
    SELECT 1 FROM Platnosc p WHERE p.WizytaID = w.WizytaID
);
GO



/*
--------------------------------------------------------------------
WIDOK: vw_WiecejNiz1Wizyta

Pacjenci z więcej niż jedną wizytą w miesiącu, niezależnie
od statusu. Kontrola założeń zbioru danych testowych.
--------------------------------------------------------------------
*/

CREATE VIEW vw_WiecejNiz1Wizyta AS
SELECT 
    PacjentID,
    YEAR(DataWizyty) AS Rok,
    MONTH(DataWizyty) AS Miesiac,
    COUNT(*) AS LiczbaWizyt
FROM Wizyta
GROUP BY PacjentID, YEAR(DataWizyty), MONTH(DataWizyty)
HAVING COUNT(*) > 1;
GO



/*
--------------------------------------------------------------------
WIDOK: vw_NiespojnoscStatusow

Identyfikuje niespójne kombinacje statusów wizyt i płatności:
- umówiona konsultacja lub kontrola: nieopłacona albo opłacona;
- umówiona teleporada: opłacona z góry;
- zrealizowana wizyta: opłacona;
- anulowana konsultacja lub kontrola: nieopłacona, jeśli wcześniej
  nie pobrano wpłaty, albo zwrot, jeśli wpłatę pobrano;
- anulowana teleporada: zwrot.
Statusy opłacona/zwrot wymagają rekordu Platnosc, a nieopłacona
nie powinna mieć przypisanej wpłaty.
--------------------------------------------------------------------
*/

CREATE VIEW dbo.vw_NiespojnoscStatusow AS
SELECT w.*
FROM dbo.Wizyta w
WHERE
    -- Umówiona wizyta nie może mieć statusu zwrot.
    (w.StatusWizytyID = 1 AND w.StatusPlatnosciID = 3)
    OR
    -- Teleporada wymaga przedpłaty już na etapie rejestracji.
    (w.StatusWizytyID = 1 AND w.TypWizytyID = 3
     AND w.StatusPlatnosciID <> 2)
    OR
    -- Każda zrealizowana wizyta musi być opłacona.
    (w.StatusWizytyID = 2 AND w.StatusPlatnosciID <> 2)
    OR
    -- Anulowana wizyta nie może pozostawać opłacona.
    (w.StatusWizytyID = 3 AND w.StatusPlatnosciID = 2)
    OR
    -- Anulowana teleporada wymaga oznaczenia zwrotu.
    (w.StatusWizytyID = 3 AND w.TypWizytyID = 3
     AND w.StatusPlatnosciID <> 3)
    OR
    -- Opłacenie/zwrot wymaga zachowania rekordu wpłaty.
    (w.StatusPlatnosciID IN (2, 3) AND NOT EXISTS (
        SELECT 1 FROM dbo.Platnosc p WHERE p.WizytaID = w.WizytaID
    ))
    OR
    -- Wizyta nieopłacona nie może posiadać przypisanej wpłaty.
    (w.StatusPlatnosciID = 1 AND EXISTS (
        SELECT 1 FROM dbo.Platnosc p WHERE p.WizytaID = w.WizytaID
    ));
GO



/*
--------------------------------------------------------------------
WIDOK: vw_PlatnoscNiezgodnaZCennikiem

Płatności, których kwota różni się od bieżącej ceny typu
wizyty. Kontrola przeznaczona dla niezmienianego cennika
danych testowych; nie uwzględnia historycznych zmian cen.
--------------------------------------------------------------------
*/

CREATE VIEW vw_PlatnoscNiezgodnaZCennikiem AS
SELECT 
    p.PlatnoscID,
    p.WizytaID,
    p.Kwota AS Kwota_Platnosci,
    c.Kwota AS Kwota_Z_Cennika,
    w.TypWizytyID
FROM Platnosc p
    JOIN Wizyta w ON p.WizytaID = w.WizytaID
    JOIN Cennik c ON w.TypWizytyID = c.TypWizytyID
WHERE p.Kwota <> c.Kwota;
GO



/*
====================================================================
II. WIDOKI ANALITYCZNE
====================================================================
*/


/*
--------------------------------------------------------------------
WIDOK: vw_HistoriaKliniczna

Liczba rozpoznań danego kodu ICD-10 dla pacjenta oraz daty
pierwszej i ostatniej wizyty z tym rozpoznaniem.
--------------------------------------------------------------------
*/

CREATE VIEW vw_HistoriaKliniczna AS
SELECT 
    p.PacjentID,
    p.Imie,
    p.Nazwisko,
    i.Kod,
    i.Nazwa,
    COUNT(*) AS LiczbaRozpoznan,
    MIN(w.DataWizyty) AS PierwszaWizyta,
    MAX(w.DataWizyty) AS OstatniaWizyta
FROM Diagnoza d
    JOIN Wizyta w ON d.WizytaID = w.WizytaID
    JOIN Pacjent p ON w.PacjentID = p.PacjentID
    JOIN ICD10 i ON d.ICD10ID = i.ICD10ID
GROUP BY p.PacjentID, p.Imie, p.Nazwisko, i.Kod, i.Nazwa;
GO



/*
--------------------------------------------------------------------
WIDOK: vw_HistoriaWizytPacjenta

Historia wizyt z lekarzem, specjalizacją, typem i statusem
świadczenia oraz opcjonalną diagnozą i płatnością.
--------------------------------------------------------------------
*/

CREATE VIEW vw_HistoriaWizytPacjenta AS
SELECT
    p.PacjentID,
    p.Imie AS PacjentImie,
    p.Nazwisko AS PacjentNazwisko,
    w.WizytaID,
    w.DataWizyty,
    u.Imie AS LekarzImie,
    u.Nazwisko AS LekarzNazwisko,
    s.Nazwa AS Specjalizacja,
    tw.Nazwa AS TypWizyty,
    sw.Nazwa AS StatusWizyty,
    i.Kod AS KodICD10,
    i.Nazwa AS Diagnoza,
    pl.Kwota,
	sp.Nazwa AS StatusPlatnosci,
	pl.DataPlatnosci
FROM Wizyta w
    JOIN Pacjent p ON w.PacjentID = p.PacjentID
    JOIN Lekarz l ON w.LekarzID = l.LekarzID
    JOIN Uzytkownik u ON l.UzytkownikID = u.UzytkownikID
    JOIN Specjalizacja s ON w.SpecjalizacjaID = s.SpecjalizacjaID
    JOIN TypWizyty tw ON w.TypWizytyID = tw.TypWizytyID
    JOIN StatusWizyty sw ON w.StatusWizytyID = sw.StatusWizytyID
    LEFT JOIN Diagnoza d ON w.WizytaID = d.WizytaID
    LEFT JOIN ICD10 i ON d.ICD10ID = i.ICD10ID
    LEFT JOIN Platnosc pl ON w.WizytaID = pl.WizytaID
	JOIN StatusPlatnosci sp ON w.StatusPlatnosciID = sp.StatusPlatnosciID;
GO



/*
--------------------------------------------------------------------
WIDOK: vw_GrafikLekarza

Terminy wizyt lekarzy z danymi pacjentów, typem i statusem
wizyty; obejmuje także wizyty anulowane i umówione.
--------------------------------------------------------------------
*/

CREATE VIEW vw_GrafikLekarza AS
SELECT
    l.LekarzID,
    u.Imie AS LekarzImie,
    u.Nazwisko AS LekarzNazwisko,
    s.Nazwa AS Specjalizacja,
    w.WizytaID,
    w.DataWizyty,
    p.Imie AS PacjentImie,
    p.Nazwisko AS PacjentNazwisko,
    tw.Nazwa AS TypWizyty,
    sw.Nazwa AS StatusWizyty
FROM Wizyta w
    JOIN Lekarz l ON w.LekarzID = l.LekarzID
    JOIN Uzytkownik u ON l.UzytkownikID = u.UzytkownikID
    JOIN Specjalizacja s ON w.SpecjalizacjaID = s.SpecjalizacjaID
    JOIN Pacjent p ON w.PacjentID = p.PacjentID
    JOIN TypWizyty tw ON w.TypWizytyID = tw.TypWizytyID
    JOIN StatusWizyty sw ON w.StatusWizytyID = sw.StatusWizytyID;
GO



/*
--------------------------------------------------------------------
WIDOK: vw_OblozenieLekarzy

Liczba zrealizowanych wizyt i suma przypisanych do nich kwot
dla każdego lekarza, również bez zrealizowanych wizyt.
Brak filtra daty płatności.
--------------------------------------------------------------------
*/

CREATE VIEW vw_OblozenieLekarzy AS
SELECT
    l.LekarzID,
    u.Imie,
    u.Nazwisko,
    COUNT(w.WizytaID) AS LiczbaWizyt,
    COALESCE(SUM(p.Kwota), 0) AS Przychod
FROM Lekarz l
    JOIN Uzytkownik u ON l.UzytkownikID = u.UzytkownikID
    LEFT JOIN Wizyta w ON l.LekarzID = w.LekarzID
    AND w.StatusWizytyID = 2
    LEFT JOIN Platnosc p ON w.WizytaID = p.WizytaID
GROUP BY l.LekarzID, u.Imie, u.Nazwisko;
GO



/*
--------------------------------------------------------------------
WIDOK: vw_RaportPrzychodow

Przychód miesięczny z płatności, grupowany według daty płatności.
--------------------------------------------------------------------
*/

CREATE OR ALTER VIEW dbo.vw_RaportPrzychodow AS
SELECT
    YEAR(p.DataPlatnosci) AS Rok,
    MONTH(p.DataPlatnosci) AS Miesiac,
    SUM(p.Kwota) AS Przychod
FROM dbo.Platnosc p
GROUP BY
    YEAR(p.DataPlatnosci),
    MONTH(p.DataPlatnosci);
GO



/*
--------------------------------------------------------------------
WIDOK: vw_PrzychodyLekarzy

Przychód miesięczny według lekarza i daty płatności.
--------------------------------------------------------------------
*/

CREATE OR ALTER VIEW dbo.vw_PrzychodyLekarzy AS
SELECT
    YEAR(p.DataPlatnosci) AS Rok,
    MONTH(p.DataPlatnosci) AS Miesiac,
    l.LekarzID,
    u.Imie,
    u.Nazwisko,
    SUM(p.Kwota) AS Przychod
FROM dbo.Platnosc p
JOIN dbo.Wizyta w
    ON p.WizytaID = w.WizytaID
JOIN dbo.Lekarz l
    ON w.LekarzID = l.LekarzID
JOIN dbo.Uzytkownik u
    ON l.UzytkownikID = u.UzytkownikID
GROUP BY
    YEAR(p.DataPlatnosci),
    MONTH(p.DataPlatnosci),
    l.LekarzID,
    u.Imie,
    u.Nazwisko;
GO



/*
--------------------------------------------------------------------
WIDOK: vw_NajczestszeDiagnozy

Liczba wystąpień poszczególnych rozpoznań ICD-10.
Widok nie ogranicza wyników do określonej liczby pozycji.
--------------------------------------------------------------------
*/

CREATE VIEW vw_NajczestszeDiagnozy AS
SELECT
    i.Kod,
    i.Nazwa,
    COUNT(*) AS LiczbaWystapien
FROM Diagnoza d
    JOIN ICD10 i ON d.ICD10ID = i.ICD10ID
GROUP BY
    i.Kod,
    i.Nazwa;
GO



/*
--------------------------------------------------------------------
WIDOK: vw_FactWizyty

Jeden wiersz na wizytę: identyfikatory wymiarów, statusy,
daty, rozpoznanie oraz kwota i data płatności.
LEFT JOIN zachowuje wizyty bez diagnozy lub płatności.
Źródło tabeli FactWizyta w modelu Power BI.
--------------------------------------------------------------------
*/

CREATE VIEW vw_FactWizyty AS
SELECT
    w.WizytaID,
    w.DataWizyty,
    YEAR(w.DataWizyty) AS Rok,
    MONTH(w.DataWizyty) AS Miesiac,
    DAY(w.DataWizyty) AS Dzien,
    p.PacjentID,
    p.Plec,
    l.LekarzID,
    u.Imie AS LekarzImie,
    u.Nazwisko AS LekarzNazwisko,
	w.SpecjalizacjaID,
	s.Nazwa AS Specjalizacja,
	w.TypWizytyID,
    tw.Nazwa AS TypWizyty,
	w.StatusWizytyID,
    sw.Nazwa AS StatusWizyty,
	d.ICD10ID,
    icd.Kod AS KodICD10,
    icd.Nazwa AS NazwaICD10,
    pl.Kwota,
	pl.DataPlatnosci,
	w.StatusPlatnosciID,
	sp.Nazwa AS StatusPlatnosci
FROM Wizyta w
    JOIN Pacjent p ON w.PacjentID = p.PacjentID
    JOIN Lekarz l ON w.LekarzID = l.LekarzID
    JOIN Uzytkownik u ON l.UzytkownikID = u.UzytkownikID
	JOIN Specjalizacja s ON w.SpecjalizacjaID = s.SpecjalizacjaID
    JOIN TypWizyty tw ON w.TypWizytyID = tw.TypWizytyID
    JOIN StatusWizyty sw ON w.StatusWizytyID = sw.StatusWizytyID
    LEFT JOIN Diagnoza d ON w.WizytaID = d.WizytaID
    LEFT JOIN ICD10 icd ON d.ICD10ID = icd.ICD10ID
    LEFT JOIN Platnosc pl ON w.WizytaID = pl.WizytaID
	JOIN StatusPlatnosci sp ON w.StatusPlatnosciID = sp.StatusPlatnosciID;
GO
