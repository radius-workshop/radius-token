// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {PolicyRegistry} from "../src/interfaces/PolicyRegistry.sol";
import {IPolicyRegistry} from "../src/interfaces/IPolicyRegistry.sol";
import {RadiusToken} from "../src/RadiusToken.sol";

contract RadiusTokenTest is Test {
    PolicyRegistry public registry;
    RadiusToken public token;
    address admin = makeAddr("admin");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        registry = new PolicyRegistry();
        token = new RadiusToken("USD Coin", "USDC", "USD", 6, 1_000_000e6, address(registry), admin);
        vm.prank(admin);
        token.mint(alice, 10_000e6);
    }

    function test_metadata() public view {
        assertEq(token.name(), "USD Coin");
        assertEq(token.symbol(), "USDC");
        assertEq(token.decimals(), 6);
        assertEq(keccak256(bytes(token.currencyCode())), keccak256("USD"));
        assertEq(token.maxSupply(), 1_000_000e6);
    }

    function test_mint_and_transfer() public {
        vm.prank(alice);
        token.transfer(bob, 1000e6);
        assertEq(token.balanceOf(bob), 1000e6);
    }

    function test_transferWithMemo() public {
        bytes32 memo = bytes32("INV-2026-001");
        vm.prank(alice);
        token.transferWithMemo(bob, 500e6, memo);
        assertEq(token.balanceOf(bob), 500e6);
    }

    function test_maxSupply_enforced() public {
        vm.prank(admin);
        vm.expectRevert(RadiusToken.ExceedsMaxSupply.selector);
        token.mint(alice, 1_000_000e6);
    }

    function test_pause_blocks_transfers() public {
        vm.prank(admin);
        token.pause();
        vm.prank(alice);
        vm.expectRevert(RadiusToken.TokenPaused.selector);
        token.transfer(bob, 100e6);
    }

    function test_unpause_restores_transfers() public {
        vm.prank(admin);
        token.pause();
        vm.prank(admin);
        token.unpause();
        vm.prank(alice);
        token.transfer(bob, 100e6);
        assertEq(token.balanceOf(bob), 100e6);
    }

    function test_policy_blocks_transfer() public {
        vm.prank(admin);
        uint256 blackId = registry.createPolicy(IPolicyRegistry.PolicyType.BLACKLIST);
        vm.prank(admin);
        registry.addAccount(blackId, bob);
        vm.prank(admin);
        token.attachPolicy(blackId);

        vm.prank(alice);
        vm.expectRevert(RadiusToken.TransferBlocked.selector);
        token.transfer(bob, 100e6);
    }

    function test_detachPolicy_restores_transfer() public {
        vm.prank(admin);
        uint256 blackId = registry.createPolicy(IPolicyRegistry.PolicyType.BLACKLIST);
        vm.prank(admin);
        registry.addAccount(blackId, bob);
        vm.prank(admin);
        token.attachPolicy(blackId);
        vm.prank(admin);
        token.detachPolicy(blackId);

        vm.prank(alice);
        token.transfer(bob, 100e6);
        assertEq(token.balanceOf(bob), 100e6);
    }

    function test_burn() public {
        vm.prank(alice);
        token.burn(500e6);
        assertEq(token.balanceOf(alice), 9500e6);
    }

    function test_mint_reverts_unauthorized() public {
        vm.prank(alice);
        vm.expectRevert();
        token.mint(alice, 100e6);
    }
}
