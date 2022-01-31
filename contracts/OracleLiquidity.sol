// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./interfaces/IExonswapV2Factory.sol";
// import "../interfaces/IOracle.sol";
import "./interfaces/ITRC721.sol";
import "./interfaces/IExonswapV2Pair.sol";
import "./interfaces/IExonswapV2PairRouter.sol";
import "./libraries/SafeMath.sol";

contract OracleLiquidity {
    
    using SafeMath for uint;
    
    address public nftAddress;
    address public factoryAddress;
    address public routerAddress;
    address public wtrxAddress;
    address public usdtAddress;
    address public owner;
    
   
    
    
    constructor(address _nftAddress, 
                address _factoryAddress, 
                address _routerAddress,
                address _wtrx,
                address _usdt) {
        nftAddress = _nftAddress;
        factoryAddress = _factoryAddress;
        routerAddress = _routerAddress;
        wtrxAddress = _wtrx;
        usdtAddress = _usdt;
        owner = msg.sender;
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }
    
    
    
    function getPairUSDTRX() public view returns(address) {
        IExonswapV2Factory factoryContract = IExonswapV2Factory(factoryAddress);
        address usdtTrxPair = factoryContract.getPair(usdtAddress, wtrxAddress);
        return usdtTrxPair;
    }
    
    function getCurrentPriceTRX() public view returns(uint) {
        IExonswapV2Router _router = IExonswapV2Router(routerAddress);
        address pair = getPairUSDTRX();
        if (pair == address(0)) {
            return 0;
        }
        address[] memory path = new address[](2);
        path[0] = wtrxAddress;
        path[1] = usdtAddress;
        uint[] memory price = _router.getAmountsOut(1000000, path);
        return price[1];
    }
    
    
    function getTokenPriceInUSD(address _tokenAddress) public view returns(uint) {
        address pairAddress;
        
        if ( _tokenAddress == usdtAddress) {
            return 1000000;
        }
        if ( _tokenAddress == wtrxAddress) {
            return getCurrentPriceTRX();
        }
        
        address[] memory path;
        pairAddress = IExonswapV2Factory(factoryAddress).getPair(_tokenAddress, usdtAddress);
        if (pairAddress != address(0)) {
            
            path = new address[](2);
            path[0] = _tokenAddress;
            path[1] = usdtAddress;
            uint[] memory priceUSD = IExonswapV2Router(routerAddress).getAmountsOut(1000000, path);
            return priceUSD[1];
        }
        pairAddress = IExonswapV2Factory(factoryAddress).getPair(_tokenAddress, wtrxAddress);
        if (pairAddress != address(0)) {
            uint priceTrx = getCurrentPriceTRX();
            path = new address[](2);
            path[0] = _tokenAddress;
            path[1] = wtrxAddress;
            uint[] memory priceResultTrx = IExonswapV2Router(routerAddress).getAmountsOut(priceTrx, path);
            return priceResultTrx[1];
        }
        return 0;
    }
    
    function setNftAddress(address _address) public onlyOwner {
        nftAddress = _address;
    }
    
    function setFactoryAddress(address _address) public onlyOwner {
        factoryAddress = _address;
    }
    
    function getLiquidityByTokenId(address _address, uint _tokenId) public view returns(uint, uint) {
         IExonswapV2Pair _pair = IExonswapV2Pair(_address);
         uint _balance= _pair.nftBalanceOf(_tokenId);
         uint amount0;
         uint amount1;
         if (_balance > 0) {
             (amount0, amount1) = _pair.removeAmount(_balance, _tokenId);
         }
         return (amount0, amount1);
    }
    
    

    function getPersonalSwap(uint _token_id) public view returns(uint) {
        IExonswapV2Router _router = IExonswapV2Router(routerAddress);
        uint tokenIds = _router.tokenIds(_token_id);
        uint totalSwapUSD;
        for (uint p; p < tokenIds; p++) {
             address token = _router.swapIndex(_token_id, p+1);
             uint token0Amount = _router.swapHistory(_token_id, token);
             uint token0price = getTokenPriceInUSD(token);
             totalSwapUSD += token0price.mul(token0Amount);
        }
        return totalSwapUSD;
    }
    
    function getPersonalLiquidity(uint _token_id) public view returns(uint) {
        IExonswapV2Factory _factory = IExonswapV2Factory(factoryAddress);
        uint pairsLength = _factory.allPairsLength();
        address pairAddress;
        uint token0Amount;
        uint token1Amount;
        uint totalSwapUSD;
        for (uint p; p < pairsLength; p++) {
             pairAddress = _factory.allPairs(p);
             (token0Amount, token1Amount) = getLiquidityByTokenId(pairAddress, _token_id);
             uint token0price = getTokenPriceInUSD(IExonswapV2Pair(pairAddress).token0());
             uint token1price = getTokenPriceInUSD(IExonswapV2Pair(pairAddress).token1());
             totalSwapUSD += token0price * token0Amount + token1price * token1Amount;
        }
        return totalSwapUSD;
    }
    
    
    
    
    
    
}