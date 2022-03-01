// SPDX-License-Identifier: MIT

pragma solidity ^0.6.11;
pragma experimental ABIEncoderV2;

import "../deps/@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "../deps/@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "../deps/@openzeppelin/contracts-upgradeable/math/MathUpgradeable.sol";
import "../deps/@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "../deps/@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";
import "../deps/@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import "../interfaces/badger/IController.sol";
import "../interfaces/solidly/IBaseV1Gauge.sol";
import "../interfaces/solidly/IBaseV1Voter.sol";
import "../interfaces/solidly/IVe.sol";

import {BaseStrategy} from "../deps/BaseStrategy.sol";

contract MyStrategy is BaseStrategy, ReentrancyGuardUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using AddressUpgradeable for address;
    using SafeMathUpgradeable for uint256;

    // address public want // Inherited from BaseStrategy, the token the strategy wants, swaps into and tries to grow
    address public lpComponent; // Gauge
    address public reward; // Token we farm and swap to want / lpComponent

    address public constant BADGER_TREE =
        0x89122c767A5F543e663DB536b603123225bc3823;

    
    IVe public constant VE = IVe(0xcBd8fEa77c2452255f59743f55A3Ea9d83b3c72b);

    IBaseV1Voter public constant VOTER = IBaseV1Voter(0xdC819F5d05a6859D2faCbB4A44E5aB105762dbaE);
    
    uint256 public lockId; // Will be set on first lock and always used

    bool public relockOnEarn; // Should we relock?
    bool public relockOnTend;

    uint public constant MAXTIME = 4 * 365 * 86400;

    event SetRelockOnEarn(bool value);
    event SetRelockOnTend(bool value);

    // Used to signal to the Badger Tree that rewards where sent to it
    event TreeDistribution(
        address indexed token,
        uint256 amount,
        uint256 indexed blockNumber,
        uint256 timestamp
    );

    function _onlyTrusted() internal view {
        require(
            msg.sender == keeper || msg.sender == governance || msg.sender == strategist,
            "_onlyTrusted"
        );
    }

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
        // Approve the Locker for SOLID
        IERC20Upgradeable(want).safeApprove(address(VE), type(uint256).max);
    }

    /// ===== View Functions =====

    // @dev Specify the name of the strategy
    function getName() external pure override returns (string memory) {
        return "Strategy Vested Escrow Solid";
    }

    // @dev Specify the version of the Strategy, for upgrades
    function version() external pure returns (string memory) {
        return "1.0";
    }

    /// @dev When does the lock expire?
    function unlocksAt() public view returns (uint256) {
        return VE.locked(lockId).end; 
    }

    /// @dev Balance of want currently held in strategy positions
    function balanceOfPool() public view override returns (uint256) {
        if(lockId != 0){
            return uint256(VE.locked(lockId).amount);
        }

        // No lock yet
        return 0;
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
        protectedTokens[0] = want; // SOLID
        protectedTokens[1] = lpComponent; // VE
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

    //// === VE CUSTOM == //

    /// @notice Because locks last 4 years, we let strategist change the setting, impact is minimal
    function setRelockOnEarn(bool _relock) external {
        _onlyTrusted();
        relockOnEarn = _relock;
        emit SetRelockOnEarn(_relock);
    }

    function setRelockOnTend(bool _relock) external {
        _onlyTrusted();
        relockOnTend = _relock;
        emit SetRelockOnTend(_relock);
    }


    /// Claim Tokens
    function claimRewards(address _gauge, address[] memory _tokens) external nonReentrant {
        _onlyTrusted();

        uint256 length = _tokens.length;

        // Get initial Amounts
        uint256[] memory amounts = new uint256[](length);

        for(uint i; i < length; ++i) {
            amounts[i] = IERC20Upgradeable(_tokens[i]).balanceOf(address(this));
        }

        // Claim
        address[] memory gauges = new address[](1);
        gauges[0] = _gauge;

        address[][] memory tokens = new address[][](1);
        tokens[0] = _tokens;

        VOTER.claimRewards(gauges, tokens);


        // Get Amounts balAfter & Handle the diff
        for(uint i; i < length; ++i) {
            uint256 balAfter = IERC20Upgradeable(_tokens[i]).balanceOf(address(this));
            uint256 toSend = balAfter.sub(amounts[i]);

            // Send it here else a duplicate will break the math
            // Safe because we send all the tokens, hence a duplicate will have difference = 0 and will stop
            _handleToken(_tokens[i], toSend);
        }
    }

    function claimBribes(address _bribe, address[] memory _tokens, uint _tokenId) external nonReentrant {
        _onlyTrusted();

        uint256 length = _tokens.length;

        // Get initial Amounts
        uint256[] memory amounts = new uint256[](length);

        for(uint i; i < length; ++i) {
            amounts[i] = IERC20Upgradeable(_tokens[i]).balanceOf(address(this));
        }

        // Claim
        address[] memory bribes = new address[](1);
        bribes[0] = _bribe;

        address[][] memory tokens = new address[][](1);
        tokens[0] = _tokens;

        VOTER.claimBribes(bribes, tokens, _tokenId);

        // Get Amounts balAfter & Handle the diff
        for(uint i; i < length; ++i) {
            uint256 balAfter = IERC20Upgradeable(_tokens[i]).balanceOf(address(this));
            uint256 toSend = balAfter.sub(amounts[i]);

            // Send it here else a duplicate will break the math
            // Safe because we send all the tokens, hence a duplicate will have difference = 0 and will stop
            _handleToken(_tokens[i], toSend);
        }
    }

    function claimFees(address _fee, address[] memory _tokens, uint _tokenId) external nonReentrant {
        _onlyTrusted();

        uint256 length = _tokens.length;

        // Get initial Amounts
        uint256[] memory amounts = new uint256[](length);

        for(uint i; i < length; ++i) {
            amounts[i] = IERC20Upgradeable(_tokens[i]).balanceOf(address(this));
        }

        // Claim
        address[] memory fees = new address[](1);
        fees[0] = _fee;

        address[][] memory tokens = new address[][](1);
        tokens[0] = _tokens;

        VOTER.claimFees(fees, tokens, _tokenId);

        // Get Amounts balAfter & Handle the diff
        for(uint i; i < length; ++i) {
            uint256 balAfter = IERC20Upgradeable(_tokens[i]).balanceOf(address(this));
            uint256 toSend = balAfter.sub(amounts[i]);

            // Send it here else a duplicate will break the math
            // Safe because we send all the tokens, hence a duplicate will have difference = 0 and will stop
            _handleToken(_tokens[i], toSend);
        }
    }

    
    /// VOTE
    function vote(address[] memory _poolVote, int256[] memory _weights) external nonReentrant {
        _onlyGovernance();
        VOTER.vote(lockId, _poolVote, _weights);
    }

    function _handleToken(address token, uint256 _amount) internal {
        if(_amount == 0) { return; } // If we get duplicate token, before - balAfter is going to be 0

        if(token == want) {
            // It's SOLID, lock more, emit harvest event
            VE.increase_amount(lockId, _amount);

            emit Harvest(_amount, block.number);
        } else {
            // Any other token, emit to tree
            (
                uint256 governanceRewardsFee,
                uint256 strategistRewardsFee
            ) = _processRewardsFees(_amount, token);

            // Transfer balance of Sushi to the Badger Tree
            uint256 rewardToTree = _amount.sub(governanceRewardsFee).sub(
                strategistRewardsFee
            );
            IERC20Upgradeable(token).safeTransfer(BADGER_TREE, rewardToTree);

            // NOTE: Signal the _amount of reward sent to the badger tree
            emit TreeDistribution(
                reward,
                rewardToTree,
                block.number,
                block.timestamp
            );
        }
    }

    /// @dev invest the amount of want
    /// @notice When this function is called, the controller has already sent want to this
    /// @notice Just get the current balance and then invest accordingly
    function _deposit(uint256 _amount) internal override {
        if(lockId != 0) {
            // Lock More
            VE.increase_amount(lockId, _amount);
        } else {
            // Create lock, for maximum time
            lockId = VE.create_lock(_amount, MAXTIME);
        }
    }

    /// @dev utility function to withdraw everything for migration
    function _withdrawAll() internal override {
        VE.withdraw(lockId); // Revert if lock not expired
    }

    /// @dev withdraw the specified amount of want, liquidate from lpComponent to want, paying off any necessary debt for the conversion
    function _withdrawSome(uint256 _amount)
        internal
        override
        returns (uint256)
    {
        if(balanceOfWant() >= _amount) {
            return _amount; // We have liquid assets, just send those
        }

        VE.withdraw(lockId); // Will revert is lock is not expired

        return balanceOfWant();
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
