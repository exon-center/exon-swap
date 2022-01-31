// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IExonswapV2Pair {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function nftBalanceOf(uint _tokenId) external view returns (uint);
    function balanceOf(address _address) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint);

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(address sender, uint amount0In, uint amount1In);
    // event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint);
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);
    function kLast() external view returns (uint);
    function mint(address to, uint _tokenId) external returns (uint liquidity);
    function burn(address to, uint _tokenId) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data, uint amount) external;
    function skim(address to) external;
    function sync() external;
    function setUnloacked() external;
    function initialize(address, address, string memory, string memory) external;
    function changeOwner(uint _tokenId) external;
    function removeAmount(uint _liquidity, uint _tokenId) external view returns(uint amount0, uint amount1);
    function _update(uint balance0, uint balance1, uint112 _reserve0, uint112 _reserve1) external;
}