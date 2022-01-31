// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import './libraries/ExonswapV2Library.sol';
import './libraries/SafeMath.sol';
import './libraries/TransferHelper.sol';
import './interfaces/IExonswapV2Factory.sol';
import './interfaces/ITRC20Exon.sol';
import './interfaces/IWTRX.sol';
import './interfaces/IExonswapV2Pair.sol';

contract ExonswapV2SwapRouter   {
    using SafeMathExonswap for uint;

    address public immutable  factory;
    address public immutable  WTRX;
    address public pairRouter;
    address public owner;
    mapping(uint => mapping(address => uint)) public swapHistory;
    mapping(uint => mapping(uint => address)) public swapIndex;
    mapping(uint => uint) public tokenIds;

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'ExonswapV2Router: EXPIRED');
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    function setPairRouter(address _pairRouter) public onlyOwner {
        pairRouter = _pairRouter;
    }
    
    event SwapOut(address sender,uint tokenId, uint amount0Out, uint amount1Out);



    constructor(address _factory, address _WTRX)  {
        factory = _factory;
        WTRX = _WTRX;
        owner = msg.sender;
    }



    fallback() external payable {
        require(msg.sender == WTRX); // only accept TRX via fallback from the WTRX contract
    }

    receive() external payable {require(msg.sender == WTRX);}

