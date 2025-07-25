// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {DemetraShoeNFT} from "../src/DemetraShoeNFT.sol";
import {DemetraLoyalty} from "../src/DemetraLoyalty.sol";
import {MockVRFCoordinator} from "../src/mocks/MockVRFCoordinator.sol";
import {ShoeMetadata} from "../src/libraries/ShoeMetadata.sol";

contract DemetraShoeNFTTest is Test {
    DemetraShoeNFT public nft;
    DemetraLoyalty public loyalty;
    MockVRFCoordinator public mockVRF;

    address public owner = address(0x123);
    address public user1 = address(0x456);
    address public user2 = address(0x789);

    bytes32 public constant KEY_HASH =
        0x79d3d8832d904592c0bf9818b621522c988bb8b0c05cdc3b15aea1b6e8db0c15;
    uint64 public constant SUBSCRIPTION_ID = 1;
    uint256 public constant MINT_PRICE = 0.05 ether;

    function setUp() public {
        // Deploys contracts
        vm.startPrank(owner);

        // Deploy Mock VRF
        mockVRF = new MockVRFCoordinator();

        // Deploys NFT contract
        nft = new DemetraShoeNFT(address(mockVRF), KEY_HASH, SUBSCRIPTION_ID);

        // Deploys Loyalty contract
        loyalty = new DemetraLoyalty(address(nft));

        // Connects contracts
        nft.setLoyaltyContract(address(loyalty));

        vm.stopPrank();

        // Gives users some ETH
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
    }

    function testDeployment() public view {
        assertEq(nft.name(), "Demetra Sustainable Shoes");
        assertEq(nft.symbol(), "DEMETRA");
        assertEq(nft.MAX_SUPPLY(), 10000);
        assertEq(nft.mintPrice(), MINT_PRICE);
        assertEq(address(nft.loyaltyContract()), address(loyalty));
    }

    function testMintBasic() public {
        vm.startPrank(user1);

        // Checks initial state
        assertEq(nft.totalSupply(), 0);
        assertEq(nft.balanceOf(user1), 0);

        // Mints NFT
        nft.mint{value: MINT_PRICE}(1);

        // Checks state after mint
        assertEq(nft.totalSupply(), 1);
        assertEq(nft.balanceOf(user1), 1);
        assertEq(nft.walletMints(user1), 1);
        assertEq(nft.ownerOf(1), user1);

        vm.stopPrank();
    }

    function testMintInsufficientPayment() public {
        vm.startPrank(user1);

        vm.expectRevert("Insufficient payment");
        nft.mint{value: 0.01 ether}(1);

        vm.stopPrank();
    }

    function testMintExceedsWalletLimit() public {
        vm.startPrank(user1);

        // Mints max allowed (5)
        nft.mint{value: MINT_PRICE * 5}(5);
        assertEq(nft.walletMints(user1), 5);

        // Tries to mint one more (should fail)
        vm.expectRevert("Wallet limit exceeded");
        nft.mint{value: MINT_PRICE}(1);

        vm.stopPrank();
    }

    function testMintInvalidQuantity() public {
        vm.startPrank(user1);

        vm.expectRevert("Invalid quantity");
        nft.mint{value: MINT_PRICE * 6}(6);

        vm.expectRevert("Invalid quantity");
        nft.mint{value: 0}(0);

        vm.stopPrank();
    }

    function testVRFIntegration() public {
        vm.startPrank(user1);

        // Mints NFT (triggers VRF request)
        nft.mint{value: MINT_PRICE}(1);
        vm.stopPrank();

        vm.startPrank(owner);
        // Simulates VRF response with RARE rarity
        mockVRF.fulfillWithRarity(1, "rare");
        vm.stopPrank();

        vm.startPrank(user1);
        // Checks metadata was generated
        ShoeMetadata.ShoeData memory metadata = nft.getTokenMetadata(1);
        assertEq(
            uint256(metadata.rarity),
            uint256(ShoeMetadata.RarityLevel.RARE)
        );
        assertEq(metadata.shoeName, "GreenStep Pro");
        assertGt(metadata.rarityScore, 0);
        assertGt(metadata.creationTimestamp, 0);

        vm.stopPrank();
    }

    function testLotteryWinner() public {
        vm.startPrank(user1);

        // Mints NFT
        nft.mint{value: MINT_PRICE}(1);

        // Checks no lottery winners initially
        assertEq(nft.totalLotteryWinners(), 0);

        // Simulates VRF with lottery win
        mockVRF.fulfillWithLotteryWin(1);

        // Checks lottery winner was registered
        assertEq(nft.totalLotteryWinners(), 1);

        // Checks metadata shows lottery winner
        ShoeMetadata.ShoeData memory metadata = nft.getTokenMetadata(1);
        assertTrue(metadata.isLotteryWinner);

        vm.stopPrank();
    }

    function testLoyaltyPointsIntegration() public {
        vm.startPrank(user1);

        // Initial loyalty points should be 0
        assertEq(loyalty.getLoyaltyPoints(user1), 0);

        // Mints and fulfill VRF
        nft.mint{value: MINT_PRICE}(1);
        vm.stopPrank();

        vm.startPrank(owner);
        mockVRF.fulfillWithRarity(1, "epic");
        vm.stopPrank();

        vm.startPrank(user1);
        // Checks loyalty points were added
        assertGt(loyalty.getLoyaltyPoints(user1), 0);

        vm.stopPrank();
    }

    function testDiscountCalculation() public {
        vm.startPrank(user1);
        nft.mint{value: MINT_PRICE}(1);
        vm.stopPrank();

        vm.startPrank(owner);
        mockVRF.fulfillWithRarity(1, "rare");
        vm.stopPrank();

        vm.startPrank(user1);
        assertEq(loyalty.getUserDiscount(user1), 10);

        nft.mint{value: MINT_PRICE}(1);
        vm.stopPrank();

        vm.startPrank(owner);
        mockVRF.fulfillWithRarity(2, "legendary");
        vm.stopPrank();

        vm.startPrank(user1);
        assertEq(loyalty.getUserDiscount(user1), 45);
        vm.stopPrank();
    }

    function testOwnerMint() public {
        vm.startPrank(owner);

        // Owner mints with predetermined rarity
        nft.ownerMint(user1, 1, ShoeMetadata.RarityLevel.LEGENDARY);

        // Checks NFT was minted
        assertEq(nft.balanceOf(user1), 1);
        assertEq(nft.totalSupply(), 1);

        // Checks metadata
        ShoeMetadata.ShoeData memory metadata = nft.getTokenMetadata(1);
        assertEq(
            uint256(metadata.rarity),
            uint256(ShoeMetadata.RarityLevel.LEGENDARY)
        );
        assertFalse(metadata.isLotteryWinner); // Owner mint never wins lottery

        vm.stopPrank();
    }

    function testPauseUnpause() public {
        vm.startPrank(owner);

        // Pauses contract
        nft.pause();

        vm.stopPrank();
        vm.startPrank(user1);

        // Minting should fail when paused
        vm.expectRevert();
        nft.mint{value: MINT_PRICE}(1);

        vm.stopPrank();
        vm.startPrank(owner);

        // Unpauses
        nft.unpause();

        vm.stopPrank();
        vm.startPrank(user1);

        // Minting should work again
        nft.mint{value: MINT_PRICE}(1);
        assertEq(nft.balanceOf(user1), 1);

        vm.stopPrank();
    }

    function testAdminFunctions() public {
        vm.startPrank(owner);

        // Tests price change
        nft.setMintPrice(0.1 ether);
        assertEq(nft.mintPrice(), 0.1 ether);

        vm.stopPrank();
        vm.startPrank(user1);

        // Non-owner should not be able to change price
        vm.expectRevert();
        nft.setMintPrice(0.2 ether);

        vm.stopPrank();
    }

    function testWithdraw() public {
        vm.startPrank(user1);

        // Mints some NFTs to generate revenue
        nft.mint{value: MINT_PRICE * 3}(3);

        vm.stopPrank();
        vm.startPrank(owner);

        uint256 initialBalance = owner.balance;
        uint256 contractBalance = address(nft).balance;

        // Withdraws funds
        nft.withdraw();

        // Checks funds were transferred
        assertEq(address(nft).balance, 0);
        assertEq(owner.balance, initialBalance + contractBalance);

        vm.stopPrank();
    }

    function testCollectionStats() public {
        vm.startPrank(user1);

        // Checks initial stats
        (
            uint256 totalMinted,
            uint256 remainingSupply,
            uint256 lotteryWinners,
            uint256 currentPrice
        ) = nft.getCollectionStats();
        assertEq(totalMinted, 0);
        assertEq(remainingSupply, 10000);
        assertEq(lotteryWinners, 0);
        assertEq(currentPrice, MINT_PRICE);

        // Mints and fulfills
        nft.mint{value: MINT_PRICE * 2}(2);
        vm.stopPrank();

        vm.startPrank(owner);
        mockVRF.fulfillWithRarity(1, "common");
        mockVRF.fulfillWithLotteryWin(2);
        vm.stopPrank();

        vm.startPrank(owner);
        // Checks updated stats
        (totalMinted, remainingSupply, lotteryWinners, currentPrice) = nft
            .getCollectionStats();
        assertEq(totalMinted, 2);
        assertEq(remainingSupply, 9998);
        assertEq(lotteryWinners, 1);

        vm.stopPrank();
    }

    function testMaxSupply() public {
        vm.startPrank(owner);
        vm.expectRevert("Max supply exceeded");
        nft.ownerMint(user1, 10001, ShoeMetadata.RarityLevel.COMMON);

        vm.stopPrank();
    }

    // Gas optimization tests
    function testGasOptimization() public {
        vm.startPrank(user1);

        uint256 gasBefore = gasleft();
        nft.mint{value: MINT_PRICE}(1);
        uint256 gasUsed = gasBefore - gasleft();

        console2.log("Gas used for mint:", gasUsed);

        // Asserts reasonable gas usage (adjust based on actual measurements)
        assertLt(gasUsed, 300000); // Should be less than 300k gas

        vm.stopPrank();
    }
}
