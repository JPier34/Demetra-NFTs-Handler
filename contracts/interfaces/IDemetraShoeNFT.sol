// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IDemetraShoeNFT
 * @dev Interfaccia pubblica per il contratto DemetraShoeNFT
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
    
    event NFTMinted(address indexed to, uint256 indexed tokenId, uint256 requestId);
    event MetadataRevealed(uint256 indexed tokenId, RarityLevel rarity, bool isLotteryWinner, uint256 rarityScore);
    event LotteryWinner(uint256 indexed tokenId, address indexed winner);
    event LoyaltyPointsUpdated(address indexed user, uint256 newPoints);
    
    // ============ MINT FUNCTIONS ============
    
    /**
     * @dev Mint NFT pubblico
     */
    function mint(uint256 quantity) external payable;
    
    /**
     * @dev Mint riservato al proprietario
     */
    function ownerMint(address to, uint256 quantity, RarityLevel rarity) external;
    
    // ============ VIEW FUNCTIONS ============
    
    /**
     * @dev Ottieni metadati token
     */
    function getTokenMetadata(uint256 tokenId) external view returns (ShoeData memory);
    
    /**
     * @dev Ottieni sconto utente
     */
    function getUserDiscount(address user) external view returns (uint256);
    
    /**
     * @dev Ottieni punti fedeltà
     */
    function getLoyaltyPoints(address user) external view returns (uint256);
    
    /**
     * @dev Ottieni token e metadati del proprietario
     */
    function getOwnerTokensWithMetadata(address owner) 
        external 
        view 
        returns (uint256[] memory tokenIds, ShoeData[] memory metadata);
    
    /**
     * @dev Statistiche collezione
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