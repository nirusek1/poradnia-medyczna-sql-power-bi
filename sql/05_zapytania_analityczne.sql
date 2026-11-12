/*
====================================================================
PLIK: 05_zapytania_analityczne.sql

ZAKRES: Kontrola spójności, analiza wizyt, rozpoznań i finansów.
Okres analityczny: @DataOd włącznie, @DataDo wyłącznie.
====================================================================
*/

USE PoradniaDB;
GO

DECLARE @DataOd DATE = '20250101';
DECLARE @DataDo DATE = '20250701';   -- górna granica wyłączna



/*
====================================================================
I. WERYFIKACJA SPÓJNOŚCI DANYCH
====================================================================
*/

-- Liczba wizyt, diagnoz i płatności bez filtra daty.
SELECT
    (SELECT COUNT(*) FROM Wizyta) AS LiczbaWizyt,
    (SELECT COUNT(*) FROM Diagnoza) AS LiczbaDiagnoz,
    (SELECT COUNT(*) FROM Platnosc) AS LiczbaPlatnosci;


-- Liczba wykrytych naruszeń w poszczególnych widokach kontrolnych.
-- Oczekiwany wynik dla poprawnego zbioru testowego: 0 w każdym wierszu.
SELECT
    N'Zrealizowana wizyta bez diagnozy' AS Kontrola,
    COUNT(*) AS LiczbaBledow
FROM vw_WizytaBezDiagnozy

UNION ALL

SELECT
    N'Wizyta ze statusem Opłacona lub Zwrot bez rekordu płatności',
    COUNT(*)
FROM vw_WizytaBezPlatnosci

UNION ALL

SELECT
    N'Więcej niż jedna wizyta pacjenta w miesiącu',
    COUNT(*)
FROM vw_WiecejNiz1Wizyta

UNION ALL

SELECT
    N'Niespójność statusu wizyty i płatności',
    COUNT(*)
FROM vw_NiespojnoscStatusow

UNION ALL

SELECT
    N'Płatność niezgodna z cennikiem',
    COUNT(*)
FROM vw_PlatnoscNiezgodnaZCennikiem;



/*
====================================================================
II. ANALIZA WIZYT
====================================================================
*/

-- Wizyty według statusów, bez ograniczenia dat.
-- Uwzględnia również przyszłe wizyty umówione na lipiec.
SELECT
    StatusWizytyID,
    StatusWizyty,
    COUNT(*) AS LiczbaWizyt
FROM vw_FactWizyty
GROUP BY
    StatusWizytyID,
    StatusWizyty
ORDER BY
    StatusWizytyID;


-- Zrealizowane wizyty według miesiąca DataWizyty.
SELECT
    YEAR(DataWizyty) AS Rok,
    MONTH(DataWizyty) AS Miesiac,
    COUNT(*) AS LiczbaZrealizowanychWizyt
FROM vw_FactWizyty
WHERE StatusWizytyID = 2
  AND DataWizyty >= @DataOd
  AND DataWizyty < @DataDo
GROUP BY
    YEAR(DataWizyty),
    MONTH(DataWizyty)
ORDER BY
    Rok,
    Miesiac;


-- Liczba i udział procentowy zrealizowanych wizyt według typu.
SELECT
    TypWizyty,
    COUNT(*) AS LiczbaWizyt,
    CAST(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER ()
        AS DECIMAL(5,2)
    ) AS UdzialProcentowy
FROM vw_FactWizyty
WHERE StatusWizytyID = 2
  AND DataWizyty >= @DataOd
  AND DataWizyty < @DataDo
GROUP BY
    TypWizyty
ORDER BY
    LiczbaWizyt DESC;


-- Liczba i udział procentowy wizyt według specjalizacji.
SELECT
    SpecjalizacjaID,
    Specjalizacja,
    COUNT(*) AS LiczbaWizyt,
    CAST(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER ()
        AS DECIMAL(5,2)
    ) AS UdzialProcentowy
FROM vw_FactWizyty
WHERE StatusWizytyID = 2
  AND DataWizyty >= @DataOd
  AND DataWizyty < @DataDo
GROUP BY
    SpecjalizacjaID,
    Specjalizacja
