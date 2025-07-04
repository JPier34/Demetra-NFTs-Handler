// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "./libraries/ShoeMetadata.sol";

/**
 * @title DemetraShoeNFT
 * @dev NFT Collection per le calzature sostenibili di Demetra
 * @dev Include sistema di rarità basato su Chainlink VRF e lottery per tour aziendale
 */
contract DemetraShoeNFT is 
    ERC721, 
    ERC721Enumerable, 
    Ownable, 
    ReentrancyGuard, 
    Pausable,
    VRFConsumerBaseV2 
{
    // ============ USING LIBRARIES ============
    
    using ShoeMetadata for ShoeMetadata.RarityLevel;
    
    // ============ STRUCTS ============
    
    // Utilizziamo la struct dalla libreria
    struct ShoeData {
        string shoeName;
        string materialOrigin;
        string craftmanship;
        string designHistory;
        ShoeMetadata.RarityLevel rarity;
        bool isLotteryWinner;
        uint256 creationTimestamp;
        uint256 rarityScore;
    }
    
    struct VRFRequest {
        address requester;
        uint256 tokenId;
        bool fulfilled;
    }
    
    // ============ STATE VARIABLES ============
    
    // Collection Parameters
    uint256 public constant MAX_SUPPLY = 10000;
    uint256 public constant MAX_MINT_PER_WALLET = 5;
    uint256 public mintPrice = 0.05 ether;
    
    // Counters
    uint256 private _tokenIdCounter = 1; // Start from 1
    uint256 public totalLotteryWinners = 0;
    
    // Mappings
    mapping(uint256 => ShoeData) public shoeMetadata;
    mapping(address => uint256) public walletMints;
    mapping(address => uint256) public loyaltyPoints;
    mapping(uint256 => VRFRequest) public vrfRequests;
    
    // Chainlink VRF Variables
    VRFCoordinatorV2Interface private immutable COORDINATOR;
    bytes32 private immutable s_keyHash;
    uint64 private immutable s_subscriptionId;
    uint32 private constant CALLBACK_GAS_LIMIT = 200000;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 2; // [rarityRandom, lotteryRandom]
    
    // Discount percentages per rarity level
    mapping(ShoeMetadata.RarityLevel rarity => uint256) public rarityDiscounts;
    
    // ============ EVENTS ============
    
    event NFTMinted(
        address indexed to, 
        uint256 indexed tokenId, 
        uint256 requestId
    );
    
    event MetadataRevealed(
        uint256 indexed tokenId,
        ShoeMetadata.RarityLevel rarity,
        bool isLotteryWinner,
        uint256 rarityScore
    );
    
    event LotteryWinner(
        uint256 indexed tokenId,
        address indexed winner
    );
    
    event LoyaltyPointsUpdated(
        address indexed user,
        uint256 newPoints
    );
    
    // ============ CONSTRUCTOR ============
    
    constructor(
        address vrfCoordinator,
        bytes32 keyHash,
        uint64 subscriptionId
    ) 
        ERC721("Demetra Sustainable Shoes", "DEMETRA")
        VRFConsumerBaseV2(vrfCoordinator)
    {
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        s_keyHash = keyHash;
        s_subscriptionId = subscriptionId;
        
        // Initialize rarity discounts
        rarityDiscounts[ShoeMetadata.ShoeMetadata.RarityLevel.COMMON] = 5;    // 5% discount
        rarityDiscounts[ShoeMetadata.ShoeMetadata.RarityLevel.RARE] = 10;     // 10% discount
        rarityDiscounts[ShoeMetadata.ShoeMetadata.RarityLevel.EPIC] = 20;     // 20% discount
        rarityDiscounts[ShoeMetadata.ShoeMetadata.RarityLevel.LEGENDARY] = 35; // 35% discount
    }
    
    // ============ MINT FUNCTIONS ============
    
    /**
     * @dev Mint nuovo NFT - richiede VRF per generare rarità
     * @param quantity Numero di NFT da mintare (max 5 per wallet)
     */
    function mint(uint256 quantity) 
        external 
        payable 
        nonReentrant 
        whenNotPaused 
    {
        require(quantity > 0 && quantity <= 5, "Invalid quantity (1-5)");
        require(
            totalSupply() + quantity <= MAX_SUPPLY, 
            "Exceeds max supply"
        );
        require(
            walletMints[msg.sender] + quantity <= MAX_MINT_PER_WALLET,
            "Exceeds wallet mint limit"
        );
        require(
            msg.value >= mintPrice * quantity,
            "Insufficient payment"
        );
        
        // Update wallet mint count
        walletMints[msg.sender] += quantity;
        
        // Mint NFTs and request VRF for each
        for (uint256 i = 0; i < quantity; i++) {
            uint256 tokenId = _tokenIdCounter++;
            _safeMint(msg.sender, tokenId);
            
            // Request VRF for this token
            uint256 requestId = COORDINATOR.requestRandomWords(
                s_keyHash,
                s_subscriptionId,
                REQUEST_CONFIRMATIONS,
                CALLBACK_GAS_LIMIT,
                NUM_WORDS
            );
            
            // Store VRF request
            vrfRequests[requestId] = VRFRequest({
                requester: msg.sender,
                tokenId: tokenId,
                fulfilled: false
            });
            
            emit NFTMinted(msg.sender, tokenId, requestId);
        }
        
        // Refund excess payment
        if (msg.value > mintPrice * quantity) {
            payable(msg.sender).transfer(msg.value - (mintPrice * quantity));
        }
    }
    
    /**
     * @dev Owner mint per eventi speciali (senza VRF, rarità predefinita)
     */
    function ownerMint(
        address to, 
        uint256 quantity,
        ShoeMetadata.RarityLevel rarity
    ) 
        external 
        onlyOwner 
    {
        require(
            totalSupply() + quantity <= MAX_SUPPLY,
            "Exceeds max supply"
        );
        
        for (uint256 i = 0; i < quantity; i++) {
            uint256 tokenId = _tokenIdCounter++;
            _safeMint(to, tokenId);
            
            // Set predetermined metadata
            shoeMetadata[tokenId] = ShoeMetadata({
                shoeName: "Special Edition",
                materialOrigin: "Organic Cotton & Cork",
                craftmanship: "Handcrafted by Master Artisans",
                designHistory: "Limited Edition Design",
                rarity: rarity,
                isLotteryWinner: false,
                creationTimestamp: block.timestamp,
                rarityScore: uint256(rarity) * 25 + 25 // 25, 50, 75, 100
            });
            
            // Add loyalty points
            _updateLoyaltyPoints(to, shoeMetadata[tokenId].rarityScore);
        }
    }
    
    // ============ VRF CALLBACK ============
    
    /**
     * @dev Chainlink VRF callback - genera rarità e lottery status
     */
    function fulfillRandomWords(
        uint256 requestId, 
        uint256[] memory randomWords
    ) internal override {
        VRFRequest storage request = vrfRequests[requestId];
        require(!request.fulfilled, "Request already fulfilled");
        require(request.requester != address(0), "Invalid request");
        
        uint256 tokenId = request.tokenId;
        
        // Generate rarity (0-99)
        uint256 rarityRoll = randomWords[0] % 100;
        ShoeMetadata.RarityLevel rarity = _calculateRarity(rarityRoll);
        
        // Generate lottery status (1% chance)
        uint256 lotteryRoll = randomWords[1] % 1000;
        bool isLotteryWinner = lotteryRoll < 10; // 1% chance
        
        if (isLotteryWinner) {
            totalLotteryWinners++;
            emit LotteryWinner(tokenId, request.requester);
        }
        
        // Calculate rarity score for loyalty points
        uint256 rarityScore = _calculateRarityScore(rarity, rarityRoll);
        
        // Set metadata
        shoeMetadata[tokenId] = ShoeMetadata({
            shoeName: _generateShoeName(rarity),
            materialOrigin: _generateMaterialOrigin(rarity),
            craftmanship: _generateCraftmanship(rarity),
            designHistory: _generateDesignHistory(rarity),
            rarity: rarity,
            isLotteryWinner: isLotteryWinner,
            creationTimestamp: block.timestamp,
            rarityScore: rarityScore
        });
        
        // Update loyalty points
        _updateLoyaltyPoints(request.requester, rarityScore);
        
        // Mark request as fulfilled
        request.fulfilled = true;
        
        emit MetadataRevealed(tokenId, rarity, isLotteryWinner, rarityScore);
    }
    
    // ============ LOYALTY & DISCOUNT SYSTEM ============
    
    /**
     * @dev Calcola sconto totale per un utente basato sui suoi NFT
     */
    function getUserDiscount(address user) external view returns (uint256) {
        uint256 userBalance = balanceOf(user);
        if (userBalance == 0) return 0;
        
        uint256 totalDiscount = 0;
        uint256 maxDiscount = 50; // 50% max discount
        
        for (uint256 i = 0; i < userBalance; i++) {
            uint256 tokenId = tokenOfOwnerByIndex(user, i);
            ShoeMetadata.RarityLevel rarity = shoeMetadata[tokenId].rarity;
            totalDiscount += rarityDiscounts[rarity];
            
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
    
    // ============ VIEW FUNCTIONS ============
    
    /**
     * @dev Ottieni metadati completi di un token
     */
    function getTokenMetadata(uint256 tokenId) 
        external 
        view 
        returns (ShoeMetadata memory) 
    {
        require(_exists(tokenId), "Token does not exist");
        return shoeMetadata[tokenId];
    }
    
    /**
     * @dev Ottieni tutti i token di un proprietario con metadati
     */
    function getOwnerTokensWithMetadata(address owner) 
        external 
        view 
        returns (uint256[] memory tokenIds, ShoeMetadata[] memory metadata) 
    {
        uint256 balance = balanceOf(owner);
        tokenIds = new uint256[](balance);
        metadata = new ShoeMetadata[](balance);
        
        for (uint256 i = 0; i < balance; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(owner, i);
            metadata[i] = shoeMetadata[tokenIds[i]];
        }
    }
    
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
        ) 
    {
        totalMinted = totalSupply();
        remainingSupply = MAX_SUPPLY - totalMinted;
        lotteryWinners = totalLotteryWinners;
        currentPrice = mintPrice;
    }
    
    // ============ INTERNAL HELPER FUNCTIONS ============
    
    function _calculateRarity(uint256 roll) private pure returns (ShoeMetadata.RarityLevel rarity) {
        if (roll < 61) return ShoeMetadata.RarityLevel.COMMON;     // 0-60 (61%)
        if (roll < 86) return ShoeMetadata.RarityLevel.RARE;       // 61-85 (25%)
        if (roll < 96) return ShoeMetadata.RarityLevel.EPIC;       // 86-95 (10%)
        return ShoeMetadata.RarityLevel.LEGENDARY;                 // 96-99 (4%)
    }
    
    function _calculateRarityScore(
        ShoeMetadata.RarityLevel rarity, 
        uint256 roll
    ) private pure returns (uint256) {
        uint256 baseScore = uint256(rarity) * 25 + 25; // 25, 50, 75, 100
        uint256 variance = roll % 10; // 0-9 variance
        return baseScore + variance;
    }
    
    function _updateLoyaltyPoints(address user, uint256 points) private {
        loyaltyPoints[user] += points;
        emit LoyaltyPointsUpdated(user, loyaltyPoints[user]);
    }
    
    // ============ METADATA GENERATION ============
    
    function _generateShoeName(ShoeMetadata.RarityLevel rarity) 
        private 
        pure 
        returns (string memory) 
    {
        if (rarity == ShoeMetadata.RarityLevel.LEGENDARY) return "Aurora Sustainability";
        if (rarity == ShoeMetadata.RarityLevel.EPIC) return "EcoLux Premium";
        if (rarity == ShoeMetadata.RarityLevel.RARE) return "GreenStep Pro";
        return "EcoWalk Classic";
    }
    
    function _generateMaterialOrigin(ShoeMetadata.RarityLevel rarity) 
        private 
        pure 
        returns (string memory) 
    {
        if (rarity == ShoeMetadata.RarityLevel.LEGENDARY) return "Organic Bamboo Fiber from Japan";
        if (rarity == ShoeMetadata.RarityLevel.EPIC) return "Cork from Portuguese Forests";
        if (rarity == ShoeMetadata.RarityLevel.RARE) return "Organic Cotton from Italy";
        return "Recycled Materials from Europe";
    }
    
    function _generateCraftmanship(ShoeMetadata.RarityLevel rarity) 
        private 
        pure 
        returns (string memory) 
    {
        if (rarity == ShoeMetadata.RarityLevel.LEGENDARY) return "Hand-stitched by Master Artisan";
        if (rarity == ShoeMetadata.RarityLevel.EPIC) return "Premium Artisanal Crafting";
        if (rarity == ShoeMetadata.RarityLevel.RARE) return "Semi-Artisanal Production";
        return "Sustainable Manufacturing Process";
    }
    
    function _generateDesignHistory(ShoeMetadata.RarityLevel rarity) 
        private 
        pure 
        returns (string memory) 
    {
        if (rarity == ShoeMetadata.RarityLevel.LEGENDARY) return "Inspired by ancient Italian traditions";
        if (rarity == ShoeMetadata.RarityLevel.EPIC) return "Modern minimalist design philosophy";
        if (rarity == ShoeMetadata.RarityLevel.RARE) return "Classic elegance meets sustainability";
        return "Timeless design for conscious consumers";
    }
    
    // ============ ADMIN FUNCTIONS ============
    
    function setMintPrice(uint256 newPrice) external onlyOwner {
        mintPrice = newPrice;
    }
    
    function setRarityDiscount(ShoeMetadata.RarityLevel rarity, uint256 discount) 
        external 
        onlyOwner 
    {
        require(discount <= 50, "Discount too high");
        rarityDiscounts[rarity] = discount;
    }
    
    function pause() external onlyOwner {
        _pause();
    }
    
    function unpause() external onlyOwner {
        _unpause();
    }
    
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        payable(owner()).transfer(balance);
    }
    
    // ============ REQUIRED OVERRIDES ============
    
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override(ERC721, ERC721Enumerable) whenNotPaused {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }
    
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
    
    function tokenURI(uint256 tokenId) 
        public 
        view 
        override 
        returns (string memory) 
    {
        require(_exists(tokenId), "Token does not exist");
        
        // In produzione, questo punterebbe a un server IPFS
        // Per ora restituiamo metadati on-chain
        ShoeMetadata memory metadata = shoeMetadata[tokenId];
        
        return string(abi.encodePacked(
            "https://api.demetra.com/metadata/",
            Strings.toString(tokenId)
        ));
    }
}