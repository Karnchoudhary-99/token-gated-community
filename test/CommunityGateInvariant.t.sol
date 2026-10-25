// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import "../src/GatedToken.sol";
import "../src/CommunityGate.sol";

/// @notice Invariant handler for CommunityGate. The handler deploys its own
///         token + gate in its constructor, so it is the owner of both and
///         can mint, manage tiers/channels, and pause. Every action is
///         guarded so a legitimately-reverting call is never attempted:
///         with fail_on_revert, an unguarded revert would fail the run.
///         Tokens only ever move between the three actors, so supply
///         accounting stays exactly checkable.
contract GateHandler is Test {
    GatedToken public token;
    CommunityGate public gate;
    address public alice = address(0xA11E);
    address public bob = address(0xB0B);
    address public carol = address(0xCA901);

    constructor() {
        token = new GatedToken("Community Token", "COMM", address(this));
        gate = new CommunityGate(address(token), address(this));
    }

    function _actor(uint256 seed) internal view returns (address) {
        uint256 pick = seed % 3;
        if (pick == 0) return alice;
        if (pick == 1) return bob;
        return carol;
    }

    function mintTo(uint256 actorSeed, uint256 amountSeed) public {
        token.mint(_actor(actorSeed), bound(amountSeed, 0, 1000 ether));
    }

    function transferTokens(uint256 fromSeed, uint256 toSeed, uint256 amountSeed) public {
        address from = _actor(fromSeed);
        address to = _actor(toSeed);
        if (from == to) return;
        uint256 amount = bound(amountSeed, 0, token.balanceOf(from));
        vm.prank(from);
        token.transfer(to, amount);
    }

    function burnTokens(uint256 actorSeed, uint256 amountSeed) public {
        address actor = _actor(actorSeed);
        uint256 amount = bound(amountSeed, 0, token.balanceOf(actor));
        vm.prank(actor);
        token.burn(amount);
    }

    function addTier(uint256 thresholdSeed) public {
        gate.addTier("Tier", bound(thresholdSeed, 0, 1000 ether));
    }

    function updateTier(uint256 tierSeed, uint256 thresholdSeed) public {
        uint256 count = gate.nextTierId();
        if (count == 0) return;
        gate.updateTier(bound(tierSeed, 0, count - 1), "Tier", bound(thresholdSeed, 0, 1000 ether));
    }

    function setTierActive(uint256 tierSeed, bool active) public {
        uint256 count = gate.nextTierId();
        if (count == 0) return;
        gate.setTierActive(bound(tierSeed, 0, count - 1), active);
    }

    function createChannel(uint256 thresholdSeed) public {
        gate.createChannel("channel", bound(thresholdSeed, 0, 1000 ether));
    }

    function setChannelActive(uint256 channelSeed, bool active) public {
        uint256 count = gate.nextChannelId();
        if (count == 0) return;
        gate.setChannelActive(bound(channelSeed, 0, count - 1), active);
    }

    function postMessage(uint256 channelSeed, uint256 actorSeed) public {
        uint256 count = gate.nextChannelId();
        if (count == 0) return;
        uint256 channelId = bound(channelSeed, 0, count - 1);
        (, uint256 required, bool active,) = gate.channels(channelId);
        if (!active || gate.paused()) return;
        address actor = _actor(actorSeed);
        uint256 balance = token.balanceOf(actor);
        if (balance == 0 || balance < required) return;
        vm.prank(actor);
        gate.postMessage(channelId, "hello");
    }

    function pauseGate() public {
        gate.pause();
    }

    function unpauseGate() public {
        gate.unpause();
    }
}

contract CommunityGateInvariantTest is Test {
    GateHandler public handler;
    GatedToken public token;
    CommunityGate public gate;

    function setUp() public {
        handler = new GateHandler();
        token = handler.token();
        gate = handler.gate();
        targetContract(address(handler));
    }

    /// Tokens are never created or destroyed outside mint/burn, and only
    /// move between the three actors: total supply always equals the sum
    /// of the actors' balances.
    function invariant_tokenSupplyAccounting() public view {
        assertEq(
            token.totalSupply(),
            token.balanceOf(handler.alice()) + token.balanceOf(handler.bob()) + token.balanceOf(handler.carol())
        );
    }

    /// tierOf always returns the highest active tier the user qualifies
    /// for (by threshold, not insertion order), or no tier at all.
    function invariant_tierOfIsHighestQualified() public view {
        address[3] memory actors = [handler.alice(), handler.bob(), handler.carol()];
        for (uint256 a = 0; a < actors.length; a++) {
            uint256 balance = token.balanceOf(actors[a]);
            bool expectedFound = false;
            uint256 expectedId = 0;
            string memory expectedName = "";
            uint256 bestMin = 0;
            for (uint256 i = 0; i < gate.nextTierId(); i++) {
                (string memory tierName, uint256 minBalance, bool active, bool exists) = gate.tiers(i);
                if (!exists || !active) continue;
                if (balance < minBalance) continue;
                if (!expectedFound || minBalance > bestMin) {
                    expectedFound = true;
                    bestMin = minBalance;
                    expectedId = i;
                    expectedName = tierName;
                }
            }
            (bool hasTier, uint256 tierId, string memory name) = gate.tierOf(actors[a]);
            assertEq(hasTier, expectedFound);
            if (expectedFound) {
                assertEq(tierId, expectedId);
                assertEq(name, expectedName);
            }
        }
    }

    /// Every post lives in exactly one channel: the per-channel listings
    /// partition the global post log, and each listed post names its own
    /// channel.
    function invariant_channelPostsPartitionPostLog() public view {
        uint256 total = 0;
        for (uint256 c = 0; c < gate.nextChannelId(); c++) {
            CommunityGate.Post[] memory listed = gate.postsInChannel(c);
            total += listed.length;
            for (uint256 i = 0; i < listed.length; i++) {
                assertEq(listed[i].channelId, c);
                assertTrue(listed[i].author != address(0));
                assertTrue(bytes(listed[i].content).length > 0);
            }
        }
        assertEq(total, gate.postCount());
    }

    /// checkAccess is exactly the balance comparison it claims to be.
    function invariant_checkAccessMatchesBalance() public view {
        address[3] memory actors = [handler.alice(), handler.bob(), handler.carol()];
        uint256[5] memory thresholds = [uint256(0), 1 ether, 10 ether, 100 ether, 1000 ether];
        for (uint256 a = 0; a < actors.length; a++) {
            for (uint256 t = 0; t < thresholds.length; t++) {
                assertEq(gate.checkAccess(actors[a], thresholds[t]), token.balanceOf(actors[a]) >= thresholds[t]);
            }
        }
    }
}
