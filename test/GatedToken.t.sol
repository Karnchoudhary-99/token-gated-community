// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import "../src/GatedToken.sol";

contract GatedTokenTest is Test {
    GatedToken token;
    address admin = address(0xA11CE);
    address alice = address(0xA11E);
    address bob = address(0xB0B);

    function setUp() public {
        token = new GatedToken("Community Token", "COMM", admin);
    }

    function testMintAndTransfer() public {
        vm.prank(admin);
        token.mint(alice, 100 ether);
        assertEq(token.balanceOf(alice), 100 ether);
        assertEq(token.totalSupply(), 100 ether);

        vm.prank(alice);
        assertTrue(token.transfer(bob, 25 ether));
        assertEq(token.balanceOf(alice), 75 ether);
        assertEq(token.balanceOf(bob), 25 ether);
    }

    function testApproveAndTransferFrom() public {
        vm.prank(admin);
        token.mint(alice, 50 ether);

        vm.prank(alice);
        token.approve(bob, 20 ether);

        vm.prank(bob);
        assertTrue(token.transferFrom(alice, bob, 20 ether));
        assertEq(token.balanceOf(bob), 20 ether);
        assertEq(token.allowance(alice, bob), 0);
    }

    function testBurnReducesSupply() public {
        vm.prank(admin);
        token.mint(alice, 10 ether);
        vm.prank(alice);
        token.burn(4 ether);
        assertEq(token.balanceOf(alice), 6 ether);
        assertEq(token.totalSupply(), 6 ether);
    }

    function testNonOwnerCannotMint() public {
        vm.prank(alice);
        vm.expectRevert(GatedToken.NotOwner.selector);
        token.mint(alice, 1 ether);
    }

    function testTransferToZeroAddressReverts() public {
        vm.prank(admin);
        token.mint(alice, 1 ether);
        vm.prank(alice);
        vm.expectRevert(GatedToken.ZeroAddress.selector);
        token.transfer(address(0), 1 ether);
    }

    function testTransferBeyondBalanceReverts() public {
        vm.prank(alice);
        vm.expectRevert(GatedToken.InsufficientBalance.selector);
        token.transfer(bob, 1 ether);
    }

    function testTransferFromBeyondAllowanceReverts() public {
        vm.prank(admin);
        token.mint(alice, 10 ether);
        vm.prank(bob);
        vm.expectRevert(GatedToken.InsufficientAllowance.selector);
        token.transferFrom(alice, bob, 1 ether);
    }
}
