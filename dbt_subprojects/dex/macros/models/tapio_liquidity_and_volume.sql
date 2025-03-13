{% macro tapio_liquidity_and_volume(
    blockchain = null,
    project = 'tapio',
    version = '1',
    token_swapped_table = '',
    minted_table = '',
    donated_table = '',
    redeemed_table = '',
    pools_table = '',
    tokens_table = 'erc20.tokens',
    prices_table = 'prices.usd'
) %}

WITH 
    token_swapped_events AS (
        -- Extract data from TokenSwapped events
        SELECT
            block_time,
            contract_address AS pool_address,
            buyer AS provider,
            swapAmount AS amount,
            'TokenSwapped' AS event_type
        FROM {{ source(project, blockchain, token_swapped_table) }}
        WHERE swapAmount IS NOT NULL
    ),

    minted_events AS (
        -- Extract data from Minted events
        SELECT
            block_time,
            contract_address AS pool_address,
            provider,
            mintAmount AS amount,
            'Minted' AS event_type
        FROM {{ source(project, blockchain, minted_table) }}
        WHERE mintAmount IS NOT NULL
    ),

    donated_events AS (
        -- Extract data from Donated events
        SELECT
            block_time,
            contract_address AS pool_address,
            provider,
            mintAmount AS amount,
            'Donated' AS event_type
        FROM {{ source(project, blockchain, donated_table) }}
        WHERE mintAmount IS NOT NULL
    ),

    redeemed_events AS (
        -- Extract data from Redeemed events
        SELECT
            block_time,
            contract_address AS pool_address,
            provider,
            redeemAmount AS amount,
            'Redeemed' AS event_type
        FROM {{ source(project, blockchain, redeemed_table) }}
        WHERE redeemAmount IS NOT NULL
    ),

    unified_events AS (
        -- Combine all events into a single structure
        SELECT * FROM token_swapped_events
        UNION ALL
        SELECT * FROM minted_events
        UNION ALL
        SELECT * FROM donated_events
        UNION ALL
        SELECT * FROM redeemed_events
    ),

    event_data AS (
        -- Aggregate liquidity changes per day
        SELECT 
            date_trunc('day', e.block_time) AS day,
            e.pool_address,
            p.token0_address,
            p.token1_address,
            t0.symbol AS token0_symbol,
            t1.symbol AS token1_symbol,
            SUM(CASE 
                WHEN e.event_type IN ('Minted', 'Donated') AND e.amount IS NOT NULL THEN CAST(e.amount AS DOUBLE)
                ELSE 0 
            END) AS token0_balance_raw,
            SUM(CASE 
                WHEN e.event_type IN ('Redeemed', 'TokenSwapped') AND e.amount IS NOT NULL THEN CAST(e.amount AS DOUBLE)
                ELSE 0 
            END) AS token1_balance_raw
        FROM unified_events e
        JOIN {{ source(blockchain, pools_table) }} p ON e.pool_address = p.address
        JOIN {{ source(blockchain, tokens_table) }} t0 ON p.token0_address = t0.address
        JOIN {{ source(blockchain, tokens_table) }} t1 ON p.token1_address = t1.address
        GROUP BY 1, 2, 3, 4, 5, 6
    )

    running_balance AS (
        -- Fill missing days to maintain continuity
        SELECT 
            ds.day,
            ed.pool_address,
            ed.token0_address,
            ed.token1_address,
            ed.token0_symbol,
            ed.token1_symbol,
            COALESCE(ed.token0_balance_raw, 0) AS token0_balance_raw,
            COALESCE(ed.token1_balance_raw, 0) AS token1_balance_raw
        FROM (
            SELECT generate_series(
                COALESCE((SELECT MIN(day) FROM event_data), CURRENT_DATE - INTERVAL '30 days'),
                COALESCE((SELECT MAX(day) FROM event_data), CURRENT_DATE),
                INTERVAL '1' day
            ) AS day
        ) ds
        LEFT JOIN event_data ed ON ds.day = ed.day
    ),

    final_data AS (
        -- Convert balances to scaled values and USD prices
        SELECT 
            rb.day,
            rb.pool_address,
            rb.token0_address,
            rb.token1_address,
            rb.token0_symbol,
            rb.token1_symbol,
            rb.token0_balance_raw / POWER(10, COALESCE(t0.decimals, 18)) AS token0_balance_scaled, 
            rb.token1_balance_raw / POWER(10, COALESCE(t1.decimals, 18)) AS token1_balance_scaled,
            (rb.token0_balance_raw / POWER(10, COALESCE(t0.decimals, 18))) * p0.usd_price AS token0_liquidity_usd,
            (rb.token1_balance_raw / POWER(10, COALESCE(t1.decimals, 18))) * p1.usd_price AS token1_liquidity_usd
        FROM running_balance rb
        JOIN {{ source(blockchain, tokens_table) }} t0 ON rb.token0_address = t0.address
        JOIN {{ source(blockchain, tokens_table) }} t1 ON rb.token1_address = t1.address
        LEFT JOIN {{ source(blockchain, prices_table) }} p0 ON rb.token0_address = p0.token_address AND rb.day = p0.day
        LEFT JOIN {{ source(blockchain, prices_table) }} p1 ON rb.token1_address = p1.token_address AND rb.day = p1.day
    ),

    volume_data AS (
        -- Calculate daily swap volume per pool
        SELECT 
            date_trunc('day', e.block_time) AS day,
            e.pool_address,
            SUM(ABS(e.amount)) AS total_volume_raw
        FROM {{ source(blockchain, events_table) }} e
        WHERE e.event_type = 'TokenSwapped'
        GROUP BY 1, 2
    )

-- Merge Liquidity + Volume per pool per day
SELECT 
    f.day,
    f.pool_address,
    CASE
        WHEN f.token0_symbol IS NULL OR f.token1_symbol IS NULL THEN NULL
        ELSE concat(LEAST(f.token0_symbol, f.token1_symbol), '-', GREATEST(f.token0_symbol, f.token1_symbol))
    END AS pair_symbols,
    f.token0_balance_scaled AS token0_balance,
    f.token1_balance_scaled AS token1_balance,
    f.token0_liquidity_usd,
    f.token1_liquidity_usd,
    COALESCE(v.total_volume_raw, 0) AS total_volume
FROM final_data f
LEFT JOIN volume_data v ON f.day = v.day AND f.pool_address = v.pool_address
ORDER BY f.day, f.pool_address;

{% endmacro %}