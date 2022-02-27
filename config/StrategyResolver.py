from brownie import interface
from helpers.StrategyCoreResolver import StrategyCoreResolver
from rich.console import Console

console = Console()


class StrategyResolver(StrategyCoreResolver):
    def add_balances_snap(self, calls, entities):
        calls = super().add_balances_snap(calls, entities)
        reward = interface.IERC20(self.manager.strategy.reward())
        calls = self.add_entity_balances_for_tokens(calls, "reward", reward, entities)
        return calls

    def get_strategy_destinations(self):
        """
        Track balances for all strategy implementations
        (Strategy Must Implement)
        """
        # E.G
        strategy = self.manager.strategy
        return {
            "gauge": strategy.lpComponent(),
            "reward": strategy.reward(),
            "badgerTree": strategy.badgerTree(),
        }

    def hook_after_confirm_withdraw(self, before, after, params):
        """
        Specifies extra check for ordinary operation on withdrawal
        Use this to verify that balances in the get_strategy_destinations are properly set
        """
        assert after.balances("want", "gauge") < before.balances(
            "want", "gauge"
        )

    def hook_after_confirm_deposit(self, before, after, params):
        """
        Specifies extra check for ordinary operation on deposit
        Use this to verify that balances in the get_strategy_destinations are properly set
        """
        assert True

    def hook_after_earn(self, before, after, params):
        """
        Specifies extra check for ordinary operation on earn
        Use this to verify that balances in the get_strategy_destinations are properly set
        """
        assert after.balances("want", "gauge") > before.balances(
            "want", "gauge"
        )

    def confirm_harvest(self, before, after, tx):
        """
        Verfies that the Harvest produced yield and fees
        """
        super().confirm_harvest(before, after, tx)

        # Strategy want should increase
        assert after.get("strategy.balanceOf") == before.get("strategy.balanceOf")

        # PPS should not change
        assert after.get("sett.pricePerFullShare") == before.get(
            "sett.pricePerFullShare"
        )

        assert after.balances("reward", "badgerTree") > before.balances(
            "reward", "badgerTree"
        )

        # Strategist should earn if fee is enabled and value was generated
        if before.get("strategy.performanceFeeStrategist") > 0:
            assert after.balances("reward", "strategist") > before.balances(
                "reward", "strategist"
            )

        # Governance should earn if fee is enabled and value was generated
        if before.get("strategy.performanceFeeGovernance") > 0:
            assert after.balances("reward", "governanceRewards") > before.balances(
                "reward", "governanceRewards"
            )

    def confirm_tend(self, before, after, tx):
        """
        Tend Should;
        - Increase the number of staked tended tokens in the strategy-specific mechanism
        - Reduce the number of tended tokens in the Strategy to zero

        (Strategy Must Implement)
        """
        assert True
