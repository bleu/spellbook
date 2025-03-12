{{
    config(
        schema = 'tapio_optimism',
        alias = 'trades',
        materialized = 'incremental',
        file_format = 'delta',
        incremental_strategy = 'merge',
        unique_key = ['tx_hash', 'evt_index'],
        post_hook='{{ expose_spells(\'["optimism"]\',
                                "project",
                                "tapio",
                                \'["brunota20"]\') }}'
    )
}}

{{ tapio_compatible_trades(
    blockchain = 'optimism',
    project = 'tapio',
    version = '1',
    project_decoded_as = 'tapio_blockchain',
    SelfPeggingAsset_evt_TokenSwapped = 'SelfPeggingAsset_evt_TokenSwapped'
) }}