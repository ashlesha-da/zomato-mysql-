DROP DATABASE IF EXISTS zomato_db;
CREATE DATABASE zomato_db;
USE zomato_db;

-- ============================================================
--  DROP EXISTING TABLES (safe re-run)
-- ============================================================

DROP TABLE IF EXISTS deliveries;
DROP TABLE IF EXISTS Orders;
DROP TABLE IF EXISTS riders;
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS restaurants;

-- ============================================================
--  CREATE TABLES
-- ============================================================

CREATE TABLE restaurants (
    restaurant_id  SERIAL PRIMARY KEY,
    restaurant_name VARCHAR(100) NOT NULL,
    city            VARCHAR(50),
    opening_hours   VARCHAR(50)
);

CREATE TABLE customers (
    customer_id   SERIAL PRIMARY KEY,
    customer_name VARCHAR(100) NOT NULL,
    reg_date      DATE
);

CREATE TABLE riders (
    rider_id    SERIAL PRIMARY KEY,
    rider_name  VARCHAR(100) NOT NULL,
    sign_up     DATE
);

CREATE TABLE Orders (
    order_id        SERIAL PRIMARY KEY,
    customer_id     INT,
    restaurant_id   INT,
    order_item      VARCHAR(255),
    order_date      DATE NOT NULL,
    order_time      TIME NOT NULL,
    order_status    VARCHAR(20) DEFAULT 'Pending',
    total_amount    DECIMAL(10,2) NOT NULL,
    FOREIGN KEY (customer_id)   REFERENCES customers(customer_id),
    FOREIGN KEY (restaurant_id) REFERENCES restaurants(restaurant_id)
);

CREATE TABLE deliveries (
    delivery_id     SERIAL PRIMARY KEY,
    order_id        INT,
    delivery_status VARCHAR(20) DEFAULT 'Pending',
    delivery_time   TIME,
    rider_id        INT,
    FOREIGN KEY (order_id)  REFERENCES Orders(order_id),
    FOREIGN KEY (rider_id)  REFERENCES riders(rider_id)
);


-- ============================================================
--   ANALYSIS QUERIES (Great for Interview!)
-- ============================================================

-- -------------------------------------------------------
-- Q1. Top 5 restaurants by total revenue
-- -------------------------------------------------------
SELECT 
    r.restaurant_name,
    r.city,
    COUNT(o.order_id)       AS total_orders,
    SUM(o.total_amount)     AS total_revenue
FROM Orders o
JOIN restaurants r ON o.restaurant_id = r.restaurant_id
WHERE o.order_status = 'Delivered'
GROUP BY r.restaurant_id, r.restaurant_name, r.city
ORDER BY total_revenue DESC
LIMIT 5;

-- -------------------------------------------------------
-- Q2. Monthly order trend
-- -------------------------------------------------------
SELECT 
    DATE_FORMAT(order_date, '%Y-%m') AS month,
    COUNT(order_id)                  AS total_orders,
    SUM(total_amount)                AS total_revenue
FROM Orders
GROUP BY month
ORDER BY month;

-- -------------------------------------------------------
-- Q3. Customer who spent the most
-- -------------------------------------------------------
SELECT 
    c.customer_name,
    COUNT(o.order_id)   AS total_orders,
    SUM(o.total_amount) AS total_spent
FROM Orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_status = 'Delivered'
GROUP BY c.customer_id, c.customer_name
ORDER BY total_spent DESC
LIMIT 5;

-- -------------------------------------------------------
-- Q4. Order cancellation rate per restaurant
-- -------------------------------------------------------
SELECT 
    r.restaurant_name,
    COUNT(o.order_id)                                               AS total_orders,
    SUM(CASE WHEN o.order_status = 'Cancelled' THEN 1 ELSE 0 END)  AS cancelled_orders,
    ROUND(
        SUM(CASE WHEN o.order_status = 'Cancelled' THEN 1 ELSE 0 END) * 100.0
        / COUNT(o.order_id), 2
    )                                                               AS cancellation_rate_pct
