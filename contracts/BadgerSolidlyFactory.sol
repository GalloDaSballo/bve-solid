// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "./proxy/AdminUpgradeabilityProxy.sol";
import "../deps/@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "../interfaces/badger/IController.sol";
import "../interfaces/badger/IBadgerRegistry.sol";
import "../interfaces/solidly/IBaseV1Voter.sol";

contract BadgerSolidlyFactory is Initializable {
    // =====================
    // ===== Constants =====
    // =====================

    // TODO: Maybe make settable and not constants
    uint256 public constant PERFORMANCE_FEE_GOVERNANCE = 1000;
    uint256 public constant PERFORMANCE_FEE_STRATEGIST = 1000;
    uint256 public constant WITHDRAWAL_FEE = 100;

    address public constant SOLID = 0x888EF71766ca594DED1F0FA3AE64eD2941740A20;

    IBaseV1Voter public constant SOLIDLY_VOTER =
        IBaseV1Voter(0xdC819F5d05a6859D2faCbB4A44E5aB105762dbaE);

    IBadgerRegistry public constant REGISTRY =
        IBadgerRegistry(0xFda7eB6f8b7a9e9fCFd348042ae675d1d652454f);

    // =================
    // ===== State =====
    // =================

    address public governance;
    address public strategist;
    address public keeper;
    address public rewards;
    address public guardian;
    address public proxyAdmin;

    address public strategyLogic;
    address public vaultLogic;

    IController public controller;

    // ==================
    // ===== Events =====
    // ==================

    event Deployed(
        address indexed want,
        address indexed strategy,
        address indexed vault
    );

    function initialize(
        address _controllerLogic,
        address _strategyLogic,
        address _vaultLogic
    ) public initializer {
        address _governance = REGISTRY.get("governance");
        address _keeper = REGISTRY.get("keeperAccessControl");
        address _guardian = REGISTRY.get("guardian");
        address _proxyAdminTimelock = REGISTRY.get("proxyAdminTimelock");

        require(_governance != address(0), "ZERO ADDRESS");
        require(_keeper != address(0), "ZERO ADDRESS");
        require(_guardian != address(0), "ZERO ADDRESS");
        require(_proxyAdminTimelock != address(0), "ZERO ADDRESS");

        governance = _governance;
        strategist = _governance;
        keeper = _keeper;
        guardian = _guardian;
        rewards = _governance;
        proxyAdmin = _proxyAdminTimelock;

        strategyLogic = _strategyLogic;
        vaultLogic = _vaultLogic;

        controller = IController(
            deployProxy(
                _controllerLogic,
                _proxyAdminTimelock,
                abi.encodeWithSelector(
                    IController.initialize.selector,
                    address(this), // governance
                    _governance, // strategist
                    _keeper,
                    _governance // rewards
                )
            )
        );
    }

    // ====================
    // ===== External =====
    // ====================

    function deploy(address _want)
        external
        returns (address strategy_, address vault_)
    {
        strategy_ = deployStrategy(_want);
        vault_ = deployVault(_want);

        emit Deployed(_want, strategy_, vault_);
    }

    // ============================
    // ===== Internal helpers =====
    // ============================

    function deployStrategy(address _token)
        internal
        returns (address strategy_)
    {
        require(
            controller.strategies(_token) == address(0),
            "already deployed"
        );
        address gauge = SOLIDLY_VOTER.gauges(_token);
        require(gauge != address(0), "no gauge");

        strategy_ = deployProxy(
            strategyLogic,
            proxyAdmin,
            abi.encodeWithSignature(
                "initialize(address,address,address,address,address,address[3],uint256[3])",
                governance,
                strategist,
                address(controller),
                keeper,
                guardian,
                [_token, gauge, SOLID],
                [
                    PERFORMANCE_FEE_GOVERNANCE,
                    PERFORMANCE_FEE_STRATEGIST,
                    WITHDRAWAL_FEE
                ]
            )
        );

        controller.approveStrategy(_token, strategy_);
        controller.setStrategy(_token, strategy_);
    }

    function deployVault(address _token) internal returns (address vault_) {
        require(controller.vaults(_token) == address(0), "already deployed");

        vault_ = deployProxy(
            vaultLogic,
            proxyAdmin,
            abi.encodeWithSignature(
                "initialize(address,address,address,address,address,bool,string,string)",
                _token,
                address(controller),
                governance,
                keeper,
                guardian,
                false,
                "",
                ""
            )
        );
        controller.setVault(_token, vault_);
    }

    function deployProxy(
        address _logic,
        address _admin,
        bytes memory _data
    ) internal returns (address proxy_) {
        proxy_ = address(new AdminUpgradeabilityProxy(_logic, _admin, _data));
    }
}

/*
TODO:
- Issues with having factory as governance of controller?
- Deterministic proxy deployments using create2 with bytecode as salt?
- setVaultLogic/setStrategyLogic by owner? Ownable?
- Only strategy/vault deployments?
- Parameter settings (fees etc.)?
*/
