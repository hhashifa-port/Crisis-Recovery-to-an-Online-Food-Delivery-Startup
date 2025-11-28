-- Database: QuickBite

-- DROP DATABASE IF EXISTS "QuickBite";

CREATE DATABASE "QuickBite"
    WITH
    OWNER = postgres
    ENCODING = 'UTF8'
    LC_COLLATE = 'English_Indonesia.1252'
    LC_CTYPE = 'English_Indonesia.1252'
    LOCALE_PROVIDER = 'libc'
    TABLESPACE = pg_default
    CONNECTION LIMIT = -1
    IS_TEMPLATE = False;

-- CREATE TABLE: fact_orders
-- Tracks customer orders, including amounts, timestamps, and cancellation status.
CREATE TABLE IF NOT EXISTS fact_orders (
	 order_id TEXT PRIMARY KEY,
	 customer_id TEXT NOT NULL,
	 restaurant_id TEXT NOT NULL,
	 delivery_partner_id TEXT,
	 order_timestamp TIMESTAMP NOT NULL,
	 subtotal_amount FLOAT NOT NULL,
	 discount_amount FLOAT NOT NULL,
	 delivery_fee FLOAT NOT NULL,
	 total_amount FLOAT NOT NULL,
	 is_cod TEXT NOT NULL,
	 is_cancelled TEXT NOT NULL
);

-- CREATE TABLE: fact_order_items
-- Tracks individual items in each order.
CREATE TABLE IF NOT EXISTS fact_order_items (
	order_id TEXT NOT NULL,
	item_id TEXT NOT NULL,
	menu_item_id TEXT NOT NULL,
	restaurant_id TEXT NOT NULL,
	quantity INTEGER NOT NULL,
	unit_price FLOAT NOT NULL,
	item_discount FLOAT NOT NULL,
	line_total FLOAT NOT NULL
);

-- CREATE TABLE: fact_ratings
-- Contains ratings and review data provided by customers for each order.
CREATE TABLE IF NOT EXISTS fact_ratings(
	order_id TEXT,
	customer_id TEXT,
	restaurant_id TEXT,
	rating FLOAT,
	review_text TEXT,
	review_timestamp TIMESTAMP,
	sentiment_score	FLOAT
);

-- CREATE TABLE: fact_delivery_performance
-- Tracks delivery performance metrics like delivery times and distance.
CREATE TABLE IF NOT EXISTS fact_delivery_performance(
	order_id TEXT PRIMARY KEY,
	actual_delivery_time_mins INTEGER NOT NULL,
	expected_delivery_time_mins INTEGER NOT NULL,
	distance_km FLOAT NOT NULL
);

-- CREATE TABLE: dim_customer
-- Captures customer onboarding and acquisition details including signup information, location, and acquisition channel.
CREATE TABLE IF NOT EXISTS dim_customer(
	customer_id TEXT PRIMARY KEY,
	signup_date DATE NOT NULL,
	city TEXT NOT NULL,
	acquisition_channel TEXT NOT NULL
);

-- CREATE TABLE: dim_restaurant
-- Contains information about the restaurants involved with QuickBite.
CREATE TABLE IF NOT EXISTS dim_restaurant(
	restaurant_id TEXT PRIMARY KEY,
	restaurant_name TEXT NOT NULL,
	city TEXT NOT NULL,
	cuisine_type TEXT NOT NULL,
	partner_type TEXT NOT NULL,
	avg_prep_time_min TEXT NOT NULL,
	is_active TEXT NOT NULL
);

-- CREATE TABLE: dim_delivery_partner
-- Contains details about the delivery partners.
CREATE TABLE IF NOT EXISTS dim_delivery_partner(
	delivery_partner_id TEXT PRIMARY KEY, 
	partner_name TEXT NOT NULL,
	city TEXT NOT NULL,
	vehicle_type TEXT NOT NULL,
	employment_type TEXT NOT NULL,
	avg_rating FLOAT NOT NULL,
	is_active TEXT NOT NULL
);

-- CREATE TABLE: dim_menu_item
-- Contains details about menu items offered by restaurants.
CREATE TABLE IF NOT EXISTS dim_menu_item(
	menu_item_id TEXT PRIMARY KEY,
	restaurant_id TEXT NOT NULL,
	item_name TEXT NOT NULL,
	category TEXT NOT NULL,
	is_veg TEXT NOT NULL,
	price FLOAT NOT NULL
);