FROM Orders o
JOIN restaurants r ON o.restaurant_id = r.restaurant_id
GROUP BY r.restaurant_id, r.restaurant_name
ORDER BY cancellation_rate_pct DESC;

-- -------------------------------------------------------
-- Q5. Rider performance – number of deliveries each rider made
-- -------------------------------------------------------
SELECT 
    ri.rider_name,
    COUNT(d.delivery_id)                                                AS total_deliveries,
    SUM(CASE WHEN d.delivery_status = 'Delivered' THEN 1 ELSE 0 END)   AS successful,
    SUM(CASE WHEN d.delivery_status = 'Cancelled' THEN 1 ELSE 0 END)   AS cancelled
FROM deliveries d
JOIN riders ri ON d.rider_id = ri.rider_id
GROUP BY ri.rider_id, ri.rider_name
ORDER BY total_deliveries DESC;

-- -------------------------------------------------------
-- Q6. Peak order hours
-- -------------------------------------------------------
SELECT 
    HOUR(order_time)    AS order_hour,
    COUNT(order_id)     AS total_orders
FROM Orders
GROUP BY order_hour
ORDER BY total_orders DESC
LIMIT 5;

-- -------------------------------------------------------
-- Q7. City-wise revenue
-- -------------------------------------------------------
SELECT 
    r.city,
    COUNT(o.order_id)       AS total_orders,
    SUM(o.total_amount)     AS total_revenue,
    ROUND(AVG(o.total_amount), 2) AS avg_order_value
FROM Orders o
JOIN restaurants r ON o.restaurant_id = r.restaurant_id
WHERE o.order_status = 'Delivered'
GROUP BY r.city
ORDER BY total_revenue DESC;

-- -------------------------------------------------------
-- Q8. Customers with NO orders (not yet active)
-- -------------------------------------------------------
SELECT 
    c.customer_id,
    c.customer_name,
    c.reg_date
FROM customers c
LEFT JOIN Orders o ON c.customer_id = o.customer_id
WHERE o.order_id IS NULL;

-- -------------------------------------------------------
-- Q9. Most popular food items ordered
-- -------------------------------------------------------
SELECT 
    order_item,
    COUNT(*) AS times_ordered
FROM Orders
WHERE order_status = 'Delivered'
GROUP BY order_item
ORDER BY times_ordered DESC
LIMIT 10;

-- -------------------------------------------------------
-- Q10. Average delivery time per rider (in minutes)
-- -------------------------------------------------------
SELECT 
    ri.rider_name,
    ROUND(
        AVG(
            TIMESTAMPDIFF(MINUTE,
                o.order_time,
                d.delivery_time)
        ), 2
    ) AS avg_delivery_minutes
FROM deliveries d
JOIN Orders o  ON d.order_id = o.order_id
JOIN riders ri ON d.rider_id = ri.rider_id
WHERE d.delivery_status = 'Delivered'
  AND d.delivery_time IS NOT NULL
GROUP BY ri.rider_id, ri.rider_name
ORDER BY avg_delivery_minutes ASC;

-- -------------------------------------------------------
-- Q11. New vs Returning customers per month
-- -------------------------------------------------------
SELECT 
    DATE_FORMAT(order_date, '%Y-%m') AS month,
    COUNT(DISTINCT customer_id)      AS unique_customers
FROM Orders
GROUP BY month
ORDER BY month;

-- -------------------------------------------------------
-- Q12. Revenue growth month over month
-- -------------------------------------------------------
SELECT 
    month,
    total_revenue,
    LAG(total_revenue) OVER (ORDER BY month)  AS prev_month_revenue,
    ROUND(
        (total_revenue - LAG(total_revenue) OVER (ORDER BY month))
        * 100.0
        / LAG(total_revenue) OVER (ORDER BY month), 2
    ) AS growth_pct
FROM (
    SELECT 
        DATE_FORMAT(order_date, '%Y-%m') AS month,
        SUM(total_amount)                AS total_revenue
    FROM Orders
    WHERE order_status = 'Delivered'
    GROUP BY month
) monthly_revenue
ORDER BY month;

