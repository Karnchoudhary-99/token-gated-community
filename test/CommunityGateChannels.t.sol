// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import "../src/GatedToken.sol";
import "../src/CommunityGate.sol";

contract CommunityGateChannelsTest is Test {
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

    function testPostAtThresholdAndListByChannel() public {
        vm.prank(admin);
        uint256 general = gate.createChannel("general", 1 ether);
        vm.prank(admin);
        uint256 patrons = gate.createChannel("patrons", 100 ether);

        vm.prank(alice);
        uint256 postId = gate.postMessage(general, "hello everyone");
        assertEq(postId, 0);
        assertEq(gate.postCount(), 1);

        // Alice (50) cannot post in the 100-token channel; Bob (5) can in general.
        vm.prank(alice);
        vm.expectRevert(CommunityGate.InsufficientBalance.selector);
        gate.postMessage(patrons, "too soon");

        vm.prank(bob);
        gate.postMessage(general, "hi alice");

        CommunityGate.Post[] memory generalPosts = gate.postsInChannel(general);
        assertEq(generalPosts.length, 2);
        assertEq(generalPosts[0].author, alice);
        assertEq(generalPosts[1].content, "hi alice");
        assertEq(gate.postsInChannel(patrons).length, 0);
    }

    function testNonMemberCannotPost() public {
        vm.prank(admin);
        uint256 general = gate.createChannel("general", 1 ether);
        vm.prank(address(0xDEAD));
        vm.expectRevert(CommunityGate.NotMember.selector);
        gate.postMessage(general, "let me in");
    }

    function testEmptyPostReverts() public {
        vm.prank(admin);
        uint256 general = gate.createChannel("general", 1 ether);
        vm.prank(alice);
        vm.expectRevert(CommunityGate.EmptyContent.selector);
        gate.postMessage(general, "");
    }

    function testDeactivatedChannelBlocksPosts() public {
        vm.prank(admin);
        uint256 general = gate.createChannel("general", 1 ether);
        vm.prank(admin);
        gate.setChannelActive(general, false);
        vm.prank(alice);
        vm.expectRevert(CommunityGate.ChannelInactive.selector);
        gate.postMessage(general, "hello?");
    }

    function testPauseBlocksPostsButNotReads() public {
        vm.prank(admin);
        uint256 general = gate.createChannel("general", 1 ether);
        vm.prank(admin);
        gate.pause();
        vm.prank(alice);
        vm.expectRevert(CommunityGate.PausedGate.selector);
        gate.postMessage(general, "hello?");

        // Reads still work while paused.
        assertTrue(gate.checkAccess(alice, 10 ether));

        vm.prank(admin);
        gate.unpause();
        vm.prank(alice);
        gate.postMessage(general, "back");
        assertEq(gate.postCount(), 1);
    }

    function testUnknownChannelReverts() public {
        vm.prank(admin);
        vm.expectRevert(CommunityGate.UnknownChannel.selector);
        gate.setChannelActive(42, false);
    }
}
