// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IExonswapV2Pair.sol";
import "./ExonswapV2TRC20.sol";
import "./libraries/Math.sol";
import "./libraries/UQ112x112.sol";
import "./interfaces/ITRC20Exon.sol";
import "./interfaces/IExonswapV2Factory.sol";
import "./interfaces/IExonswapV2Callee.sol";

contract ExonswapV2Pair is  ExonswapV2TRC20 {
    using SafeMathExonswap  for uint;
    using UQ112x112 for uint224;

    uint public constant MINIMUM_LIQUIDITY = 10**3;
    bytes4 private constant SELECTOR = bytes4(keccak256(bytes("transfer(address,uint256)")));
    string public dash = "-";

    address public factory;
    address public token0;
    address public token1;
    address constant USDTAddr = 0xa614f803B6FD780986A42c78Ec9c7f77e6DeD13C;

    uint112 private reserve0;           // uses single storage slot, accessible via getReserves
    uint112 private reserve1;           // uses single storage slot, accessible via getReserves
    uint32  private blockTimestampLast; // uses single storage slot, accessible via getReserves

    uint public price0CumulativeLast;
    uint public price1CumulativeLast;
    uint public totalPersonalLiquidity0;
    uint public totalPersonalLiquidity1;
    uint public kLast; // reserve0 * reserve1, as of immediately after the most recent liquidity event

    uint private unlocked = 1;
    modifier lock() {
        require(unlocked == 1, "ExonswapV2: LOCKED");
        unlocked = 0;
        _;
        unlocked = 1;
    }


    function getReserves() public view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }



    function _safeTransfer(address token, address to, uint value) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR, to, value));
        if (token == USDTAddr) {
            require(success == true, "ExonswapV2: TRANSFER_FAILED");
        } else {
            require(success && (data.length == 0 || abi.decode(data, (bool))), "ExonswapV2: TRANSFER_FAILED");
        }
    }

    event Mint(address to, uint tokenId, uint upliner, uint amount0, uint amount1);
    event Burn(address to, uint tokenId, uint upliner, uint amount0, uint amount1);
    event Swap(address sender, uint tokenId, uint upliner, uint amount0In, uint amount1In);

    constructor()  {
        factory = msg.sender;
        
    }

    // // called once by the factory at time of deployment
    function initialize(address _token0, address _token1, string memory _symbol0, string memory _symbol1) external {
        require(msg.sender == factory, "ExonswapV2: FORBIDDEN"); // sufficient check
        token0 = _token0;
        token1 = _token1;
        name = string(abi.encodePacked(_symbol0,"-", _symbol1,"-","LP")); //WENT-USDT-LP
        symbol = string(abi.encodePacked(_symbol0,"-",_symbol1)); //USDT-EXON
    }

    // //update reserves and, on the first call per block, price accumulators
    function _update(uint balance0, uint balance1, uint112 _reserve0, uint112 _reserve1) public {
        require(balance0 <= type(uint112).max && balance1 <= type(uint112).max, "ExonswapV2: OVERFLOW");
        uint32 blockTimestamp = uint32(block.timestamp % 2**32);
        uint32 timeElapsed = blockTimestamp - blockTimestampLast; // overflow is desired
        if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
            // * never overflows, and + overflow is desired
            price0CumulativeLast += uint(UQ112x112.encode(_reserve1).uqdiv(_reserve0)) * timeElapsed;
            price1CumulativeLast += uint(UQ112x112.encode(_reserve0).uqdiv(_reserve1)) * timeElapsed;
        }
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = blockTimestamp;
    }

    // // if fee is on, mint liquidity equivalent to 1/6th of the growth in sqrt(k)
    function _mintFee(uint112 _reserve0, uint112 _reserve1) private returns (bool feeOn) {
        address feeTo = IExonswapV2Factory(factory).feeTo();
        uint feeToTokenId = IExonswapV2Factory(factory).feeToTokenId();
        uint feeToPercent = IExonswapV2Factory(factory).getFeeToPercent();
        feeOn = feeTo != address(0);
        uint _kLast = kLast; // gas savings
        if (feeOn) {
            if (_kLast != 0) {
                uint rootK = Math.sqrt(uint(_reserve0).mul(_reserve1));
                uint rootKLast = Math.sqrt(_kLast);
                if (rootK > rootKLast) {
                    uint numerator = totalSupply.mul(rootK.sub(rootKLast));
                    uint denominator = rootK.mul(feeToPercent).add(rootKLast);
                    uint liquidity = numerator / denominator;
                    if (liquidity > 0) _mint(feeTo, liquidity, feeToTokenId);
                }
            }
        } else if (_kLast != 0) {
            kLast = 0;
        }
    }

    // // this low-level function should be called from a contract which performs important safety checks
    function mint(address to, uint _tokenId) external lock returns (uint liquidity) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        uint balance0 = ITRC20Exonswap(token0).balanceOf(address(this));
        uint balance1 = ITRC20Exonswap(token1).balanceOf(address(this));
        uint amount0 = balance0.sub(_reserve0);
        uint amount1 = balance1.sub(_reserve1);

        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint _totalSupply = totalSupply; // gas savings, must be defined here since totalSupply can update in _mintFee
        if (_totalSupply == 0) {
            liquidity = Math.sqrt(amount0.mul(amount1)).sub(MINIMUM_LIQUIDITY);
           _mint(address(0), MINIMUM_LIQUIDITY, 0); // permanently lock the first MINIMUM_LIQUIDITY tokens
        } else {
            liquidity = Math.min(amount0.mul(_totalSupply) / _reserve0, amount1.mul(_totalSupply) / _reserve1);
        }
        require(liquidity > 0, "ExonswapV2: INSUFFICIENT_LIQUIDITY_MINTED");
        _mint(to, liquidity, _tokenId);
        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = uint(reserve0).mul(reserve1); // reserve0 and reserve1 are up-to-date
        addressByNFTId[_tokenId] = to;
        uint upliner = IExonswapV2Factory(factory).NFTGetUpliner(_tokenId);
        emit Mint(to, _tokenId, upliner, amount0, amount1);
    }

    // // this low-level function should be called from a contract which performs important safety checks
    function burn(address to, uint _tokenId) external lock returns (uint amount0, uint amount1) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        address _token0 = token0;                                // gas savings
        address _token1 = token1;                                // gas savings
        uint balance0 = ITRC20Exonswap(_token0).balanceOf(address(this)) - totalPersonalLiquidity0;
        uint balance1 = ITRC20Exonswap(_token1).balanceOf(address(this)) - totalPersonalLiquidity1;
        uint liquidity = balanceOf[address(this)];
        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint _totalSupply = totalSupply; // gas savings, must be defined here since totalSupply can update in _mintFee
        amount0 = liquidity.mul(balance0) / _totalSupply; // using balances ensures pro-rata distribution
        amount1 = liquidity.mul(balance1) / _totalSupply; // using balances ensures pro-rata distribution
        require(amount0 > 0 && amount1 > 0, "ExonswapV2: INSUFFICIENT_LIQUIDITY_BURNED");
        _burn(address(this), liquidity, _tokenId);
        _safeTransfer(_token0, to, amount0);
        _safeTransfer(_token1, to, amount1);
        balance0 = ITRC20Exonswap(_token0).balanceOf(address(this));
        balance1 = ITRC20Exonswap(_token1).balanceOf(address(this));

        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = uint(reserve0).mul(reserve1); // reserve0 and reserve1 are up-to-date
        uint upliner = IExonswapV2Factory(factory).NFTGetUpliner(_tokenId);
        emit Burn(to, _tokenId, upliner, amount0, amount1);
    }

    function removeAmount(uint _liquidity, uint _tokenId) external view returns(uint amount0, uint amount1) {
        address _token0 = token0;                                // gas savings
        address _token1 = token1;                                // gas savings
        uint balance0 = ITRC20Exonswap(_token0).balanceOf(address(this)) - totalPersonalLiquidity0;
        uint balance1 = ITRC20Exonswap(_token1).balanceOf(address(this)) - totalPersonalLiquidity1;
        uint _totalSupply = totalSupply; // gas savings, must be defined here since totalSupply can update in _mintFee
        amount0 = _liquidity.mul(balance0) / _totalSupply; // using balances ensures pro-rata distribution
        amount1 = _liquidity.mul(balance1) / _totalSupply; // using balances ensures pro-rata distribution
        require(amount0 > 0 && amount1 > 0, "ExonswapV2: INSUFFICIENT_LIQUIDITY_BURNED");
        amount0 = _liquidity.mul(personalLiquidity[_tokenId][0])/_totalSupply + amount0;
        amount1 = _liquidity.mul(personalLiquidity[_tokenId][1])/_totalSupply + amount1;
    }
    

    // this low-level function should be called from a contract which performs important safety checks
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data, uint tokenId) external lock {
        require(amount0Out > 0 || amount1Out > 0, "ExonswapV2: INSUFFICIENT_OUTPUT_AMOUNT");
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        require(amount0Out < _reserve0 && amount1Out < _reserve1, "ExonswapV2: INSUFFICIENT_LIQUIDITY");
        uint balance0;
        uint balance1;
        { // scope for _token{0,1}, avoids stack too deep errors
            address _token0 = token0;
            address _token1 = token1;
            require(to != _token0 && to != _token1, "ExonswapV2: INVALID_TO");
            if (amount0Out > 0) _safeTransfer(_token0, to, amount0Out); // optimistically transfer tokens
            if (amount1Out > 0) _safeTransfer(_token1, to, amount1Out); // optimistically transfer tokens
            if (data.length > 0) IExonswapV2Callee(to).exonswapV2Call(msg.sender, amount0Out, amount1Out, data);
            balance0 = ITRC20Exonswap(_token0).balanceOf(address(this));
            balance1 = ITRC20Exonswap(_token1).balanceOf(address(this));
        }
        // todo
        // mint exon tokens
        uint amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;
        uint amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;
        require(amount0In > 0 || amount1In > 0, "ExonswapV2: INSUFFICIENT_INPUT_AMOUNT");
        { 
            uint _currentFee = IExonswapV2Factory(factory).getPairFee(token0, token1);
            uint balance0Adjusted = balance0.mul(1000).sub(amount0In.mul(_currentFee));
            uint balance1Adjusted = balance1.mul(1000).sub(amount1In.mul(_currentFee));
            require(balance0Adjusted.mul(balance1Adjusted) >= uint(_reserve0).mul(_reserve1).mul(1000**2), "ExonswapV2: K");
        }
        _update(balance0, balance1, _reserve0, _reserve1);
        uint upliner = IExonswapV2Factory(factory).NFTGetUpliner(tokenId);
        emit Swap(to, tokenId, upliner, amount0In, amount1In);
    }
    
    // // force balances to match reserves
    function skim(address to) external lock {
        address _token0 = token0; // gas savings
        address _token1 = token1; // gas savings
        _safeTransfer(_token0, to, ITRC20Exonswap(_token0).balanceOf(address(this)).sub(reserve0));
        _safeTransfer(_token1, to, ITRC20Exonswap(_token1).balanceOf(address(this)).sub(reserve1));
    }

    //force reserves to match balances
    function sync() external lock {
        _update(ITRC20Exonswap(token0).balanceOf(address(this)), ITRC20Exonswap(token1).balanceOf(address(this)), reserve0, reserve1);
    }


    function changeOwner(uint _tokenId) external {
        require(msg.sender == factory, "Only factory");
        _updateOwnerById(_tokenId);
    }


    function _transfer(address from, address to, uint value) internal override {
        balanceOf[from] = balanceOf[from].sub(value);
        balanceOf[to] = balanceOf[to].add(value);
        if (to != address(this)) {
            uint nftAmount = IExonswapV2Factory(factory).NFTBalanceOf(from);
            uint nftTo = IExonswapV2Factory(factory).NFTTokenOfOwnerByIndex(to, 0);
            uint nftBalance = value;
            for (uint i; i < nftAmount; i++) {
                uint currentToken = IExonswapV2Factory(factory).NFTTokenOfOwnerByIndex(from,i);
                uint balanceNFT = nftBalanceOf[currentToken];
                if (nftBalance <= balanceNFT ) {
                    nftBalanceOf[currentToken] = nftBalanceOf[currentToken].sub(nftBalance);
                } else {
                    nftBalanceOf[currentToken] = 0;
                    nftBalance = nftBalance.sub(balanceNFT);
                }
            }
            nftBalanceOf[nftTo] = nftBalanceOf[nftTo].add(value);
            if (addressByNFTId[nftTo] == address(0)) {
                addressByNFTId[nftTo] = to;
            }
        }
        emit Transfer(from, to, value);
    }
    

    function _updateOwnerById(uint _tokenId) private  {
        address _currentLPUserAddress = addressByNFTId[_tokenId];
        address _currentNFTUserAddress = IExonswapV2Factory(factory).getNFTAddress(_tokenId);
        uint _currentBalance = nftBalanceOf[_tokenId];
        balanceOf[_currentLPUserAddress] = balanceOf[_currentLPUserAddress].sub(_currentBalance);
        balanceOf[_currentNFTUserAddress] = balanceOf[_currentNFTUserAddress].add(_currentBalance);
        addressByNFTId[_tokenId] = _currentNFTUserAddress;
        
    }
}
