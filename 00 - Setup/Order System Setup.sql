-- Module 2 demo setup
-- Query performance and indexing

DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS customers;

SELECT setseed(0.42);

CREATE TABLE customers (
    customer_id     BIGSERIAL PRIMARY KEY,
    customer_name   TEXT NOT NULL,
    email           TEXT NOT NULL,
    region          TEXT NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE products (
    product_id      BIGSERIAL PRIMARY KEY,
    product_name    TEXT NOT NULL,
    category        TEXT NOT NULL,
    unit_price      NUMERIC(10,2) NOT NULL,
    product_details JSONB NOT NULL,
    active          BOOLEAN NOT NULL DEFAULT true
);

CREATE TABLE orders (
    order_id        BIGSERIAL PRIMARY KEY,
    customer_id     BIGINT NOT NULL REFERENCES customers(customer_id),
    order_date      DATE NOT NULL,
    status          TEXT NOT NULL,
    shipping_region TEXT NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE order_items (
    order_item_id   BIGSERIAL PRIMARY KEY,
    order_id        BIGINT NOT NULL REFERENCES orders(order_id),
    product_id      BIGINT NOT NULL REFERENCES products(product_id),
    quantity        INTEGER NOT NULL,
    unit_price      NUMERIC(10,2) NOT NULL
);

INSERT INTO customers (
    customer_name,
    email,
    region,
    created_at
)
SELECT
    'Customer ' || gs,
    'customer' || gs || '@example.com',
    (ARRAY['North America', 'Europe', 'Asia Pacific', 'Latin America'])[1 + floor(random() * 4)::int],
    now() - (random() * interval '3 years')
FROM generate_series(1, 50000) AS gs;

INSERT INTO products (
    product_name,
    category,
    unit_price,
    product_details,
    active
)
SELECT
    'Product ' || gs,
    category,
    price,
    jsonb_build_object(
        'brand', (
            ARRAY[
                'Carved Rock Fitness',
                'Globomatics',
                'Globoticket',
                'Bethany''s Pie Shop',
                'Wired Brain Coffee Company'
            ]
            )[1 + floor(random() * 5)::int],
        'color', (ARRAY['black', 'white', 'blue', 'red', 'silver', 'green'])[1 + floor(random() * 6)::int],
        'warranty_months', (ARRAY[0, 6, 12, 24, 36])[1 + floor(random() * 5)::int],
        'rating', round((3.0 + random() * 2.0)::numeric, 2),
        'fragile', random() < 0.15
    ),
    random() < 0.95
FROM (
    SELECT
        gs,
        (ARRAY['Electronics', 'Home', 'Office', 'Sports', 'Clothing', 'Books'])[1 + floor(random() * 6)::int] AS category,
        round((10 + random() * 490)::numeric, 2) AS price
    FROM generate_series(1, 10000) AS gs
) AS p;

INSERT INTO orders (
    customer_id,
    order_date,
    status,
    shipping_region,
    created_at
)
SELECT
    1 + floor(random() * 50000)::bigint,
    current_date - floor(random() * 730)::int,
    CASE
        WHEN random() < 0.72 THEN 'completed'
        WHEN random() < 0.86 THEN 'shipped'
        WHEN random() < 0.94 THEN 'pending'
        WHEN random() < 0.98 THEN 'cancelled'
        ELSE 'returned'
    END,
    (ARRAY['North America', 'Europe', 'Asia Pacific', 'Latin America'])[1 + floor(random() * 4)::int],
    now() - (random() * interval '2 years')
FROM generate_series(1, 500000);

INSERT INTO order_items (
    order_id,
    product_id,
    quantity,
    unit_price
)
SELECT
    o.order_id,
    p.product_id,
    1 + floor(random() * 5)::int,
    p.unit_price
FROM orders o
JOIN LATERAL generate_series(1, 1 + floor(random() * 4)::int) AS item(n)
    ON true
JOIN LATERAL (
    SELECT
        product_id,
        unit_price
    FROM products
    OFFSET floor(random() * 10000)
    LIMIT 1
) AS p
    ON true;

ANALYZE customers;
ANALYZE products;
ANALYZE orders;
ANALYZE order_items;