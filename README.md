# Projekt i implementacja bazy danych oraz systemu raportowania dla poradni medycznej

Repozytorium zawiera implementację relacyjnej bazy danych poradni medycznej oraz projektu raportowania umożliwiającego analizę wizyt, pacjentów, lekarzy, rozpoznań i płatności.

## Zawartość repozytorium

- **[sql](sql/)** – skrypty tworzące strukturę bazy danych, widoki, procedury, funkcje, triggery oraz dane testowe. Folder zawiera również diagram ERD.
- **[powerBI](powerBI/)** – projekt raportowania, model danych, miary DAX i eksport raportu do PDF.
-  **[test](test/)** – skrypty SQL służące do weryfikacji integralności danych, działania widoków kontrolnych i indeksów oraz zapytań analitycznych.

## Uruchomienie

1. Utworzyć bazę danych, wykonując skrypty SQL w kolejności określonej przez ich numerację.
2. Otworzyć projekt PBIP w Power BI Desktop.
3. Skonfigurować połączenie z bazą danych i odświeżyć model.

Szczegółowe informacje dotyczące poszczególnych części projektu znajdują się w plikach README odpowiednich folderów.
