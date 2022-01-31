// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IExonOracle {
    function getTokenPriceInUSD(address _tokenAddress) external view returns(uint);
}