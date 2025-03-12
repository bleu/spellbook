{% macro tapio_compatible_trades(
        blockchain = '',
        project = 'tapio',
        version = '1',
        project_decoded_as = 'tapio_blockchain',
        SelfPeggingAsset_evt_TokenSwapped = 'SelfPeggingAsset_evt_TokenSwapped'
    )
%}

WITH raw_trades AS (
    SELECT
        evt_tx_hash AS tx_hash,
        evt_block_time AS block_time,
        evt_block_number AS block_number,
        evt_index,
        buyer AS taker,
        amounts[0] AS token_sold_amount_raw,  -- amounts[_i] is the input token amount
        amounts[1] AS token_bought_amount_raw,  -- amounts[_j] is the output token amount
        contract_address AS maker,  -- The contract is the maker
        tokens[0] AS token_sold_address,
        tokens[1] AS token_bought_address,
        feeAmount AS fee_amount,
        evt_tx_from AS tx_from,
        evt_tx_to AS tx_to,
        '{{ project }}' AS project,
        '{{ version }}' AS version,
        '{{ blockchain }}' AS blockchain
    FROM {{ source(project_decoded_as ~ '_' ~ blockchain, SelfPeggingAsset_evt_TokenSwapped) }}
    {% if is_incremental() %}
    WHERE {{ incremental_predicate('evt_block_time') }}
    {% endif %}
)

SELECT
    blockchain,
    project,
    version,
    date_trunc('month', block_time) AS block_month,
    date_trunc('day', block_time) AS block_date,
    block_time,
    block_number,
    token_bought_amount_raw,
    token_sold_amount_raw,
    token_bought_address,
    token_sold_address,
    taker,
    maker,
    contract_address AS project_contract_address,
    tx_hash,
    evt_index,
    tx_from,
    tx_to
FROM raw_trades

{% endmacro %}