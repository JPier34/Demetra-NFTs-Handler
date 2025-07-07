// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "./libraries/ShoeMetadata.sol";
import "./DemetraLoyalty.sol";

/**
 * @title DemetraShoeNFT - Core NFT Contract
 */
contract DemetraShoeNFT is 
    ERC721, 
    ERC721Enumerable, 
    Ownable, 
    ReentrancyGuard, 
    Pausable,
    VRFConsumerBaseV2 
{
    // ============ STRUCTS ============
    
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
    uint256 private _tokenIdCounter = 1;
    uint256 public totalLotteryWinners = 0;
    
    // Mappings
    mapping(uint256 => ShoeMetadata.ShoeData) public shoeMetadata;
    mapping(address => uint256) public walletMints;
    mapping(uint256 => VRFRequest) public vrfRequests;
    
    // Chainlink VRF Variables
    VRFCoordinatorV2Interface private immutable COORDINATOR;
    bytes32 private immutable s_keyHash;
    uint64 private immutable s_subscriptionId;
    uint32 private constant CALLBACK_GAS_LIMIT = 200000;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 2;
    
    // External Contracts
    DemetraLoyalty public loyaltyContract;
    
    // ============ EVENTS ============
    
    event NFTMinted(address indexed to, uint256 indexed tokenId, uint256 requestId);
    event MetadataRevealed(uint256 indexed tokenId, ShoeMetadata.RarityLevel rarity, bool isLotteryWinner, uint256 rarityScore);
    event LotteryWinner(uint256 indexed tokenId, address indexed winner);
    
    // ============ CONSTRUCTOR ============
    
    constructor(
        address vrfCoordinator,
        bytes32 keyHash,
        uint64 subscriptionId
    ) 
        ERC721("Demetra Sustainable Shoes", "DEMETRA")
        Ownable(msg.sender)
        VRFConsumerBaseV2(vrfCoordinator)
    {
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        s_keyHash = keyHash;
        s_subscriptionId = subscriptionId;
    }
    
    // ============ MINT FUNCTIONS ============
    
    function mint(uint256 quantity) 
        external 
        payable 
        nonReentrant 
        whenNotPaused 
    {
        require(quantity > 0 && quantity <= 5, "Invalid quantity");
        require(totalSupply() + quantity <= MAX_SUPPLY, "Max supply exceeded");
        require(walletMints[msg.sender] + quantity <= MAX_MINT_PER_WALLET, "Wallet limit exceeded");
        require(msg.value >= mintPrice * quantity, "Insufficient payment");
        
        walletMints[msg.sender] += quantity;
        
        for (uint256 i = 0; i < quantity; i++) {
            uint256 tokenId = _tokenIdCounter++;
            _safeMint(msg.sender, tokenId);
            
            uint256 requestId = COORDINATOR.requestRandomWords(
                s_keyHash,
                s_subscriptionId,
                REQUEST_CONFIRMATIONS,
                CALLBACK_GAS_LIMIT,
                NUM_WORDS
            );
            
            vrfRequests[requestId] = VRFRequest({
                requester: msg.sender,
                tokenId: tokenId,
                fulfilled: false
            });
            
            emit NFTMinted(msg.sender, tokenId, requestId);
        }
        
        if (msg.value > mintPrice * quantity) {
            payable(msg.sender).transfer(msg.value - (mintPrice * quantity));
        }
    }
    
    function ownerMint(
        address to, 
        uint256 quantity,
        ShoeMetadata.RarityLevel rarity
    ) 
        external 
        onlyOwner 
    {
        require(totalSupply() + quantity <= MAX_SUPPLY, "Max supply exceeded");
        
        for (uint256 i = 0; i < quantity; i++) {
            uint256 tokenId = _tokenIdCounter++;
            _safeMint(to, tokenId);
            
            shoeMetadata[tokenId] = ShoeMetadata.generateShoeMetadata(
                rarity,
                block.timestamp,
                false,
                ShoeMetadata.calculateRarityScore(rarity, 50)
            );
            
            // Notify loyalty contract
            if (address(loyaltyContract) != address(0)) {
                loyaltyContract.addLoyaltyPoints(to, shoeMetadata[tokenId].rarityScore);
            }
        }
    }
    
    // ============ VRF CALLBACK ============
    
    function fulfillRandomWords(
        uint256 requestId, 
        uint256[] memory randomWords
    ) internal override {
        VRFRequest storage request = vrfRequests[requestId];
        require(!request.fulfilled, "Already fulfilled");
        require(request.requester != address(0), "Invalid request");
        
        uint256 tokenId = request.tokenId;
        
        uint256 rarityRoll = randomWords[0] % 100;
        ShoeMetadata.RarityLevel rarity = ShoeMetadata.calculateRarity(rarityRoll);
        
        uint256 lotteryRoll = randomWords[1] % 1000;
        bool isLotteryWinner = lotteryRoll < 10;
        
        if (isLotteryWinner) {
            totalLotteryWinners++;
            emit LotteryWinner(tokenId, request.requester);
        }
        
        uint256 rarityScore = ShoeMetadata.calculateRarityScore(rarity, rarityRoll);
        
        shoeMetadata[tokenId] = ShoeMetadata.generateShoeMetadata(
            rarity,
            randomWords[1],
            isLotteryWinner,
            rarityScore
        );
        
        // Notify loyalty contract
        if (address(loyaltyContract) != address(0)) {
            loyaltyContract.addLoyaltyPoints(request.requester, rarityScore);
        }
        
        request.fulfilled = true;
        
        emit MetadataRevealed(tokenId, rarity, isLotteryWinner, rarityScore);
    }
    
    // ============ VIEW FUNCTIONS ============
    
    function getTokenMetadata(uint256 tokenId) 
        external 
        view 
        returns (ShoeMetadata.ShoeData memory) 
    {
        require(tokenId > 0 && tokenId < _tokenIdCounter, "Token not found");
        return shoeMetadata[tokenId];
    }
    
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
        return (totalSupply(), MAX_SUPPLY - totalSupply(), totalLotteryWinners, mintPrice);
    }
    
    // ============ ADMIN FUNCTIONS ============
    
    function setLoyaltyContract(address _loyaltyContract) external onlyOwner {
        loyaltyContract = DemetraLoyalty(_loyaltyContract);
    }
    
    function setMintPrice(uint256 newPrice) external onlyOwner {
        mintPrice = newPrice;
    }
    
    function pause() external onlyOwner {
        _pause();
    }
    
    function unpause() external onlyOwner {
        _unpause();
    }
    
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds");
        payable(owner()).transfer(balance);
    }
    
    // ============ REQUIRED OVERRIDES ============
    
    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override(ERC721, ERC721Enumerable) whenNotPaused returns (address) {
        return super._update(to, tokenId, auth);
    }
    
    function _increaseBalance(address account, uint128 value) internal override(ERC721, ERC721Enumerable) {
        super._increaseBalance(account, value);
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
        require(tokenId > 0 && tokenId < _tokenIdCounter, "Not found");
        return string(abi.encodePacked("https://api.demetra.com/metadata/", Strings.toString(tokenId)));
    }
}