---------------------------------------------------

-- DATA TRANSFORMATION

-- Did the transactions occur before, during, or after crisis?
ALTER TABLE fact_orders
ADD COLUMN IF NOT EXISTS crisis_phase TEXT;

UPDATE fact_orders
SET crisis_phase = 
	CASE
		WHEN order_timestamp < '2025-06-01' THEN 'Pre-Crisis'
		WHEN order_timestamp > '2025-06-30' THEN 'Recovery'
		ELSE 'Crisis'
	END
;

SELECT crisis_phase, COUNT(*)
FROM fact_orders
GROUP BY 1;

ALTER TABLE fact_orders
ADD COLUMN IF NOT EXISTS pre_crisis INTEGER;

UPDATE fact_orders
SET pre_crisis = 
	CASE
		WHEN crisis_phase = 'Pre-Crisis' THEN 1
		ELSE 0
	END
;

-- Change boolean columns from Y/N to 1/0
ALTER TABLE dim_delivery_partner
ALTER COLUMN is_active TYPE integer
USING 
	CASE
		WHEN is_active = 'Y' THEN 1
		ELSE 0
	END
;

ALTER TABLE dim_menu_item
ALTER COLUMN is_veg TYPE integer
USING 
	CASE
		WHEN is_veg = 'Y' THEN 1
		ELSE 0
	END
;

ALTER TABLE dim_restaurant
ALTER COLUMN is_active TYPE integer
USING 
	CASE
		WHEN is_active = 'Y' THEN 1
		ELSE 0
	END
;

ALTER TABLE fact_orders
ALTER COLUMN is_cod TYPE integer
USING 
	CASE
		WHEN is_cod = 'Y' THEN 1
		ELSE 0
	END
;

ALTER TABLE fact_orders
ALTER COLUMN is_cancelled TYPE integer
USING 
	CASE
		WHEN is_cancelled = 'Y' THEN 1
		ELSE 0
	END
;


-- Create New Columns
ALTER TABLE fact_delivery_performance
ADD COLUMN delayed_delivery_mins integer;

UPDATE fact_delivery_performance
SET 
	delivery_time_difference = expected_delivery_time_mins - actual_delivery_time_mins;

ALTER TABLE dim_restaurant
ADD COLUMN prep_time_level INTEGER;

UPDATE dim_restaurant
SET prep_time_level = CASE
	WHEN avg_prep_time_min = '<=15' THEN 1
	WHEN avg_prep_time_min = '16-25' THEN 2
	WHEN avg_prep_time_min = '26-40' THEN 3
	WHEN avg_prep_time_min = '>40' THEN 4
	ELSE 0
END;

ALTER TABLE fact_ratings
ADD COLUMN review_sentiment INTEGER;

UPDATE fact_ratings
SET review_sentiment = CASE
	WHEN 
		review_text IN ('Horrible service', 'Packaging was poor', 'Not worth the price',
						'Portion size smaller than expected', 'Food quality is not good',
						'Food safety issue', 'Very late', 'Cold food', 'Worst order',
						'Never again', 'Stale food served', 'Could be hotter', 'Packaging issue',
						'Bad taste', 'Terrible hygiene', 'Food quality not great', 'Not recommended') 
	THEN -1
	
	WHEN 
		review_text IN ('Fresh and delicious', 'Excellent service', 'Satisfied overall',
						'Okay experience', 'Good but can improve', 'Great taste!', 'Loved it!',
						'Super fast delivery') 
	THEN 1
	
	WHEN review_text IN ('Average experience', 'Tasty but a bit late') THEN 0
	ELSE NULL
END;

ALTER TABLE fact_ratings
ADD COLUMN food_sentiment INTEGER,
ADD COLUMN delivery_sentiment INTEGER,
ADD COLUMN service_sentiment INTEGER;

