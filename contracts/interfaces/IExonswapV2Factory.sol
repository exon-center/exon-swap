// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IExonswapV2Factory {
    event PairCreated(address indexed tokenn0, address indexed tokenn1, address pair, uint);

    function feeTo() external view returns (address);
    function feeToTokenId() external view returns (uint);
    function feeToSetter() external view returns (address);
    function migrator() external view returns (address);
    function nftAddress() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);
    function getFeeToPercent() external view returns(uint);
    function createPair(address tokenA, address tokenB) external returns (address pair);
    function getPairFee(address _token0, address _token1) external view returns(uint);
    function getPairFeeByAddress(address _pair) external view returns(uint);
    function setFeeTo(address,uint) external;
    function setFeeToSetter(address) external;
    function setFeeToPercent(uint _feeToPercent) external;
    function setMigrator(address) external;
    function getNFTAddress(uint _tokenId) external  returns(address);
    function setFeeForPair(address _token0, address _token1, uint _fee) external;
    function setDefaultPairFee(uint _default_pair_fee) external;
    function changeOwner(uint _tokenId) external;
    function NFTGetUpliner(uint _tokenId) external returns(uint);
    function NFTBalanceOf(address _address) external returns(uint);
    function NFTTokenOfOwnerByIndex(address _address, uint _index) external returns(uint);
}