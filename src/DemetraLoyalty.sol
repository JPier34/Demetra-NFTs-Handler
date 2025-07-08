// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./libraries/ShoeMetadata.sol";

interface IDemetraShoeNFT {
    function balanceOf(address owner) external view returns (uint256);

    function tokenOfOwnerByIndex(
        address owner,
        uint256 index
    ) external view returns (uint256);

    function getTokenMetadata(
        uint256 tokenId
    ) external view returns (ShoeMetadata.ShoeData memory);
}

/**
 * @title DemetraLoyalty - Fidelity and discounts system
 * @dev Handles fidelity points and discounts for NFT Demetra tokens owners
 */
contract DemetraLoyalty is Ownable {
    // ============ STATE VARIABLES ============

    IDemetraShoeNFT public nftContract;

    // Mappings
    mapping(address => uint256) public loyaltyPoints;
    mapping(ShoeMetadata.RarityLevel => uint256) public rarityDiscounts;

    // Settings
    uint256 public maxDiscount = 50; // 50% max discount

    // ============ EVENTS ============

    event LoyaltyPointsUpdated(address indexed user, uint256 newPoints);
    event RarityDiscountUpdated(
        ShoeMetadata.RarityLevel rarity,
        uint256 discount
    );
    event MaxDiscountUpdated(uint256 newMaxDiscount);

    // ============ CONSTRUCTOR ============

    constructor(address _nftContract) Ownable(msg.sender) {
        nftContract = IDemetraShoeNFT(_nftContract);

        // Initialize rarity discounts
        rarityDiscounts[ShoeMetadata.RarityLevel.COMMON] = 5; // 5% discount
        rarityDiscounts[ShoeMetadata.RarityLevel.RARE] = 10; // 10% discount
        rarityDiscounts[ShoeMetadata.RarityLevel.EPIC] = 20; // 20% discount
        rarityDiscounts[ShoeMetadata.RarityLevel.LEGENDARY] = 35; // 35% discount
    }

    // ============ LOYALTY FUNCTIONS ============

    /**
     * @dev Adds fidelity points (NFT contract only)
     */
    function addLoyaltyPoints(address user, uint256 points) external {
        require(msg.sender == address(nftContract), "Only NFT contract");
        loyaltyPoints[user] += points;
        emit LoyaltyPointsUpdated(user, loyaltyPoints[user]);
    }

    /**
     * @dev Calculate total discount for a user based on his NFTs
     */
    function getUserDiscount(address user) external view returns (uint256) {
        uint256 userBalance = nftContract.balanceOf(user);
        if (userBalance == 0) return 0;

        uint256 totalDiscount = 0;

        for (uint256 i = 0; i < userBalance; i++) {
            uint256 tokenId = nftContract.tokenOfOwnerByIndex(user, i);
            ShoeMetadata.ShoeData memory metadata = nftContract
                .getTokenMetadata(tokenId);
            totalDiscount += rarityDiscounts[metadata.rarity];

            // Cap at max discount
            if (totalDiscount >= maxDiscount) {
                return maxDiscount;
            }
        }

        return totalDiscount;
    }

    /**
     * @dev Get fidelity points for a user
     */
    function getLoyaltyPoints(address user) external view returns (uint256) {
        return loyaltyPoints[user];
    }

    /**
     * @dev Get discount based on a specific rarity
     */
    function getDiscountByRarity(
        ShoeMetadata.RarityLevel rarity
    ) external view returns (uint256) {
        return rarityDiscounts[rarity];
    }

    /**
     * @dev Verify if a user won
     */
    function isLotteryWinner(
        address user
    )
        external
        view
        returns (bool hasWinningNFT, uint256[] memory winningTokens)
    {
        uint256 userBalance = nftContract.balanceOf(user);
        if (userBalance == 0) return (false, new uint256[](0));

        uint256[] memory tempWinning = new uint256[](userBalance);
        uint256 winningCount = 0;

        for (uint256 i = 0; i < userBalance; i++) {
            uint256 tokenId = nftContract.tokenOfOwnerByIndex(user, i);
            ShoeMetadata.ShoeData memory metadata = nftContract
                .getTokenMetadata(tokenId);

            if (metadata.isLotteryWinner) {
                tempWinning[winningCount] = tokenId;
                winningCount++;
            }
        }

        // Creates properly sized array
        winningTokens = new uint256[](winningCount);
        for (uint256 i = 0; i < winningCount; i++) {
            winningTokens[i] = tempWinning[i];
        }

        hasWinningNFT = winningCount > 0;
    }

    /**
     * @dev Gets complete user stats
     */
    function getUserStats(
        address user
    )
        external
        view
        returns (
            uint256 totalNFTs,
            uint256 totalLoyaltyPoints,
            uint256 totalDiscount,
            bool hasLotteryWin,
            uint256[] memory rarityBreakdown // [common, rare, epic, legendary]
        )
    {
        uint256 userBalance = nftContract.balanceOf(user);
        totalNFTs = userBalance;
        totalLoyaltyPoints = loyaltyPoints[user];

        if (userBalance == 0) {
            return (0, totalLoyaltyPoints, 0, false, new uint256[](4));
        }

        rarityBreakdown = new uint256[](4);
        uint256 discount = 0;

        for (uint256 i = 0; i < userBalance; i++) {
            uint256 tokenId = nftContract.tokenOfOwnerByIndex(user, i);
            ShoeMetadata.ShoeData memory metadata = nftContract
                .getTokenMetadata(tokenId);

            // Counts rarities
            rarityBreakdown[uint256(metadata.rarity)]++;

            // Calculates discount
            discount += rarityDiscounts[metadata.rarity];

            // Checks lottery
            if (metadata.isLotteryWinner) {
                hasLotteryWin = true;
            }
        }

        totalDiscount = discount > maxDiscount ? maxDiscount : discount;
    }

    /**
     * @dev Get every owner's tokens with metadata
     */
    function getOwnerTokensWithMetadata(
        address owner
    )
        external
        view
        returns (
            uint256[] memory tokenIds,
            ShoeMetadata.ShoeData[] memory metadata
        )
    {
        uint256 balance = nftContract.balanceOf(owner);
        tokenIds = new uint256[](balance);
        metadata = new ShoeMetadata.ShoeData[](balance);

        for (uint256 i = 0; i < balance; i++) {
            tokenIds[i] = nftContract.tokenOfOwnerByIndex(owner, i);
            metadata[i] = nftContract.getTokenMetadata(tokenIds[i]);
        }
    }

    // ============ ADMIN FUNCTIONS ============

    /**
     * @dev Set discount percentage for specific rarity level
     */
    function setRarityDiscount(
        ShoeMetadata.RarityLevel rarity,
        uint256 discount
    ) external onlyOwner {
        require(discount <= 50, "Discount too high");
        rarityDiscounts[rarity] = discount;
        emit RarityDiscountUpdated(rarity, discount);
    }

    /**
     * @dev Set maximum discount cap
     */
    function setMaxDiscount(uint256 _maxDiscount) external onlyOwner {
        require(_maxDiscount <= 100, "Max discount too high");
        maxDiscount = _maxDiscount;
        emit MaxDiscountUpdated(_maxDiscount);
    }

    /**
     * @dev Update NFT contract address
     */
    function setNFTContract(address _nftContract) external onlyOwner {
        nftContract = IDemetraShoeNFT(_nftContract);
    }

    /**
     * @dev Add bonus points manually (for special events)
     */
    function addBonusPoints(address user, uint256 points) external onlyOwner {
        loyaltyPoints[user] += points;
        emit LoyaltyPointsUpdated(user, loyaltyPoints[user]);
    }

    /**
     * @dev Reset user points (admin only)
     */
    function resetUserPoints(address user) external onlyOwner {
        loyaltyPoints[user] = 0;
        emit LoyaltyPointsUpdated(user, 0);
    }
}
