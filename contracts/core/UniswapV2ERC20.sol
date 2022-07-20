// SPDX-License-Identifier: UNLICENSED
pragma solidity = 0.8.12;

import './interfaces/IUniswapV2ERC20.sol';

contract UniswapV2ERC20 is IUniswapV2ERC20 {
    uint private _totalSupply;
    string private constant _name = 'Uniswap V2';
    string private constant _symbol = 'UNI-V2';
    uint8 private constant _decimals = 18;

    mapping (address => uint256) private _balances;
    mapping (address => mapping(address => uint256)) private _allowances;

    bytes32 private _DOMAIN_SEPARATOR;
    // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 private constant _PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;
    mapping(address => uint) private _nonces;

    constructor() {
        uint chainId;
        assembly {
            chainId := chainId
        }
        _DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256('EIP712Domain(string name, string version, uint256 chainId, address verifyingContract)'),
                keccak256(bytes(_name)),
                keccak256(bytes('1')),
                chainId,
                address(this)
            )
        );
    }

    function name() public pure virtual returns (string memory) {
        return _name;    
    }

    function symbol() public pure virtual returns (string memory) {
        return _symbol;    
    }

    function decimals() public pure virtual returns (uint8) {
        return _decimals;    
    }

    function totalSupply() public view virtual returns (uint) {
        return _totalSupply;    
    }

    function balanceOf(address owner) public view virtual returns (uint) {
        return _balances[owner];
    }

    function allowance(address owner, address spender) public view virtual returns (uint) {
        return _allowances[owner][spender];
    }

    function _mint(address to, uint value) internal {
        _totalSupply = _totalSupply + value;
        _balances[to] = _balances[to] + value;
        emit Transfer(address(0), to, value);
    }

    function _burn(address from, uint value) internal {
        _balances[from] = _balances[from] - value;
        _totalSupply = _totalSupply - value;
        emit Transfer(from, address(0), value);
    }

    function _approve(address owner, address spender, uint value) private {
        _allowances[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    function _transfer(address from, address to, uint value) private {
        _balances[from] = _balances[from] - value;
        _balances[to] = _balances[to] + value;
        emit Transfer(from, to, value);
    }

    function approve(address spender, uint value) public virtual returns (bool) {
        _approve(msg.sender, spender, value);        
        return true;
    }

    function transfer(address to, uint value) public virtual returns (bool) {
        _transfer(msg.sender, to, value);    
        return true;
    }

    function transferFrom(address from, address to, uint value) public virtual returns (bool) {
        if (_allowances[from][msg.sender] !=  type(uint).max) {
            _allowances[from][msg.sender] = _allowances[from][msg.sender] - value;
        }
        _transfer(from, to, value);
        return true;
    }

    function DOMAIN_SEPARATOR() public view virtual returns (bytes32) {
        return _DOMAIN_SEPARATOR;    
    }

    function PERMIT_TYPEHASH() public pure virtual returns (bytes32) {
        return _PERMIT_TYPEHASH;
    }

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) public virtual {
        require(deadline >= block.timestamp, 'UniswapV2: EXPIRED');        
        bytes32 digest = keccak256(
            abi.encodePacked(
                '\x19\x01',
                _DOMAIN_SEPARATOR,
                keccak256(abi.encode(_PERMIT_TYPEHASH, owner, spender, value, _nonces[owner]++, deadline))
            )
        );
        address recoverAddress = ecrecover(digest, v, r, s);
        require(recoverAddress != address(0) && recoverAddress == owner, 'UNISWAPV2: INVALID_SIGNATURE');
        _approve(owner, spender, value);
    }

    function nonces(address owner) public view virtual returns (uint) {
        return _nonces[owner];
    }
}
