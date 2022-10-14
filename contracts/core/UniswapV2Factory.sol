// SPDX-License-Identifier: UNLICENSED
pragma solidity = 0.8.12;

import './interfaces/IUniswapV2Factory.sol';
import './UniswapV2Pair.sol';
import "hardhat/console.sol";

contract UniswapV2Factory is IUniswapV2Factory {
    address private _feeTo;
    address private _feeToSetter;

    mapping(address => mapping(address => address)) public _pairs;
    address[] public allPairs;

    constructor(address feeToSetter_) {
        _feeToSetter = feeToSetter_;
    }

    function allPairsLength() external view returns (uint) {
        return allPairs.length;
    }

    function feeTo() external view returns (address) {
        return _feeTo;    
    }

    function feeToSetter() external view returns (address) {
        return _feeToSetter;    
    }

    function getPair(address tokenA, address tokenB) external view returns (address) {
        return _pairs[tokenA][tokenB];
    }

    function createPair(address tokenA, address tokenB) external returns (address pair) {
        require(tokenA != tokenB, 'UniswapV2: IDENTICAL_ADDRESS');    
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'UniswapV2: ZERO_ADDRESS');
        require(_pairs[token0][token1] == address(0), 'UniswapV2: PAIR_EXISTS');
        bytes memory bytecode = type(UniswapV2Pair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        IUniswapV2Pair(pair).initialize(token0, token1);
        _pairs[token0][token1] = pair;
        _pairs[token1][token0] = pair;
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setFeeTo(address feeTo_) external {
        require(msg.sender == _feeToSetter, 'UniswapV2: FORBIDDEN');
        _feeTo = feeTo_;    
    }

    function setFeeToSetter(address feeToSetter_) external {
        require(msg.sender == _feeToSetter, 'UniswapV2: FORBIDDEN');
        _feeToSetter = feeToSetter_;    
    }
}