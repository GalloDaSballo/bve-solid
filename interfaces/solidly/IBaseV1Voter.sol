// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

interface IBaseV1Voter {
    function claimBribes(
        address[] memory _bribes,
        address[][] memory _tokens,
        uint256 _tokenId
    ) external;

    function claimFees(
        address[] memory _bribes,
        address[][] memory _tokens,
        uint256 _tokenId
    ) external;

    function distribute() external;

    function vote(
        uint256 tokenId,
        address[] calldata _poolVote,
        int256[] calldata _weights
    ) external;

    function claimable(address gauge) external view returns (uint256);

    function claimRewards(address[] memory _gauges, address[][] memory _tokens)
        external;

    function pools(uint256) external view returns (address);

    function gauges(address) external view returns (address);

    function poolForGauge(address) external view returns (address);

    function bribes(address) external view returns (address);

    function weights(address) external view returns (uint256);

    function votes(uint256, address) external view returns (uint256);

    function poolVote(uint256) external view returns (address[] memory);
}
