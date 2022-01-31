// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IExonswapV2Router {

   function swap(address pair, uint amount0Out, uint amount1Out, address to, bytes calldata data, uint tokenId) external;
   function nftCollection() external;
   function factory() external view returns (address);
   function WTRX() external view returns (address);
   function getAmountsOut(uint amountIn, address[] memory path) external view returns(uint[] memory);
    function getAmountsIn(uint amountOut, address[] memory path) external view returns(uint[] memory);
    function swapHistoryLength() external view returns(uint);
    function swapHistory(uint, address) external view returns(uint);
    function swapIndex(uint, uint) external view returns(address);
    function tokenIds(uint) external view returns(uint);
}