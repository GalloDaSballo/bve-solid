// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

interface IVe {
    function token() external view returns (address);

    function balanceOfNFT(uint256) external view returns (uint256);

    function isApprovedOrOwner(address, uint256) external view returns (bool);

    function ownerOf(uint256) external view returns (address);

    function transferFrom(
        address,
        address,
        uint256
    ) external;

    struct Point {
        int128 bias;
        int128 slope; // # -dweight / dt
        uint256 ts;
        uint256 blk; // block
    }

    function user_point_epoch(uint256 tokenId) external view returns (uint256);

    function epoch() external view returns (uint256);

    function user_point_history(uint256 tokenId, uint256 loc)
        external
        view
        returns (Point memory);

    function point_history(uint256 loc) external view returns (Point memory);

    function checkpoint() external;

    function deposit_for(uint256 tokenId, uint256 value) external;

    function create_lock(uint256 _value, uint256 _lock_duration)
        external
        returns (uint256);

    function MAXTIME() external returns (uint256);
}
