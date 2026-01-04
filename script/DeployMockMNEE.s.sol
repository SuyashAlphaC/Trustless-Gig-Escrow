// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {MockMNEE} from "../src/MockMNEE.sol";

/**
 * @title DeployMockMNEE
 * @notice Deployment script for the MockMNEE token on Sepolia testnet
 * @dev Run with: forge script script/DeployMockMNEE.s.sol:DeployMockMNEE --rpc-url sepolia --broadcast --verify
 */
contract DeployMockMNEE is Script {
    function run() external returns (MockMNEE token) {
        // Get deployer address from private key
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== MockMNEE Deployment ===");
        console.log("Chain ID:", block.chainid);
        console.log("Deployer:", deployer);
        console.log("");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy MockMNEE with deployer as initial owner
        token = new MockMNEE(deployer);

        vm.stopBroadcast();

        console.log("=== Deployment Complete ===");
        console.log("MockMNEE deployed at:", address(token));
        console.log("Initial supply (MNEE):", token.totalSupply() / 1e18);
        console.log("Owner:", token.owner());
        console.log("");
        console.log("=== Next Steps ===");
        console.log("1. Update MNEE_TOKEN_ADDRESS in your .env file");
        console.log("2. Verify on Etherscan if not auto-verified");
        console.log("3. Users can claim test tokens by calling faucet()");
        console.log("   - 10,000 MNEE per claim, 1 hour cooldown");

        return token;
    }
}

/**
 * @title MintMockMNEE
 * @notice Script to mint additional MockMNEE tokens (owner only)
 * @dev Run with: forge script script/DeployMockMNEE.s.sol:MintMockMNEE --rpc-url sepolia --broadcast
 */
contract MintMockMNEE is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address tokenAddress = vm.envAddress("MNEE_TOKEN_ADDRESS");
        address recipient = vm.envOr("MINT_RECIPIENT", vm.addr(deployerPrivateKey));
        uint256 amount = vm.envOr("MINT_AMOUNT", uint256(100_000 ether)); // Default 100k MNEE

        MockMNEE token = MockMNEE(tokenAddress);

        console.log("=== Minting MockMNEE ===");
        console.log("Token:", tokenAddress);
        console.log("Recipient:", recipient);
        console.log("Amount (MNEE):", amount / 1e18);

        vm.startBroadcast(deployerPrivateKey);

        token.mint(recipient, amount);

        vm.stopBroadcast();

        console.log("=== Mint Complete ===");
        console.log("New balance (MNEE):", token.balanceOf(recipient) / 1e18);
    }
}
