// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IDemetraShoeNFT
 * @dev Public interface for DemetraShoeNFT contract
 */
interface IDemetraShoeNFT {
    // ============ ENUMS & STRUCTS ============

    enum RarityLevel {
        COMMON,
        RARE,
        EPIC,
        LEGENDARY
    }

    struct ShoeData {
        string shoeName;
        string materialOrigin;
        string craftmanship;
        string designHistory;
        RarityLevel rarity;
        bool isLotteryWinner;
        uint256 creationTimestamp;
        uint256 rarityScore;
    }

    // ============ EVENTS ============

    event NFTMinted(
        address indexed to,
        uint256 indexed tokenId,
        uint256 requestId
    );
    event MetadataRevealed(
        uint256 indexed tokenId,
        RarityLevel rarity,
        bool isLotteryWinner,
        uint256 rarityScore
    );
    event LotteryWinner(uint256 indexed tokenId, address indexed winner);
    event LoyaltyPointsUpdated(address indexed user, uint256 newPoints);

    // ============ MINT FUNCTIONS ============

    /**
     * @dev Mint public NFT
     */
    function mint(uint256 quantity) external payable;

    /**
     * @dev Mint (only for the owner)
     */
    function ownerMint(
        address to,
        uint256 quantity,
        RarityLevel rarity
    ) external;

    // ============ VIEW FUNCTIONS ============

    /**
     * @dev Get token metadata
     */
    function getTokenMetadata(
        uint256 tokenId
    ) external view returns (ShoeData memory);

    /**
     * @dev Get user discount
     */
    function getUserDiscount(address user) external view returns (uint256);

    /**
     * @dev Get fidelity points
     */
    function getLoyaltyPoints(address user) external view returns (uint256);

    /**
     * @dev Get token and metadata from owner
     */
    function getOwnerTokensWithMetadata(
        address owner
    )
        external
        view
        returns (uint256[] memory tokenIds, ShoeData[] memory metadata);

    /**
     * @dev Collection stats
     */
    function getCollectionStats()
        external
        view
        returns (
            uint256 totalMinted,
            uint256 remainingSupply,
            uint256 lotteryWinners,
            uint256 currentPrice
        );

    // ============ ADMIN FUNCTIONS ============

    function setMintPrice(uint256 newPrice) external;

    function setRarityDiscount(RarityLevel rarity, uint256 discount) external;

    function pause() external;

    function unpause() external;

    function withdraw() external;
}
