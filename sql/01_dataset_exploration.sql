-- 01.01 Outlining the dataset by looking for min and max dates (each table's suffix is formatted as YYYYMMDD)
SELECT
    MIN(_TABLE_SUFFIX) AS first_table,
    MAX(_TABLE_SUFFIX) AS last_table,
    COUNT(DISTINCT _TABLE_SUFFIX) AS number_of_tables
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`;
-- Determined that last row is 2021-01-31 (20210131) and first row is 2020-11-01 (20201101), therefore I will be working with the last row of the dataset, which is table: events_20210131

-- 01.02 Getting a preview of the table events_20210131
SELECT * 
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_20210131`
LIMIT 5;
-- So I identified the column: event_name, which I determined to be the most relevant column for this analysis, as it contains the type of event that occurred (e.g. purchase, add_to_cart, etc.). I will be using this column to conduct my funnel analysis on the different types of events, and how many times those events occured on January 31, 2021.

-- 01.03 Seeing the count of event_name in the table events_20210131
SELECT event_name, COUNT(*) AS event_count
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_20210131`
GROUP BY event_name
ORDER BY event_count DESC;