// **** SWAP ****
    // requires the initial amount to have already been sent to the first pair
    function _swap(uint[] memory amounts, 
                   address[] memory path, 
                   address _to, 
                   uint _tokenId) internal virtual {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = ExonswapV2Library.sortTokens(input, output);
            uint amountOut = amounts[i + 1];
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOut) : (amountOut, uint(0));
            address to = i < path.length - 2 ? ExonswapV2Library.pairFor(factory, output, path[i + 2]) : _to;
            IExonswapV2Pair(ExonswapV2Library.pairFor(factory, input, output)).swap(amount0Out, amount1Out, to, new bytes(0), _tokenId);
            if (swapHistory[_tokenId][input] == 0) {
                tokenIds[_tokenId] += 1;
                swapIndex[_tokenId][tokenIds[_tokenId]] = input;
                
            }
            swapHistory[_tokenId][input] += amounts[i];
            emit SwapOut(to,_tokenId, amount0Out, amount1Out);
        }
    }
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline,
        uint _tokenId
    ) external virtual ensure(deadline) returns (uint[] memory amounts) {
        amounts = ExonswapV2Library.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'ExonswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, ExonswapV2Library.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, to, _tokenId);
    }
    
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline,
        uint _tokenId
    ) external virtual ensure(deadline) returns (uint[] memory amounts) {
        amounts = ExonswapV2Library.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= amountInMax, 'ExonswapV2Router: EXCESSIVE_INPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, ExonswapV2Library.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, to, _tokenId);
    }
    function swapExactTRXForTokens(uint amountOutMin, 
                                   address[] calldata path, 
                                   address to, 
                                   uint deadline,
                                   uint _tokenId)
        external
        virtual
        payable
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[0] == WTRX, 'ExonswapV2Router: INVALID_PATH');
        amounts = ExonswapV2Library.getAmountsOut(factory, msg.value, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'ExonswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT');
        IWTRX(WTRX).deposit{value: amounts[0]}();
        assert(IWTRX(WTRX).transfer(ExonswapV2Library.pairFor(factory, path[0], path[1]), amounts[0]));
        _swap(amounts, path, to, _tokenId);
    }

    function swapTokensForExactTRX(uint amountOut, 
                                   uint amountInMax, 
                                   address[] calldata path, 
                                   address to, 
                                   uint deadline,
                                   uint _tokenId)
        external
        virtual
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[path.length - 1] == WTRX, 'ExonswapV2Router: INVALID_PATH');
        amounts = ExonswapV2Library.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= amountInMax, 'ExonswapV2Router: EXCESSIVE_INPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, ExonswapV2Library.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, address(this), _tokenId);
        IWTRX(WTRX).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferTRX(to, amounts[amounts.length - 1]);
    }

    function swapExactTokensForTRX(uint amountIn, 
                                   uint amountOutMin, 
                                   address[] calldata path, 
                                   address to, 
                                   uint deadline,
                                   uint _tokenId)
        external
        virtual
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[path.length - 1] == WTRX, 'ExonswapV2Router: INVALID_PATH');
        amounts = ExonswapV2Library.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'ExonswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, ExonswapV2Library.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, address(this), _tokenId);
        IWTRX(WTRX).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferTRX(to, amounts[amounts.length - 1]);
    }

    function swapTRXForExactTokens(uint amountOut, 
                                   address[] calldata path, 
                                   address to, 
                                   uint deadline,
                                   uint _tokenId)
        external
        virtual
        payable
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[0] == WTRX, 'ExonswapV2Router: INVALID_PATH');
        amounts = ExonswapV2Library.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= msg.value, 'ExonswapV2Router: EXCESSIVE_INPUT_AMOUNT');
        IWTRX(WTRX).deposit{value: amounts[0]}();
        assert(IWTRX(WTRX).transfer(ExonswapV2Library.pairFor(factory, path[0], path[1]), amounts[0]));
        _swap(amounts, path, to, _tokenId);
        // refund dust eth, if any
        if (msg.value > amounts[0]) TransferHelper.safeTransferTRX(msg.sender, msg.value - amounts[0]);
    }

    // **** SWAP (supporting fee-on-transfer tokens) ****
    // requires the initial amount to have already been sent to the first pair
    
    function _swapSupportingFeeOnTransferTokens(address[] memory path, address _to, uint _tokenId) internal virtual {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = ExonswapV2Library.sortTokens(input, output);
            IExonswapV2Pair pair = IExonswapV2Pair(ExonswapV2Library.pairFor(factory, input, output));
            uint amountInput;
            uint amountOutput;
            { // scope to avoid stack too deep errors
            (uint reserve0, uint reserve1,) = pair.getReserves();
            (uint reserveInput, uint reserveOutput) = input == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
            amountInput = ITRC20Exonswap(input).balanceOf(address(pair)).sub(reserveInput);
            uint pairFee = IExonswapV2Factory(factory).getPairFeeByAddress(address(pair));
            amountOutput = ExonswapV2Library.getAmountOut(pairFee, amountInput, reserveInput, reserveOutput);
            }
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOutput) : (amountOutput, uint(0));
            address to = i < path.length - 2 ? ExonswapV2Library.pairFor(factory, output, path[i + 2]) : _to;
            {
                uint tokenId = _tokenId;
                pair.swap(amount0Out, amount1Out, to, new bytes(0), tokenId);
            }
           
        }
    }
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline,
        uint _tokenId
    ) external virtual ensure(deadline) {
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, ExonswapV2Library.pairFor(factory, path[0], path[1]), amountIn
        );
        uint balanceBefore = ITRC20Exonswap(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to, _tokenId);
        require(
            ITRC20Exonswap(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >= amountOutMin,
            'ExonswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT'
        );
    }
    function swapExactTRXForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline,
        uint _tokenId
    )
        external
        virtual
        payable
        ensure(deadline)
    {
        require(path[0] == WTRX, 'ExonswapV2Router: INVALID_PATH');
        uint amountIn = msg.value;
        IWTRX(WTRX).deposit{value: amountIn}();
        assert(IWTRX(WTRX).transfer(ExonswapV2Library.pairFor(factory, path[0], path[1]), amountIn));
        uint balanceBefore = ITRC20Exonswap(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to, _tokenId);
        require(
            ITRC20Exonswap(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >= amountOutMin,
            'ExonswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT'
        );
    }
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline,
        uint _tokenId
    )
        external
        virtual
        ensure(deadline)
    {
        require(path[path.length - 1] == WTRX, 'ExonswapV2Router: INVALID_PATH');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, ExonswapV2Library.pairFor(factory, path[0], path[1]), amountIn
        );
        _swapSupportingFeeOnTransferTokens(path, address(this), _tokenId);
        uint amountOut = ITRC20Exonswap(WTRX).balanceOf(address(this));
        require(amountOut >= amountOutMin, 'ExonswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT');
        IWTRX(WTRX).withdraw(amountOut);
        TransferHelper.safeTransferTRX(to, amountOut);
    }

     function _addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin
    ) internal virtual returns (uint amountA, uint amountB) {
        // create the pair if it doesn't exist yet
        if (IExonswapV2Factory(factory).getPair(tokenA, tokenB) == address(0)) {
            IExonswapV2Factory(factory).createPair(tokenA, tokenB);
        }
        (uint reserveA, uint reserveB) = ExonswapV2Library.getReserves(factory, tokenA, tokenB);
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint amountBOptimal = ExonswapV2Library.quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, 'ExonswapV2Router: INSUFFICIENT_B_AMOUNT');
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint amountAOptimal = ExonswapV2Library.quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                require(amountAOptimal >= amountAMin, 'ExonswapV2Router: INSUFFICIENT_A_AMOUNT');
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }


     // ensure(deadline)

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        uint _tokenId
    ) external virtual ensure(deadline) returns (uint amountA, uint amountB, uint liquidity) {
        // check nft owner --------------------------------------------------------------------------
        require(IExonswapV2Factory(factory).getNFTAddress(_tokenId) == to, "Not your token");
        (amountA, amountB) = _addLiquidity(tokenA, tokenB, amountADesired, 
                                              amountBDesired, amountAMin, amountBMin);
        address pair = ExonswapV2Library.pairFor(factory, tokenA, tokenB);
        TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA);
        TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB);
        liquidity = IExonswapV2Pair(pair).mint(to, _tokenId);
        return (amountA, amountB, liquidity);
    }
    
    
    function addLiquidityTRX(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountTRXMin,
        address to,
        uint deadline,
        uint _tokenId
    ) external virtual ensure(deadline) payable  returns (uint amountToken, uint amountTRX, uint liquidity) {
        // check nft owner --------------------------------------------------------------------------
        require(IExonswapV2Factory(factory).getNFTAddress(_tokenId) == to, "Not your token");
        (amountToken, amountTRX) = _addLiquidity(
            token,
            WTRX,
            amountTokenDesired,
            msg.value,
            amountTokenMin,
            amountTRXMin
        );
        address pair = ExonswapV2Library.pairFor(factory, token, WTRX);
        TransferHelper.safeTransferFrom(token, msg.sender, pair, amountToken);
        IWTRX(WTRX).deposit{value: amountTRX}();
        assert(IWTRX(WTRX).transfer(pair, amountTRX));
        liquidity = IExonswapV2Pair(pair).mint(to, _tokenId);
        if (msg.value > amountTRX) TransferHelper.safeTransferTRX(msg.sender, msg.value - amountTRX);
        
    }
    
    // ensure(deadline)
    // **** REMOVE LIQUIDITY ****
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        uint _tokenId
    ) public virtual  ensure(deadline) returns (uint amountA, uint amountB) {
        // check nft owner --------------------------------------------------------------------------
        require(IExonswapV2Factory(factory).getNFTAddress(_tokenId) == msg.sender, "Not your token");
        
        address pair = ExonswapV2Library.pairFor(factory, tokenA, tokenB);
        IExonswapV2Pair(pair).transferFrom(msg.sender, pair, liquidity); // send liquidity to pair
        (uint amount0, uint amount1) = IExonswapV2Pair(pair).burn(to, _tokenId);
        (address token0,) = ExonswapV2Library.sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);
        require(amountA >= amountAMin, 'ExonswapV2Router: INSUFFICIENT_A_AMOUNT');
        require(amountB >= amountBMin, 'ExonswapV2Router: INSUFFICIENT_B_AMOUNT');
    }
    function removeLiquidityTRX(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountTRXMin,
        address to,
        uint deadline,
        uint _tokenId
    ) public virtual ensure(deadline) returns (uint amountToken, uint amountTRX) {
        // check nft owner --------------------------------------------------------------------------
        //require(IExonswapV2Factory(factory).getNFTAddress(_tokenId) == msg.sender, "Not your token");
        
        (amountToken, amountTRX) = removeLiquidity(
            token,
            WTRX,
            liquidity,
            amountTokenMin,
            amountTRXMin,
            address(this),
            deadline,
            _tokenId
        );
        TransferHelper.safeTransfer(token, to, amountToken);
        IWTRX(WTRX).withdraw(amountTRX);
        TransferHelper.safeTransferTRX(to, amountTRX);
    }
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        uint8 v, bytes32 r, bytes32 s, uint _tokenId
    ) external virtual returns (uint amountA, uint amountB) {
        address pair = ExonswapV2Library.pairFor(factory, tokenA, tokenB);
        uint value = liquidity;
        IExonswapV2Pair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        (amountA, amountB) = removeLiquidity(tokenA, tokenB, liquidity, amountAMin, amountBMin, to, deadline, _tokenId);
    }
    function removeLiquidityTRXWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountTRXMin,
        address to,
        uint deadline,
        uint8 v, bytes32 r, bytes32 s, uint _tokenId
    ) external virtual  returns (uint amountToken, uint amountTRX) {
        address pair = ExonswapV2Library.pairFor(factory, token, WTRX);
        uint value = liquidity;
        IExonswapV2Pair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        (amountToken, amountTRX) = removeLiquidityTRX(token, liquidity, amountTokenMin, amountTRXMin, to, deadline, _tokenId);
    }

