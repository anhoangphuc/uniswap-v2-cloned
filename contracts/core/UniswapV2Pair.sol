// SPDX-License-Identifier: UNLICENSED
pragma solidity = 0.8.12;

import './interfaces/IUniswapV2Pair.sol';
import './interfaces/IERC20.sol';
import './interfaces/IUniswapV2Factory.sol';
import './interfaces/IUniswapV2Callee.sol';
import './libraries/Math.sol';
import './libraries/UQ112x112.sol';
import './UniswapV2ERC20.sol';

contract UniswapV2Pair is UniswapV2ERC20, IUniswapV2Pair {
    using UQ112x112 for uint224;

    uint public constant MINIMUM_LIQUIDITY = 10**3;
    bytes4 private constant SELECTOR = bytes4(keccak256('transfer(address,uint256)'));

    address private _factory;
    address private _token0;
    address private _token1;

    uint112 private _reserve0;
    uint112 private _reserve1;
    uint32 private _blockTimestampLast;

    uint private _price0CumulativeLast;
    uint private _price1CumulativeLast;
    uint private _kLast;
    
    uint private unlocked = 1;

    modifier lock() {
        require(unlocked == 1, 'UniSwapV2: LOCKED');
        unlocked = 0;
        _;
        unlocked = 1;
    }

    function factory() external view returns (address) {
        return _factory;    
    }

    function token0() external view returns (address) {
        return _token0;    
    }
    
    function token1() external view returns (address) {
        return _token1;    
    }

    function price0CumulativeLast() external view returns (uint) {
        return _price0CumulativeLast;    
    }

    function price1CumulativeLast() external view returns (uint) {
        return _price1CumulativeLast;    
    }

    function kLast() external view returns (uint) { 
        return _kLast;    
    }

    function getReserves() public view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) {
        reserve0 = _reserve0;    
        reserve1 = _reserve1;
        blockTimestampLast = _blockTimestampLast;
    }

    function _safeTransfer(address token, address to, uint value) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'UniSwapV2: TRANSFER_FAILED');
    }

    constructor() {
        _factory = msg.sender;
    }

    //called once by the factory at time of deployment
    function initialize(address token0_, address token1_) external {
        require(msg.sender == _factory, 'UniswapV2: FORBIDDEN');
        _token0 = token0_;
        _token1 = token1_;
    }

    function DOMAIN_SEPARATOR() public view override (UniswapV2ERC20, IUniswapV2Pair) returns (bytes32) {
        return UniswapV2ERC20.DOMAIN_SEPARATOR();
    }

    function PERMIT_TYPEHASH() public pure override (UniswapV2ERC20, IUniswapV2Pair) returns (bytes32) {
        return UniswapV2ERC20.PERMIT_TYPEHASH();
    }

    function allowance(address owner, address spender) public view override(UniswapV2ERC20, IUniswapV2Pair) returns (uint) {
        return UniswapV2ERC20.allowance(owner, spender);        
    }

    function approve(address spender, uint value) public override (UniswapV2ERC20, IUniswapV2Pair ) returns (bool) {
        return UniswapV2ERC20.approve(spender, value);
    }

    function balanceOf(address owner) public view override (UniswapV2ERC20, IUniswapV2Pair) returns (uint) {
        return UniswapV2ERC20.balanceOf(owner);
    }

    function decimals() public pure override (UniswapV2ERC20, IUniswapV2Pair) returns (uint8) {
        return UniswapV2ERC20.decimals();
    }

    function name() public pure override (UniswapV2ERC20, IUniswapV2Pair) returns (string memory) {
        return UniswapV2ERC20.name();
    }

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) public override (UniswapV2ERC20, IUniswapV2Pair) {
        return UniswapV2ERC20.permit(owner, spender, value, deadline, v, r, s);
    }

    function nonces(address owner) public view override (UniswapV2ERC20, IUniswapV2Pair) returns (uint){
        return UniswapV2ERC20.nonces(owner);    
    }

    function symbol() public pure override (UniswapV2ERC20, IUniswapV2Pair) returns (string memory) {
        return UniswapV2ERC20.symbol();
    }

    function totalSupply() public view override (UniswapV2ERC20, IUniswapV2Pair) returns (uint) {
        return UniswapV2ERC20.totalSupply();
    }

    function transfer(address to, uint value) public override (UniswapV2ERC20, IUniswapV2Pair) returns (bool) {
        return UniswapV2ERC20.transfer(to, value);
    }

    function transferFrom(address from, address to, uint value) public override (UniswapV2ERC20, IUniswapV2Pair) returns (bool) {
        return UniswapV2ERC20.transferFrom(from, to, value);
    }

    //update reserves and, on the first call per block, price accumulators
    function _update(uint balance0, uint balance1, uint112 reserve0_, uint112 reserve1_) private {
        require(balance0 <= type(uint112).max && balance1 <= type(uint112).max, 'UniswapV2: OVERFLOW');
        uint32 blockTimestamp = uint32(block.timestamp % 2 ** 32);
        uint32 timeElapsed;
        unchecked {
            timeElapsed = blockTimestamp - _blockTimestampLast;
        }
        if (timeElapsed > 0 && reserve0_ != 0 && reserve1_ != 0) {
            // *never overflow, and + overflow is desired
            _price0CumulativeLast += uint(UQ112x112.encode(reserve1_).uqdiv(reserve0_)) * timeElapsed;
            _price1CumulativeLast += uint(UQ112x112.encode(reserve0_).uqdiv(reserve1_)) * timeElapsed;
        }
        _reserve0 = uint112(balance0);
        _reserve1 = uint112(balance1);
        _blockTimestampLast = blockTimestamp;
        emit Sync(_reserve0, _reserve1);
    }

    function _mintFee(uint112 reserve0_, uint112 reserve1_) private returns (bool feeOn) {
        address feeTo = IUniswapV2Factory(_factory).feeTo();
        feeOn = feeTo != address(0);
        uint kLast_ = _kLast;
        uint totalSupply_ = totalSupply();
        if (feeOn) {
            if (kLast_ != 0) {
                uint rootK = Math.sqrt(uint(reserve0_) * reserve1_);
                uint rootKLast = Math.sqrt(kLast_);
                if (rootK > rootKLast) {
                    uint numerator = totalSupply() * (rootK - rootKLast);
                    uint denominator = rootK * 5 + rootKLast;
                    uint liquidity = numerator / denominator;
                    if (liquidity > 0) _mint(feeTo, liquidity);
                }
            }
        } else if (kLast_ != 0) {
            _kLast = 0;
        }
    }

    function mint(address to) external lock returns (uint liquidity) {
        (uint112 reserve0_, uint112 reserve1_, ) = getReserves();
        uint balance0 = IERC20(_token0).balanceOf(address(this));
        uint balance1 = IERC20(_token1).balanceOf(address(this));
        uint amount0 = balance0 - reserve0_;
        uint amount1 = balance1 - reserve1_;
        
        bool feeOn = _mintFee(reserve0_, reserve1_);
        uint totalSupply_ = totalSupply();

        if (totalSupply_ == 0) {
            liquidity = Math.sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            _mint(address(0), MINIMUM_LIQUIDITY); //permanently lock the first MINIMUM_LIQUIDITY tokens
        } else {
            liquidity = Math.min(amount0 * totalSupply_ / reserve0_, amount1 * totalSupply_ / reserve1_);
        }
        require(liquidity > 0, 'UniswapV2: INSUFFICIENT_LIQUIDITY_MINTED');
        _mint(to, liquidity);

        _update(balance0, balance1, reserve0_, reserve1_);
        if (feeOn) _kLast = uint(_reserve0) * _reserve1;
        emit Mint(msg.sender, amount0, amount1);
    }

    function burn(address to) external lock returns (uint amount0_, uint amount1_) {
        (uint112 reserve0_, uint112 reserve1_, ) = getReserves();
        address token0_ = _token0;
        address token1_ = _token1;
        uint balance0 = IERC20(token0_).balanceOf(address(this));
        uint balance1 = IERC20(token1_).balanceOf(address(this));
        uint liquidity = balanceOf(address(this));

        bool feeOn = _mintFee(reserve0_, reserve1_);

        uint totalSupply_ = totalSupply();

        amount0_ = liquidity * balance0 / totalSupply_;
        amount1_ = liquidity * balance1 / totalSupply_;
        require(amount0_ > 0 && amount1_ > 0, 'UniswapV2: INSUFFICIENT_LIQUIDITY_BURNED');
        _burn(address(this), liquidity);
        _safeTransfer(token0_, to, amount0_);
        _safeTransfer(token1_, to, amount1_);
        balance0 = IERC20(token0_).balanceOf(address(this));
        balance1 = IERC20(token1_).balanceOf(address(this));

        _update(balance0, balance1, reserve0_, reserve1_);
        if (feeOn) _kLast = uint(_reserve0) * _reserve1;
        emit Burn(msg.sender, amount0_, amount1_, to);
    }

   function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external lock {
       require(amount0Out > 0 || amount1Out > 0, 'UniswapV2: INSUFFICIENT_OUTPUT_AMOUNT');
       (uint112 reserve0_, uint112 reserve1_, ) = getReserves();
       require(amount0Out < reserve0_ && amount1Out < reserve1_, 'UniswapV2: INSUFFICIENT_LIQUIDITY');

       uint balance0;
       uint balance1;
       {
           address token0_ = _token0;
           address token1_ = _token1;
           require(to != _token0 && to != token1_, 'UniswapV2: INVALID_TO');
           if (amount0Out > 0) _safeTransfer(token0_, to, amount0Out);
           if (amount1Out > 0) _safeTransfer(token1_, to, amount1Out);
           if (data.length > 0) IUniswapV2Callee(to).uniswapV2Call(msg.sender, amount0Out, amount1Out, data);
           balance0 = IERC20(token0_).balanceOf(address(this));
           balance1 = IERC20(token1_).balanceOf(address(this));
       }
       uint amount0In = balance0 > reserve0_ - amount0Out ? balance0 - (reserve0_ - amount0Out) : 0;
       uint amount1In = balance1 > reserve1_ - amount1Out ? balance1 - (reserve1_ - amount1Out) : 0;
       require(amount0In > 0 || amount1In > 0, 'UniswapV2: INSUFFICIENT_INPUT_AMOUNT');
        {
            uint balance0Adjusted = balance0 * 1000 - amount0In * 3;
            uint balance1Adjusted = balance1 * 1000 - amount1In * 3;
            require(balance0Adjusted * balance1Adjusted >= uint(reserve0_) * reserve1_ * 1000 ** 2, 'UniswapV2: K');
        }

        _update(balance0, balance1, reserve0_, reserve1_);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
   }

    //force balances to match reverse
    function skim(address to) external lock {
        address token0_ = _token0;    
        address token1_ = _token1;
        _safeTransfer(token0_, to, IERC20(token0_).balanceOf(address(this)) - _reserve0);
        _safeTransfer(token1_, to, IERC20(token1_).balanceOf(address(this)) - _reserve1);
    }

    //force reserve to match balances
    function sync() external lock {
        _update(IERC20(_token0).balanceOf(address(this)), IERC20(_token1).balanceOf(address(this)), _reserve0, _reserve1);    
    }
}