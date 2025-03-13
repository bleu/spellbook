{{
    config(
        schema = 'tapio',
        alias = 'liquidity_and_volume',
        materialized = 'incremental',
        incremental_strategy = 'merge',
        unique_key = ['day', 'pool_address'],
        post_hook = '{{ expose_spells(\'["ethereum"]\',
                                      "project",
                                      "tapio",
                                      \'["brunota20"]\') }}'
    )
}}

{#
    Description:
    This model aggregates daily liquidity and volume data for Tapio protocol pools.
    It uses the `tapio_liquidity_and_volume` macro to generate the data.
#}

{{ tapio_liquidity_and_volume(
    blockchain = 'ethereum',
    project = 'tapio',
    version = '1',
    token_swapped_table = 'SelfPeggingAsset_evt_TokenSwapped',
    minted_table = 'SelfPeggingAsset_evt_Minted',
    donated_table = 'SelfPeggingAsset_evt_Donated',
    redeemed_table = 'SelfPeggingAsset_evt_Redeemed',
    pools_table = 'pools',
    tokens_table = 'erc20.tokens',
    prices_table = 'prices.usd'
) }}