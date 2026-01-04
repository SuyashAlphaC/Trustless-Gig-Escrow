// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MockMNEE
 * @author Trustless Gig Escrow Team
 * @notice A mock ERC20 token for testing the GigEscrow contract on Sepolia testnet
 * @dev Includes public mint function and faucet for easy testing
 */
contract MockMNEE is ERC20, Ownable {
    // ============ Constants ============

    /// @notice Amount of tokens dispensed per faucet call (10,000 MNEE)
    uint256 public constant FAUCET_AMOUNT = 10_000 * 10 ** 18;

    /// @notice Cooldown period between faucet calls per address (1 hour)
    uint256 public constant FAUCET_COOLDOWN = 1 hours;

    /// @notice Maximum supply that can be minted (100 million MNEE)
    uint256 public constant MAX_SUPPLY = 100_000_000 * 10 ** 18;

    // ============ State Variables ============

    /// @notice Tracks the last faucet claim timestamp per address
    mapping(address => uint256) public lastFaucetClaim;

    // ============ Events ============

    /// @notice Emitted when tokens are claimed from the faucet
    event FaucetClaimed(address indexed claimer, uint256 amount);

    /// @notice Emitted when owner mints tokens
    event TokensMinted(address indexed to, uint256 amount);

    // ============ Errors ============

    error MockMNEE__FaucetCooldownActive(uint256 timeRemaining);
    error MockMNEE__MaxSupplyExceeded();
    error MockMNEE__InvalidAddress();
    error MockMNEE__InvalidAmount();

    // ============ Constructor ============

    /**
     * @notice Initializes the MockMNEE token
     * @param initialOwner The address that will own the contract and receive initial supply
     */
    constructor(address initialOwner) ERC20("Mock MNEE", "MNEE") Ownable(initialOwner) {
        if (initialOwner == address(0)) revert MockMNEE__InvalidAddress();
        
        // Mint initial supply to the owner (1 million MNEE)
        _mint(initialOwner, 1_000_000 * 10 ** 18);
    }

    // ============ External Functions ============

    /**
     * @notice Allows anyone to claim test tokens from the faucet
     * @dev Limited by cooldown period and faucet amount
     */
    function faucet() external {
        uint256 lastClaim = lastFaucetClaim[msg.sender];
        
        if (lastClaim != 0) {
            uint256 timeSinceLastClaim = block.timestamp - lastClaim;
            if (timeSinceLastClaim < FAUCET_COOLDOWN) {
                revert MockMNEE__FaucetCooldownActive(FAUCET_COOLDOWN - timeSinceLastClaim);
            }
        }

        // Check max supply
        if (totalSupply() + FAUCET_AMOUNT > MAX_SUPPLY) {
            revert MockMNEE__MaxSupplyExceeded();
        }

        lastFaucetClaim[msg.sender] = block.timestamp;
        _mint(msg.sender, FAUCET_AMOUNT);

        emit FaucetClaimed(msg.sender, FAUCET_AMOUNT);
    }

    /**
     * @notice Allows the owner to mint tokens to any address
     * @dev Useful for setting up test scenarios
     * @param to The address to receive the minted tokens
     * @param amount The amount of tokens to mint (in wei)
     */
    function mint(address to, uint256 amount) external onlyOwner {
        if (to == address(0)) revert MockMNEE__InvalidAddress();
        if (amount == 0) revert MockMNEE__InvalidAmount();
        if (totalSupply() + amount > MAX_SUPPLY) revert MockMNEE__MaxSupplyExceeded();

        _mint(to, amount);

        emit TokensMinted(to, amount);
    }

    /**
     * @notice Allows the owner to mint tokens to multiple addresses at once
     * @dev Useful for airdropping test tokens to multiple testers
     * @param recipients Array of addresses to receive tokens
     * @param amounts Array of amounts to mint to each recipient
     */
    function batchMint(address[] calldata recipients, uint256[] calldata amounts) external onlyOwner {
        if (recipients.length != amounts.length) revert MockMNEE__InvalidAmount();

        uint256 totalAmount = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            totalAmount += amounts[i];
        }

        if (totalSupply() + totalAmount > MAX_SUPPLY) revert MockMNEE__MaxSupplyExceeded();

        for (uint256 i = 0; i < recipients.length; i++) {
            if (recipients[i] == address(0)) revert MockMNEE__InvalidAddress();
            if (amounts[i] == 0) revert MockMNEE__InvalidAmount();
            
            _mint(recipients[i], amounts[i]);
            emit TokensMinted(recipients[i], amounts[i]);
        }
    }

    // ============ View Functions ============

    /**
     * @notice Returns the time remaining until an address can claim from faucet again
     * @param account The address to check
     * @return timeRemaining Seconds until faucet is available (0 if available now)
     */
    function getFaucetCooldownRemaining(address account) external view returns (uint256 timeRemaining) {
        uint256 lastClaim = lastFaucetClaim[account];
        
        if (lastClaim == 0) {
            return 0;
        }

        uint256 timeSinceLastClaim = block.timestamp - lastClaim;
        
        if (timeSinceLastClaim >= FAUCET_COOLDOWN) {
            return 0;
        }

        return FAUCET_COOLDOWN - timeSinceLastClaim;
    }

    /**
     * @notice Checks if an address can currently claim from the faucet
     * @param account The address to check
     * @return canClaim True if the address can claim tokens
     */
    function canClaimFaucet(address account) external view returns (bool canClaim) {
        uint256 lastClaim = lastFaucetClaim[account];
        
        if (lastClaim == 0) {
            return true;
        }

        return (block.timestamp - lastClaim) >= FAUCET_COOLDOWN;
    }

    /**
     * @notice Returns the remaining mintable supply
     * @return remaining The amount of tokens that can still be minted
     */
    function remainingMintableSupply() external view returns (uint256 remaining) {
        return MAX_SUPPLY - totalSupply();
    }
}
