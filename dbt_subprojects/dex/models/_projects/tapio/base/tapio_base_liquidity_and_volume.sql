{{
    config(
        schema = 'tapio',
        alias = 'base_liquidity_and_volume',
        materialized = 'incremental',
        incremental_strategy = 'merge',
        unique_key = ['day', 'pool_address'],
        post_hook = expose_spells('["base"]', "project", "tapio", '["brunota20"]')
    )
}}

{{ tapio_liquidity_and_volume(
    blockchain = 'base',
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