//     // **** REMOVE LIQUIDITY (supporting fee-on-transfer tokens) ****
    function removeLiquidityTRXSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountTRXMin,
        address to,
        uint deadline,
        uint _token_id
    ) public virtual  ensure(deadline) returns (uint amountTRX) {
        (, amountTRX) = removeLiquidity(
            token,
            WTRX,
            liquidity,
            amountTokenMin,
            amountTRXMin,
            address(this),
            deadline,
            _token_id
        );
        TransferHelper.safeTransfer(token, to, ITRC20Exonswap(token).balanceOf(address(this)));
        IWTRX(WTRX).withdraw(amountTRX);
        TransferHelper.safeTransferTRX(to, amountTRX);
    }
    function removeLiquidityTRXWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountTRXMin,
        address to,
        uint deadline,
        uint8 v, bytes32 r, bytes32 s,
        uint _token_id
    ) external virtual  returns (uint amountTRX) {
        address pair = ExonswapV2Library.pairFor(factory, token, WTRX);
        uint value =  liquidity;
        IExonswapV2Pair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        amountTRX = removeLiquidityTRXSupportingFeeOnTransferTokens(
            token, liquidity, amountTokenMin, amountTRXMin, to, deadline, _token_id
        );
    }

    function getAmountsOut(uint amountIn, address[] memory path)
        public
        view
        virtual
        returns (uint[] memory amounts)
    {
        return ExonswapV2Library.getAmountsOut(factory, amountIn, path);
    }

    function getAmountsIn(uint amountOut, address[] memory path)
        public
        view
        virtual
        returns (uint[] memory amounts)
    {
        return ExonswapV2Library.getAmountsIn(factory, amountOut, path);
    }
    
    
    function getPairReserves(address _token0, address _token1) 
        public 
        view 
        returns (uint, uint) {
            return ExonswapV2Library.getReserves(factory, _token0, _token1);
    }
    
}
