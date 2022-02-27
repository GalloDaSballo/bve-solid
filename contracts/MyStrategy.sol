// SPDX-License-Identifier: MIT

pragma solidity ^0.6.11;
pragma experimental ABIEncoderV2;

import "../deps/@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "../deps/@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "../deps/@openzeppelin/contracts-upgradeable/math/MathUpgradeable.sol";
import "../deps/@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "../deps/@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";

import "../interfaces/badger/IController.sol";
import "../interfaces/solidly/IBaseV1Gauge.sol";

import {BaseStrategy} from "../deps/BaseStrategy.sol";

contract MyStrategy is BaseStrategy {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using AddressUpgradeable for address;
    using SafeMathUpgradeable for uint256;

    // address public want // Inherited from BaseStrategy, the token the strategy wants, swaps into and tries to grow
    address public lpComponent; // Gauge
    address public reward; // Token we farm and swap to want / lpComponent

    address public constant BADGER_TREE =
        0x89122c767A5F543e663DB536b603123225bc3823;

    // Used to signal to the Badger Tree that rewards where sent to it
    event TreeDistribution(
        address indexed token,
        uint256 amount,
        uint256 indexed blockNumber,
        uint256 timestamp
    );

    function initialize(
        address _governance,
        address _strategist,
        address _controller,
        address _keeper,
        address _guardian,
        address[3] memory _wantConfig,
        uint256[3] memory _feeConfig
    ) public initializer {
        __BaseStrategy_init(
            _governance,
            _strategist,
            _controller,
            _keeper,
            _guardian
        );
        /// @dev Add config here
        want = _wantConfig[0];
        lpComponent = _wantConfig[1];
        reward = _wantConfig[2];

        performanceFeeGovernance = _feeConfig[0];
        performanceFeeStrategist = _feeConfig[1];
        withdrawalFee = _feeConfig[2];

        /// @dev do one off approvals here
        IERC20Upgradeable(want).safeApprove(lpComponent, type(uint256).max);
    }

    /// ===== View Functions =====

    // @dev Specify the name of the strategy
    function getName() external pure override returns (string memory) {
        return "SolidlyStaker";
    }

    // @dev Specify the version of the Strategy, for upgrades
    function version() external pure returns (string memory) {
        return "1.0";
    }

    /// @dev Balance of want currently held in strategy positions
    function balanceOfPool() public view override returns (uint256) {
        return IBaseV1Gauge(lpComponent).balanceOf(address(this));
    }

    /// @dev Returns true if this strategy requires tending
    function isTendable() public view override returns (bool) {
        return false;
    }

    // @dev These are the tokens that cannot be moved except by the vault
    function getProtectedTokens()
        public
        view
        override
        returns (address[] memory)
    {
        address[] memory protectedTokens = new address[](3);
        protectedTokens[0] = want;
        protectedTokens[1] = lpComponent;
        protectedTokens[2] = reward;
        return protectedTokens;
    }

    /// ===== Internal Core Implementations =====

    /// @dev security check to avoid moving tokens that would cause a rugpull, edit based on strat
    function _onlyNotProtectedTokens(address _asset) internal override {
        address[] memory protectedTokens = getProtectedTokens();

        for (uint256 x = 0; x < protectedTokens.length; x++) {
            require(
                address(protectedTokens[x]) != _asset,
                "Asset is protected"
            );
        }
    }

    /// @dev invest the amount of want
    /// @notice When this function is called, the controller has already sent want to this
    /// @notice Just get the current balance and then invest accordingly
    function _deposit(uint256 _amount) internal override {
        IBaseV1Gauge(lpComponent).deposit(_amount, 0);
    }

    /// @dev utility function to withdraw everything for migration
    function _withdrawAll() internal override {
        IBaseV1Gauge(lpComponent).withdrawAll();
    }

    /// @dev withdraw the specified amount of want, liquidate from lpComponent to want, paying off any necessary debt for the conversion
    function _withdrawSome(uint256 _amount)
        internal
        override
        returns (uint256)
    {
        uint256 balanceBefore = balanceOfWant();
        IBaseV1Gauge(lpComponent).withdraw(_amount);
        return balanceOfWant().sub(balanceBefore);
    }

    /// @dev Harvest from strategy mechanics, realizing increase in underlying position
    function harvest() external whenNotPaused returns (uint256 harvested) {
        _onlyAuthorizedActors();

        address[] memory rewards = new address[](1);
        rewards[0] = reward;

        IBaseV1Gauge(lpComponent).getReward(address(this), rewards);
        uint256 rewardBalance = IERC20Upgradeable(reward).balanceOf(
            address(this)
        );

        if (rewardBalance > 0) {
            (
                uint256 governanceRewardsFee,
                uint256 strategistRewardsFee
            ) = _processRewardsFees(rewardBalance, reward);

            // Transfer balance of Sushi to the Badger Tree
            uint256 rewardToTree = rewardBalance.sub(governanceRewardsFee).sub(
                strategistRewardsFee
            );
            IERC20Upgradeable(reward).safeTransfer(BADGER_TREE, rewardToTree);

            // NOTE: Signal the amount of reward sent to the badger tree
            emit TreeDistribution(
                reward,
                rewardToTree,
                block.number,
                block.timestamp
            );
        }

        /// @dev Harvest event that every strategy MUST have, see BaseStrategy
        emit Harvest(0, block.number);

        // No autocompounding
        harvested = 0;
    }

    /// @dev Rebalance, Compound or Pay off debt here
    function tend() external whenNotPaused {
        _onlyAuthorizedActors();
        revert();
    }

    /// ===== Internal Helper Functions =====

    /// @dev used to manage the governance and strategist fee on earned rewards, make sure to use it to get paid!
    function _processRewardsFees(uint256 _amount, address _token)
        internal
        returns (uint256 governanceRewardsFee, uint256 strategistRewardsFee)
    {
        governanceRewardsFee = _processFee(
            _token,
            _amount,
            performanceFeeGovernance,
            IController(controller).rewards()
        );

        strategistRewardsFee = _processFee(
            _token,
            _amount,
            performanceFeeStrategist,
            strategist
        );
    }
}
