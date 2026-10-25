// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Script.sol";
import "../src/GatedToken.sol";
import "../src/CommunityGate.sol";

/// @notice Deploys the token + gate and seeds a starter community:
///         Bronze (1 COMM), Silver (10), Gold (100), plus a general
///         channel (1 COMM) and a supporters channel (10 COMM).
contract Deploy is Script {
    function run() external {
        vm.startBroadcast();
        GatedToken token = new GatedToken("Community Token", "COMM", msg.sender);
        CommunityGate gate = new CommunityGate(address(token), msg.sender);
        gate.addTier("Bronze", 1 ether);
        gate.addTier("Silver", 10 ether);
        gate.addTier("Gold", 100 ether);
        gate.createChannel("general", 1 ether);
        gate.createChannel("supporters", 10 ether);
        vm.stopBroadcast();
    }
}
