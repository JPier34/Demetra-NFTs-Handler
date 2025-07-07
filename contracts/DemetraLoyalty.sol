// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./libraries/ShoeMetadata.sol";

interface IDemetraShoeNFT {
    function balanceOf(address owner) external view returns (uint256);
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);
    function shoeMetadata(uint256 tokenId) external view returns (ShoeMetadata.ShoeData memory);
}

/**
 * @title DemetraLoyalty - Sistema Fedeltà e Sconti
 * @dev Gestisce punti fedeltà e calcolo sconti per i possessori di NFT Demetra
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
    event RarityDiscountUpdated(ShoeMetadata.RarityLevel rarity, uint256 discount);
    event MaxDiscountUpdated(uint256 newMaxDiscount);
    
    // ============ CONSTRUCTOR ============
    
    constructor(address _nftContract) Ownable(msg.sender) {
        nftContract = IDemetraShoeNFT(_nftContract);
        
        // Initialize rarity discounts
        rarityDiscounts[ShoeMetadata.RarityLevel.COMMON] = 5;     // 5% discount
        rarityDiscounts[ShoeMetadata.RarityLevel.RARE] = 10;      // 10% discount
        rarityDiscounts[ShoeMetadata.RarityLevel.EPIC] = 20;      // 20% discount
        rarityDiscounts[ShoeMetadata.RarityLevel.LEGENDARY] = 35; // 35% discount
    }
    
    // ============ LOYALTY FUNCTIONS ============
    
    /**
     * @dev Aggiunge punti fedeltà (solo NFT contract)
     */
    function addLoyaltyPoints(address user, uint256 points) external {
        require(msg.sender == address(nftContract), "Only NFT contract");
        loyaltyPoints[user] += points;
        emit LoyaltyPointsUpdated(user, loyaltyPoints[user]);
    }
    
    /**
     * @dev Calcola sconto totale per un utente basato sui suoi NFT
     */
    function getUserDiscount(address user) external view returns (uint256) {
        uint256 userBalance = nftContract.balanceOf(user);
        if (userBalance == 0) return 0;
        
        uint256 totalDiscount = 0;
        
        for (uint256 i = 0; i < userBalance; i++) {
            uint256 tokenId = nftContract.tokenOfOwnerByIndex(user, i);
            ShoeMetadata.ShoeData memory metadata = nftContract.shoeMetadata(tokenId);
            totalDiscount += rarityDiscounts[metadata.rarity];
            
            // Cap at max discount
            if (totalDiscount >= maxDiscount) {
                return maxDiscount;
            }
        }
        
        return totalDiscount;
    }
    
    /**
     * @dev Ottieni punti fedeltà di un utente
     */
    function getLoyaltyPoints(address user) external view returns (uint256) {
        return loyaltyPoints[user];
    }
    
    /**
     * @dev Calcola sconto basato su rarità specifica
     */
    function getDiscountByRarity(ShoeMetadata.RarityLevel rarity) external view returns (uint256) {
        return rarityDiscounts[rarity];
    }
    
    /**
     * @dev Verifica se utente è vincitore lottery
     */
    function isLotteryWinner(address user) external view returns (bool hasWinningNFT, uint256[] memory winningTokens) {
        uint256 userBalance = nftContract.balanceOf(user);
        if (userBalance == 0) return (false, new uint256[](0));
        
        uint256[] memory tempWinning = new uint256[](userBalance);
        uint256 winningCount = 0;
        
        for (uint256 i = 0; i < userBalance; i++) {
            uint256 tokenId = nftContract.tokenOfOwnerByIndex(user, i);
            ShoeMetadata.ShoeData memory metadata = nftContract.shoeMetadata(tokenId);
            
            if (metadata.isLotteryWinner) {
                tempWinning[winningCount] = tokenId;
                winningCount++;
            }
        }
        
        // Create properly sized array
        winningTokens = new uint256[](winningCount);
        for (uint256 i = 0; i < winningCount; i++) {
            winningTokens[i] = tempWinning[i];
        }
        
        hasWinningNFT = winningCount > 0;
    }
    
    /**
     * @dev Ottieni statistiche utente complete
     */
    function getUserStats(address user) external view returns (
        uint256 totalNFTs,
        uint256 totalLoyaltyPoints,
        uint256 totalDiscount,
        bool hasLotteryWin,
        uint256[] memory rarityBreakdown // [common, rare, epic, legendary]
    ) {
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
            ShoeMetadata.ShoeData memory metadata = nftContract.shoeMetadata(tokenId);
            
            // Count rarities
            rarityBreakdown[uint256(metadata.rarity)]++;
            
            // Calculate discount
            discount += rarityDiscounts[metadata.rarity];
            
            // Check lottery
            if (metadata.isLotteryWinner) {
                hasLotteryWin = true;
            }
        }
        
        totalDiscount = discount > maxDiscount ? maxDiscount : discount;
    }
    
    /**
     * @dev Ottieni tutti i token di un proprietario con metadati
     */
    function getOwnerTokensWithMetadata(address owner) 
        external 
        view 
        returns (uint256[] memory tokenIds, ShoeMetadata.ShoeData[] memory metadata) 
    {
        uint256 balance = nftContract.balanceOf(owner);
        tokenIds = new uint256[](balance);
        metadata = new ShoeMetadata.ShoeData[](balance);
        
        for (uint256 i = 0; i < balance; i++) {
            tokenIds[i] = nftContract.tokenOfOwnerByIndex(owner, i);
            metadata[i] = nftContract.shoeMetadata(tokenIds[i]);
        }
    }
    
    // ============ ADMIN FUNCTIONS ============
    
    /**
     * @dev Imposta sconto per rarità
     */
    function setRarityDiscount(ShoeMetadata.RarityLevel rarity, uint256 discount) 
        external 
        onlyOwner 
    {
        require(discount <= 50, "Discount too high");
        rarityDiscounts[rarity] = discount;
        emit RarityDiscountUpdated(rarity, discount);
    }
    
    /**
     * @dev Imposta sconto massimo
     */
    function setMaxDiscount(uint256 _maxDiscount) external onlyOwner {
        require(_maxDiscount <= 100, "Max discount too high");
        maxDiscount = _maxDiscount;
        emit MaxDiscountUpdated(_maxDiscount);
    }
    
    /**
     * @dev Aggiorna indirizzo contratto NFT
     */
    function setNFTContract(address _nftContract) external onlyOwner {
        nftContract = IDemetraShoeNFT(_nftContract);
    }
    
    /**
     * @dev Aggiungi punti manualmente (per eventi speciali)
     */
    function addBonusPoints(address user, uint256 points) external onlyOwner {
        loyaltyPoints[user] += points;
        emit LoyaltyPointsUpdated(user, loyaltyPoints[user]);
    }
    
    /**
     * @dev Reset punti utente (solo admin)
     */
    function resetUserPoints(address user) external onlyOwner {
        loyaltyPoints[user] = 0;
        emit LoyaltyPointsUpdated(user, 0);
    }
}