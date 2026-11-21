-- MAVEN FUZZY FACTORY | SQL ANALYSIS PACK (SQLite)
-- Source tables: website_sessions, website_pageviews, orders_mav,
-- order_items, order_item_refunds, products
-- Run after importing the six CSV files as tables with the names above.

-- 1. Overall sales, cost and gross profit (line-item basis)
SELECT
  ROUND(SUM(price_usd), 2) AS total_revenue,
  ROUND(SUM(cogs_usd), 2) AS total_cogs,
  ROUND(SUM(price_usd) - SUM(cogs_usd), 2) AS gross_profit,
  ROUND((SUM(price_usd) - SUM(cogs_usd)) / NULLIF(SUM(price_usd), 0) * 100, 2) AS gross_margin_pct
FROM order_items;

-- 2. Orders, customers and average order value
SELECT
  COUNT(DISTINCT order_id) AS total_orders,
  COUNT(DISTINCT user_id) AS total_customers,
  ROUND(SUM(price_usd) / NULLIF(COUNT(DISTINCT order_id), 0), 2) AS average_order_value
FROM orders_mav;

-- 3. Monthly revenue and gross profit
SELECT
  strftime('%Y-%m', created_at) AS year_month,
  ROUND(SUM(price_usd), 2) AS revenue,
  ROUND(SUM(cogs_usd), 2) AS cogs,
  ROUND(SUM(price_usd) - SUM(cogs_usd), 2) AS gross_profit
FROM order_items
GROUP BY strftime('%Y-%m', created_at)
ORDER BY year_month;

-- 4. Revenue and gross profit by product
SELECT
  p.product_name,
  ROUND(SUM(oi.price_usd), 2) AS revenue,
  ROUND(SUM(oi.cogs_usd), 2) AS cogs,
  ROUND(SUM(oi.price_usd) - SUM(oi.cogs_usd), 2) AS gross_profit
FROM order_items oi
JOIN products p ON p.product_id = oi.product_id
GROUP BY p.product_name
ORDER BY revenue DESC;

-- 5. Website traffic and pageviews
SELECT
  COUNT(DISTINCT website_session_id) AS total_sessions
FROM website_sessions;

SELECT
  COUNT(DISTINCT website_pageview_id) AS total_pageviews,
  ROUND(
    COUNT(DISTINCT website_pageview_id) * 1.0 /
    NULLIF(COUNT(DISTINCT website_session_id), 0), 2
  ) AS average_pages_per_session
FROM website_pageviews;

-- 6. Bounce rate: sessions with exactly one recorded pageview
WITH page_counts AS (
  SELECT website_session_id, COUNT(*) AS pageview_count
  FROM website_pageviews
  GROUP BY website_session_id
)
SELECT
  SUM(CASE WHEN pageview_count = 1 THEN 1 ELSE 0 END) AS bounced_sessions,
  ROUND(
    SUM(CASE WHEN pageview_count = 1 THEN 1.0 ELSE 0 END) /
    NULLIF((SELECT COUNT(DISTINCT website_session_id) FROM website_sessions), 0) * 100,
    2
  ) AS bounce_rate_pct
FROM page_counts;

-- 7. Orders and session conversion by marketing source
SELECT
  COALESCE(ws.utm_source, 'Unattributed') AS utm_source,
  COUNT(DISTINCT ws.website_session_id) AS sessions,
  COUNT(DISTINCT o.order_id) AS orders,
  ROUND(
    COUNT(DISTINCT o.order_id) * 1.0 /
    NULLIF(COUNT(DISTINCT ws.website_session_id), 0) * 100, 2
  ) AS conversion_rate_pct
FROM website_sessions ws
LEFT JOIN orders_mav o ON o.website_session_id = ws.website_session_id
GROUP BY COALESCE(ws.utm_source, 'Unattributed')
ORDER BY sessions DESC;

-- 8. Revenue by marketing campaign (revenue attributed through session)
SELECT
  COALESCE(ws.utm_campaign, 'Unattributed') AS utm_campaign,
  ROUND(SUM(oi.price_usd), 2) AS revenue
FROM website_sessions ws
JOIN orders_mav o ON o.website_session_id = ws.website_session_id
JOIN order_items oi ON oi.order_id = o.order_id
GROUP BY COALESCE(ws.utm_campaign, 'Unattributed')
ORDER BY revenue DESC;

-- 9. Device conversion performance
SELECT
  ws.device_type,
  COUNT(DISTINCT ws.website_session_id) AS sessions,
  COUNT(DISTINCT o.order_id) AS orders,
  ROUND(
    COUNT(DISTINCT o.order_id) * 1.0 /
    NULLIF(COUNT(DISTINCT ws.website_session_id), 0) * 100, 2
  ) AS conversion_rate_pct
FROM website_sessions ws
LEFT JOIN orders_mav o ON o.website_session_id = ws.website_session_id
GROUP BY ws.device_type
ORDER BY conversion_rate_pct DESC;

-- 10. Refunds by product
SELECT
  p.product_name,
  ROUND(SUM(r.refund_amount_usd), 2) AS refund_amount
FROM order_item_refunds r
JOIN order_items oi ON oi.order_item_id = r.order_item_id
JOIN products p ON p.product_id = oi.product_id
GROUP BY p.product_name
ORDER BY refund_amount DESC;

-- 11. Monthly refund trend
SELECT
  strftime('%Y-%m', created_at) AS year_month,
  ROUND(SUM(refund_amount_usd), 2) AS total_refunds
FROM order_item_refunds
GROUP BY strftime('%Y-%m', created_at)
ORDER BY year_month;

-- 12. Refund rate by item count and refund value as share of revenue
SELECT
  (SELECT COUNT(DISTINCT order_item_id) FROM order_item_refunds) AS refunded_items,
  (SELECT COUNT(DISTINCT order_item_id) FROM order_items) AS items_purchased,
  ROUND(
    (SELECT COUNT(DISTINCT order_item_id) FROM order_item_refunds) * 100.0 /
    NULLIF((SELECT COUNT(DISTINCT order_item_id) FROM order_items), 0), 2
  ) AS item_refund_rate_pct,
  ROUND(
    (SELECT SUM(refund_amount_usd) FROM order_item_refunds) * 100.0 /
    NULLIF((SELECT SUM(price_usd) FROM order_items), 0), 2
  ) AS refund_value_as_pct_of_revenue;
