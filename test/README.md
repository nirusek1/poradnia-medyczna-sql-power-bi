# Testy bazy danych poradni medycznej

Folder zawiera skrypty służące do weryfikacji integralności diagnoz, działania widoków kontrolnych oraz analizy indeksów i zapytań analitycznych.

## Zawartość katalogu

| Plik | Zawartość |
|---|---|
| `01_integralnosc_diagnoz.sql` | Pięć scenariuszy sprawdzających odrzucanie operacji naruszających integralność diagnoz i zgodność kodów ICD-10 ze specjalizacją wizyty. |
| `02_widoki_kontrolne.sql` | Pięć scenariuszy sprawdzających wykrywanie nieprawidłowości przez widoki kontrolne oraz działanie ograniczenia CHECK. |
| `03_indeksy.sql` | Zapytania służące do oceny wykorzystania indeksów i odczytów logicznych. |
| `04_zapytania_analityczne.sql` | Zapytania analityczne służące do kontroli wyników i pomiaru czasu wykonania. |

## Wymagania

- Microsoft SQL Server.
- SQL Server Management Studio.
- Baza testowa `PoradniaDB_test` zawierająca strukturę, obiekty programowalne i dane testowe projektu.
- Uprawnienia do wykonywania operacji używanych w skryptach.

## Przygotowanie bazy testowej

Testy należy wykonywać na osobnej bazie `PoradniaDB_test`.

Bazę można przygotować przez odtworzenie kopii zapasowej `PoradniaDB` pod nazwą `PoradniaDB_test`, z osobnymi plikami danych i dziennika transakcji.

Alternatywnie można wykorzystać robocze kopie skryptów z katalogu `sql`. Przed ich wykonaniem należy zmienić wszystkie odwołania do docelowej bazy z `PoradniaDB` na `PoradniaDB_test`, w tym instrukcje tworzenia, usuwania i wyboru bazy. Następnie wykonać skrypty w kolejności ich numeracji.

Samo dodanie `USE PoradniaDB_test` przed niezmienionymi skryptami nie wystarczy, jeśli zawierają one własne instrukcje `USE PoradniaDB`.

## Uruchomienie

1. Przygotować bazę `PoradniaDB_test`.
2. Otworzyć wybrany skrypt w SQL Server Management Studio.
3. Sprawdzić, czy instrukcja `USE` wskazuje bazę `PoradniaDB_test`.
4. Wykonać skrypt i przeanalizować zakładki **Results** oraz **Messages**.
5. Powtórzyć czynności dla kolejnych plików.

Przed wykonaniem testów można sprawdzić kontekst połączenia:

    USE PoradniaDB_test;
    GO
    SELECT DB_NAME() AS BazaTestowa;

Jeżeli przełączenie bazy zakończy się błędem, należy przerwać wykonywanie skryptu i sprawdzić konfigurację.

## Interpretacja wyników

### Integralność diagnoz

Skrypt `01_integralnosc_diagnoz.sql` obejmuje próby:

- przypisania kodu ICD-10 niezgodnego ze specjalizacją wizyty;
- dodania diagnozy do niezrealizowanej wizyty;
- zmiany statusu wizyty posiadającej diagnozę na niedozwolony;
- zmiany specjalizacji wizyty na niezgodną z diagnozą;
- usunięcia mapowania kodu ICD-10 i specjalizacji wykorzystywanego przez diagnozę.

Odrzucenie niedozwolonej operacji z oczekiwanym komunikatem jest prawidłowym wynikiem testu.

### Widoki kontrolne

Skrypt `02_widoki_kontrolne.sql` sprawdza wykrywanie celowo wprowadzonych nieprawidłowości oraz odrzucenie operacji naruszającej ograniczenie CHECK.

Po zakończeniu testów i wycofaniu zmian widoki kontrolne powinny ponownie wskazywać brak nieprawidłowości w wyjściowym zbiorze danych.

### Indeksy i zapytania analityczne

Wyniki skryptów `03_indeksy.sql` i `04_zapytania_analityczne.sql` należy oceniać na podstawie zwróconych danych, komunikatów statystycznych oraz planów wykonania.

Czasy wykonania zależą od konfiguracji środowiska, obciążenia serwera i stanu pamięci podręcznej. Nie muszą być identyczne z wartościami przedstawionymi w pracy dyplomowej.

## Zakres weryfikacji

Skrypty sprawdzają wybrane mechanizmy i zapytania projektu. Nie stanowią pełnego zestawu testów wszystkich procedur, bezpieczeństwa, współbieżności ani wydajności systemu w warunkach produkcyjnych.

Dane wykorzystane w testach są syntetyczne.
