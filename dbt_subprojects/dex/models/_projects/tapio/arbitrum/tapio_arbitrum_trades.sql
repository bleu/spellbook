{{
    config(
        schema = 'tapio_arbitrum',
        alias = 'trades',
        materialized = 'incremental',
        file_format = 'delta',
        incremental_strategy = 'merge',
        unique_key = ['tx_hash', 'evt_index'],
        post_hook='{{ expose_spells(\'["arbitrum"]\',
                                "project",
                                "tapio",
                                \'["brunota20"]\') }}'
    )
}}

{{ tapio_compatible_trades(
    blockchain = 'arbitrum',
    project = 'tapio',
    version = '1',
    project_decoded_as = 'tapio_blockchain',
    SelfPeggingAsset_evt_TokenSwapped = 'SelfPeggingAsset_evt_TokenSwapped'
) }}