// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;


interface IBaseV1Router01 {
    struct route {
        address from;
        address to;
        bool stable;
    }

    function addLiquidity(
      address tokenA,
      address tokenB,
      bool stable,
      uint amountADesired,
      uint amountBDesired,
      uint amountAMin,
      uint amountBMin,
      address to,
      uint deadline
  ) external returns (uint amountA, uint amountB, uint liquidity);

  function removeLiquidity(
      address tokenA,
      address tokenB,
      bool stable,
      uint liquidity,
      uint amountAMin,
      uint amountBMin,
      address to,
      uint deadline
  ) external returns (uint amountA, uint amountB);

  function swapExactTokensForTokens(
      uint amountIn,
      uint amountOutMin,
      route[] calldata routes,
      address to,
      uint deadline
  ) external returns (uint[] memory amounts);
}