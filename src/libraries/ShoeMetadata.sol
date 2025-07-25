// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title ShoeMetadata
 * @dev Library to handle metadatas from Demetra shoes
 * @dev Logics for automatic generation of names, materials, descriptions...
 */
library ShoeMetadata {
    // ============ ENUMS & STRUCTS ============

    enum RarityLevel {
        COMMON, // 0-60%
        RARE, // 61-85%
        EPIC, // 86-95%
        LEGENDARY // 96-99%
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

    // ============ FUNCTIONS ============

    function createShoeData(
        RarityLevel rarity,
        uint256 materialSeed,
        bool isLotteryWinner,
        uint256 rarityScore
    )
        internal
        view
        returns (
            string memory shoeName,
            string memory materialOrigin,
            string memory craftmanship,
            string memory designHistory,
            RarityLevel rarityLevel,
            bool lottery,
            uint256 timestamp,
            uint256 score
        )
    {
        return (
            generateShoeName(rarity),
            generateMaterialOrigin(rarity, materialSeed),
            generateCraftmanship(rarity),
            generateDesignHistory(rarity),
            rarity,
            isLotteryWinner,
            block.timestamp,
            rarityScore
        );
    }

    // ============ CONSTANTS ============

    // Shoes names
    string private constant LEGENDARY_NAME = "Aurora Sustainability";
    string private constant EPIC_NAME = "EcoLux Premium";
    string private constant RARE_NAME = "GreenStep Pro";
    string private constant COMMON_NAME = "EcoWalk Classic";

    // ============ RARITY CALCULATION ============

    /**
     * @dev Calculate rarità level based on VRF roll
     * @param roll Random number 0-99 from VRF
     * @return RarityLevel calculated
     */
    function calculateRarity(uint256 roll) internal pure returns (RarityLevel) {
        if (roll < 61) return RarityLevel.COMMON; // 0-60 (61%)
        if (roll < 86) return RarityLevel.RARE; // 61-85 (25%)
        if (roll < 96) return RarityLevel.EPIC; // 86-95 (10%)
        return RarityLevel.LEGENDARY; // 96-99 (4%)
    }

    /**
     * @dev Calculate score based on loyalty points
     * @param rarity Rarity level
     * @param roll Random original number for variation
     * @return Numeric score by rarity
     */
    function calculateRarityScore(
        RarityLevel rarity,
        uint256 roll
    ) internal pure returns (uint256) {
        uint256 baseScore;

        if (rarity == RarityLevel.COMMON) baseScore = 25;
        else if (rarity == RarityLevel.RARE) baseScore = 50;
        else if (rarity == RarityLevel.EPIC) baseScore = 75;
        else baseScore = 100; // LEGENDARY

        // Adds variation based on roll (0-24 bonus points)
        uint256 variance = roll % 25;
        return baseScore + variance;
    }

    // ============ METADATA GENERATION ============

    /**
     * @dev Generate metadata for a shoe
     * @param rarity Rarity level
     * @param materialSeed Seed for material variation
     * @param isLotteryWinner If wins tour draft
     * @param rarityScore gets the score
     * @return ShoeData complete
     */
    function generateShoeMetadata(
        RarityLevel rarity,
        uint256 materialSeed,
        bool isLotteryWinner,
        uint256 rarityScore
    ) internal view returns (ShoeData memory) {
        return
            ShoeData({
                shoeName: generateShoeName(rarity),
                materialOrigin: generateMaterialOrigin(rarity, materialSeed),
                craftmanship: generateCraftmanship(rarity),
                designHistory: generateDesignHistory(rarity),
                rarity: rarity,
                isLotteryWinner: isLotteryWinner,
                creationTimestamp: block.timestamp,
                rarityScore: rarityScore
            });
    }

    /**
     * @dev Generate shoe name based on rarity
     */
    function generateShoeName(
        RarityLevel rarity
    ) internal pure returns (string memory) {
        if (rarity == RarityLevel.LEGENDARY) return LEGENDARY_NAME;
        if (rarity == RarityLevel.EPIC) return EPIC_NAME;
        if (rarity == RarityLevel.RARE) return RARE_NAME;
        return COMMON_NAME;
    }

    /**
     * @dev Generate materials origin with random variation
     * @param rarity Rarity level
     * @param seed Seed for random selection
     */
    function generateMaterialOrigin(
        RarityLevel rarity,
        uint256 seed
    ) internal pure returns (string memory) {
        uint256 index = seed % 4; // 0-3 to get from array

        if (rarity == RarityLevel.LEGENDARY) {
            return _getLegendaryMaterial(index);
        } else if (rarity == RarityLevel.EPIC) {
            return _getEpicMaterial(index);
        } else if (rarity == RarityLevel.RARE) {
            return _getRareMaterial(index);
        } else {
            return _getCommonMaterial(index);
        }
    }

    /**
     * @dev Generate craftmanship description
     */
    function generateCraftmanship(
        RarityLevel rarity
    ) internal pure returns (string memory) {
        if (rarity == RarityLevel.LEGENDARY) {
            return "Hand-stitched by Master Artisan with 30+ years experience";
        } else if (rarity == RarityLevel.EPIC) {
            return "Premium Artisanal Crafting with Traditional Techniques";
        } else if (rarity == RarityLevel.RARE) {
            return "Semi-Artisanal Production with Quality Control";
        } else {
            return "Sustainable Manufacturing with Automated Precision";
        }
    }

    /**
     * @dev Generate history from design
     */
    function generateDesignHistory(
        RarityLevel rarity
    ) internal pure returns (string memory) {
        if (rarity == RarityLevel.LEGENDARY) {
            return
                "Inspired by ancient Italian shoemaking traditions dating back to Renaissance";
        } else if (rarity == RarityLevel.EPIC) {
            return
                "Modern minimalist design philosophy meets sustainable innovation";
        } else if (rarity == RarityLevel.RARE) {
            return
                "Classic elegance reimagined for the conscious modern consumer";
        } else {
            return
                "Timeless design crafted for everyday sustainability and comfort";
        }
    }

    // ============ UTILITY FUNCTIONS ============

    /**
     * @dev RarityLevel -> string (for display)
     */
    function rarityToString(
        RarityLevel rarity
    ) internal pure returns (string memory) {
        if (rarity == RarityLevel.LEGENDARY) return "LEGENDARY";
        if (rarity == RarityLevel.EPIC) return "EPIC";
        if (rarity == RarityLevel.RARE) return "RARE";
        return "COMMON";
    }

    /**
     * @dev Get % rarity chance
     */
    function getRarityProbability(
        RarityLevel rarity
    ) internal pure returns (uint256) {
        if (rarity == RarityLevel.LEGENDARY) return 4; // 4%
        if (rarity == RarityLevel.EPIC) return 10; // 10%
        if (rarity == RarityLevel.RARE) return 25; // 25%
        return 61; // COMMON - 61%
    }

    /**
     * @dev Get discount based on rarity (no moltiplicators)
     */
    function getBaseDiscount(
        RarityLevel rarity
    ) internal pure returns (uint256) {
        if (rarity == RarityLevel.LEGENDARY) return 35; // 35%
        if (rarity == RarityLevel.EPIC) return 20; // 20%
        if (rarity == RarityLevel.RARE) return 10; // 10%
        return 5; // COMMON - 5%
    }

    /**
     * @dev Verify metadati completion
     */
    function validateMetadata(
        ShoeData memory data
    ) internal pure returns (bool) {
        return
            bytes(data.shoeName).length > 0 &&
            bytes(data.materialOrigin).length > 0 &&
            bytes(data.craftmanship).length > 0 &&
            bytes(data.designHistory).length > 0 &&
            data.rarityScore > 0;
    }

    /**
     * @dev Generate JSON metadata for OpenSea/Marketplaces compatibility
     */
    function generateJSONMetadata(
        uint256 tokenId,
        ShoeData memory data
    ) internal pure returns (string memory) {
        return
            string(
                abi.encodePacked(
                    '{"name": "',
                    data.shoeName,
                    " #",
                    _toString(tokenId),
                    '",',
                    '"description": "Sustainable footwear NFT from Demetra Collection",',
                    _toString(tokenId),
                    '.png",',
                    '"attributes": [',
                    '{"trait_type": "Rarity", "value": "',
                    rarityToString(data.rarity),
                    '"},',
                    '{"trait_type": "Material Origin", "value": "',
                    data.materialOrigin,
                    '"},',
                    '{"trait_type": "Craftmanship", "value": "',
                    data.craftmanship,
                    '"},',
                    '{"trait_type": "Design History", "value": "',
                    data.designHistory,
                    '"},',
                    '{"trait_type": "Rarity Score", "value": ',
                    _toString(data.rarityScore),
                    "},",
                    '{"trait_type": "Lottery Winner", "value": ',
                    data.isLotteryWinner ? "true" : "false",
                    "},",
                    '{"trait_type": "Creation Date", "value": ',
                    _toString(data.creationTimestamp),
                    "}",
                    "]}"
                )
            );
    }

    // ============ PRIVATE HELPERS ============

    /**
     * @dev Get Common material based on index
     */
    function _getCommonMaterial(
        uint256 index
    ) private pure returns (string memory) {
        if (index == 0) return "Recycled Organic Cotton from Italy";
        if (index == 1) return "Sustainable Hemp Fiber from Europe";
        if (index == 2) return "Recycled Plastic Bottles from Mediterranean";
        return "Organic Linen from French Countryside";
    }

    /**
     * @dev Get Rare material based on index
     */
    function _getRareMaterial(
        uint256 index
    ) private pure returns (string memory) {
        if (index == 0) return "Premium Cork from Portuguese Forests";
        if (index == 1) return "Organic Bamboo Fiber from Sustainable Farms";
        if (index == 2) return "Recycled Ocean Plastic from Adriatic Sea";
        return "Bio-based Leather from Pineapple Leaves";
    }

    /**
     * @dev Get Epic material based on index
     */
    function _getEpicMaterial(
        uint256 index
    ) private pure returns (string memory) {
        if (index == 0) return "Hand-harvested Cork from Century-old Trees";
        if (index == 1)
            return
                "Japanese Organic Bamboo with Natural Antimicrobial Properties";
        if (index == 2) return "Lab-grown Mycelium Leather from Fungi";
        return "Alpaca Wool from Ethical Peruvian Farms";
    }

    /**
     * @dev Get Legendary material based on index
     */
    function _getLegendaryMaterial(
        uint256 index
    ) private pure returns (string memory) {
        if (index == 0)
            return "Rare Organic Bamboo Fiber from Ancient Japanese Groves";
        if (index == 1)
            return "Premium Cork from 200-year-old Portuguese Trees";
        if (index == 2) return "Bio-engineered Spider Silk Protein Fiber";
        return "Certified Organic Merino Wool from New Zealand";
    }

    /**
     * @dev uint256 -> string (internal helper)
     */
    function _toString(uint256 value) private pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}
