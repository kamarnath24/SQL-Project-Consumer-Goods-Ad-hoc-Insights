/* ATLIQ HARDWARE'S MANAGEMENT WANTS TO GET SOME INSIGHTS INTO ITS PRODUCT'S SALES. 
AS A DATA ANALYST MY TASK IS TO RESPOND TO 10 AD-HOC QUERIES ASSIGNED TO ME. */

-- 1. List of markets in which customer "Atliq Exlcusive" operates business in the APAC region*/

SELECT DISTINCT
    market
FROM
    dim_customer
WHERE
    customer = 'Atliq Exclusive'
        AND region = 'APAC';


-- 2. What is the percentage of unique product increase in 2021 vs 2020?

WITH products_2020 AS (SELECT 
    COUNT(DISTINCT product_code) AS unique_products_2020
FROM
    dim_product p
        JOIN
    fact_sales_monthly f USING (product_code)
WHERE
    f.fiscal_year = 2020),
products_2021 AS (SELECT 
    COUNT(DISTINCT product_code) AS unique_products_2021
FROM
    dim_product p
        JOIN
    fact_sales_monthly f USING (product_code)
WHERE
    f.fiscal_year = 2021)
SELECT 
    unique_products_2020,
    unique_products_2021,
    ROUND(((unique_products_2021 - unique_products_2020) * 100 / unique_products_2020),
            2) AS pct_chnge
FROM
    products_2020
        CROSS JOIN
    products_2021;

-- 3. A report on all unique products for each segment, sorted in descending order.

SELECT 
    segment, COUNT(product_code) AS product_count
FROM
    dim_product
GROUP BY segment
ORDER BY product_count DESC;


-- 4. Which segment had the most increase in unique products in 2021 vs 2020? 

WITH products_2020 AS (
SELECT segment,
    COUNT(DISTINCT product_code) AS products_2020
FROM
    dim_product p
        JOIN
    fact_sales_monthly f USING (product_code)
WHERE
    f.fiscal_year = 2020
GROUP BY segment
ORDER BY products_2020 DESC),
products_2021 AS (
SELECT 
    segment, COUNT(DISTINCT product_code) AS products_2021
FROM
    dim_product p
        JOIN
    fact_sales_monthly f USING (product_code)
WHERE
    f.fiscal_year = 2021
GROUP BY segment
ORDER BY products_2021 DESC)
SELECT 
    p0.segment,
    products_2021,
    products_2020,
    products_2021 - products_2020 AS difference
FROM
    products_2020 p0
        JOIN
    products_2021 p1 USING (segment)
ORDER BY difference DESC;

-- 5. Products with the highest and lowest manufacturing cost

WITH CTE AS 
(SELECT 
	product_code, manufacturing_cost,
		DENSE_RANK() OVER(ORDER BY manufacturing_cost DESC) as drnk
FROM 
	fact_manufacturing_cost
ORDER BY drnk)
SELECT 
    c.product_code, p.product, c.manufacturing_cost
FROM
    CTE c
        JOIN
    dim_product p USING (product_code)
WHERE
    drnk IN ((SELECT 
            MAX(drnk)
        FROM
            CTE), (SELECT 
                MIN(drnk)
            FROM
                CTE))
ORDER BY manufacturing_cost DESC;


-- 6. A report which contains the top 5 customers who received an average high pre_invoice_discount_pct for the fiscal_year 2021 and in the Indian market

SELECT 
    f.customer_code,
    customer,
    CONCAT(ROUND(AVG(pre_invoice_discount_pct) * 100, 2),
            '%') AS average_discount_percentage
FROM
    fact_pre_invoice_deductions f
        JOIN
    dim_customer c USING (customer_code)
WHERE
    fiscal_year = 2021 AND market = 'India'
GROUP BY f.customer_code , customer
ORDER BY pre_invoice_discount_pct DESC
LIMIT 5;



-- 7. A complete report of Gross sales amount for the customer "Atliq Exclusive" for each month. This analysis helps to get an idea of low and high-performing months and make strategic decisions

SELECT 
    DATE_FORMAT(date, '%M') AS month,
    s.fiscal_year,
    CONCAT(ROUND(SUM(g.gross_price * sold_quantity)/1000000,
                    2),
            ' M') AS gross_sales_mlns
FROM
    fact_sales_monthly s
        JOIN
    fact_gross_price g USING (product_code, fiscal_year)
		JOIN
	dim_customer c USING (customer_code)
WHERE  
    customer LIKE 'Atliq Exclusive'
GROUP BY month, s.fiscal_year
ORDER BY 
FIELD(month, 'September', 'October',' November', 'December',
'January',' February', 'March', 'April',' May', 'June', 'July',' August');

-- 8. 2020 Quarter with maximum quantities sold

SELECT 
    CASE
        WHEN MONTH(date) IN ('9', '10', '11') THEN 'Quarter 1'
        WHEN MONTH(date) IN ('12', '01', '02') THEN 'Quarter 2'
        WHEN MONTH(date) IN ('03', '04', '05') THEN 'Quarter 3'
        ELSE 'Quarter 4'
    END AS Quarter,
    SUM(sold_quantity) AS total_sold_quantity
FROM
    fact_sales_monthly
WHERE
    fiscal_year = 2020
GROUP BY Quarter
ORDER BY total_sold_quantity DESC;

-- 9. Channel with more gross sales in 2021 and percentage contributions

WITH gross_sales AS (SELECT 
    c.channel,
    ROUND(SUM(s.sold_quantity * g.gross_price) / 1000000,
                    2) AS gross_sales_mlns
FROM
    fact_sales_monthly s
        JOIN
    dim_customer c USING (customer_code)
        JOIN
    fact_gross_price g USING (product_code , fiscal_year)
WHERE fiscal_year=2021
GROUP BY channel)
SELECT *,
CONCAT(ROUND(gross_sales_mlns*100/SUM(gross_sales_mlns) OVER(),2),"%") as pct_contribution
FROM gross_sales
GROUP BY channel
ORDER BY pct_contribution DESC;

-- 10. Top 3 products  in each division that have high total quantity for fiscal year 2021

  WITH top_sold_products AS /*creating a CTE for getting top-selling products for all divisions*/
	(SELECT 
		p.division,
		s.product_code,
		p.product,
		variant,
		SUM(sold_quantity) AS total_sold_quantity
	FROM fact_sales_monthly s
		JOIN dim_product p USING (product_code)
	WHERE fiscal_year=2021
	GROUP BY p.division, s.product_code, p.product
    ),
top_sold_per_division AS /*creating this CTE to get top 3 based on total_sold quantity per division*/
(
    SELECT *, 
		RANK() OVER(PARTITION BY division ORDER BY total_sold_quantity DESC) as rank_order
		FROM top_sold_products
  )
SELECT * FROM top_sold_per_division -- finally filtering the above-created table to have 1,2 and 3 ranks
	WHERE rank_order IN (1,2,3);
;


-- Extra Insights
-- Number of products that were discontinued in year 2021 from 2020.

SELECT DISTINCT product_code, product,segment, fiscal_year  
FROM fact_sales_monthly as fm
JOIN dim_product as dp 
USING (product_code)
WHERE product_code NOT IN (SELECT DISTINCT product_code 
							FROM fact_sales_monthly 
                            WHERE fiscal_year=2021) 
and fiscal_year = 2020
;

            