UPDATE fact_ratings
SET
    food_sentiment = CASE
        WHEN review_text IS NULL THEN NULL
        WHEN review_text IN (
            'Not worth the price', 
            'Portion size smaller than expected', 
            'Food quality is not good', 
            'Food safety issue', 
            'Bad taste', 
            'Food quality not great', 
            'Not recommended'
        ) THEN -1
        WHEN review_text IN (
            'Fresh and delicious', 
            'Great taste!', 
            'Satisfied overall', 
            'Loved it!'
        ) THEN 1
        ELSE 0
    END,
    
    delivery_sentiment = CASE
        WHEN review_text IS NULL THEN NULL
        WHEN review_text IN (
            'Packaging was poor', 
            'Packaging issue', 
            'Very late', 
            'Cold food', 
            'Stale food served', 
            'Could be hotter'
        ) THEN -1
        WHEN review_text IN ('Super fast delivery') THEN 1
        WHEN review_text IN ('Tasty but a bit late') THEN 0
        ELSE 0
    END,
    
    service_sentiment = CASE
        WHEN review_text IS NULL THEN NULL
        WHEN review_text IN ('Horrible service', 'Terrible hygiene') THEN -1
        WHEN review_text IN ('Excellent service', 'Loved it!') THEN 1
        WHEN review_text IN ('Good but can improve', 'Average experience', 'Okay experience') THEN 0
        ELSE 0
    END;
	

---------------------------------------------------


-- MERGE TABLES FOR CUSTOMER SEGMENTATION
CREATE TABLE IF NOT EXISTS order_details AS
SELECT 
	fo.customer_id,
	foi.order_id,
	fo.order_timestamp,
	fo.crisis_phase,
	fo.pre_crisis,
	foi.item_id, 
	foi.menu_item_id,
	foi.restaurant_id,
	fo.delivery_partner_id,

	cust.signup_date,
	cust.city AS customer_city,
	cust.acquisition_channel,

	foi.quantity,
	foi.unit_price,
	foi.item_discount,
	foi.line_total,
	fo.subtotal_amount,
	fo.discount_amount,
	fo.delivery_fee,
	fo.total_amount,
	fo.is_cod,
	fo.is_cancelled,

	rest.restaurant_name,
	rest.city AS restaurant_city,
	rest.cuisine_type,
	rest.partner_type,
	rest.avg_prep_time_min,
	rest.prep_time_level,
	rest.is_active AS is_restaurant_active,

	menu.item_name,
	menu.category,
	menu.is_veg,
	menu.price AS menu_price,

	fr.rating,
	fr.review_text,
	fr.review_timestamp,
	fr.sentiment_score,
	fr.review_sentiment,
	fr.food_sentiment,
	fr.delivery_sentiment,
	fr.service_sentiment,

	ddp.partner_name,
	ddp.city AS delivery_partner_city,
	ddp.vehicle_type,
	ddp.employment_type,
	ddp.avg_rating,
	ddp.is_active AS is_delivery_partner_active,

	fdp.actual_delivery_time_mins,
	fdp.expected_delivery_time_mins,
	fdp.distance_km,
	fdp.delayed_delivery_mins
	
FROM fact_order_items AS foi
LEFT JOIN fact_orders AS fo
	ON foi.order_id = fo.order_id 
	AND foi.restaurant_id = fo.restaurant_id
LEFT JOIN dim_customer AS cust
	ON fo.customer_id = cust.customer_id
LEFT JOIN dim_restaurant AS rest 
	ON foi.restaurant_id = rest.restaurant_id
LEFT JOIN dim_menu_item AS menu
	ON foi.menu_item_id = menu.menu_item_id 
	AND foi.restaurant_id = menu.restaurant_id
LEFT JOIN fact_ratings AS fr
	ON fo.order_id = fr.order_id 
	AND fo.customer_id = fr.customer_id 
	AND fo.restaurant_id = fr.restaurant_id
LEFT JOIN dim_delivery_partner AS ddp
	ON fo.delivery_partner_id = ddp.delivery_partner_id
LEFT JOIN fact_delivery_performance AS fdp
	ON foi.order_id = fdp.order_id
WHERE fo.order_id IS NOT NULL
;


-- order_details table checking
SELECT order_id, customer_id, restaurant_id, delivery_partner_id, item_id, menu_item_id
FROM order_details
WHERE customer_id IS NULL
   OR restaurant_id IS NULL
   OR order_id IS NULL
   OR delivery_partner_id IS NULL
   OR item_id IS NULL
   OR menu_item_id IS NULL;


