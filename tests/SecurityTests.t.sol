// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {DemetraShoeNFT} from "../src/DemetraShoeNFT.sol";
import {DemetraLoyalty} from "../src/DemetraLoyalty.sol";
import {MockVRFCoordinator} from "../src/mocks/MockVRFCoordinator.sol";
import {ShoeMetadata} from "../src/libraries/ShoeMetadata.sol";

/**
 * @title SecurityTests
 * @dev Comprehensive security test suite per identificare vulnerabilità
 */
contract SecurityTests is Test {
    DemetraShoeNFT public nft;
    DemetraLoyalty public loyalty;
    MockVRFCoordinator public mockVRF;
    
    address public owner = address(0x123);
    address public attacker = address(0x666);
    address public user1 = address(0x456);
    address public user2 = address(0x789);
    
    bytes32 public constant KEY_HASH = 0x79d3d8832d904592c0bf9818b621522c988bb8b0c05cdc3b15aea1b6e8db0c15;
    uint64 public constant SUBSCRIPTION_ID = 1;
    uint256 public constant MINT_PRICE = 0.05 ether;
    
    // Events per tracking attacks
    event AttackAttempted(string attackType, bool successful);
    
    function setUp() public {
        vm.startPrank(owner);
        
        mockVRF = new MockVRFCoordinator();
        nft = new DemetraShoeNFT(address(mockVRF), KEY_HASH, SUBSCRIPTION_ID);
        loyalty = new DemetraLoyalty(address(nft));
        nft.setLoyaltyContract(address(loyalty));
        
        vm.stopPrank();
        
        // Fund test accounts
        vm.deal(attacker, 100 ether);
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
    }
    
    // ==================== REENTRANCY ATTACKS ====================
    
    function testReentrancyOnMint() public {
        vm.startPrank(attacker);
        
        // Deploy malicious contract
        ReentrancyAttacker attackContract = new ReentrancyAttacker(address(nft), MINT_PRICE);
        vm.deal(address(attackContract), 1 ether);
        
        // Attempt reentrancy attack
        vm.expectRevert(); // Should fail due to ReentrancyGuard
        attackContract.attack();
        
        // Verify no extra NFTs were minted
        assertEq(nft.balanceOf(address(attackContract)), 0);
        
        vm.stopPrank();
    }
    
    function testReentrancyOnRefund() public {
        vm.startPrank(attacker);
        
        RefundAttacker attackContract = new RefundAttacker(address(nft));
        vm.deal(address(attackContract), 1 ether);
        
        // Try to exploit refund mechanism
        vm.expectRevert(); // Should fail
        attackContract.attack();
        
        vm.stopPrank();
    }
    
    // ==================== ACCESS CONTROL ATTACKS ====================
    
    function testUnauthorizedOwnerFunctions() public {
        vm.startPrank(attacker);
        
        // Try to change mint price
        vm.expectRevert();
        nft.setMintPrice(0.1 ether);
        
        // Try to pause contract
        vm.expectRevert();
        nft.pause();
        
        // Try to withdraw funds
        vm.expectRevert();
        nft.withdraw();
        
        // Try to mint as owner
        vm.expectRevert();
        nft.ownerMint(attacker, 1, ShoeMetadata.RarityLevel.LEGENDARY);
        
        vm.stopPrank();
    }
    
    function testLoyaltyAccessControl() public {
        vm.startPrank(attacker);
        
        // Try to manipulate loyalty points directly
        vm.expectRevert("Only NFT contract");
        loyalty.addLoyaltyPoints(attacker, 1000);
        
        // Try to change discount rates
        vm.expectRevert();
        loyalty.setRarityDiscount(ShoeMetadata.RarityLevel.COMMON, 50);
        
        vm.stopPrank();
    }
    
    // ==================== VRF MANIPULATION ATTACKS ====================
    
    function testDirectVRFCallback() public {
        vm.startPrank(attacker);
        
        // Try to call VRF callback directly
        uint256[] memory fakeRandomWords = new uint256[](2);
        fakeRandomWords[0] = 97; // Try to force LEGENDARY
        fakeRandomWords[1] = 5;  // Try to force lottery win
        
        vm.expectRevert();
        // This should fail - only VRF coordinator can call
        nft.rawFulfillRandomWords(1, fakeRandomWords);
        
        vm.stopPrank();
    }
    
    function testVRFRequestManipulation() public {
        vm.startPrank(user1);
        
        // Legitimate mint
        nft.mint{value: MINT_PRICE}(1);
        uint256 requestId = 1;
        
        vm.stopPrank();
        vm.startPrank(attacker);
        
        // Try to hijack VRF request
        vm.expectRevert();
        mockVRF.fulfillWithRarity(requestId, "legendary");
        
        vm.stopPrank();
    }
    
    function testDoubleVRFFulfillment() public {
        vm.startPrank(user1);
        nft.mint{value: MINT_PRICE}(1);
        vm.stopPrank();
        
        // First fulfillment
        mockVRF.fulfillWithRarity(1, "rare");
        
        // Try second fulfillment - should fail
        vm.expectRevert("Request already fulfilled");
        mockVRF.fulfillWithRarity(1, "legendary");
    }
    
    // ==================== ECONOMIC ATTACKS ====================
    
    function testOverflowAttacks() public {
        vm.startPrank(attacker);
        
        // Try to overflow mint price
        vm.expectRevert();
        nft.mint{value: type(uint256).max}(1);
        
        // Try to mint impossible quantity
        vm.expectRevert("Invalid quantity");
        nft.mint{value: MINT_PRICE * type(uint256).max}(type(uint256).max);
        
        vm.stopPrank();
    }
    
    function testPriceManipulation() public {
        vm.startPrank(user1);
        
        // Legitimate mint
        nft.mint{value: MINT_PRICE}(1);
        
        vm.stopPrank();
        vm.startPrank(owner);
        
        // Owner changes price
        nft.setMintPrice(0.1 ether);
        
        vm.stopPrank();
        vm.startPrank(attacker);
        
        // Should pay new price, not old
        vm.expectRevert("Insufficient payment");
        nft.mint{value: MINT_PRICE}(1); // Old price
        
        // Correct payment should work
        nft.mint{value: 0.1 ether}(1);
        
        vm.stopPrank();
    }
    
    function testRefundExploitation() public {
        uint256 attackerBalanceBefore = attacker.balance;
        
        vm.startPrank(attacker);
        
        // Try to get free money through overpayment
        nft.mint{value: 1 ether}(1); // Massive overpayment
        
        uint256 attackerBalanceAfter = attacker.balance;
        
        // Should only pay mint price, rest refunded
        assertEq(attackerBalanceBefore - attackerBalanceAfter, MINT_PRICE);
        
        vm.stopPrank();
    }
    
    function testMaxSupplyBoundary() public {
        vm.startPrank(owner);
        
        // Mint to near max supply
        nft.ownerMint(user1, 9999, ShoeMetadata.RarityLevel.COMMON);
        
        vm.stopPrank();
        vm.startPrank(user2);
        
        // Last mint should work
        nft.mint{value: MINT_PRICE}(1);
        assertEq(nft.totalSupply(), 10000);
        
        vm.stopPrank();
        vm.startPrank(attacker);
        
        // Should fail - max supply reached
        vm.expectRevert("Max supply exceeded");
        nft.mint{value: MINT_PRICE}(1);
        
        vm.stopPrank();
    }
    
    // ==================== LOYALTY SYSTEM ATTACKS ====================
    
    function testLoyaltyPointManipulation() public {
        vm.startPrank(user1);
        
        // Mint and get points
        nft.mint{value: MINT_PRICE}(1);
        mockVRF.fulfillWithRarity(1, "legendary");
        
        uint256 legitPoints = loyalty.getLoyaltyPoints(user1);
        
        vm.stopPrank();
        vm.startPrank(attacker);
        
        // Try to steal or manipulate points
        vm.expectRevert("Only NFT contract");
        loyalty.addLoyaltyPoints(attacker, legitPoints);
        
        // Verify attacker has no points
        assertEq(loyalty.getLoyaltyPoints(attacker), 0);
        
        vm.stopPrank();
    }
    
    function testDiscountExploitation() public {
        vm.startPrank(user1);
        
        // Mint LEGENDARY NFT
        nft.mint{value: MINT_PRICE}(1);
        mockVRF.fulfillWithRarity(1, "legendary");
        
        uint256 discount = loyalty.getUserDiscount(user1);
        assertEq(discount, 35); // LEGENDARY = 35%
        
        // Mint multiple to test cap
        nft.mint{value: MINT_PRICE * 2}(2);
        mockVRF.fulfillWithRarity(2, "legendary");
        mockVRF.fulfillWithRarity(3, "legendary");
        
        // Should cap at 50%
        uint256 cappedDiscount = loyalty.getUserDiscount(user1);
        assertEq(cappedDiscount, 50);
        
        vm.stopPrank();
    }
    
    // ==================== FRONT-RUNNING / MEV ATTACKS ====================
    
    function testFrontRunningPrevention() public {
        vm.startPrank(user1);
        
        // User1 mints
        nft.mint{value: MINT_PRICE}(1);
        uint256 requestId1 = 1;
        
        vm.stopPrank();
        vm.startPrank(attacker);
        
        // Attacker tries to mint immediately after seeing user1's tx
        nft.mint{value: MINT_PRICE}(1);
        uint256 requestId2 = 2;
        
        vm.stopPrank();
        
        // Fulfill VRF requests
        mockVRF.fulfillWithRarity(requestId1, "legendary");
        mockVRF.fulfillWithRarity(requestId2, "common");
        
        // Verify each gets their own result
        assertEq(uint256(nft.getTokenMetadata(1).rarity), uint256(ShoeMetadata.RarityLevel.LEGENDARY));
        assertEq(uint256(nft.getTokenMetadata(2).rarity), uint256(ShoeMetadata.RarityLevel.COMMON));
    }
    
    // ==================== EMERGENCY SCENARIOS ====================
    
    function testPauseEmergency() public {
        vm.startPrank(owner);
        
        // Pause contract
        nft.pause();
        
        vm.stopPrank();
        vm.startPrank(user1);
        
        // Should fail when paused
        vm.expectRevert();
        nft.mint{value: MINT_PRICE}(1);
        
        vm.stopPrank();
        vm.startPrank(owner);
        
        // Owner can still do admin functions
        nft.setMintPrice(0.1 ether);
        
        // Unpause
        nft.unpause();
        
        vm.stopPrank();
        vm.startPrank(user1);
        
        // Should work again
        nft.mint{value: 0.1 ether}(1);
        
        vm.stopPrank();
    }
    
    function testWithdrawSecurity() public {
        // Generate some revenue
        vm.startPrank(user1);
        nft.mint{value: MINT_PRICE * 3}(3);
        vm.stopPrank();
        
        uint256 contractBalance = address(nft).balance;
        uint256 ownerBalanceBefore = owner.balance;
        
        vm.startPrank(attacker);
        
        // Attacker can't withdraw
        vm.expectRevert();
        nft.withdraw();
        
        vm.stopPrank();
        vm.startPrank(owner);
        
        // Owner can withdraw
        nft.withdraw();
        
        // Verify transfer
        assertEq(address(nft).balance, 0);
        assertEq(owner.balance, ownerBalanceBefore + contractBalance);
        
        vm.stopPrank();
    }
    
    // ==================== STRESS TESTS ====================
    
    function testMassiveMintStress() public {
        vm.startPrank(user1);
        
        // Max mint per wallet
        nft.mint{value: MINT_PRICE * 5}(5);
        
        // Should fail on 6th
        vm.expectRevert("Wallet limit exceeded");
        nft.mint{value: MINT_PRICE}(1);
        
        vm.stopPrank();
    }
    
    function testGasExhaustionAttack() public {
        vm.startPrank(attacker);
        
        // Try to mint with minimal gas (should fail gracefully)
        vm.expectRevert();
        nft.mint{gas: 50000, value: MINT_PRICE}(1);
        
        vm.stopPrank();
    }
    
    // ==================== DATA INTEGRITY TESTS ====================
    
    function testMetadataConsistency() public {
        vm.startPrank(user1);
        
        nft.mint{value: MINT_PRICE}(1);
        mockVRF.fulfillWithRarity(1, "epic");
        
        ShoeMetadata.ShoeData memory metadata = nft.getTokenMetadata(1);
        
        // Verify data consistency
        assertEq(uint256(metadata.rarity), uint256(ShoeMetadata.RarityLevel.EPIC));
        assertGt(metadata.rarityScore, 0);
        assertGt(metadata.creationTimestamp, 0);
        assertTrue(bytes(metadata.shoeName).length > 0);
        assertTrue(bytes(metadata.materialOrigin).length > 0);
        
        vm.stopPrank();
    }
    
    function testTokenURIConsistency() public {
        vm.startPrank(user1);
        
        nft.mint{value: MINT_PRICE}(1);
        
        string memory uri = nft.tokenURI(1);
        assertTrue(bytes(uri).length > 0);
        
        // Should fail for non-existent token
        vm.expectRevert("Token not found");
        nft.tokenURI(999);
        
        vm.stopPrank();
    }
}

// ==================== ATTACK CONTRACTS ====================

contract ReentrancyAttacker {
    DemetraShoeNFT public target;
    uint256 public mintPrice;
    uint256 public attackCount;
    
    constructor(address _target, uint256 _mintPrice) {
        target = DemetraShoeNFT(_target);
        mintPrice = _mintPrice;
    }
    
    function attack() external {
        target.mint{value: mintPrice}(1);
    }
    
    receive() external payable {
        if (attackCount < 2 && address(target).balance >= mintPrice) {
            attackCount++;
            target.mint{value: mintPrice}(1);
        }
    }
}

contract RefundAttacker {
    DemetraShoeNFT public target;
    bool public attacking;
    
    constructor(address _target) {
        target = DemetraShoeNFT(_target);
    }
    
    function attack() external {
        attacking = true;
        target.mint{value: 1 ether}(1); // Overpay to trigger refund
    }
    
    receive() external payable {
        if (attacking && address(target).balance > 0) {
            target.mint{value: 0.05 ether}(1);
        }
    }
}