// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IExonswapV2Factory.sol";
import "./ExonswapV2Pair.sol";
import "../interfaces/ITRC20.sol";
import "../libraries/NFTHelper.sol";

contract ExonswapV2Factory is IExonswapV2Factory {
    address public  override feeTo;
    address public  override feeToSetter;
    address public  override migrator;
    address public  override nftAddress;
    address public owner;
    uint public defaultPairFee;
    uint public feeToPercent;
    uint public override feeToTokenId;
   

    mapping(address => mapping(address => address)) public  override getPair;
    mapping(address => uint) public PairFee;
    mapping(address => bool) public FarmingContract;
    address[] public  override allPairs;


    constructor(address _feeToSetter, address _nft)  {
        feeToSetter = _feeToSetter;
        nftAddress = _nft;
        owner = msg.sender;
        defaultPairFee = 1;
        feeToPercent = 5;
        feeToTokenId = 2;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    function allPairsLength() external  view override returns (uint) {
        return allPairs.length;
    }

    function pairCodeHash() external pure returns (bytes32) {
        return keccak256(type(ExonswapV2Pair).creationCode);
    }


    function getNFTAddress(uint _tokenId) external view override returns(address) {
        return NFTHelper.getNFTAddress(nftAddress, _tokenId);
    }

    function createPair(address tokenA, address tokenB) external  override returns (address pair) {
        require(tokenA != tokenB, 'ExonswapV2: IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'ExonswapV2: ZERO_ADDRESS');
        require(getPair[token0][token1] == address(0), 'ExonswapV2: PAIR_EXISTS'); // single check is sufficient
        bytes memory bytecode = type(ExonswapV2Pair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
        }
        string memory symbol0 = ITRC20(token0).symbol();
        string memory symbol1 = ITRC20(token1).symbol();
        IExonswapV2Pair(pair).initialize(token0, token1, symbol0, symbol1); 
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
        return pair;
    }


    function setFeeTo(address _feeTo, uint _token_id) external override {
        require(msg.sender == feeToSetter, 'ExonswapV2: FORBIDDEN');
        feeTo = _feeTo;
        feeToTokenId = _token_id;
    }

    function setFeeToPercent(uint _feeToPercent) external override {
        require(msg.sender == feeToSetter, 'ExonswapV2: FORBIDDEN');
        feeToPercent = _feeToPercent;
    }
    

    function getFeeToPercent() external view override returns(uint) {
        return feeToPercent;
    }

    function setMigrator(address _migrator) external  override {
        require(msg.sender == feeToSetter, 'ExonswapV2: FORBIDDEN');
        migrator = _migrator;
    }

    function setFeeToSetter(address _feeToSetter) external  override {
        require(msg.sender == feeToSetter, 'ExonswapV2: FORBIDDEN');
        feeToSetter = _feeToSetter;
    }

    // set fee to exact pair
    function setFeeForPair(address _token0, address _token1, uint _fee) external override onlyOwner {
       PairFee[getPair[_token0][ _token1] ] = _fee;
    }


    // set default fee for pair
    function setDefaultPairFee(uint _default_pair_fee) external override onlyOwner {
        defaultPairFee = _default_pair_fee;
    }

    function getPairFee(address _token0, address _token1) external view override returns(uint) {
        if (PairFee[getPair[_token0][ _token1]] > 0 ) {
            return PairFee[getPair[_token0][ _token1]];
        } else {
            return defaultPairFee;
        }
    }
    
    function getPairFeeByAddress(address _address) external view override returns(uint) {
        return PairFee[_address];
    }

    function changeOwner(uint _tokenId) external override {
        require(msg.sender == nftAddress, "Only from NFT contract");
        for (uint i; i < allPairs.length; i++) {
            ExonswapV2Pair(allPairs[i]).changeOwner(_tokenId);
        }
    }
    
    function NFTGetUpliner(uint _tokenId) external override view returns(uint) {
        return NFTHelper.getUpliner(nftAddress, _tokenId);
    }
    
    function NFTBalanceOf(address _address) external override view returns(uint) {
        return NFTHelper.balanceOf(nftAddress, _address);
    }
    
    function NFTTokenOfOwnerByIndex(address _address, uint _index) external override view returns(uint) {
        return NFTHelper.tokenOfOwnerByIndex(nftAddress, _address, _index);
    }

}
