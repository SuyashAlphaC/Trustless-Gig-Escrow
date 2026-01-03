// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title GigEscrow
 * @author Trustless Gig Escrow Team
 * @notice A decentralized escrow system for freelance gigs that releases payment
 *         when a GitHub Pull Request is merged, verified via Chainlink Functions
 * @dev Inherits from FunctionsClient for Chainlink DON interaction, ConfirmedOwner
 *      for ownership management, and ReentrancyGuard for security
 */
contract GigEscrow is FunctionsClient, ConfirmedOwner, ReentrancyGuard {
    using FunctionsRequest for FunctionsRequest.Request;
    using SafeERC20 for IERC20;

    // ============ Type Declarations ============

    /**
     * @notice Represents a gig/job in the escrow system
     * @param client The address that created and funded the gig
     * @param freelancer The address that will receive payment upon PR merge
     * @param amount The amount of MNEE tokens locked in escrow
     * @param repoOwner GitHub username or organization owning the repository
     * @param repoName Name of the GitHub repository
     * @param prId Pull Request number as a string
     * @param isOpen Whether the gig is still active (funds not yet released)
     * @param createdAt Timestamp when the gig was created
     */
    struct Gig {
        address client;
        address freelancer;
        uint256 amount;
        string repoOwner;
        string repoName;
        string prId;
        bool isOpen;
        uint256 createdAt;
    }

    /**
     * @notice Tracks pending Chainlink Functions requests
     * @param gigId The gig ID associated with this request
     * @param exists Whether this request mapping exists
     */
    struct PendingRequest {
        uint256 gigId;
        bool exists;
    }

    // ============ State Variables ============

    /// @notice The MNEE ERC20 token used for payments
    IERC20 public immutable i_mneeToken;

    /// @notice Chainlink Functions subscription ID for billing
    uint64 public s_subscriptionId;

    /// @notice Chainlink DON ID for routing requests
    bytes32 public s_donId;

    /// @notice Gas limit for the Chainlink Functions callback
    uint32 public s_callbackGasLimit;

    /// @notice The JavaScript source code for GitHub PR verification
    string public s_source;

    /// @notice Counter for generating unique gig IDs
    uint256 public s_gigCounter;

    /// @notice Mapping of gig ID to Gig struct
    mapping(uint256 => Gig) public s_gigs;

    /// @notice Mapping of Chainlink request ID to pending request info
    mapping(bytes32 => PendingRequest) public s_pendingRequests;

    /// @notice Mapping to track if a gig has a pending verification request
    mapping(uint256 => bool) public s_gigHasPendingRequest;

    // ============ Events ============

    /// @notice Emitted when a new gig is created and funded
    event GigCreated(
        uint256 indexed gigId,
        address indexed client,
        address indexed freelancer,
        uint256 amount,
        string repoOwner,
        string repoName,
        string prId
    );

    /// @notice Emitted when a gig is funded (included in creation for this implementation)
    event GigFunded(uint256 indexed gigId, uint256 amount);

    /// @notice Emitted when work verification is requested via Chainlink
    event WorkVerificationRequested(
        uint256 indexed gigId,
        bytes32 indexed requestId,
        address indexed requester
    );

    /// @notice Emitted when Chainlink returns the verification result
    event WorkVerified(
        uint256 indexed gigId,
        bytes32 indexed requestId,
        bool isMerged
    );

    /// @notice Emitted when payment is released to the freelancer
    event PaymentReleased(
        uint256 indexed gigId,
        address indexed freelancer,
        uint256 amount
    );

    /// @notice Emitted when a gig is cancelled by the client
    event GigCancelled(uint256 indexed gigId, address indexed client, uint256 amount);

    /// @notice Emitted when the Chainlink Functions source is updated
    event SourceUpdated(string newSource);

    /// @notice Emitted when Chainlink configuration is updated
    event ChainlinkConfigUpdated(uint64 subscriptionId, bytes32 donId, uint32 callbackGasLimit);

    // ============ Errors ============

    error GigEscrow__InvalidAddress();
    error GigEscrow__InvalidAmount();
    error GigEscrow__InvalidGigId();
    error GigEscrow__GigNotOpen();
    error GigEscrow__GigAlreadyClosed();
    error GigEscrow__UnauthorizedCaller();
    error GigEscrow__RequestAlreadyPending();
    error GigEscrow__RequestNotFound();
    error GigEscrow__TransferFailed();
    error GigEscrow__EmptySource();
    error GigEscrow__EmptyRepoInfo();
    error GigEscrow__GigTooRecent();

    // ============ Modifiers ============

    /**
     * @notice Ensures the gig exists and is still open
     * @param gigId The ID of the gig to check
     */
    modifier gigExists(uint256 gigId) {
        if (gigId == 0 || gigId > s_gigCounter) {
            revert GigEscrow__InvalidGigId();
        }
        _;
    }

    /**
     * @notice Ensures the gig is still open for operations
     * @param gigId The ID of the gig to check
     */
    modifier gigIsOpen(uint256 gigId) {
        if (!s_gigs[gigId].isOpen) {
            revert GigEscrow__GigNotOpen();
        }
        _;
    }

    // ============ Constructor ============

    /**
     * @notice Initializes the GigEscrow contract
     * @param router Address of the Chainlink Functions Router
     * @param mneeToken Address of the MNEE ERC20 token
     * @param subscriptionId Chainlink Functions subscription ID
     * @param donId Chainlink DON ID for the target network
     * @param callbackGasLimit Gas limit for fulfillRequest callback
     * @param source JavaScript source code for GitHub verification
     */
    constructor(
        address router,
        address mneeToken,
        uint64 subscriptionId,
        bytes32 donId,
        uint32 callbackGasLimit,
        string memory source
    ) FunctionsClient(router) ConfirmedOwner(msg.sender) {
        if (mneeToken == address(0)) revert GigEscrow__InvalidAddress();
        if (bytes(source).length == 0) revert GigEscrow__EmptySource();

        i_mneeToken = IERC20(mneeToken);
        s_subscriptionId = subscriptionId;
        s_donId = donId;
        s_callbackGasLimit = callbackGasLimit;
        s_source = source;
    }

    // ============ External Functions ============

    /**
     * @notice Creates a new gig and deposits MNEE tokens into escrow
     * @dev Transfers tokens from client to this contract using transferFrom
     * @param freelancer Address of the freelancer who will receive payment
     * @param amount Amount of MNEE tokens to lock in escrow
     * @param repoOwner GitHub username/organization owning the repository
     * @param repoName Name of the GitHub repository
     * @param prId Pull Request number as a string
     * @return gigId The unique identifier for the created gig
     */
    function createGig(
        address freelancer,
        uint256 amount,
        string calldata repoOwner,
        string calldata repoName,
        string calldata prId
    ) external nonReentrant returns (uint256 gigId) {
        // Validate inputs
        if (freelancer == address(0)) revert GigEscrow__InvalidAddress();
        if (freelancer == msg.sender) revert GigEscrow__InvalidAddress();
        if (amount == 0) revert GigEscrow__InvalidAmount();
        if (bytes(repoOwner).length == 0 || bytes(repoName).length == 0 || bytes(prId).length == 0) {
            revert GigEscrow__EmptyRepoInfo();
        }

        // Increment counter and create gig ID
        s_gigCounter++;
        gigId = s_gigCounter;

        // Create the gig struct
        s_gigs[gigId] = Gig({
            client: msg.sender,
            freelancer: freelancer,
            amount: amount,
            repoOwner: repoOwner,
            repoName: repoName,
            prId: prId,
            isOpen: true,
            createdAt: block.timestamp
        });

        // Transfer MNEE tokens from client to this contract
        // Requires prior approval from the client
        i_mneeToken.safeTransferFrom(msg.sender, address(this), amount);

        emit GigCreated(gigId, msg.sender, freelancer, amount, repoOwner, repoName, prId);
        emit GigFunded(gigId, amount);

        return gigId;
    }

    /**
     * @notice Initiates verification of work by checking if the PR is merged
     * @dev Sends a request to Chainlink Functions DON to check GitHub API
     * @param gigId The ID of the gig to verify
     * @return requestId The Chainlink Functions request ID
     */
    function verifyWork(uint256 gigId)
        external
        gigExists(gigId)
        gigIsOpen(gigId)
        nonReentrant
        returns (bytes32 requestId)
    {
        Gig storage gig = s_gigs[gigId];

        // Only client, freelancer, or owner can trigger verification
        if (msg.sender != gig.client && msg.sender != gig.freelancer && msg.sender != owner()) {
            revert GigEscrow__UnauthorizedCaller();
        }

        // Prevent multiple pending requests for the same gig
        if (s_gigHasPendingRequest[gigId]) {
            revert GigEscrow__RequestAlreadyPending();
        }

        // Build the Chainlink Functions request
        // The request contains the JavaScript source and arguments
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(s_source);

        // Set the arguments: [owner, repo, prNumber]
        string[] memory args = new string[](3);
        args[0] = gig.repoOwner;
        args[1] = gig.repoName;
        args[2] = gig.prId;
        req.setArgs(args);

        // Send the request to Chainlink Functions
        // This will trigger the DON to execute our JavaScript code
        requestId = _sendRequest(
            req.encodeCBOR(),
            s_subscriptionId,
            s_callbackGasLimit,
            s_donId
        );

        // Track the pending request
        s_pendingRequests[requestId] = PendingRequest({
            gigId: gigId,
            exists: true
        });
        s_gigHasPendingRequest[gigId] = true;

        emit WorkVerificationRequested(gigId, requestId, msg.sender);

        return requestId;
    }

    /**
     * @notice Allows the client to cancel a gig and reclaim funds
     * @dev Can only be called by the client, and only if no pending verification
     * @param gigId The ID of the gig to cancel
     */
    function cancelGig(uint256 gigId)
        external
        gigExists(gigId)
        gigIsOpen(gigId)
        nonReentrant
    {
        Gig storage gig = s_gigs[gigId];

        // Only the client can cancel
        if (msg.sender != gig.client) {
            revert GigEscrow__UnauthorizedCaller();
        }

        // Cannot cancel if there's a pending verification
        if (s_gigHasPendingRequest[gigId]) {
            revert GigEscrow__RequestAlreadyPending();
        }

        // Require minimum time before cancellation (e.g., 24 hours)
        // This gives the freelancer time to complete work
        if (block.timestamp < gig.createdAt + 24 hours) {
            revert GigEscrow__GigTooRecent();
        }

        // Close the gig
        gig.isOpen = false;

        // Return funds to client
        i_mneeToken.safeTransfer(gig.client, gig.amount);

        emit GigCancelled(gigId, gig.client, gig.amount);
    }

    // ============ Internal Functions ============

    /**
     * @notice Callback function invoked by Chainlink Functions with the result
     * @dev This is called by the Chainlink Router after DON execution
     * @param requestId The request ID returned by sendRequest
     * @param response The response bytes from the DON (encoded uint256)
     * @param err Any error bytes from the DON execution
     */
    function fulfillRequest(
        bytes32 requestId,
        bytes memory response,
        bytes memory err
    ) internal override {
        // Retrieve the pending request info
        PendingRequest memory pendingRequest = s_pendingRequests[requestId];

        // Validate the request exists
        if (!pendingRequest.exists) {
            revert GigEscrow__RequestNotFound();
        }

        uint256 gigId = pendingRequest.gigId;
        Gig storage gig = s_gigs[gigId];

        // Clear the pending request tracking
        delete s_pendingRequests[requestId];
        s_gigHasPendingRequest[gigId] = false;

        // Check if there was an error in the DON execution
        if (err.length > 0) {
            // Log the error but don't release funds
            // The verification can be retried
            emit WorkVerified(gigId, requestId, false);
            return;
        }

        // Decode the response - expecting a uint256 (1 = merged, 0 = not merged)
        // The response is ABI encoded by Functions.encodeUint256() in the JS
        uint256 result = abi.decode(response, (uint256));
        bool isMerged = result == 1;

        emit WorkVerified(gigId, requestId, isMerged);

        // If PR is merged and gig is still open, release payment
        if (isMerged && gig.isOpen) {
            // Mark gig as closed BEFORE transfer (CEI pattern)
            gig.isOpen = false;

            // Transfer MNEE tokens to the freelancer
            i_mneeToken.safeTransfer(gig.freelancer, gig.amount);

            emit PaymentReleased(gigId, gig.freelancer, gig.amount);
        }
        // If not merged, funds remain locked and verification can be retried
    }

    // ============ Admin Functions ============

    /**
     * @notice Updates the JavaScript source code for verification
     * @dev Only callable by the contract owner
     * @param newSource The new JavaScript source code
     */
    function updateSource(string calldata newSource) external onlyOwner {
        if (bytes(newSource).length == 0) revert GigEscrow__EmptySource();
        s_source = newSource;
        emit SourceUpdated(newSource);
    }

    /**
     * @notice Updates Chainlink Functions configuration
     * @dev Only callable by the contract owner
     * @param subscriptionId New subscription ID
     * @param donId New DON ID
     * @param callbackGasLimit New callback gas limit
     */
    function updateChainlinkConfig(
        uint64 subscriptionId,
        bytes32 donId,
        uint32 callbackGasLimit
    ) external onlyOwner {
        s_subscriptionId = subscriptionId;
        s_donId = donId;
        s_callbackGasLimit = callbackGasLimit;
        emit ChainlinkConfigUpdated(subscriptionId, donId, callbackGasLimit);
    }

    // ============ View Functions ============

    /**
     * @notice Returns the full details of a gig
     * @param gigId The ID of the gig to query
     * @return The Gig struct with all details
     */
    function getGig(uint256 gigId) external view gigExists(gigId) returns (Gig memory) {
        return s_gigs[gigId];
    }

    /**
     * @notice Returns the total number of gigs created
     * @return The current gig counter value
     */
    function getGigCount() external view returns (uint256) {
        return s_gigCounter;
    }

    /**
     * @notice Checks if a gig has a pending verification request
     * @param gigId The ID of the gig to check
     * @return True if there's a pending request
     */
    function hasPendingRequest(uint256 gigId) external view returns (bool) {
        return s_gigHasPendingRequest[gigId];
    }

    /**
     * @notice Returns the MNEE token address
     * @return The address of the MNEE ERC20 token
     */
    function getMneeToken() external view returns (address) {
        return address(i_mneeToken);
    }

    /**
     * @notice Returns the current Chainlink Functions configuration
     * @return subscriptionId The subscription ID
     * @return donId The DON ID
     * @return callbackGasLimit The callback gas limit
     */
    function getChainlinkConfig()
        external
        view
        returns (uint64 subscriptionId, bytes32 donId, uint32 callbackGasLimit)
    {
        return (s_subscriptionId, s_donId, s_callbackGasLimit);
    }
}
