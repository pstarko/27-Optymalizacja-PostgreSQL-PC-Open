-- ============================================================================
-- WARSZTATY: Optymalizacja Zapytań i Indeksowanie w PostgreSQL 
-- ============================================================================
-- Wymagane środowisko: PostgreSQL 15+ z rozszerzeniem pg_stat_statements
-- ============================================================================

-------------------------------------------------------------------------------
-- CZĘŚĆ 1: Przygotowanie środowiska i generowanie danych testowych
-------------------------------------------------------------------------------

DROP TABLE IF EXISTS TrainingData CASCADE;

CREATE TABLE TrainingData (
    ID SERIAL PRIMARY KEY,
    FirstName VARCHAR(50),
    LastName VARCHAR(50),
    Country VARCHAR(50),
    City VARCHAR(50),
    ModifiedDate TIMESTAMP
);

-- Generowanie 100 000 losowych rekordów
INSERT INTO TrainingData (FirstName, LastName, Country, City, ModifiedDate)
SELECT 
    (ARRAY['Eric', 'John', 'Anna', 'Maria', 'Piotr'])[floor(random() * 5 + 1)],
    (ARRAY['Smith', 'Nowak', 'Kowalski', 'Taylor', 'Davis'])[floor(random() * 5 + 1)],
    (ARRAY['Germany', 'Poland', 'USA', 'France', 'UK'])[floor(random() * 5 + 1)],
    (ARRAY['Berlin', 'Warsaw', 'New York', 'Paris', 'London'])[floor(random() * 5 + 1)],
    NOW() - (random() * (interval '365 days'))
FROM generate_series(1, 100000);

-- Aktualizacja statystyk tabeli dla planera zapytań
ANALYZE TrainingData;


-------------------------------------------------------------------------------
-- CZĘŚĆ 2: Analiza odczytów z bufora i sortowania
-------------------------------------------------------------------------------

-- Task 2.1: Skanowanie sterty (Seq Scan) i badanie bufora (shared hit / read)
-- Zadanie: Wykonaj profilowanie poniższego zapytania. Zwróć uwagę na wartości `shared hit` oraz `read`.

--- shared hit:
--- read: 
SELECT * FROM TrainingData WHERE FirstName = 'Eric';

-- Czy w sekcji Buffers pojawiło się 'read'? Co oznacza wyłączna obecność 'shared hit'?


-- Task 2.2: Operacje sortowania i pliki tymczasowe na dysku
-- Zadanie: Przeanalizuj plan dla sortowania nieindeksowanej kolumny przy dużym zbiorze danych.
-- Odczytaj wartości 'temp read' i 'temp written'. Co oznaczają te parametry i z jakiego powodu się pojawiły?
-- Jak zmiana parametru work_mem wpłynęłaby na ten wynik? (SET work_mem = '64MB';)

-- temp read: 
-- temp written:
SELECT * FROM TrainingData ORDER BY ModifiedDate;




-------------------------------------------------------------------------------
-- CZĘŚĆ 3: Indeksowanie B-Tree i weryfikacja rozmiarów tabel/indeksów 
-------------------------------------------------------------------------------

-- Task 3.1: Zakładanie indeksu B-Tree i profilowanie zapytania z filtrującym warunkiem ID
-- Jaki jest typ skanowania (z Seq Scan na Index Scan)?
-- Jaka jest liczba odczytanych bloków z bufora (shared hit)?

SELECT * FROM TrainingData WHERE ID = 1667;


-- Task 3.2: Ponowne profilowanie zapytania z filtrującym warunkiem ID
-- Jak zmienił się typ skanowania (z Seq Scan na Index Scan)?
-- O ile spadła liczba odczytanych bloków z bufora (shared hit)?

SELECT * FROM TrainingData WHERE ID = 1667;





-- Task 3.3: Weryfikacja rozmiarów tabeli oraz indeksów
SELECT pg_size_pretty(..........................('TrainingData')) AS tabela_size;
SELECT pg_size_pretty(..........................('TrainingData')) AS indexy_size;
SELECT pg_size_pretty(..........................('TrainingData')) AS calkowity_rozmiar;

-- Sprawdzenie czy tabela korzysta z TOAST i jakie kolumny są na to podatne:
SELECT reltoastrelid::regclass AS toast_table 
FROM ........................
WHERE .......................


-------------------------------------------------------------------------------
-- CZĘŚĆ 4: Narzut indeksów przy INSERT oraz fragmentacja (REINDEX) 
-------------------------------------------------------------------------------

-- Task 4.1: Porównanie kosztów wstawiania danych (Heap vs Tabela z indeksem)
DROP TABLE IF EXISTS AllData_heap;
DROP TABLE IF EXISTS AllData_ci;

SELECT * INTO AllData_heap FROM TrainingData WHERE 1=2;
SELECT * INTO AllData_ci FROM TrainingData WHERE 1=2;

-- Tworzymy indeks na drugiej tabeli PRZED wstawianiem danych
..............................................

-- Mierzymy i porównujemy koszt wstawiania:
EXPLAIN (...............) 
INSERT INTO AllData_heap SELECT * FROM TrainingData;

EXPLAIN (...............) 
INSERT INTO AllData_ci SELECT * FROM TrainingData;

-- Dlaczego tabela z indeksem wymusiła znacznie większą liczbę odczytów/zapisów bloków (shared_blks_hit)?


-- Task 4.2: Fragmentacja i przebudowa indeksu (REINDEX)
DROP TABLE IF EXISTS AllData2;
CREATE TABLE AllData2 AS SELECT * FROM TrainingData;
CREATE INDEX idx_alldata2_id ON AllData2(id);

-- Rozmiar indeksu przed aktualizacją:
SELECT relname AS indeks, pg_size_pretty(..........................) AS rozmiar_indeksu 
FROM ........................ 
WHERE .......................

-- Modyfikacja danych (spowoduje fragmentację i rozrost indeksu):
UPDATE AllData2 SET LastName = concat(LastName, 'x');

-- Rozmiar indeksu po UPDATE:
SELECT relname AS indeks, pg_size_pretty(..........................) AS rozmiar_indeksu 
FROM ........................ 
WHERE .......................

-- Przebudowa indeksu:
REINDEX INDEX idx_alldata2_id;

-- Rozmiar indeksu po REINDEX:
SELECT relname AS indeks, pg_size_pretty(..........................) AS rozmiar_indeksu 
FROM ........................ 
WHERE .......................;


-------------------------------------------------------------------------------
-- CZĘŚĆ 5: Analiza statystyk i Cache Hit Ratio 
-------------------------------------------------------------------------------

-- Włączenie rozszerzenia pg_stat_statements (jeśli jeszcze nie włączono)
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Task 5.1: Odczyt statystyk zapytań z bufora
SELECT query, calls, blk_read_time, blk_write_time, shared_blks_read, shared_blks_hit 
FROM ....................
ORDER BY calls DESC ;

-- Task 5.2: Obliczenie wskaźnika trafień w pamięci podręcznej (Cache Hit Ratio)
-- Wzór: shared_blks_hit / (shared_blks_hit + shared_blks_read)
....................................


-- Wskaźnik > 90% oznacza wysoką efektywność pamięci podręcznej.
-- Wskaźnik < 50% wskazuje na konieczność optymalizacji zapytań lub założenia dodatkowych indeksów.
