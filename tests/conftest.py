from brownie import (
    accounts,
    interface,
    Controller,
    SettV4,
    MyStrategy,
)
from config import (
    BADGER_DEV_MULTISIG,
    WANT,
    LP_COMPONENT,
    REWARD_TOKEN,
    PROTECTED_TOKENS,
    FEES,
)
from dotmap import DotMap
import pytest


@pytest.fixture
def solid():
    return interface.IBaseV1Token("0x888EF71766ca594DED1F0FA3AE64eD2941740A20")


@pytest.fixture
def router():
    return interface.IBaseV1Router01("0xa38cd27185a464914D3046f0AB9d43356B34829D")


@pytest.fixture
def ve():
    return interface.IVe("0xcBd8fEa77c2452255f59743f55A3Ea9d83b3c72b")


@pytest.fixture
def voter():
    return interface.IBaseV1Voter("0xdC819F5d05a6859D2faCbB4A44E5aB105762dbaE")


@pytest.fixture
def custom_setup(web3, router, solid, ve, voter):
    dev = accounts[0]
    STABLE = True
    AMT = 1000e18

    pair = interface.IBaseV1Pair(WANT)

    token0 = interface.IBridgedToken(pair.token0())
    token1 = interface.IBridgedToken(pair.token1())

    for token in [token0, token1]:
        token.Swapin(web3.keccak(0), dev, AMT, {"from": token.owner()})

        token.approve(router, AMT, {"from": dev})

    ## Add liquidity
    router.addLiquidity(
        token0,
        token1,
        STABLE,
        token0.balanceOf(dev),
        token1.balanceOf(dev),
        0,
        0,
        dev,
        999999999999999999999,
        {"from": dev},
    )

    ## Confirm liqudiity is in
    print(f"Balance: {pair.balanceOf(dev)}")

    ## Approve the gauge
    pair.approve(LP_COMPONENT, pair.balanceOf(dev), {"from": dev})

    ## Mint token
    solid.mint(dev, AMT, {"from": solid.minter()})
    ## Approve for locking
    solid.approve(ve, AMT, {"from": dev})
    ## Lock for 4 years
    lock_tx = ve.create_lock(AMT, 4 * 365 * 86400, {"from": dev})

    ## Vote
    LOCK_ID = lock_tx.return_value
    voter.vote(LOCK_ID, [pair], [100], {"from": dev})


@pytest.fixture
def deployed(custom_setup):
    """
    Deploys, vault, controller and strats and wires them up for you to test
    """
    deployer = accounts[0]

    strategist = deployer
    keeper = deployer
    guardian = deployer

    governance = accounts.at(BADGER_DEV_MULTISIG, force=True)

    controller = Controller.deploy({"from": deployer})
    controller.initialize(BADGER_DEV_MULTISIG, strategist, keeper, BADGER_DEV_MULTISIG)

    sett = SettV4.deploy({"from": deployer})
    sett.initialize(
        WANT,
        controller,
        BADGER_DEV_MULTISIG,
        keeper,
        guardian,
        False,
        "prefix",
        "PREFIX",
    )

    sett.unpause({"from": governance})
    controller.setVault(WANT, sett)

    ## TODO: Add guest list once we find compatible, tested, contract
    # guestList = VipCappedGuestListWrapperUpgradeable.deploy({"from": deployer})
    # guestList.initialize(sett, {"from": deployer})
    # guestList.setGuests([deployer], [True])
    # guestList.setUserDepositCap(100000000)
    # sett.setGuestList(guestList, {"from": governance})

    ## Start up Strategy
    strategy = MyStrategy.deploy({"from": deployer})
    strategy.initialize(
        BADGER_DEV_MULTISIG,
        strategist,
        controller,
        keeper,
        guardian,
        PROTECTED_TOKENS,
        FEES,
    )

    ## Tool that verifies bytecode (run independently) <- Webapp for anyone to verify

    ## Set up tokens
    want = interface.IERC20(WANT)
    lpComponent = interface.IERC20(LP_COMPONENT)
    rewardToken = interface.IERC20(REWARD_TOKEN)

    ## Wire up Controller to Strart
    ## In testing will pass, but on live it will fail
    controller.approveStrategy(WANT, strategy, {"from": governance})
    controller.setStrategy(WANT, strategy, {"from": deployer})

    return DotMap(
        deployer=deployer,
        controller=controller,
        vault=sett,
        sett=sett,
        strategy=strategy,
        # guestList=guestList,
        want=want,
        lpComponent=lpComponent,
        rewardToken=rewardToken,
    )


## Contracts ##


@pytest.fixture
def vault(deployed):
    return deployed.vault


@pytest.fixture
def sett(deployed):
    return deployed.sett


@pytest.fixture
def controller(deployed):
    return deployed.controller


@pytest.fixture
def strategy(deployed):
    return deployed.strategy


## Tokens ##


@pytest.fixture
def want(deployed):
    return deployed.want


@pytest.fixture
def tokens():
    return [WANT, LP_COMPONENT, REWARD_TOKEN]


## Accounts ##


@pytest.fixture
def deployer(deployed):
    return deployed.deployer


@pytest.fixture
def strategist(strategy):
    return accounts.at(strategy.strategist(), force=True)


@pytest.fixture
def settKeeper(vault):
    return accounts.at(vault.keeper(), force=True)


@pytest.fixture
def strategyKeeper(strategy):
    return accounts.at(strategy.keeper(), force=True)


## Forces reset before each test
@pytest.fixture(autouse=True)
def isolation(fn_isolation):
    pass