---------------------------------------------------


-- WORK WITH TABLE: CUSTOMER SEGMENTATION

-- Calculate RFM per-customer
CREATE OR REPLACE VIEW customer_rfm AS
SELECT
	customer_id,

	-- Overall RFM
	-- Recency: how many days have passed since the customer's last transaction
	COALESCE(CURRENT_DATE - MAX(order_timestamp::date), 0) AS recency_days,
	-- Frequency: how often the customer conducts transactions during a defined period
	COUNT(*) FILTER (WHERE is_cancelled = 0) AS frequency,
	-- Monetary: customer's total spending amount
	COALESCE(SUM(total_amount) FILTER (WHERE is_cancelled = 0), 0) AS monetary,
	
	-- Recency pre-crisis
	COALESCE(DATE '2025-06-01' - MAX(order_timestamp::date) FILTER(WHERE pre_crisis = 1), 0)  AS recency_days_pre,
	-- Recency post-crisis
	COALESCE(CURRENT_DATE - MAX(order_timestamp::date) FILTER(WHERE pre_crisis = 0), 0) AS recency_days_post,

	-- Frequency pre-crisis
	COUNT(*) FILTER (WHERE is_cancelled = 0 AND pre_crisis = 1) AS frequency_pre,
	-- Frequency post-crisis
	COUNT(*) FILTER (WHERE is_cancelled = 0 AND pre_crisis = 0) AS frequency_post,

	-- Monetary pre-crisis
	COALESCE(SUM(total_amount) FILTER (WHERE is_cancelled = 0 AND pre_crisis = 1), 0) AS monetary_pre,
	-- Monetary post-crisis
	COALESCE(SUM(total_amount) FILTER (WHERE is_cancelled = 0 AND pre_crisis = 0), 0) AS monetary_post,

	-- Others relevant feature (aggregatable for transactions related)
	COALESCE(AVG(discount_amount) FILTER (WHERE is_cancelled = 0 AND pre_crisis = 1), 0) AS discount_used_pre,
	COALESCE(AVG(discount_amount) FILTER (WHERE is_cancelled = 0 AND pre_crisis = 0), 0) AS discount_used_post,
	
	COALESCE(AVG(rating) FILTER (WHERE is_cancelled = 0 AND pre_crisis = 1), 0) AS rating_pre,
	COALESCE(AVG(rating) FILTER (WHERE is_cancelled = 0 AND pre_crisis = 0), 0) AS rating_post,

	COALESCE(AVG(sentiment_score) FILTER (WHERE is_cancelled = 0 AND pre_crisis = 1), 0) AS sentiment_score_pre,
	COALESCE(AVG(sentiment_score) FILTER (WHERE is_cancelled = 0 AND pre_crisis = 0), 0) AS sentiment_score_post,

	-- Review related
	COALESCE(SUM(review_sentiment) FILTER (WHERE is_cancelled = 0 AND pre_crisis = 1), 0) AS cummulative_review_sentiment_pre,
	COALESCE(SUM(review_sentiment) FILTER (WHERE is_cancelled = 0 AND pre_crisis = 0), 0) AS cummulative_review_sentiment_post,

	COALESCE(SUM(food_sentiment) FILTER (WHERE is_cancelled = 0 AND pre_crisis = 1), 0) AS cummulative_food_sentiment_pre,
	COALESCE(SUM(food_sentiment) FILTER (WHERE is_cancelled = 0 AND pre_crisis = 0), 0) AS cummulative_food_sentiment_post,

	COALESCE(SUM(service_sentiment) FILTER (WHERE is_cancelled = 0 AND pre_crisis = 1), 0) AS cummulative_service_sentiment_pre,
	COALESCE(SUM(service_sentiment) FILTER (WHERE is_cancelled = 0 AND pre_crisis = 0), 0) AS cummulative_service_sentiment_post,
	
	MODE() WITHIN GROUP (ORDER BY prep_time_level) AS prep_time_mode,

	-- Delivery related
	COALESCE(AVG(avg_rating) FILTER (WHERE is_cancelled = 0 AND pre_crisis = 1), 0) AS delivery_rating_pre,	
	COALESCE(AVG(avg_rating) FILTER (WHERE is_cancelled = 0 AND pre_crisis = 0), 0) AS delivery_rating_post,
	COALESCE(SUM(delivery_sentiment), 0) AS cummulative_delivery_sentiment,
	COALESCE(AVG(delayed_delivery_mins), 0) AS expected_delivery_delayed,
	ROUND(COUNT(*) FILTER (WHERE delayed_delivery_mins >= 0) * 100 / COUNT(*), 2) AS SLA_compliance_rate

