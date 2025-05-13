{{
    config(
        schema = 'tapio',
        alias = 'liquidity_and_volume',
        materialized = 'incremental',
        incremental_strategy = 'merge',
        unique_key = ['day', 'pool_address'],
        post_hook = expose_spells('["base", "sonic"]', "project", "tapio", '["brunota20"]')
    )
}}

{#
    Description:
    This model aggregates daily liquidity and volume data for Tapio protocol pools.
    It unions data from multiple blockchains.
#}

{% set uniswap_models = [
     ref('tapio_base_liquidity_and_volume'),
     ref('tapio_sonic_liquidity_and_volume')
] %}

{{ uniswap_models | join('\nUNION ALL\n') }}
