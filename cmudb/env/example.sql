-- Create customers table
CREATE TABLE customers (
    customer_id INTEGER,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    email VARCHAR(100),
    phone VARCHAR(20),
    city VARCHAR(50),
    signup_date DATE,
    account_balance DECIMAL(10,2)
);

-- Populate customers with 1000 rows
INSERT INTO customers (customer_id, first_name, last_name, email, phone, city, signup_date, account_balance)
SELECT
    gs,
    'FirstName' || gs AS first_name,
    'LastName' || gs AS last_name,
    'user' || gs || '@example.com' AS email,
    '+1-555-' || LPAD(gs::TEXT, 4, '0') AS phone,
    CASE (gs % 10)
        WHEN 0 THEN 'New York'
        WHEN 1 THEN 'Los Angeles'
        WHEN 2 THEN 'Chicago'
        WHEN 3 THEN 'Houston'
        WHEN 4 THEN 'Phoenix'
        WHEN 5 THEN 'Philadelphia'
        WHEN 6 THEN 'San Antonio'
        WHEN 7 THEN 'San Diego'
        WHEN 8 THEN 'Dallas'
        WHEN 9 THEN 'Austin'
    END AS city,
    CURRENT_DATE - (random() * 365 * 3)::INT AS signup_date,
    (random() * 10000)::DECIMAL(10,2) AS account_balance
FROM generate_series(1, 1000) gs;

-- Create orders table
CREATE TABLE orders (
    order_id INTEGER,
    customer_id INTEGER,
    order_date TIMESTAMP,
    total_amount DECIMAL(10,2),
    status VARCHAR(20),
    payment_method VARCHAR(20),
    shipping_address VARCHAR(200)
);

-- Populate orders with 2000 rows
INSERT INTO orders (order_id, customer_id, order_date, total_amount, status, payment_method, shipping_address)
SELECT 
    gs,
    (random() * 999 + 1)::INT AS customer_id,
    CURRENT_TIMESTAMP - (random() * 365 * 2 || ' days')::INTERVAL AS order_date,
    (random() * 500 + 10)::DECIMAL(10,2) AS total_amount,
    CASE (gs % 5)
        WHEN 0 THEN 'Pending'
        WHEN 1 THEN 'Processing'
        WHEN 2 THEN 'Shipped'
        WHEN 3 THEN 'Delivered'
        WHEN 4 THEN 'Cancelled'
    END AS status,
    CASE (gs % 3)
        WHEN 0 THEN 'Credit Card'
        WHEN 1 THEN 'PayPal'
        WHEN 2 THEN 'Debit Card'
    END AS payment_method,
    gs || ' Main Street, City, State' AS shipping_address
FROM generate_series(1, 2000) gs;

-- Verify row counts
SELECT 'customers' AS table_name, COUNT(*) AS row_count FROM customers
UNION ALL
SELECT 'orders' AS table_name, COUNT(*) AS row_count FROM orders;
