-- =========================================
-- KPI 1: Total Bookings
-- Measures overall demand volume
-- =========================================
SELECT 
    COUNT(*) AS total_bookings
FROM BOOKINGS;

-- =========================================
-- KPI 2: Total Revenue Generated
-- =========================================
SELECT 
    CAST(SUM(total_revenue) AS DECIMAL(12,2)) AS total_revenue
FROM BOOKINGS
WHERE is_canceled = 0; 

-- =========================================
-- KPI 3: Overall Cancellation Rate (%)
-- =========================================
SELECT
    CAST(
        SUM(CASE WHEN is_canceled = 1 THEN 1 ELSE 0 END) 
        * 100.0 / COUNT(*)
        AS DECIMAL(5,2)
    ) AS cancellation_rate_percentage
FROM BOOKINGS;

-- =========================================
-- Revenue Contribution by Hotel Type
-- =========================================
SELECT
    h.hotel,
    CAST(SUM(b.total_revenue) AS DECIMAL(12,2)) 
        AS total_revenue
FROM BOOKINGS b
JOIN HOTEL h
    ON b.hotel_id = h.hotel_id
WHERE b.is_canceled = 0
GROUP BY h.hotel
ORDER BY total_revenue DESC;

-- =========================================
-- Revenue by Market Segment
-- =========================================
SELECT 
    m.market_segment,
    COUNT(*) AS total_bookings,
    CAST(SUM(b.total_revenue) AS DECIMAL(12,2)) 
        AS total_revenue
FROM BOOKINGS b
JOIN MARKET_SEGMENT m
    ON b.market_id = m.market_id
WHERE b.is_canceled = 0
GROUP BY m.market_segment
ORDER BY total_revenue DESC;

-- =========================================
-- Pricing Strategy Analysis (ADR)
-- =========================================
SELECT
    c.customer_type,
    CAST(AVG(b.average_daily_rate) AS DECIMAL(10,2)) 
        AS avg_daily_rate
FROM BOOKINGS b
JOIN CUSTOMER c
    ON b.customer_id = c.customer_id
WHERE b.is_canceled = 0
GROUP BY c.customer_type
ORDER BY avg_daily_rate DESC;

-- =========================================
-- Revenue by Country (Top 5)
-- =========================================
SELECT TOP 5
    c.country_name,
    CAST(SUM(b.total_revenue) AS DECIMAL(12,2)) 
        AS total_revenue
FROM BOOKINGS b
JOIN CUSTOMER c
    ON b.customer_id = c.customer_id
WHERE b.is_canceled = 0
GROUP BY c.country_name
ORDER BY total_revenue DESC;

-- =========================================
-- Monthly Revenue Trend
-- =========================================
SELECT
    d.arrival_date_month,
    CAST(SUM(b.total_revenue) AS DECIMAL(12,2)) 
        AS monthly_revenue
FROM BOOKINGS b
JOIN DATES d
    ON b.date_id = d.date_id
WHERE b.is_canceled = 0
GROUP BY d.arrival_date_month
ORDER BY d.arrival_date_month;

-- =========================================
-- Cancellation Risk by Hotel + Market Segment
-- =========================================
SELECT 
    h.hotel,
    m.market_segment,
    COUNT(*) AS total_bookings,
    CAST(
        SUM(CASE WHEN b.is_canceled = 1 THEN 1 ELSE 0 END) 
        * 100.0 / COUNT(*)
        AS DECIMAL(5,2)
    ) AS cancellation_rate_percentage
FROM BOOKINGS b
JOIN MARKET_SEGMENT m 
    ON b.market_id = m.market_id
JOIN HOTEL h 
    ON b.hotel_id = h.hotel_id
GROUP BY h.hotel, m.market_segment
HAVING COUNT(*) > 100  
ORDER BY cancellation_rate_percentage DESC;

-- =========================================
-- Revenue Leakage Detection
-- Long stays but low revenue
-- =========================================
SELECT 
    booking_id,
    stays_in_week_nights + stays_in_weekend_nights AS total_nights,
    CAST(total_revenue AS DECIMAL(10,2)) AS total_revenue
FROM BOOKINGS
WHERE 
    (stays_in_week_nights + stays_in_weekend_nights) > 5
    AND total_revenue < (
        SELECT AVG(total_revenue)
        FROM BOOKINGS
        WHERE is_canceled = 0
    )
ORDER BY total_revenue ASC;

-- =========================================
-- Seasonal Profitability Analysis
-- =========================================
SELECT
    d.season,
    CAST(SUM(b.total_revenue) AS DECIMAL(12,2)) 
        AS total_revenue,
    CAST(AVG(b.average_daily_rate) AS DECIMAL(10,2)) 
        AS avg_daily_rate,
    CAST(
        SUM(CASE WHEN b.is_canceled = 1 THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*)
        AS DECIMAL(5,2)
    ) AS cancellation_rate
FROM BOOKINGS b
JOIN DATES d
    ON b.date_id = d.date_id
GROUP BY d.season
ORDER BY total_revenue DESC;

-- =====================================================
-- Customer Loyalty Impact
-- Compare profitability between Repeated vs New Guests
-- =====================================================

