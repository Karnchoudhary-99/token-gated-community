// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import "../src/GatedToken.sol";
import "../src/CommunityGate.sol";

contract CommunityGateTierTest is Test {
    GatedToken token;
    CommunityGate gate;
    address admin = address(0xA11CE);
    address alice = address(0xA11E);
    address bob = address(0xB0B);

    function setUp() public {
        token = new GatedToken("Community Token", "COMM", admin);
        gate = new CommunityGate(address(token), admin);
        vm.prank(admin);
        token.mint(alice, 50 ether);
        vm.prank(admin);
        token.mint(bob, 5 ether);
    }

    function testHighestTierWinsRegardlessOfOrder() public {
        // Deliberately add Gold before Bronze: tierOf must pick by threshold.
        vm.prank(admin);
        uint256 gold = gate.addTier("Gold", 100 ether);
        vm.prank(admin);
        uint256 bronze = gate.addTier("Bronze", 1 ether);
        vm.prank(admin);
        uint256 silver = gate.addTier("Silver", 10 ether);
        assertTrue(gold != bronze && bronze != silver);

        (bool hasTier, uint256 tierId, string memory name) = gate.tierOf(alice);
        assertTrue(hasTier);
        assertEq(tierId, silver);
        assertEq(name, "Silver");

        (hasTier, tierId, name) = gate.tierOf(bob);
        assertTrue(hasTier);
        assertEq(name, "Bronze");
    }

    function testNoTierForNonHolder() public {
        vm.prank(admin);
        gate.addTier("Bronze", 1 ether);
        (bool hasTier,,) = gate.tierOf(address(0xDEAD));
        assertFalse(hasTier);
        assertFalse(gate.isMember(address(0xDEAD)));
        assertTrue(gate.isMember(alice));
    }

    function testDeactivatedTierIsSkipped() public {
        vm.prank(admin);
        uint256 silver = gate.addTier("Silver", 10 ether);
        vm.prank(admin);
        gate.addTier("Bronze", 1 ether);
        vm.prank(admin);
        gate.setTierActive(silver, false);

        (, , string memory name) = gate.tierOf(alice);
        assertEq(name, "Bronze");
    }

    function testUpdateTierChangesEligibility() public {
        vm.prank(admin);
        uint256 tierId = gate.addTier("Silver", 100 ether);
        (bool hasTier,,) = gate.tierOf(alice);
        assertFalse(hasTier);

        vm.prank(admin);
        gate.updateTier(tierId, "Silver", 10 ether);
        (hasTier,, string memory name) = gate.tierOf(alice);
        assertTrue(hasTier);
        assertEq(name, "Silver");
    }

    function testCheckAccess() public {
        assertTrue(gate.checkAccess(alice, 50 ether));
        assertFalse(gate.checkAccess(alice, 51 ether));
        assertFalse(gate.checkAccess(bob, 10 ether));
    }

    function testNonOwnerCannotAddTier() public {
        vm.prank(alice);
        vm.expectRevert(CommunityGate.NotOwner.selector);
        gate.addTier("Bronze", 1 ether);
    }

    function testUnknownTierReverts() public {
        vm.prank(admin);
        vm.expectRevert(CommunityGate.UnknownTier.selector);
        gate.setTierActive(99, false);
    }

    function testEmptyTierNameReverts() public {
        vm.prank(admin);
        vm.expectRevert(CommunityGate.EmptyName.selector);
        gate.addTier("", 1 ether);
    }
}
