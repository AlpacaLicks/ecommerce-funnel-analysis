-- 02.01 Cleaning the table events_20210131 by removing any unnecessary rows not needed, (or at least not needed for the core funnel analysis)
SELECT event_name, COUNT(*) AS event_count
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_20210131`
WHERE event_name IN ('session_start', 'view_item', 'add_to_cart', 'begin_checkout', 'add_payment_info', 'purchase')
GROUP BY event_name
ORDER BY event_count DESC;

-- 02.02 I noticed that each event_name does not explicitly tell me whether the event done was triggered by a unique user or not, eg. a user could have triggered the same event multiple times. So I will delve deeper into the dataset and see if there is a column that can help me identify the data that I need.
SELECT * 
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_20210131`
LIMIT 5;
-- I noticed that there are columns called: 
    -- user_pseudo_id --> which is the unique identifier for each user.
    -- event_params.key -> which shows a nested value: ga_session_id, which identifies the session created by the user

-- 02.03 I will now create a CTE combining user_pseudo_id and ga_session_id so that we can get a unique_session_id for each event. 
WITH clean_events AS (
    SELECT event_name, user_pseudo_id,
        (
            SELECT value.int_value
            FROM UNNEST(event_params)
            WHERE key = 'ga_session_id'
        ) AS ga_session_id,
    -- Combining user_pseudo_id and ga_session_id to create a unique session identifier (unique_session_id) for each event
        CONCAT(user_pseudo_id, '-',
            CAST((
                SELECT value.int_value
                FROM UNNEST(event_params)
                WHERE key = 'ga_session_id'
            ) AS STRING)
        ) AS unique_session_id
    FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_20210131`
    WHERE event_name IN (
        'session_start',
        'view_item',
        'add_to_cart',
        'begin_checkout',
        'add_payment_info',
        'purchase'
    )
)
-- Now instead of relying on the raw counts of event_name which could lead to overcounting, we can now count the number of unique_session_id instead.
SELECT event_name, COUNT(DISTINCT unique_session_id) AS unique_session_count
FROM clean_events
GROUP BY event_name
ORDER BY unique_session_count DESC;