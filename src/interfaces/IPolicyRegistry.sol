// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IPolicyRegistry {
    enum PolicyType {
        ALLOWLIST,
        BLACKLIST
    }

    struct Policy {
        PolicyType policyType;
        address admin;
        bool active;
    }

    event PolicyCreated(uint256 indexed policyId, PolicyType policyType, address indexed admin);
    event PolicyUpdated(uint256 indexed policyId, bool active);
    event AccountAdded(uint256 indexed policyId, address indexed account);
    event AccountRemoved(uint256 indexed policyId, address indexed account);
    event AdminTransferred(uint256 indexed policyId, address indexed oldAdmin, address indexed newAdmin);

    error PolicyNotFound();
    error NotPolicyAdmin();
    error PolicyInactive();
    error AccountAlreadyInPolicy();
    error AccountNotInPolicy();
    error ZeroAddress();

    function createPolicy(PolicyType policyType) external returns (uint256 policyId);
    function addAccount(uint256 policyId, address account) external;
    function addAccountsBatch(uint256 policyId, address[] calldata accounts) external;
    function removeAccount(uint256 policyId, address account) external;
    function setActive(uint256 policyId, bool active) external;
    function transferAdmin(uint256 policyId, address newAdmin) external;
    function isAllowed(uint256 policyId, address account) external view returns (bool);
    function checkTransfer(uint256[] calldata policyIds, address from, address to) external view returns (bool);
    function getPolicy(uint256 policyId) external view returns (Policy memory);
    function isInPolicy(uint256 policyId, address account) external view returns (bool);
}
