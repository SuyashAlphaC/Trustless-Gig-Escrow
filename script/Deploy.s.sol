// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {GigEscrow} from "../src/GigEscrow.sol";

/**
 * @title DeployGigEscrow
 * @notice Deployment script for the GigEscrow contract
 * @dev Automatically detects chain ID and configures appropriate addresses
 */
contract DeployGigEscrow is Script {
    // ============ Network Configuration ============

    // Sepolia Testnet (Chain ID: 11155111)
    address constant SEPOLIA_FUNCTIONS_ROUTER = 0xb83E47C2bC239B3bf370bc41e1459A34b41238D0;
    bytes32 constant SEPOLIA_DON_ID = 0x66756e2d657468657265756d2d7365706f6c69612d3100000000000000000000; // "fun-ethereum-sepolia-1"

    // Ethereum Mainnet (Chain ID: 1)
    address constant MAINNET_FUNCTIONS_ROUTER = 0x65Dcc24F8ff9e51F10DCc7Ed1e4e2A61e6E14bd6;
    bytes32 constant MAINNET_DON_ID = 0x66756e2d657468657265756d2d6d61696e6e65742d3100000000000000000000; // "fun-ethereum-mainnet-1"

    // Polygon Mumbai (Chain ID: 80001) - Deprecated but included for reference
    address constant MUMBAI_FUNCTIONS_ROUTER = 0x6E2dc0F9DB014aE19888F539E59285D2Ea04244C;
    bytes32 constant MUMBAI_DON_ID = 0x66756e2d706f6c79676f6e2d6d756d6261692d31000000000000000000000000; // "fun-polygon-mumbai-1"

    // Polygon Mainnet (Chain ID: 137)
    address constant POLYGON_FUNCTIONS_ROUTER = 0xdc2AAF042Aeff2E68B3e8E33F19e4B9fA7C73F10;
    bytes32 constant POLYGON_DON_ID = 0x66756e2d706f6c79676f6e2d6d61696e6e65742d310000000000000000000000; // "fun-polygon-mainnet-1"

    // Avalanche Fuji (Chain ID: 43113)
    address constant FUJI_FUNCTIONS_ROUTER = 0xA9d587a00A31A52Ed70D6026794a8FC5E2F5dCb0;
    bytes32 constant FUJI_DON_ID = 0x66756e2d6176616c616e6368652d66756a692d31000000000000000000000000; // "fun-avalanche-fuji-1"

    // Arbitrum Sepolia (Chain ID: 421614)
    address constant ARB_SEPOLIA_FUNCTIONS_ROUTER = 0x234a5fb5Bd614a7AA2FfAB244D603abFA0Ac5C5C;
    bytes32 constant ARB_SEPOLIA_DON_ID = 0x66756e2d617262697472756d2d7365706f6c69612d3100000000000000000000; // "fun-arbitrum-sepolia-1"

    // Base Sepolia (Chain ID: 84532)
    address constant BASE_SEPOLIA_FUNCTIONS_ROUTER = 0xf9B8fc078197181C841c296C876945aaa425B278;
    bytes32 constant BASE_SEPOLIA_DON_ID = 0x66756e2d626173652d7365706f6c69612d310000000000000000000000000000; // "fun-base-sepolia-1"

    // Default callback gas limit for Chainlink Functions
    uint32 constant DEFAULT_CALLBACK_GAS_LIMIT = 300000;

    // ============ Deployment Configuration ============

    struct NetworkConfig {
        address functionsRouter;
        bytes32 donId;
        address mneeToken;
        uint64 subscriptionId;
        uint32 callbackGasLimit;
    }

    /**
     * @notice Returns the network configuration based on chain ID
     * @dev Add new networks here as needed
     * @return config The network configuration struct
     */
    function getNetworkConfig() public view returns (NetworkConfig memory config) {
        uint256 chainId = block.chainid;

        if (chainId == 11155111) {
            // Sepolia
            config = NetworkConfig({
                functionsRouter: SEPOLIA_FUNCTIONS_ROUTER,
                donId: SEPOLIA_DON_ID,
                mneeToken: _getMneeTokenAddress(chainId),
                subscriptionId: _getSubscriptionId(),
                callbackGasLimit: DEFAULT_CALLBACK_GAS_LIMIT
            });
        } else if (chainId == 1) {
            // Ethereum Mainnet
            config = NetworkConfig({
                functionsRouter: MAINNET_FUNCTIONS_ROUTER,
                donId: MAINNET_DON_ID,
                mneeToken: _getMneeTokenAddress(chainId),
                subscriptionId: _getSubscriptionId(),
                callbackGasLimit: DEFAULT_CALLBACK_GAS_LIMIT
            });
        } else if (chainId == 137) {
            // Polygon Mainnet
            config = NetworkConfig({
                functionsRouter: POLYGON_FUNCTIONS_ROUTER,
                donId: POLYGON_DON_ID,
                mneeToken: _getMneeTokenAddress(chainId),
                subscriptionId: _getSubscriptionId(),
                callbackGasLimit: DEFAULT_CALLBACK_GAS_LIMIT
            });
        } else if (chainId == 43113) {
            // Avalanche Fuji
            config = NetworkConfig({
                functionsRouter: FUJI_FUNCTIONS_ROUTER,
                donId: FUJI_DON_ID,
                mneeToken: _getMneeTokenAddress(chainId),
                subscriptionId: _getSubscriptionId(),
                callbackGasLimit: DEFAULT_CALLBACK_GAS_LIMIT
            });
        } else if (chainId == 421614) {
            // Arbitrum Sepolia
            config = NetworkConfig({
                functionsRouter: ARB_SEPOLIA_FUNCTIONS_ROUTER,
                donId: ARB_SEPOLIA_DON_ID,
                mneeToken: _getMneeTokenAddress(chainId),
                subscriptionId: _getSubscriptionId(),
                callbackGasLimit: DEFAULT_CALLBACK_GAS_LIMIT
            });
        } else if (chainId == 84532) {
            // Base Sepolia
            config = NetworkConfig({
                functionsRouter: BASE_SEPOLIA_FUNCTIONS_ROUTER,
                donId: BASE_SEPOLIA_DON_ID,
                mneeToken: _getMneeTokenAddress(chainId),
                subscriptionId: _getSubscriptionId(),
                callbackGasLimit: DEFAULT_CALLBACK_GAS_LIMIT
            });
        } else if (chainId == 31337) {
            // Local Anvil - will need mock addresses
            revert("Local deployment requires mock contracts. Use DeployLocal.s.sol instead.");
        } else {
            revert(string(abi.encodePacked("Unsupported chain ID: ", _uint2str(chainId))));
        }

        return config;
    }

    /**
     * @notice Main deployment function
     * @return escrow The deployed GigEscrow contract
     */
    function run() external returns (GigEscrow escrow) {
        NetworkConfig memory config = getNetworkConfig();

        // Load the JavaScript source code for GitHub verification
        string memory source = _loadJavaScriptSource();

        console.log("=== GigEscrow Deployment ===");
        console.log("Chain ID:", block.chainid);
        console.log("Functions Router:", config.functionsRouter);
        console.log("DON ID:", vm.toString(config.donId));
        console.log("MNEE Token:", config.mneeToken);
        console.log("Subscription ID:", config.subscriptionId);
        console.log("Callback Gas Limit:", config.callbackGasLimit);

        // Start broadcast for deployment
        vm.startBroadcast();

        escrow = new GigEscrow(
            config.functionsRouter,
            config.mneeToken,
            config.subscriptionId,
            config.donId,
            config.callbackGasLimit,
            source
        );

        vm.stopBroadcast();

        console.log("=== Deployment Complete ===");
        console.log("GigEscrow deployed at:", address(escrow));
        console.log("");
        console.log("Next steps:");
        console.log("1. Add the contract as a consumer to your Chainlink Functions subscription");
        console.log("2. Fund the subscription with LINK tokens");
        console.log("3. Verify the contract on Etherscan (optional)");

        return escrow;
    }

    // ============ Helper Functions ============

    /**
     * @notice Gets the MNEE token address from environment or returns placeholder
     * @dev Override this with actual MNEE token addresses per network
     */
    function _getMneeTokenAddress(uint256 chainId) internal view returns (address) {
        // Try to get from environment variable first
        try vm.envAddress("MNEE_TOKEN_ADDRESS") returns (address addr) {
            return addr;
        } catch {
            // Return placeholder addresses per network
            // These should be replaced with actual MNEE token addresses
            if (chainId == 11155111) {
                // Sepolia - placeholder, deploy your own test token
                return address(0x1234567890123456789012345678901234567890);
            } else if (chainId == 1) {
                // Mainnet - placeholder
                return address(0x1234567890123456789012345678901234567890);
            }
            // Default placeholder
            return address(0x1234567890123456789012345678901234567890);
        }
    }

    /**
     * @notice Gets the Chainlink Functions subscription ID from environment
     */
    function _getSubscriptionId() internal view returns (uint64) {
        try vm.envUint("CHAINLINK_SUBSCRIPTION_ID") returns (uint256 subId) {
            return uint64(subId);
        } catch {
            // Default subscription ID (should be set in .env)
            return 0;
        }
    }

    /**
     * @notice Loads the JavaScript source code from the functions directory
     * @dev Falls back to inline source if file read fails
     */
    function _loadJavaScriptSource() internal view returns (string memory) {
        try vm.readFile("functions/github-check.js") returns (string memory source) {
            return source;
        } catch {
            // Fallback inline source
            return _getInlineSource();
        }
    }

    /**
     * @notice Returns inline JavaScript source as fallback
     */
    function _getInlineSource() internal pure returns (string memory) {
        return
            'if (!args || args.length < 3) { throw Error("Missing required arguments"); }'
            'const owner = args[0];'
            'const repo = args[1];'
            'const prNumber = args[2];'
            'const apiUrl = `https://api.github.com/repos/${owner}/${repo}/pulls/${prNumber}`;'
            'const response = await Functions.makeHttpRequest({'
            '  url: apiUrl,'
            '  method: "GET",'
            '  headers: { "Accept": "application/vnd.github.v3+json", "User-Agent": "Chainlink-Functions" }'
            '});'
            'if (response.error || response.status !== 200) { return Functions.encodeUint256(0); }'
            'const isMerged = response.data.merged === true;'
            'return Functions.encodeUint256(isMerged ? 1 : 0);';
    }

    /**
     * @notice Converts uint to string
     */
    function _uint2str(uint256 _i) internal pure returns (string memory) {
        if (_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 length;
        while (j != 0) {
            length++;
            j /= 10;
        }
        bytes memory bstr = new bytes(length);
        uint256 k = length;
        while (_i != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(_i - (_i / 10) * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }
}

/**
 * @title DeployGigEscrowLocal
 * @notice Deployment script for local testing with Anvil
 * @dev Deploys mock contracts for local development
 */
contract DeployGigEscrowLocal is Script {
    function run() external returns (GigEscrow escrow, address mneeToken, address mockRouter) {
        console.log("=== Local Deployment (Anvil) ===");

        vm.startBroadcast();

        // Deploy mock MNEE token
        // Using a simple inline mock for local testing
        MockMNEE mockMnee = new MockMNEE();
        mneeToken = address(mockMnee);
        console.log("Mock MNEE Token deployed at:", mneeToken);

        // Deploy mock Functions Router
        MockRouter router = new MockRouter();
        mockRouter = address(router);
        console.log("Mock Functions Router deployed at:", mockRouter);

        // Deploy GigEscrow
        string memory source = "return Functions.encodeUint256(1);"; // Simple mock source

        escrow = new GigEscrow(
            mockRouter,
            mneeToken,
            1, // subscriptionId
            bytes32("local-don"), // donId
            300000, // callbackGasLimit
            source
        );
        console.log("GigEscrow deployed at:", address(escrow));

        // Mint some tokens to the deployer for testing
        mockMnee.mint(msg.sender, 1000000 ether);
        console.log("Minted 1,000,000 MNEE to deployer");

        vm.stopBroadcast();

        console.log("=== Local Deployment Complete ===");

        return (escrow, mneeToken, mockRouter);
    }
}

/**
 * @title MockMNEE
 * @notice Simple mock ERC20 for local deployment
 */
contract MockMNEE {
    string public name = "Mock MNEE";
    string public symbol = "MNEE";
    uint8 public decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient balance");
        require(allowance[from][msg.sender] >= amount, "Insufficient allowance");
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }
}

/**
 * @title MockRouter
 * @notice Simple mock Chainlink Functions Router for local deployment
 */
contract MockRouter {
    uint256 private requestCounter;
    mapping(bytes32 => address) public requestToClient;

    event RequestSent(bytes32 indexed requestId, address indexed client);

    function sendRequest(
        uint64,
        bytes calldata,
        uint16,
        uint32,
        bytes32
    ) external returns (bytes32 requestId) {
        requestCounter++;
        requestId = keccak256(abi.encodePacked(msg.sender, requestCounter, block.timestamp));
        requestToClient[requestId] = msg.sender;
        emit RequestSent(requestId, msg.sender);
        return requestId;
    }

    // Function to simulate fulfillment (call from test/script)
    function fulfillRequest(bytes32 requestId, bytes memory response) external {
        address client = requestToClient[requestId];
        require(client != address(0), "Request not found");
        delete requestToClient[requestId];

        // Call the client's callback
        (bool success,) = client.call(
            abi.encodeWithSignature(
                "handleOracleFulfillment(bytes32,bytes,bytes)",
                requestId,
                response,
                ""
            )
        );
        require(success, "Callback failed");
    }
}
