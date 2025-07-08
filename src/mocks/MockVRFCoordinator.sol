// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title MockVRFCoordinator
 * @dev Chainlink VRF Coordinator Mock
 * @dev Simulate VRF behaviour without waiting for Chainlink
 */
contract MockVRFCoordinator {
    // ============ STATE VARIABLES ============

    uint256 private s_requestId = 1;
    mapping(uint256 => address) private s_consumers;
    mapping(uint256 => bool) private s_fulfilled;

    address public owner;

    // Events to simulate Chainlink VRF
    event RandomWordsRequested(
        bytes32 indexed keyHash,
        uint256 requestId,
        uint256 preSeed,
        uint64 indexed subId,
        uint16 minimumRequestConfirmations,
        uint32 callbackGasLimit,
        uint32 numWords,
        address indexed sender
    );

    event RandomWordsFulfilled(
        uint256 indexed requestId,
        uint256 outputSeed,
        uint96 payment,
        bool success
    );

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier validRequest(uint256 requestId) {
        require(s_consumers[requestId] != address(0), "Invalid request ID");
        require(!s_fulfilled[requestId], "Request already fulfilled");
        _;
    }

    // ============ MOCK FUNCTIONS ============

    /**
     * @dev Simulate requestRandomWords from Chainlink VRF
     */
    function requestRandomWords(
        bytes32 keyHash,
        uint64 subId,
        uint16 minimumRequestConfirmations,
        uint32 callbackGasLimit,
        uint32 numWords
    ) external returns (uint256 requestId) {
        requestId = s_requestId++;
        s_consumers[requestId] = msg.sender;
        s_fulfilled[requestId] = false;

        emit RandomWordsRequested(
            keyHash,
            requestId,
            block.timestamp, // Mock preSeed
            subId,
            minimumRequestConfirmations,
            callbackGasLimit,
            numWords,
            msg.sender
        );

        return requestId;
    }

    /**
     * @dev Simulate manually for callback VRF
     * @param requestId ID from request to fulfill
     * @param randomWords Random numbers by array (manually given for test)
     */
    function fulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) external {
        require(s_consumers[requestId] != address(0), "Invalid request ID");
        require(!s_fulfilled[requestId], "Request already fulfilled");

        address consumer = s_consumers[requestId];
        s_fulfilled[requestId] = true;

        // Call the consumer's fulfillRandomWords function
        (bool success, ) = consumer.call(
            abi.encodeWithSignature(
                "rawFulfillRandomWords(uint256,uint256[])",
                requestId,
                randomWords
            )
        );

        emit RandomWordsFulfilled(
            requestId,
            randomWords[0], // Mock outputSeed
            0, // Mock payment
            success
        );
    }

    /**
     * @dev Automatically generates random numbers for quick tests
     * @param requestId ID from request
     * @param seed Seed to generate pseudo-random
     */
    function autoFulfillRandomWords(uint256 requestId, uint256 seed) external {
        require(s_consumers[requestId] != address(0), "Invalid request ID");
        require(!s_fulfilled[requestId], "Request already fulfilled");

        // Generate pseudo-random numbers using seed
        uint256[] memory randomWords = new uint256[](2);
        randomWords[0] =
            uint256(keccak256(abi.encode(seed, block.timestamp, 1))) %
            100; // Rarity 0-99
        randomWords[1] =
            uint256(keccak256(abi.encode(seed, block.timestamp, 2))) %
            1000; // Lottery 0-999

        address consumer = s_consumers[requestId];
        s_fulfilled[requestId] = true;

        (bool success, ) = consumer.call(
            abi.encodeWithSignature(
                "rawFulfillRandomWords(uint256,uint256[])",
                requestId,
                randomWords
            )
        );

        emit RandomWordsFulfilled(requestId, randomWords[0], 0, success);
    }

    // ============ HELPER FUNCTIONS PER TEST ============

    /**
     * @dev Simulate different rarity outcomes for testing
     */
    function fulfillWithRarity(
        uint256 requestId,
        string memory rarityType
    ) external onlyOwner {
        require(s_consumers[requestId] != address(0), "Invalid request ID");
        require(!s_fulfilled[requestId], "Request already fulfilled");

        uint256[] memory randomWords = new uint256[](2);

        // Set rarity based on type
        if (keccak256(bytes(rarityType)) == keccak256(bytes("common"))) {
            randomWords[0] = 30; // Common (0-60)
        } else if (keccak256(bytes(rarityType)) == keccak256(bytes("rare"))) {
            randomWords[0] = 70; // Rare (61-85)
        } else if (keccak256(bytes(rarityType)) == keccak256(bytes("epic"))) {
            randomWords[0] = 90; // Epic (86-95)
        } else if (
            keccak256(bytes(rarityType)) == keccak256(bytes("legendary"))
        ) {
            randomWords[0] = 97; // Legendary (96-99)
        } else {
            randomWords[0] = 50; // Default to common
        }

        // Random lottery (1% chance)
        randomWords[1] = uint256(keccak256(abi.encode(block.timestamp))) % 1000;

        address consumer = s_consumers[requestId];
        s_fulfilled[requestId] = true;

        (bool success, ) = consumer.call(
            abi.encodeWithSignature(
                "rawFulfillRandomWords(uint256,uint256[])",
                requestId,
                randomWords
            )
        );

        emit RandomWordsFulfilled(requestId, randomWords[0], 0, success);
    }

    /**
     * @dev Force lottery winner for testing
     */
    function fulfillWithLotteryWin(uint256 requestId) external {
        require(s_consumers[requestId] != address(0), "Invalid request ID");
        require(!s_fulfilled[requestId], "Request already fulfilled");

        uint256[] memory randomWords = new uint256[](2);
        randomWords[0] = 85; // Rare rarity
        randomWords[1] = 5; // Lottery winner (< 10)

        address consumer = s_consumers[requestId];
        s_fulfilled[requestId] = true;

        (bool success, ) = consumer.call(
            abi.encodeWithSignature(
                "rawFulfillRandomWords(uint256,uint256[])",
                requestId,
                randomWords
            )
        );

        emit RandomWordsFulfilled(requestId, randomWords[0], 0, success);
    }

    function fulfillRandomWordsForTest(
        uint256 requestId
    ) external validRequest(requestId) {
        uint256[] memory randomWords = new uint256[](2);
        randomWords[0] =
            uint256(keccak256(abi.encode(block.timestamp, requestId, 1))) %
            100;
        randomWords[1] =
            uint256(keccak256(abi.encode(block.timestamp, requestId, 2))) %
            1000;

        address consumer = s_consumers[requestId];
        s_fulfilled[requestId] = true;

        (bool success, ) = consumer.call(
            abi.encodeWithSignature(
                "rawFulfillRandomWords(uint256,uint256[])",
                requestId,
                randomWords
            )
        );

        emit RandomWordsFulfilled(requestId, randomWords[0], 0, success);
    }

    // ============ VIEW FUNCTIONS ============

    function getRequestConsumer(
        uint256 requestId
    ) external view returns (address) {
        return s_consumers[requestId];
    }

    function isRequestFulfilled(
        uint256 requestId
    ) external view returns (bool) {
        return s_fulfilled[requestId];
    }

    function getCurrentRequestId() external view returns (uint256) {
        return s_requestId;
    }
}