ORDER BY
    LiczbaWizyt DESC;


-- Wolumen zrealizowanych wizyt według lekarza (bez czasu pracy).
SELECT
    LekarzID,
    LekarzImie,
    LekarzNazwisko,
    COUNT(*) AS LiczbaZrealizowanychWizyt
FROM vw_FactWizyty
WHERE StatusWizytyID = 2
  AND DataWizyty >= @DataOd
  AND DataWizyty < @DataDo
GROUP BY
    LekarzID,
    LekarzImie,
    LekarzNazwisko
ORDER BY
    LiczbaZrealizowanychWizyt DESC,
    LekarzNazwisko,
    LekarzImie;


-- Dziesięciu pacjentów z największą liczbą zrealizowanych wizyt.
SELECT TOP (10)
    f.PacjentID,
    p.Imie,
    p.Nazwisko,
    COUNT(*) AS LiczbaZrealizowanychWizyt
FROM vw_FactWizyty f
JOIN Pacjent p
    ON p.PacjentID = f.PacjentID
WHERE f.StatusWizytyID = 2
  AND f.DataWizyty >= @DataOd
  AND f.DataWizyty < @DataDo
GROUP BY
    f.PacjentID,
    p.Imie,
    p.Nazwisko
ORDER BY
    LiczbaZrealizowanychWizyt DESC,
    p.Nazwisko,
    p.Imie;


-- Liczba i udział wizyt według płci pacjenta.
SELECT
    Plec,
    COUNT(*) AS LiczbaWizyt,
    CAST(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER ()
        AS DECIMAL(5,2)
    ) AS UdzialProcentowy
FROM vw_FactWizyty
WHERE StatusWizytyID = 2
  AND DataWizyty >= @DataOd
  AND DataWizyty < @DataDo
GROUP BY
    Plec
ORDER BY
    Plec;



/*
====================================================================
III. ANALIZA KLINICZNA
====================================================================
*/

-- Dziesięć najczęściej występujących rozpoznań ICD-10
-- w zrealizowanych wizytach, według daty wizyty.
SELECT TOP (10)
    KodICD10,
    NazwaICD10,
    COUNT(*) AS LiczbaWystapien
FROM vw_FactWizyty
WHERE StatusWizytyID = 2
  AND DataWizyty >= @DataOd
  AND DataWizyty < @DataDo
  AND KodICD10 IS NOT NULL
GROUP BY
    KodICD10,
    NazwaICD10
ORDER BY
    LiczbaWystapien DESC,
    KodICD10;



/*
====================================================================
IV. ANALIZA FINANSOWA
====================================================================
*/

-- Przychód miesięczny według DataPlatnosci.
-- Wszystkie zarejestrowane wpłaty w okresie, również przedpłaty
-- oraz wpłaty dotyczące wizyt anulowanych (bez potrącania zwrotów).
SELECT
    YEAR(DataPlatnosci) AS Rok,
    MONTH(DataPlatnosci) AS Miesiac,
    SUM(Kwota) AS Przychod
FROM vw_FactWizyty
WHERE DataPlatnosci >= @DataOd
  AND DataPlatnosci < @DataDo
  AND Kwota IS NOT NULL
GROUP BY
    YEAR(DataPlatnosci),
    MONTH(DataPlatnosci)
ORDER BY
    Rok,
    Miesiac;


-- Wartość usług zrealizowanych według lekarza i DataWizyty.
-- W zestawieniu uwzględnia się kwoty związane z wizytami
-- wykonanymi w analizowanym okresie, niezależnie od terminu
-- wcześniejszej przedpłaty.
SELECT
    LekarzID,
    LekarzImie,
    LekarzNazwisko,
    SUM(Kwota) AS WartoscZrealizowanychUslug
FROM vw_FactWizyty
WHERE StatusWizytyID = 2
  AND DataWizyty >= @DataOd
  AND DataWizyty < @DataDo
  AND Kwota IS NOT NULL
GROUP BY
    LekarzID,
    LekarzImie,
    LekarzNazwisko
ORDER BY
    WartoscZrealizowanychUslug DESC,
    LekarzNazwisko,
    LekarzImie;
