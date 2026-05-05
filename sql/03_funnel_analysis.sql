-- 03.01 So now its time to display the funnel conversion and drop off rates for each event
-- Grabbing the CTE from 02_table_cleaning.sql:
WITH clean_events AS (
    SELECT event_name, user_pseudo_id,
        (
            SELECT value.int_value
            FROM UNNEST(event_params)
            WHERE key = 'ga_session_id'
        ) AS ga_session_id,
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
),
-- Then counting how many unique sessions reached each stage of the funnel
funnel_counts AS (
    SELECT event_name, COUNT(DISTINCT unique_session_id) AS unique_session_count
    FROM clean_events
    GROUP BY event_name
)
-- Then using CASE statements to calculate the conversion and drop off rates for each stage
SELECT
    CASE
        WHEN event_name = 'session_start' THEN 1
        WHEN event_name = 'view_item' THEN 2
        WHEN event_name = 'add_to_cart' THEN 3
        WHEN event_name = 'begin_checkout' THEN 4
        WHEN event_name = 'add_payment_info' THEN 5
        WHEN event_name = 'purchase' THEN 6
    END AS step_number,
    event_name as funnel_step,
    unique_session_count,
    CASE
        WHEN event_name = 'session_start' THEN 100.0
        ELSE ROUND(
            SAFE_DIVIDE(
                unique_session_count,
                (
                    SELECT unique_session_count
                    FROM funnel_counts
                    WHERE event_name = 'session_start'
                )
            ) * 100, 2
        )
    END AS overall_conversion_rate,
    CASE 
        WHEN event_name = 'session_start' THEN 0.0
        ELSE ROUND(
            SAFE_DIVIDE(
                (
                    SELECT unique_session_count
                    FROM funnel_counts
                    WHERE event_name = 'session_start'
                ) - unique_session_count,
                (
                    SELECT unique_session_count
                    FROM funnel_counts
                    WHERE event_name = 'session_start'
                )
            ) * 100, 2
        )
    END AS overall_drop_off_rate
FROM funnel_counts
ORDER BY step_number;
-- Note that this query calculates the overall converion and drop off rates relative to the first stage of the funnel, which is session_start

-- 03.02 Now I will calculate the conversion and drop off rates for each stage of the funnel relative to the previous step
WITH clean_events AS (
    SELECT
        event_name,
        CONCAT(
            user_pseudo_id,
            '-',
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
),
funnel_counts AS (
    SELECT
        CASE
            WHEN event_name = 'session_start' THEN 1
            WHEN event_name = 'view_item' THEN 2
            WHEN event_name = 'add_to_cart' THEN 3
            WHEN event_name = 'begin_checkout' THEN 4
            WHEN event_name = 'add_payment_info' THEN 5
            WHEN event_name = 'purchase' THEN 6
        END AS step_number,
        event_name AS funnel_step,
        COUNT(DISTINCT unique_session_id) AS unique_session_count
    FROM clean_events
    GROUP BY step_number, funnel_step
),
funnel_with_previous AS (
    SELECT
        step_number,
        funnel_step,
        unique_session_count,
        LAG(unique_session_count) OVER (
            ORDER BY step_number
        ) AS previous_step_sessions
    FROM funnel_counts
)
SELECT
    step_number,
    funnel_step,
    unique_session_count,
    CASE
        WHEN previous_step_sessions IS NULL THEN 100.0
        ELSE ROUND(
            SAFE_DIVIDE(unique_session_count, previous_step_sessions) * 100,
            2
        )
    END AS step_conversion_rate,
    CASE
        WHEN previous_step_sessions IS NULL THEN 0.0
        ELSE ROUND(
            (1 - SAFE_DIVIDE(unique_session_count, previous_step_sessions)) * 100,
            2
        )
    END AS step_drop_off_rate
FROM funnel_with_previous
ORDER BY step_number;

-- 03.03 Now the combined table output, querying for both the overall conversion and drop off rates relative to the first stage and previous stage of the funnel.
WITH clean_events AS (
    SELECT
        event_name,
        CONCAT(
            user_pseudo_id,
            '-',
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
),
funnel_counts AS (
    SELECT
        CASE
            WHEN event_name = 'session_start' THEN 1
            WHEN event_name = 'view_item' THEN 2
            WHEN event_name = 'add_to_cart' THEN 3
            WHEN event_name = 'begin_checkout' THEN 4
            WHEN event_name = 'add_payment_info' THEN 5
            WHEN event_name = 'purchase' THEN 6
        END AS step_number,
        event_name AS funnel_step,
        COUNT(DISTINCT unique_session_id) AS sessions
    FROM clean_events
    GROUP BY
        step_number,
        funnel_step
),
funnel_with_context AS (
    SELECT
        step_number,
        funnel_step,
        sessions,
        LAG(sessions) OVER (
            ORDER BY step_number
        ) AS previous_step_sessions,
        FIRST_VALUE(sessions) OVER (
            ORDER BY step_number
        ) AS starting_sessions
    FROM funnel_counts
)
SELECT
    funnel_step,
    sessions,
    CASE
        WHEN step_number = 1 THEN 100.0
        ELSE ROUND(
            SAFE_DIVIDE(sessions, starting_sessions) * 100,
            2
        )
    END AS overall_conversion_rate_from_start,
    CASE
        WHEN step_number = 1 THEN 0.0
        ELSE ROUND(
            (1 - SAFE_DIVIDE(sessions, starting_sessions)) * 100,
            2
        )
    END AS overall_drop_off_rate_from_start,
    CASE
        WHEN step_number = 1 THEN 100.0
        ELSE ROUND(
            SAFE_DIVIDE(sessions, previous_step_sessions) * 100,
            2
        )
    END AS step_conversion_rate,
    CASE
        WHEN step_number = 1 THEN 0.0
        ELSE ROUND(
            (1 - SAFE_DIVIDE(sessions, previous_step_sessions)) * 100,
            2
        )
    END AS step_drop_off_rate
FROM funnel_with_context
ORDER BY step_number;
