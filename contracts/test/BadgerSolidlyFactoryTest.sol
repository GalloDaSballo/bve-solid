// SPDX-License-Identifier: Unlicense
pragma solidity ^0.6.11;

import "ds-test/test.sol";
import "forge-std/Vm.sol";

import "../deps/Controller.sol";
import "../deps/SettV4.sol";
import "../MyStrategy.sol";
import "../../interfaces/badger/IController.sol";
import "../BadgerSolidlyFactory.sol";

contract BadgerSolidlyFactoryTest is DSTest {
    // ==============
    // ===== Vm =====
    // ==============

    Vm constant vm = Vm(HEVM_ADDRESS);

    // =================
    // ===== State =====
    // =================

    BadgerSolidlyFactory factory = new BadgerSolidlyFactory();
    IController controller;

    // ==================
    // ===== Set up =====
    // ==================

    function setUp() public {
        factory.initialize(
            address(new Controller()),
            address(new MyStrategy()),
            address(new SettV4())
        );

        controller = factory.controller();
    }

    event Deployed(
        address indexed want,
        address indexed strategy,
        address indexed vault
    );

    // ======================
    // ===== Unit Tests =====
    // ======================

    function testDeploy() public {
        address want = 0xC0240Ee4405f11EFb87A00B432A8be7b7Afc97CC;

        vm.expectEmit(true, true, true, false);
        (address strategy, address vault) = factory.deploy(want);

        assertEq(strategy, controller.strategies(want));
        assertEq(vault, controller.vaults(want));
    }

    function testPreventDuplicateDeploy() public {
        address want = 0xC0240Ee4405f11EFb87A00B432A8be7b7Afc97CC;
        factory.deploy(want);
        vm.expectRevert("already deployed");
        factory.deploy(want);
    }

    function testNoGauge() public {
        vm.expectRevert("no gauge");
        factory.deploy(address(0));
    }
}
