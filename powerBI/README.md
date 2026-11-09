# System raportowania poradni medycznej

## Struktura projektu

| Element | Zawartość |
|---|---|
| `system_raportowania.pbip` | Plik projektu Power BI |
| `system_raportowania.Report/` | Definicje stron, wizualizacji i interakcji |
| `system_raportowania.SemanticModel/` | Model danych, relacje, zapytania Power Query i miary DAX |
| `system_raportowania.pdf` | Podgląd gotowego raportu |

## Model danych

Model analityczny oparto na tabeli faktów `FactWizyta` oraz powiązanych tabelach wymiarów.

Dane wizyt pobierane są z widoku SQL `dbo.vw_FactWizyty`, natomiast dane opisowe pochodzą z odpowiednich tabel bazy `PoradniaDB`.

Zastosowano:
- Relacje jeden-do-wielu z jednokierunkowym filtrowaniem.
- Aktywną relację kalendarza dla daty wizyty.
- Nieaktywną relację kalendarza dla daty płatności.
- Transformacje Power Query przygotowujące dane do analiz.
- Miary DAX uwzględniające kontekst filtrowania.

## Wybrane rozwiązania DAX

- **`USERELATIONSHIP`** – obliczanie przychodu według daty płatności, niezależnie od daty wykonania świadczenia.
- **`REMOVEFILTERS`** – uwzględnianie historii wizyt przy identyfikacji pacjentów powracających.
- **Miary referencyjne** – porównywanie wskaźników specjalizacji i lekarzy z wynikami całej poradni.
- **`DIVIDE`** – obliczanie wskaźników procentowych i średnich z obsługą dzielenia przez zero.

## Strony raportu

**1. Podsumowanie działalności poradni**

Analiza wizyt zrealizowanych i anulowanych, aktywnych pacjentów, przychodów oraz struktury świadczeń.

**2. Pacjenci i analiza medyczna**

Struktura demograficzna pacjentów, analiza pacjentów powracających oraz ranking rozpoznań ICD-10.

**3. Działalność operacyjna i finanse**

Analiza aktywności lekarzy, wskaźników anulowań, przychodów oraz struktury typów wizyt według specjalizacji.

Raport udostępnia zsynchronizowane fragmentatory okresu i specjalizacji, dynamiczne podpowiedzi oraz linie referencyjne.

Wybrane wykresy porównawcze pozostają niezależne od fragmentatora specjalizacji.

## Uruchomienie projektu

**Wymagania:** Power BI Desktop oraz dostęp do bazy SQL Server `PoradniaDB`.

1. Pobrać repozytorium, zachowując strukturę folderów projektu.
2. Odtworzyć bazę `PoradniaDB` przy użyciu skryptów z katalogu `SQL`.
3. Otworzyć plik `system_raportowania.pbip` w Power BI Desktop.
4. W razie potrzeby przejść do **Plik → Opcje i ustawienia → Ustawienia źródła danych** i zaktualizować nazwę serwera SQL Server.
5. Skonfigurować uwierzytelnianie i odświeżyć dane.

Domyślna konfiguracja projektu wskazuje serwer `localhost` i bazę `PoradniaDB`.

**Uwaga:** Projekt PBIP zawiera definicje raportu i modelu, ale nie zawiera zaimportowanych danych. Po pobraniu z GitHuba należy zapewnić dostęp do bazy źródłowej i wykonać odświeżenie.

Podgląd raportu bez uruchamiania Power BI jest dostępny w pliku `system_raportowania.pdf`.
