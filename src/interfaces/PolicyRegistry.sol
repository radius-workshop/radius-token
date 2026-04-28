// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IPolicyRegistry} from "./IPolicyRegistry.sol";

contract PolicyRegistry is IPolicyRegistry {
    uint256 private _nextPolicyId = 1;

    mapping(uint256 => Policy) private _policies;
    mapping(uint256 => mapping(address => bool)) private _members;

    modifier onlyAdmin(uint256 policyId) {
        if (_policies[policyId].admin == address(0)) revert PolicyNotFound();
        if (_policies[policyId].admin != msg.sender) revert NotPolicyAdmin();
        _;
    }

    function createPolicy(PolicyType policyType) external returns (uint256 policyId) {
        policyId = _nextPolicyId++;
        _policies[policyId] = Policy({policyType: policyType, admin: msg.sender, active: true});
        emit PolicyCreated(policyId, policyType, msg.sender);
    }

    function addAccount(uint256 policyId, address account) external onlyAdmin(policyId) {
        if (account == address(0)) revert ZeroAddress();
        if (_members[policyId][account]) revert AccountAlreadyInPolicy();
        _members[policyId][account] = true;
        emit AccountAdded(policyId, account);
    }

    function addAccountsBatch(uint256 policyId, address[] calldata accounts)
        external
        onlyAdmin(policyId)
    {
        for (uint256 i = 0; i < accounts.length; i++) {
            if (accounts[i] == address(0)) revert ZeroAddress();
            if (_members[policyId][accounts[i]]) revert AccountAlreadyInPolicy();
            _members[policyId][accounts[i]] = true;
            emit AccountAdded(policyId, accounts[i]);
        }
    }

    function removeAccount(uint256 policyId, address account) external onlyAdmin(policyId) {
        if (!_members[policyId][account]) revert AccountNotInPolicy();
        _members[policyId][account] = false;
        emit AccountRemoved(policyId, account);
    }

    function setActive(uint256 policyId, bool active) external onlyAdmin(policyId) {
        _policies[policyId].active = active;
        emit PolicyUpdated(policyId, active);
    }

    function transferAdmin(uint256 policyId, address newAdmin) external onlyAdmin(policyId) {
        if (newAdmin == address(0)) revert ZeroAddress();
        address old = _policies[policyId].admin;
        _policies[policyId].admin = newAdmin;
        emit AdminTransferred(policyId, old, newAdmin);
    }

    function isAllowed(uint256 policyId, address account) public view returns (bool) {
        Policy storage p = _policies[policyId];
        if (p.admin == address(0)) revert PolicyNotFound();
        if (!p.active) return true;

        bool isMember = _members[policyId][account];
        if (p.policyType == PolicyType.ALLOWLIST) return isMember;
        return !isMember;
    }

    function checkTransfer(uint256[] calldata policyIds, address from, address to)
        external
        view
        returns (bool)
    {
        for (uint256 i = 0; i < policyIds.length; i++) {
            if (!isAllowed(policyIds[i], from)) return false;
            if (!isAllowed(policyIds[i], to)) return false;
        }
        return true;
    }

    function getPolicy(uint256 policyId) external view returns (Policy memory) {
        if (_policies[policyId].admin == address(0)) revert PolicyNotFound();
        return _policies[policyId];
    }

    function isInPolicy(uint256 policyId, address account) external view returns (bool) {
        return _members[policyId][account];
    }
}
