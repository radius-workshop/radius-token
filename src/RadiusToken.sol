// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {IPolicyRegistry} from "./interfaces/IPolicyRegistry.sol";

contract RadiusToken is ERC20, ERC20Permit, AccessControl {
    bytes32 public constant ISSUER_ROLE = keccak256("ISSUER_ROLE");
    bytes32 public constant PAUSE_ROLE = keccak256("PAUSE_ROLE");
    bytes32 public constant BURN_BLOCKED_ROLE = keccak256("BURN_BLOCKED_ROLE");

    string private _currencyCode;
    uint8 private immutable _decimals;
    uint128 private immutable _maxSupply;
    IPolicyRegistry public immutable policyRegistry;
    uint256[] private _policyIds;
    bool public paused;

    event TransferWithMemo(address indexed from, address indexed to, uint256 amount, bytes32 memo);
    event Paused(address indexed account);
    event Unpaused(address indexed account);
    event PolicyAttached(uint256 indexed policyId);
    event PolicyDetached(uint256 indexed policyId);

    error TokenPaused();
    error ExceedsMaxSupply();
    error TransferBlocked();
    error PolicyAlreadyAttached();
    error PolicyNotAttached();

    constructor(
        string memory name_,
        string memory symbol_,
        string memory currencyCode_,
        uint8 decimals_,
        uint128 maxSupply_,
        address policyRegistry_,
        address admin
    ) ERC20(name_, symbol_) ERC20Permit(name_) {
        _currencyCode = currencyCode_;
        _decimals = decimals_;
        _maxSupply = maxSupply_;
        policyRegistry = IPolicyRegistry(policyRegistry_);

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ISSUER_ROLE, admin);
        _grantRole(PAUSE_ROLE, admin);
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function currencyCode() external view returns (string memory) {
        return _currencyCode;
    }

    function maxSupply() external view returns (uint128) {
        return _maxSupply;
    }

    function policyIds() external view returns (uint256[] memory) {
        return _policyIds;
    }

    function mint(address to, uint256 amount) external onlyRole(ISSUER_ROLE) {
        if (_maxSupply > 0 && totalSupply() + amount > _maxSupply) revert ExceedsMaxSupply();
        _mint(to, amount);
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    function burnFrom(address account, uint256 amount) external onlyRole(BURN_BLOCKED_ROLE) {
        _burn(account, amount);
    }

    function transferWithMemo(address to, uint256 amount, bytes32 memo) external returns (bool) {
        emit TransferWithMemo(msg.sender, to, amount, memo);
        return transfer(to, amount);
    }

    function transferFromWithMemo(address from, address to, uint256 amount, bytes32 memo)
        external
        returns (bool)
    {
        emit TransferWithMemo(from, to, amount, memo);
        return transferFrom(from, to, amount);
    }

    function pause() external onlyRole(PAUSE_ROLE) {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyRole(PAUSE_ROLE) {
        paused = false;
        emit Unpaused(msg.sender);
    }

    function attachPolicy(uint256 policyId) external onlyRole(DEFAULT_ADMIN_ROLE) {
        for (uint256 i = 0; i < _policyIds.length; i++) {
            if (_policyIds[i] == policyId) revert PolicyAlreadyAttached();
        }
        _policyIds.push(policyId);
        emit PolicyAttached(policyId);
    }

    function detachPolicy(uint256 policyId) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 len = _policyIds.length;
        for (uint256 i = 0; i < len; i++) {
            if (_policyIds[i] == policyId) {
                _policyIds[i] = _policyIds[len - 1];
                _policyIds.pop();
                emit PolicyDetached(policyId);
                return;
            }
        }
        revert PolicyNotAttached();
    }

    function _update(address from, address to, uint256 value) internal override {
        if (paused) revert TokenPaused();

        if (from != address(0) && to != address(0) && _policyIds.length > 0) {
            if (!policyRegistry.checkTransfer(_policyIds, from, to)) {
                revert TransferBlocked();
            }
        }

        super._update(from, to, value);
    }
}