FROM order_details
GROUP BY customer_id;


-- Divide each column into three quantiles
CREATE OR REPLACE VIEW customer_rfm_scores AS
WITH rfm AS (
    SELECT * FROM customer_rfm
),
raw_data AS (
	SELECT 
		*,
        NTILE(5) OVER (ORDER BY recency_days_pre DESC) AS recency_score_pre,
        NTILE(5) OVER (ORDER BY frequency_pre ASC) AS frequency_score_pre,
        NTILE(5) OVER (ORDER BY monetary_pre ASC) AS monetary_score_pre,

		NTILE(5) OVER (ORDER BY recency_days_post DESC) AS recency_score_post,
        NTILE(5) OVER (ORDER BY frequency_post ASC) AS frequency_score_post,
        NTILE(5) OVER (ORDER BY monetary_post ASC) AS monetary_score_post
		
    FROM rfm
)
SELECT * FROM raw_data;


-- Customer Segmentation Here!
CREATE OR REPLACE VIEW customer_segmentation AS
WITH customer_scoring AS (
	SELECT * FROM customer_rfm_scores
),

level2 AS (
	SELECT
		*,
		-- LEVEL 2: Customer Segmentation
		CASE
			WHEN 
				frequency_pre > 0
				AND frequency_post > 0
				AND sentiment_score_post >= 0
			THEN 'Loyal Retained'
	
			WHEN 
				frequency_pre > 0
				AND frequency_post > 0
				AND sentiment_score_post < 0
			THEN 'Loyal Retained but Dissatisfied'
			
			WHEN
				frequency_pre = 0
				AND frequency_post > 0
				AND sentiment_score_post >= 0
			THEN 'Post-Crisis New Joiners'
	
			WHEN
				frequency_pre = 0
				AND frequency_post > 0
				AND sentiment_score_post < 0
			THEN 'Post-Crisis New Joiners but Dissatisfied'
	
			WHEN
				frequency_pre > 0
				AND frequency_post = 0
				AND (
					recency_score_pre + frequency_score_pre + monetary_score_pre IN (13, 14, 15)
					OR frequency_score_pre IN (4, 5)
					OR monetary_score_pre IN (4, 5)
					)
			THEN 'High-Value Crisis Churners'
	
			WHEN
				frequency_pre > 0
				AND frequency_post = 0
				AND sentiment_score_pre >= 0
				AND (recency_score_pre + frequency_score_pre + monetary_score_pre) IN (7, 8, 9, 10, 11, 12)
			THEN 'Mid-Value Crisis Churners'
			
			WHEN
				frequency_pre > 0
				AND frequency_post = 0
				AND (
					(recency_score_pre + frequency_score_pre + monetary_score_pre) IN (3, 4, 5, 6)				
					OR sentiment_score_pre < 0
				)
			THEN 'Low-Value Crisis Churners'
			
			ELSE 'Others'
			
		END AS segmentation_level_2

	FROM customer_scoring
)

SELECT 
	*,
	-- LEVEL 1: Customer Segmentation
	CASE
		WHEN segmentation_level_2 IN (
			'High-Value Crisis Churners',
			'Mid-Value Crisis Churners',
			'Loyal Retained but Dissatisfied')
		THEN 'Recoverable'

		WHEN segmentation_level_2 IN (
			'Post-Crisis New Joiners',
			'Post-Crisis New Joiners but Dissatisfied',
			'Loyal Retained')
		THEN 'Strategy or Reward'

		WHEN segmentation_level_2 IN (
			'Low-Value Crisis Churners')
		THEN 'Low Priority'

		ELSE 'Others'

	END AS segmentation_level_1

FROM level2;

-- Table Check
SELECT *
FROM customer_segmentation;

-- Customer Segmentation Check
SELECT segmentation_level_1, segmentation_level_2, COUNT(*)
FROM customer_segmentation
GROUP BY 1, 2;
