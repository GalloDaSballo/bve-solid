## Ideally, they have one file with the settings for the strat and deployment
## This file would allow them to configure so they can test, deploy and interact with the strategy

BADGER_DEV_MULTISIG = "0xb65cef03b9b89f99517643226d76e286ee999e77"

## NOTE: Because this is a bodged testnet mix, conftest.py is the "real" code and these are just values to feed to the strat
WANT = "0x888EF71766ca594DED1F0FA3AE64eD2941740A20"  ## Solid
LP_COMPONENT = "0xcBd8fEa77c2452255f59743f55A3Ea9d83b3c72b"  ## ve
REWARD_TOKEN = "0xcBd8fEa77c2452255f59743f55A3Ea9d83b3c72b"  ## ve

PROTECTED_TOKENS = [WANT, LP_COMPONENT, REWARD_TOKEN]
## Fees in Basis Points
DEFAULT_GOV_PERFORMANCE_FEE = 2000 ## 20% to governance
DEFAULT_PERFORMANCE_FEE = 0
DEFAULT_WITHDRAWAL_FEE = 10

FEES = [DEFAULT_GOV_PERFORMANCE_FEE, DEFAULT_PERFORMANCE_FEE, DEFAULT_WITHDRAWAL_FEE]

REGISTRY = "0xFda7eB6f8b7a9e9fCFd348042ae675d1d652454f"  # Multichain BadgerRegistry
