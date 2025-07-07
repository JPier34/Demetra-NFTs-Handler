// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console2} from "forge-std/Script.sol";
import {DemetraShoeNFT} from "../src/DemetraShoeNFT.sol";
import {DemetraLoyalty} from "../src/DemetraLoyalty.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console2.log("Deploying with account:", deployer);
        
        uint64 subscriptionId = uint64(vm.envUint("VRF_SUBSCRIPTION_ID"));
        address vrfCoordinator = vm.envAddress("VRF_COORDINATOR_SEPOLIA");
        bytes32 keyHash = vm.envBytes32("VRF_KEY_HASH_SEPOLIA");
        
        vm.startBroadcast(deployerPrivateKey);
        
        DemetraShoeNFT nft = new DemetraShoeNFT(
            vrfCoordinator,
            keyHash,
            subscriptionId
        );
        console2.log("NFT deployed:", address(nft));
        
        DemetraLoyalty loyalty = new DemetraLoyalty(address(nft));
        console2.log("Loyalty deployed:", address(loyalty));
        
        nft.setLoyaltyContract(address(loyalty));
        
        vm.stopBroadcast();
        
        console2.log("Deploy complete!");
    }
}
