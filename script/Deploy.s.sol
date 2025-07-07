// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console2} from "forge-std/Script.sol";
import {DemetraShoeNFT} from "../src/DemetraShoeNFT.sol";
import {DemetraLoyalty} from "../src/DemetraLoyalty.sol";
import {MockVRFCoordinator} from "../src/mocks/MockVRFCoordinator.sol";

contract DeployScript is Script {
    function run() external {
        console2.log("Deploy script running");
    }
}