## Ideally, they have one file with the settings for the strat and deployment
## This file would allow them to configure so they can test, deploy and interact with the strategy

BADGER_DEV_MULTISIG = "0xb65cef03b9b89f99517643226d76e286ee999e77"

## NOTE: Because this is a bodged testnet mix, conftest.py is the "real" code and these are just values to feed to the strat
WANT = "0xC0240Ee4405f11EFb87A00B432A8be7b7Afc97CC"  ## usdc/dai
LP_COMPONENT = "0x9C7EaC4b4a8d37fA9dE7e4cb81F0a99256C672d1"  ## gauge
REWARD_TOKEN = "0x888EF71766ca594DED1F0FA3AE64eD2941740A20"  ## solid

PROTECTED_TOKENS = [WANT, LP_COMPONENT, REWARD_TOKEN]
## Fees in Basis Points
DEFAULT_GOV_PERFORMANCE_FEE = 1000
DEFAULT_PERFORMANCE_FEE = 1000
DEFAULT_WITHDRAWAL_FEE = 10

FEES = [DEFAULT_GOV_PERFORMANCE_FEE, DEFAULT_PERFORMANCE_FEE, DEFAULT_WITHDRAWAL_FEE]

REGISTRY = "0xFda7eB6f8b7a9e9fCFd348042ae675d1d652454f"  # Multichain BadgerRegistry
