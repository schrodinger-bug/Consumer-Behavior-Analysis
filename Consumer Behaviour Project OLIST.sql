-- To take a look into the purchase frequency of customers
-- Make a new table as purchase_freq
-- then count the order_id per customer_unique_id
CREATE TABLE purchase_freq
(
	customer_id TEXT,
    customer_unique_id TEXT,
    order_id TEXT
);

INSERT INTO purchase_freq
(
	customer_id,
    customer_unique_id,
    order_id
)
SELECT
	c.customer_id,
    c.customer_unique_id,
    o.order_id
FROM
	olist_customers_dataset c
		JOIN
	olist_orders_dataset o ON c.customer_id=o.customer_id;

SELECT 
	customer_unique_id,
    count(order_id) as no_of_orders
FROM purchase_freq
GROUP BY customer_unique_id
ORDER BY no_of_orders DESC
Limit 100; 

-- To get the value of a customers total money spent in buying goods from olist
-- This means that we will study the total contribution of a consumer to the total revenue of olist
-- We will call this as customer lifetime value
-- For this, first create a table named as customer_lifetime value then have a look into it using select statement 
-- Through select statement get total value of money spent by one consumer using count and sum functions

CREATE TABLE customer_lifetime_value
(
	customer_unique_id TEXT,
    no_of_orders INT,
    total_value INT
);

INSERT INTO customer_lifetime_value
(
	customer_unique_id,
    no_of_orders,
    total_value
)
SELECT
	pf.customer_unique_id,
    COUNT(pf.order_id),
    SUM(op.payment_value)
FROM
	purchase_freq pf
		JOIN
	olist_order_payments_dataset op ON pf.order_id=op.order_id
GROUP BY customer_unique_id;
    
SELECT
	* 
FROM customer_lifetime_value
GROUP BY customer_unique_id
ORDER BY total_value DESC
LIMIT 100;

-- To determine the average amount spent by customers per order
-- use the select statement and sum function

SELECT 
	AVG(payment_value)
FROM olist_order_payments_dataset;

-- To determine the repeat purchase rate  of consumers which means that how much consumers the firm is able to retain over the time 
-- For this, we will count the distinct customer_id and then calulate its percentage over the count of order id 
-- and call it as repeat_purchase_rate

SELECT 
	customer_id,
    COUNT(DISTINCT customer_id) AS returning_customers,
    (COUNT(DISTINCT customer_id) / COUNT(order_id)) AS repeat_purchase_rate
FROM
    purchase_freq
GROUP BY customer_id; 

-- To identify the products frequently purchsed together we will do the basket analysis 
-- For this, select order_id, product_id and order_items id from olist_order_items_dataset
-- And then also count the items in one order to find out the maximum number of items in an order

SELECT
	order_id,
    product_id ,
    order_item_id
FROM
	olist_order_items_dataset;

SELECT
	order_id,
    COUNT(product_id) AS no_of_prod,
    COUNT(order_item_id) AS items_in_basket
FROM
	olist_order_items_dataset
 GROUP BY order_id
 ORDER BY items_in_basket DESC
 LIMIT 100;
 
 -- To perform the customer segmentation on the basis of customer geolocation
 -- This will be done by selecting the customer_city and the count of customer_unique_id grouped by customer_city
 -- from olist_customers_dataset
 -- The state wise distribution of customers will also be analysed by selecting the customer_state and count of customer_unique_id
 -- grouped by customer_state 
 
 SELECT
	customer_city,
    COUNT(customer_unique_id) AS customers_in_city
FROM
	olist_customers_dataset
GROUP BY customer_city
ORDER BY customers_in_city DESC
LIMIT 100;
 
 SELECT
	customer_state,
    COUNT(customer_unique_id) AS customers_in_state
FROM
	olist_customers_dataset
GROUP BY customer_state
ORDER BY customers_in_state DESC
LIMIT 100;
 
 -- To obtain the customer segmentation by seller preference, select seller_id and take a count of order_id grouped by seller_id
 -- To know the products that the customers prefer to buy from a particular seller or the products that a particular seller sells
 -- also the count of the product that a particular seller sells 
 
 SELECT 
	seller_id,
    COUNT(order_id) AS orders
FROM
	olist_order_items_dataset
GROUP BY seller_id
ORDER BY orders DESC
LIMIT 100;

-- disabling ONLY_FULL_GROUP_BY for the current database session

SET sql_mode = (SELECT REPLACE(@@sql_mode, 'ONLY_FULL_GROUP_BY',''));

-- ONLY_FULL_GROUP_BY is disabled to remove error code 1055

SELECT
	seller_id,
    product_id,
    COUNT(order_id) AS orders
FROM
	olist_order_items_dataset
GROUP BY product_id
ORDER BY orders DESC
LIMIT 100;

SELECT
	seller_id,
    COUNT(product_id) AS products
FROM
	olist_order_items_dataset
