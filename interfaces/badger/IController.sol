// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0 <0.8.0;

interface IController {
    function initialize(
        address _governance,
        address _strategist,
        address _keeper,
        address _rewards
    ) external;

    function withdraw(address, uint256) external;

    function strategies(address) external view returns (address);

    function balanceOf(address) external view returns (uint256);

    function earn(address, uint256) external;

    function want(address) external view returns (address);

    function rewards() external view returns (address);

    function vaults(address) external view returns (address);

    function approveStrategy(address _token, address _strategy) external;

    function setStrategy(address _token, address _strategy) external;

    function setVault(address _token, address _vault) external;
}
