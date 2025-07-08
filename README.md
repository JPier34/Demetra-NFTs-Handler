# 🌱 Demetra Sustainable Shoes NFT

> **Enterprise-grade NFT collection with Chainlink VRF integration and loyalty rewards system**

A complete NFT ecosystem featuring randomized metadata generation, rarity-based rewards, and sustainable shoe-themed collectibles deployed on Ethereum Sepolia testnet.

## 🚀 Live Demo

- **NFT Contract**: [0x6F51920528e1E50C42109E03EdB1d202fa8a4f47](https://sepolia.etherscan.io/address/0x6f51920528e1e50c42109e03edb1d202fa8a4f47)
- **Loyalty Contract**: [0xe866a85FCdb6fc1Fb104675795A7F303D3445FC4](https://sepolia.etherscan.io/address/0xe866a85fcdb6fc1fb104675795a7f303d3445fc4)
- **Deployment Transaction**: [0x4a7124cd...ef7dd](https://sepolia.etherscan.io/tx/0x4a7124cd96a8c67c71622863b3f8b6a920df42f37214191ea5f8d7d68dbef7dd)
- **Network**: Ethereum Sepolia Testnet

## ✨ Features

### 🎨 Core NFT Functionality

- **ERC721 Standard**: Full compatibility with OpenSea, Blur, and all major marketplaces
- **Dynamic Metadata**: Rich, sustainable shoe-themed attributes
- **Rarity System**: 5 levels (Common, Uncommon, Rare, Epic, Legendary)
- **Verifiable Randomness**: Chainlink VRF v2 integration for tamper-proof randomization

### 🎁 Advanced Features

- **Loyalty Rewards**: Automatic point accumulation based on NFT rarity
- **Discount System**: Up to 50% discounts for premium holders
- **Lottery Mechanism**: 1% chance for special rewards on each mint
- **Pause/Emergency Controls**: Admin safety mechanisms

### 🛡️ Security Features

- **Access Control**: Owner-only administrative functions
- **Reentrancy Protection**: Guards against common attack vectors
- **Overflow Protection**: Safe arithmetic operations
- **VRF Manipulation Prevention**: Secure randomness generation

## 📊 Collection Stats

| Parameter               | Value       |
| ----------------------- | ----------- |
| **Max Supply**          | 10,000 NFTs |
| **Mint Price**          | 0.05 ETH    |
| **Max Per Wallet**      | 5 NFTs      |
| **Max Per Transaction** | 5 NFTs      |
| **Lottery Chance**      | 1% per mint |

## 🏗️ Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│  DemetraShoeNFT │────│  Chainlink VRF   │    │  DemetraLoyalty │
│                 │    │   Coordinator    │    │                 │
│ • Minting       │    │                  │    │ • Point System  │
│ • Metadata      │────│ • Randomness     │    │ • Discounts     │
│ • Transfers     │    │ • Tamper-proof   │    │ • Rewards       │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## 🔧 Technology Stack

- **Solidity 0.8.30**: Smart contract development
- **Foundry**: Testing and deployment framework
- **Chainlink VRF v2**: Verifiable random function
- **OpenZeppelin**: Security and standard implementations
- **Etherscan**: Contract verification and transparency

## 🎯 Rarity Distribution

| Rarity        | Probability | Discount |
| ------------- | ----------- | -------- |
| **Common**    | 49%         | 5%       |
| **Uncommon**  | 30%         | 10%      |
| **Rare**      | 15%         | 15%      |
| **Epic**      | 5%          | 25%      |
| **Legendary** | 1%          | 35%      |

## 🚀 Quick Start

### Prerequisites

```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Clone repository
git clone https://github.com/yourusername/demetra-nft
cd demetra-nft
```

### Installation

```bash
# Install dependencies
forge install

# Run tests
forge test

# Deploy to Sepolia
forge script script/Deploy.s.sol --rpc-url sepolia --broadcast --verify
```

### Environment Setup

```bash
# Create .env file
cp .env.example .env

# Add your keys
PRIVATE_KEY=your_private_key
ALCHEMY_API_URL=your_alchemy_url
ETHERSCAN_API_KEY=your_etherscan_key
VRF_SUBSCRIPTION_ID=your_chainlink_subscription
```

## 📝 Smart Contracts

### DemetraShoeNFT.sol

Main NFT contract with minting, metadata, and VRF integration.

**Key Functions:**

- `mint(uint256 quantity)`: Public minting with payment
- `ownerMint(address to, uint256 quantity, RarityLevel rarity)`: Admin minting
- `getTokenMetadata(uint256 tokenId)`: Retrieve NFT attributes
- `getCollectionStats()`: Collection statistics

### DemetraLoyalty.sol

Loyalty rewards system for NFT holders.

**Key Functions:**

- `getLoyaltyPoints(address user)`: Get user's point balance
- `getUserDiscount(address user)`: Calculate discount percentage
- `addLoyaltyPoints(address user, uint256 points)`: Add points (NFT contract only)

### ShoeMetadata.sol

Library for generating dynamic metadata based on rarity.

## 🧪 Testing

The project includes comprehensive testing with 40+ test cases covering:

- **Unit Tests**: Individual function testing
- **Integration Tests**: Contract interaction testing
- **Security Tests**: Attack vector prevention
- **Gas Optimization**: Efficiency testing

```bash
# Run all tests
forge test

# Run specific test category
forge test --match-test testSecurity

# Run with verbosity
forge test -vvv

# Generate coverage report
forge coverage
```

## 🛡️ Security Auditing

### Automated Testing

- **40+ test cases** covering all major functions
- **Security-focused tests** for common vulnerabilities
- **Reentrancy protection** testing
- **Access control** verification

### Manual Review

- **Overflow/underflow** protection
- **VRF manipulation** prevention
- **Access control** mechanisms
- **Emergency procedures**

## 📈 Gas Optimization

| Function       | Gas Usage | Optimization     |
| -------------- | --------- | ---------------- |
| `mint(1)`      | ~275k gas | Optimized loops  |
| `ownerMint(1)` | ~512k gas | Batch processing |
| `transfer`     | ~85k gas  | Standard ERC721  |

## 🎨 Metadata Examples

### Legendary NFT

```json
{
  "shoeName": "Aurora Sustainability",
  "materialOrigin": "Bio-engineered Spider Silk Protein Fiber",
  "craftingMethod": "Hand-stitched by Master Artisan with 30+ years experience",
  "sustainability": "Inspired by ancient Italian shoemaking traditions dating back to Renaissance",
  "rarity": "LEGENDARY",
  "isLotteryWinner": false,
  "rarityScore": 122,
  "creationTimestamp": 1734567890
}
```

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🔗 Links

- **Documentation**: [Wiki](https://github.com/yourusername/demetra-nft/wiki)
- **Bug Reports**: [Issues](https://github.com/yourusername/demetra-nft/issues)
- **Feature Requests**: [Discussions](https://github.com/yourusername/demetra-nft/discussions)

## 👥 Team

- **Developer**: Your Name
- **Advisor**: Blockchain Expert
- **Designer**: NFT Artist

---

**⭐ If this project helped you, please consider giving it a star!**

_Built with ❤️ for the sustainable future_
