# Baza danych poradni medycznej

## Struktura bazy danych

Relacyjna baza danych `PoradniaDB` obejmuje obsługę pacjentów, lekarzy, specjalizacji, wizyt, diagnoz ICD-10 oraz płatności.

Zaimplementowano klucze główne i obce, ograniczenia integralności, indeksy, widoki, procedury składowane, funkcje oraz wyzwalacze (triggery).

### Diagram ERD

![Diagram ERD](erd.png)

## Zawartość katalogu

| Plik | Zawartość |
|---|---|
| `01_struktura_bazy.sql` | Definicje tabel, relacji, ograniczeń integralności i indeksów |
| `02_widoki.sql` | Widoki kontrolne i analityczne, w tym `vw_FactWizyty` |
| `03_procedury_triggery_funkcje.sql` | Procedury operacyjne i raportowe, funkcje oraz triggery kontrolujące integralność danych |
| `04_dane_testowe.sql` | Syntetyczne dane testowe dotyczące pacjentów, lekarzy, wizyt, diagnoz i płatności |
| `05_zapytania_analityczne.sql` | Zapytania analityczne oraz weryfikacja spójności danych |

## Uruchomienie

**Wymagania:** Microsoft SQL Server oraz SQL Server Management Studio (SSMS).

W SSMS należy połączyć się z odpowiednią instancją SQL Server i wykonać skrypty w następującej kolejności:

1. `01_struktura_bazy.sql` – utworzenie bazy danych `PoradniaDB`, tabel, relacji, ograniczeń i indeksów.
2. `02_widoki.sql` – utworzenie widoków kontrolnych i analitycznych.
3. `03_procedury_triggery_funkcje.sql` – utworzenie procedur składowanych, funkcji i triggerów.
4. `04_dane_testowe.sql` – wprowadzenie danych testowych.

Po wykonaniu powyższych skryptów można uruchomić `05_zapytania_analityczne.sql` w celu przeprowadzenia analiz oraz weryfikacji spójności danych.

Dane testowe obejmują wizyty historyczne z okresu od stycznia do czerwca 2025 r. oraz wizyty umówione na lipiec 2025 r. Główny okres analityczny obejmuje pierwsze półrocze 2025 r.

**Uwaga:** Skrypty przeznaczone są do inicjalizacji projektu w nowym środowisku. Ponowne uruchomienie ich na już wypełnionej bazie może powodować konflikty istniejących obiektów lub danych.

## Wybrane rozwiązania

- **Integralność relacyjna** – zastosowanie kluczy głównych, obcych oraz ograniczeń `CHECK` i `UNIQUE`.
- **Relacje lekarzy i specjalizacji** – kontrola poprawności przypisania specjalizacji do wizyty za pomocą złożonego klucza obcego.
- **Walidacja terminów** – ograniczenie rejestracji wizyt do dni roboczych, godzin 08:00–15:30 oraz 30-minutowych odstępów.
- **Kontrola dostępności lekarza** – zapobieganie kolizjom terminów z wykorzystaniem unikalnego indeksu filtrowanego. Anulowane wizyty nie blokują ponownej rezerwacji terminu.
- **Obsługa wizyt i płatności** – procedury rejestracji, opłacania, anulowania i realizacji wizyt, z uwzględnieniem przedpłat za teleporady oraz statusów płatności.
- **Integralność diagnoz** – triggery kontrolujące zgodność kodów ICD-10 ze specjalizacją i statusem wizyty oraz poprawność istniejących powiązań.
- **Obsługa transakcji** – wykorzystanie transakcji i mechanizmów `TRY...CATCH` w wybranych procedurach operacyjnych.
- **Widoki kontrolne** – identyfikacja wybranych niespójności dotyczących wizyt, diagnoz, płatności i statusów.
- **Widok analityczny `vw_FactWizyty`** – przygotowanie danych wizyt, diagnoz i płatności na potrzeby modelu raportowania w Power BI.

Dodatkowe skrypty weryfikacyjne znajdują się w katalogu [`test`](../test/) głównego repozytorium.