GROUP BY seller_id
ORDER BY products DESC
LIMIT 100;

-- Measure customer satisfaction and loyalty based on feedback, termed as net promoter score
-- For this we will check thw review_score of customers and then categorize them on the basis of it
-- First of all creating a table called as customer_review_score
-- Then categorize the customers on the bsis of review score by assigning them net_promoter_score 
-- If review_score> 3; net_promoter_score =1 else net_promoter_score = 0
	
SELECT
	 order_id,
     review_score
FROM
	olist_order_reviews_dataset
ORDER BY review_score DESC;

CREATE TABLE customer_review_score
(
	customer_unique_id TEXT,
    order_id TEXT,
	review_id TEXT,
    review_score INT
);

INSERT INTO customer_review_score
(
	customer_unique_id,
    order_id,
    review_id,
    review_score
)
SELECT
	pf.customer_unique_id,
    orev.order_id,
    orev.review_id,
    orev.review_score
FROM
	purchase_freq pf
		LEFT JOIN
	olist_order_reviews_dataset orev ON pf.order_id=orev.order_id;
    
SELECT * FROM customer_review_score;
    
ALTER TABLE customer_review_score
ALTER COLUMN review_score SET DEFAULT 0;
    
-- In order to remove error code 1175 that says the server is using safe update mode and thus poses some restrictions on updating the table

SET SQL_SAFE_UPDATES = 0;

-- Now running the update query will not throw an error and the table will be updated successfully

UPDATE customer_review_score
SET review_score = 0
WHERE review_score IS NULL;

SELECT
	customer_unique_id,
	ROUND(SUM(CASE WHEN review_score >= 3 THEN 1 ELSE 0 END)) AS nps
FROM 
	customer_review_score
GROUP BY customer_unique_id
ORDER BY nps DESC;

-- For RFM segmentation use customer_unique_id, order_purchase_timestamp, order_id, payment_value
-- In the below query, statement 2 under SELECT is describing if the consumer is continuing with the firm or not and thus named as recency
-- statement 3 is decribing the no. of times a distinct order is placed by a consumer thus describing frequency
-- statement 4 is describing the total amount of money spent by a customer at the firm thus describing monetary 
-- contribution of a customer to the firm
-- And so the customers now can be classified on the basis of their recency of orders, frequency of orders and the monetary contribution 

SELECT
	pf.customer_unique_id,
    DATEDIFF(NOW(), MAX(o.order_purchase_timestamp)) AS recency,
    COUNT(DISTINCT pf.order_id) AS frequency,
    SUM(op.payment_value) AS monetary
FROM
	purchase_freq pf
		JOIN
	olist_orders_dataset o ON pf.order_id = o.order_id
		JOIN
	olist_order_payments_dataset op ON o.order_id = op.order_id
GROUP BY customer_unique_id
ORDER BY recency, monetary DESC
LIMIT 100;

-- Fetching product insights
-- To know which product is ordered how many times

SELECT
	product_id,
    product_category_name,
    product_description_lenght
FROM
	olist_products_dataset
ORDER BY product_id ASC;

-- Categorizing customers according to their preference towards different payment methods
-- by payment_value and by orders
-- statement 2 under SELECT is describing how frequently the consumers prefer using a particular payment method

SELECT 
	payment_type,
    COUNT(order_id) AS orders
FROM
	olist_order_payments_dataset
GROUP BY payment_type
ORDER BY orders DESC;

-- statement 2 under SELECT is describing the volume of payment through a particular payment method

SELECT
	payment_type,
    SUM(payment_value) AS total_value
FROM
	olist_order_payments_dataset
GROUP BY payment_type
ORDER BY total_value DESC;

-- Categorizing customers on the basis of both the geographical area and payment method
-- or we can say that we want to know what payment method people prefer the most in a geographical area

CREATE TABLE payment_preference_geo
(
	customer_unique_id TEXT,
    customer_city TEXT,
    customer_state TEXT,
    order_id TEXT,
    payment_type TEXT
);

INSERT INTO payment_preference_geo
(
	customer_unique_id,
    customer_city,
    customer_state,
    order_id,
    payment_type 
)
SELECT
	c.customer_unique_id,
    c.customer_city,
    c.customer_state,
    pf.order_id,
    op.payment_type
FROM
	olist_customers_dataset c
		JOIN
	purchase_freq pf ON pf.customer_unique_id = c.customer_unique_id
		JOIN
	olist_order_payments_dataset op ON pf.order_id = op.order_id;
    
SELECT
	payment_type,
    customer_city,
    COUNT(customer_unique_id) AS no_of_customers
FROM
	payment_preference_geo
GROUP BY customer_city
ORDER BY no_of_customers DESC;

SELECT
	payment_type,
    customer_state,
    COUNT(customer_unique_id) AS no_of_customers
FROM
	payment_preference_geo
GROUP BY customer_state
ORDER BY no_of_customers DESC;

    





    
    
    
    