SELECT
    CASE 
        WHEN c.is_repeated_guest = 1 THEN 'Repeated Guest'
        ELSE 'New Guest'
    END AS guest_type,

    COUNT(*) AS total_bookings,

    -- Realized revenue only
    CAST(AVG(CASE WHEN b.is_canceled = 0 
                  THEN b.total_revenue END) 
         AS DECIMAL(10,2)) 
         AS avg_revenue_per_booking,

    CAST(
        SUM(CASE WHEN b.is_canceled = 1 THEN 1 ELSE 0 END) 
        * 100.0 / COUNT(*)
        AS DECIMAL(5,2)
    ) AS cancellation_rate_percentage

FROM BOOKINGS b
JOIN CUSTOMER c
    ON b.customer_id = c.customer_id

GROUP BY c.is_repeated_guest
ORDER BY avg_revenue_per_booking DESC;

-- =====================================================
-- Average Lead Time: Canceled vs Non-Canceled
-- =====================================================

SELECT
    CASE 
        WHEN is_canceled = 1 THEN 'Canceled'
        ELSE 'Not Canceled'
    END AS booking_status,

    COUNT(*) AS total_bookings,

    CAST(AVG(lead_time) AS DECIMAL(10,2)) 
        AS avg_lead_time

FROM BOOKINGS
GROUP BY is_canceled;
-- =====================================================
-- Cancellation Rate by Lead Time Bucket
-- =====================================================

SELECT
    CASE
        WHEN lead_time <= 50 THEN '0-50 Days'
        WHEN lead_time <= 150 THEN '51-150 Days'
        WHEN lead_time <= 300 THEN '151-300 Days'
        ELSE '300+ Days'
    END AS lead_time_group,

    COUNT(*) AS total_bookings,

    CAST(
        SUM(CASE WHEN is_canceled = 1 THEN 1 ELSE 0 END) 
        * 100.0 / COUNT(*)
        AS DECIMAL(5,2)
    ) AS cancellation_rate

FROM BOOKINGS
GROUP BY
    CASE
        WHEN lead_time <= 50 THEN '0-50 Days'
        WHEN lead_time <= 150 THEN '51-150 Days'
        WHEN lead_time <= 300 THEN '151-300 Days'
        ELSE '300+ Days'
    END

ORDER BY MIN(lead_time);  

-- =====================================================
-- Revenue Concentration Risk
-- What % of revenue comes from top 10% bookings?
-- =====================================================

WITH revenue_groups AS (
    SELECT
        total_revenue,
        NTILE(10) OVER (ORDER BY total_revenue DESC) AS revenue_decile
    FROM BOOKINGS
    WHERE is_canceled = 0
)

SELECT
    CAST(SUM(total_revenue) AS DECIMAL(12,2)) 
        AS top_10_percent_revenue,

    CAST(
        SUM(total_revenue) * 100.0 
        / (SELECT SUM(total_revenue) 
           FROM BOOKINGS 
           WHERE is_canceled = 0)
        AS DECIMAL(6,2)
    ) AS revenue_percentage

FROM revenue_groups
WHERE revenue_decile = 1;

-- =====================================================
-- Weekend vs Weekday Revenue Contribution
-- =====================================================

SELECT
    CAST(SUM(stays_in_weekend_nights * average_daily_rate) 
         AS DECIMAL(12,2)) AS weekend_revenue,

    CAST(SUM(stays_in_week_nights * average_daily_rate) 
         AS DECIMAL(12,2)) AS weekday_revenue,

    CAST(
        SUM(stays_in_weekend_nights * average_daily_rate) * 100.0
        / SUM(total_revenue)
        AS DECIMAL(6,2)
    ) AS weekend_revenue_percentage,

    CAST(
        SUM(stays_in_week_nights * average_daily_rate) * 100.0
        / SUM(total_revenue)
        AS DECIMAL(6,2)
    ) AS weekday_revenue_percentage

FROM BOOKINGS
WHERE is_canceled = 0;

-- =====================================================
-- Distribution Channel Performance
-- High ADR + Low Cancellation
-- =====================================================

SELECT
    m.distribution_channel,
    COUNT(*) AS total_bookings,

    CAST(AVG(CASE WHEN b.is_canceled = 0 
                  THEN b.average_daily_rate END)
         AS DECIMAL(10,2)) AS avg_adr,

    CAST(
        SUM(CASE WHEN b.is_canceled = 1 THEN 1 ELSE 0 END) * 100.0
        / COUNT(*)
        AS DECIMAL(5,2)
    ) AS cancellation_rate

FROM BOOKINGS b
JOIN MARKET_SEGMENT m
    ON b.market_id = m.market_id

GROUP BY m.distribution_channel
HAVING COUNT(*) > 1000
ORDER BY avg_adr DESC, cancellation_rate ASC;

-- =====================================================
-- Revenue Loss from No Deposit Cancellations
-- =====================================================

SELECT
    COUNT(*) AS canceled_no_deposit_bookings,

    CAST(SUM(b.total_revenue) AS DECIMAL(12,2)) 
        AS potential_revenue_lost,

    CAST(
        SUM(b.total_revenue) * 100.0 
        / (SELECT SUM(total_revenue) 
           FROM BOOKINGS 
           WHERE is_canceled = 0)
        AS DECIMAL(6,2)
    ) AS revenue_loss_percentage

FROM BOOKINGS b
JOIN DEPOSIT d
    ON b.deposit_id = d.deposit_id

WHERE b.is_canceled = 1
  AND d.deposit_type = 'No Deposit';
