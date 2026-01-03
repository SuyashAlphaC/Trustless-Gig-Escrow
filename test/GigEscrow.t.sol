// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {GigEscrow} from "../src/GigEscrow.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockFunctionsRouter} from "./mocks/MockFunctionsRouter.sol";

/**
 * @title GigEscrowTest
 * @notice Comprehensive test suite for the GigEscrow contract
 * @dev Tests all core functionality including gig creation, verification, and payment release
 */
contract GigEscrowTest is Test {
    // ============ State Variables ============

    GigEscrow public escrow;
    MockERC20 public mneeToken;
    MockFunctionsRouter public mockRouter;

    // Test accounts
    address public owner;
    address public client;
    address public freelancer;
    address public randomUser;

    // Test constants
    uint256 public constant INITIAL_BALANCE = 10000 ether;
    uint256 public constant GIG_AMOUNT = 100 ether;
    uint64 public constant SUBSCRIPTION_ID = 1;
    bytes32 public constant DON_ID = bytes32("fun-ethereum-sepolia-1");
    uint32 public constant CALLBACK_GAS_LIMIT = 300000;

    // Test GitHub repo info
    string public constant REPO_OWNER = "ethereum";
    string public constant REPO_NAME = "go-ethereum";
    string public constant PR_ID = "12345";

    // Sample JavaScript source for testing
    string public constant JS_SOURCE = 
        "const owner = args[0];"
        "const repo = args[1];"
        "const prNumber = args[2];"
        "return Functions.encodeUint256(1);";

    // ============ Events (for testing) ============

    event GigCreated(
        uint256 indexed gigId,
        address indexed client,
        address indexed freelancer,
        uint256 amount,
        string repoOwner,
        string repoName,
        string prId
    );

    event GigFunded(uint256 indexed gigId, uint256 amount);

    event WorkVerificationRequested(
        uint256 indexed gigId,
        bytes32 indexed requestId,
        address indexed requester
    );

    event WorkVerified(
        uint256 indexed gigId,
        bytes32 indexed requestId,
        bool isMerged
    );

    event PaymentReleased(
        uint256 indexed gigId,
        address indexed freelancer,
        uint256 amount
    );

    event GigCancelled(uint256 indexed gigId, address indexed client, uint256 amount);

    // ============ Setup ============

    function setUp() public {
        // Create test accounts
        owner = makeAddr("owner");
        client = makeAddr("client");
        freelancer = makeAddr("freelancer");
        randomUser = makeAddr("randomUser");

        // Deploy contracts as owner
        vm.startPrank(owner);

        // Deploy mock MNEE token
        mneeToken = new MockERC20("MNEE Token", "MNEE", 18);

        // Deploy mock Chainlink Functions Router
        mockRouter = new MockFunctionsRouter();

        // Deploy GigEscrow contract
        escrow = new GigEscrow(
            address(mockRouter),
            address(mneeToken),
            SUBSCRIPTION_ID,
            DON_ID,
            CALLBACK_GAS_LIMIT,
            JS_SOURCE
        );

        vm.stopPrank();

        // Mint tokens to client
        mneeToken.mint(client, INITIAL_BALANCE);

        // Approve escrow contract to spend client's tokens
        vm.prank(client);
        mneeToken.approve(address(escrow), type(uint256).max);
    }

    // ============ Constructor Tests ============

    function test_Constructor_SetsCorrectValues() public view {
        assertEq(escrow.getMneeToken(), address(mneeToken));
        assertEq(escrow.owner(), owner);

        (uint64 subId, bytes32 donId, uint32 gasLimit) = escrow.getChainlinkConfig();
        assertEq(subId, SUBSCRIPTION_ID);
        assertEq(donId, DON_ID);
        assertEq(gasLimit, CALLBACK_GAS_LIMIT);
    }

    function test_Constructor_RevertsOnZeroTokenAddress() public {
        vm.prank(owner);
        vm.expectRevert(GigEscrow.GigEscrow__InvalidAddress.selector);
        new GigEscrow(
            address(mockRouter),
            address(0),
            SUBSCRIPTION_ID,
            DON_ID,
            CALLBACK_GAS_LIMIT,
            JS_SOURCE
        );
    }

    function test_Constructor_RevertsOnEmptySource() public {
        vm.prank(owner);
        vm.expectRevert(GigEscrow.GigEscrow__EmptySource.selector);
        new GigEscrow(
            address(mockRouter),
            address(mneeToken),
            SUBSCRIPTION_ID,
            DON_ID,
            CALLBACK_GAS_LIMIT,
            ""
        );
    }

    // ============ createGig Tests ============

    function test_CreateGig_Success() public {
        vm.prank(client);

        vm.expectEmit(true, true, true, true);
        emit GigCreated(1, client, freelancer, GIG_AMOUNT, REPO_OWNER, REPO_NAME, PR_ID);

        vm.expectEmit(true, false, false, true);
        emit GigFunded(1, GIG_AMOUNT);

        uint256 gigId = escrow.createGig(
            freelancer,
            GIG_AMOUNT,
            REPO_OWNER,
            REPO_NAME,
            PR_ID
        );

        assertEq(gigId, 1);
        assertEq(escrow.getGigCount(), 1);

        // Verify gig details
        GigEscrow.Gig memory gig = escrow.getGig(gigId);
        assertEq(gig.client, client);
        assertEq(gig.freelancer, freelancer);
        assertEq(gig.amount, GIG_AMOUNT);
        assertEq(gig.repoOwner, REPO_OWNER);
        assertEq(gig.repoName, REPO_NAME);
        assertEq(gig.prId, PR_ID);
        assertTrue(gig.isOpen);

        // Verify token transfer
        assertEq(mneeToken.balanceOf(address(escrow)), GIG_AMOUNT);
        assertEq(mneeToken.balanceOf(client), INITIAL_BALANCE - GIG_AMOUNT);
    }

    function test_CreateGig_MultipleGigs() public {
        vm.startPrank(client);

        uint256 gigId1 = escrow.createGig(freelancer, GIG_AMOUNT, REPO_OWNER, REPO_NAME, "1");
        uint256 gigId2 = escrow.createGig(freelancer, GIG_AMOUNT * 2, REPO_OWNER, REPO_NAME, "2");
        uint256 gigId3 = escrow.createGig(freelancer, GIG_AMOUNT / 2, REPO_OWNER, REPO_NAME, "3");

        vm.stopPrank();

        assertEq(gigId1, 1);
        assertEq(gigId2, 2);
        assertEq(gigId3, 3);
        assertEq(escrow.getGigCount(), 3);

        // Verify total tokens locked
        uint256 totalLocked = GIG_AMOUNT + (GIG_AMOUNT * 2) + (GIG_AMOUNT / 2);
        assertEq(mneeToken.balanceOf(address(escrow)), totalLocked);
    }

    function test_CreateGig_RevertsOnZeroFreelancerAddress() public {
        vm.prank(client);
        vm.expectRevert(GigEscrow.GigEscrow__InvalidAddress.selector);
        escrow.createGig(address(0), GIG_AMOUNT, REPO_OWNER, REPO_NAME, PR_ID);
    }

    function test_CreateGig_RevertsOnSameClientAndFreelancer() public {
        vm.prank(client);
        vm.expectRevert(GigEscrow.GigEscrow__InvalidAddress.selector);
        escrow.createGig(client, GIG_AMOUNT, REPO_OWNER, REPO_NAME, PR_ID);
    }

    function test_CreateGig_RevertsOnZeroAmount() public {
        vm.prank(client);
        vm.expectRevert(GigEscrow.GigEscrow__InvalidAmount.selector);
        escrow.createGig(freelancer, 0, REPO_OWNER, REPO_NAME, PR_ID);
    }

    function test_CreateGig_RevertsOnEmptyRepoInfo() public {
        vm.startPrank(client);

        vm.expectRevert(GigEscrow.GigEscrow__EmptyRepoInfo.selector);
        escrow.createGig(freelancer, GIG_AMOUNT, "", REPO_NAME, PR_ID);

        vm.expectRevert(GigEscrow.GigEscrow__EmptyRepoInfo.selector);
        escrow.createGig(freelancer, GIG_AMOUNT, REPO_OWNER, "", PR_ID);

        vm.expectRevert(GigEscrow.GigEscrow__EmptyRepoInfo.selector);
        escrow.createGig(freelancer, GIG_AMOUNT, REPO_OWNER, REPO_NAME, "");

        vm.stopPrank();
    }

    function test_CreateGig_RevertsOnInsufficientBalance() public {
        address poorClient = makeAddr("poorClient");
        mneeToken.mint(poorClient, GIG_AMOUNT / 2);

        vm.startPrank(poorClient);
        mneeToken.approve(address(escrow), type(uint256).max);

        vm.expectRevert(); // ERC20 insufficient balance
        escrow.createGig(freelancer, GIG_AMOUNT, REPO_OWNER, REPO_NAME, PR_ID);

        vm.stopPrank();
    }

    // ============ verifyWork Tests ============

    function test_VerifyWork_Success() public {
        // Create a gig first
        vm.prank(client);
        uint256 gigId = escrow.createGig(freelancer, GIG_AMOUNT, REPO_OWNER, REPO_NAME, PR_ID);

        // Verify work as freelancer
        vm.prank(freelancer);

        vm.expectEmit(true, false, true, false);
        emit WorkVerificationRequested(gigId, bytes32(0), freelancer);

        bytes32 requestId = escrow.verifyWork(gigId);

        assertTrue(requestId != bytes32(0));
        assertTrue(escrow.hasPendingRequest(gigId));
    }

    function test_VerifyWork_ClientCanVerify() public {
        vm.prank(client);
        uint256 gigId = escrow.createGig(freelancer, GIG_AMOUNT, REPO_OWNER, REPO_NAME, PR_ID);

        vm.prank(client);
        bytes32 requestId = escrow.verifyWork(gigId);

        assertTrue(requestId != bytes32(0));
    }

    function test_VerifyWork_OwnerCanVerify() public {
        vm.prank(client);
        uint256 gigId = escrow.createGig(freelancer, GIG_AMOUNT, REPO_OWNER, REPO_NAME, PR_ID);

        vm.prank(owner);
        bytes32 requestId = escrow.verifyWork(gigId);

        assertTrue(requestId != bytes32(0));
    }

    function test_VerifyWork_RevertsOnInvalidGigId() public {
        vm.prank(client);
        vm.expectRevert(GigEscrow.GigEscrow__InvalidGigId.selector);
        escrow.verifyWork(999);
    }

    function test_VerifyWork_RevertsOnUnauthorizedCaller() public {
        vm.prank(client);
        uint256 gigId = escrow.createGig(freelancer, GIG_AMOUNT, REPO_OWNER, REPO_NAME, PR_ID);

        vm.prank(randomUser);
        vm.expectRevert(GigEscrow.GigEscrow__UnauthorizedCaller.selector);
        escrow.verifyWork(gigId);
    }

    function test_VerifyWork_RevertsOnPendingRequest() public {
        vm.prank(client);
        uint256 gigId = escrow.createGig(freelancer, GIG_AMOUNT, REPO_OWNER, REPO_NAME, PR_ID);

        vm.prank(freelancer);
        escrow.verifyWork(gigId);

        // Try to verify again while request is pending
        vm.prank(freelancer);
        vm.expectRevert(GigEscrow.GigEscrow__RequestAlreadyPending.selector);
        escrow.verifyWork(gigId);
    }

    // ============ fulfillRequest Tests (Successful Release) ============

    function test_SuccessfulRelease_PRMerged() public {
        // Create a gig
        vm.prank(client);
        uint256 gigId = escrow.createGig(freelancer, GIG_AMOUNT, REPO_OWNER, REPO_NAME, PR_ID);

        // Verify work
        vm.prank(freelancer);
        bytes32 requestId = escrow.verifyWork(gigId);

        // Record freelancer balance before
        uint256 freelancerBalanceBefore = mneeToken.balanceOf(freelancer);

        // Simulate Chainlink DON response: PR is merged (1)
        bytes memory response = abi.encode(uint256(1));

        vm.expectEmit(true, true, false, true);
        emit WorkVerified(gigId, requestId, true);

        vm.expectEmit(true, true, false, true);
        emit PaymentReleased(gigId, freelancer, GIG_AMOUNT);

        mockRouter.fulfillRequest(requestId, response);

        // Verify state changes
        GigEscrow.Gig memory gig = escrow.getGig(gigId);
        assertFalse(gig.isOpen);
        assertFalse(escrow.hasPendingRequest(gigId));

        // Verify token transfer to freelancer
        assertEq(mneeToken.balanceOf(freelancer), freelancerBalanceBefore + GIG_AMOUNT);
        assertEq(mneeToken.balanceOf(address(escrow)), 0);
    }

    // ============ fulfillRequest Tests (Failed Release) ============

    function test_FailedRelease_PRNotMerged() public {
        // Create a gig
        vm.prank(client);
        uint256 gigId = escrow.createGig(freelancer, GIG_AMOUNT, REPO_OWNER, REPO_NAME, PR_ID);

        // Verify work
        vm.prank(freelancer);
        bytes32 requestId = escrow.verifyWork(gigId);

        // Record balances before
        uint256 freelancerBalanceBefore = mneeToken.balanceOf(freelancer);
        uint256 escrowBalanceBefore = mneeToken.balanceOf(address(escrow));

        // Simulate Chainlink DON response: PR is NOT merged (0)
        bytes memory response = abi.encode(uint256(0));

        vm.expectEmit(true, true, false, true);
        emit WorkVerified(gigId, requestId, false);

        mockRouter.fulfillRequest(requestId, response);

        // Verify state - gig should still be open
        GigEscrow.Gig memory gig = escrow.getGig(gigId);
        assertTrue(gig.isOpen);
        assertFalse(escrow.hasPendingRequest(gigId));

        // Verify funds remain locked
        assertEq(mneeToken.balanceOf(freelancer), freelancerBalanceBefore);
        assertEq(mneeToken.balanceOf(address(escrow)), escrowBalanceBefore);
    }

    function test_FailedRelease_DONError() public {
        // Create a gig
        vm.prank(client);
        uint256 gigId = escrow.createGig(freelancer, GIG_AMOUNT, REPO_OWNER, REPO_NAME, PR_ID);

        // Verify work
        vm.prank(freelancer);
        bytes32 requestId = escrow.verifyWork(gigId);

        // Record balances before
        uint256 freelancerBalanceBefore = mneeToken.balanceOf(freelancer);
        uint256 escrowBalanceBefore = mneeToken.balanceOf(address(escrow));

        // Simulate Chainlink DON error response
        bytes memory errorData = abi.encodePacked("GitHub API error");

        vm.expectEmit(true, true, false, true);
        emit WorkVerified(gigId, requestId, false);

        mockRouter.fulfillRequestWithError(requestId, errorData);

        // Verify state - gig should still be open
        GigEscrow.Gig memory gig = escrow.getGig(gigId);
        assertTrue(gig.isOpen);
        assertFalse(escrow.hasPendingRequest(gigId));

        // Verify funds remain locked
        assertEq(mneeToken.balanceOf(freelancer), freelancerBalanceBefore);
        assertEq(mneeToken.balanceOf(address(escrow)), escrowBalanceBefore);
    }

    function test_RetryVerification_AfterFailure() public {
        // Create a gig
        vm.prank(client);
        uint256 gigId = escrow.createGig(freelancer, GIG_AMOUNT, REPO_OWNER, REPO_NAME, PR_ID);

        // First verification attempt - PR not merged
        vm.prank(freelancer);
        bytes32 requestId1 = escrow.verifyWork(gigId);

        mockRouter.fulfillRequest(requestId1, abi.encode(uint256(0)));

        // Gig should still be open, can retry
        assertTrue(escrow.getGig(gigId).isOpen);
        assertFalse(escrow.hasPendingRequest(gigId));

        // Second verification attempt - PR now merged
        vm.prank(freelancer);
        bytes32 requestId2 = escrow.verifyWork(gigId);

        mockRouter.fulfillRequest(requestId2, abi.encode(uint256(1)));

        // Now gig should be closed and payment released
        assertFalse(escrow.getGig(gigId).isOpen);
        assertEq(mneeToken.balanceOf(freelancer), GIG_AMOUNT);
    }

    // ============ cancelGig Tests ============

    function test_CancelGig_Success() public {
        vm.prank(client);
        uint256 gigId = escrow.createGig(freelancer, GIG_AMOUNT, REPO_OWNER, REPO_NAME, PR_ID);

        // Fast forward 24 hours
        vm.warp(block.timestamp + 24 hours + 1);

        uint256 clientBalanceBefore = mneeToken.balanceOf(client);

        vm.prank(client);

        vm.expectEmit(true, true, false, true);
        emit GigCancelled(gigId, client, GIG_AMOUNT);

        escrow.cancelGig(gigId);

        // Verify state
        GigEscrow.Gig memory gig = escrow.getGig(gigId);
        assertFalse(gig.isOpen);

        // Verify refund
        assertEq(mneeToken.balanceOf(client), clientBalanceBefore + GIG_AMOUNT);
        assertEq(mneeToken.balanceOf(address(escrow)), 0);
    }

    function test_CancelGig_RevertsOnUnauthorized() public {
        vm.prank(client);
        uint256 gigId = escrow.createGig(freelancer, GIG_AMOUNT, REPO_OWNER, REPO_NAME, PR_ID);

        vm.warp(block.timestamp + 24 hours + 1);

        vm.prank(freelancer);
        vm.expectRevert(GigEscrow.GigEscrow__UnauthorizedCaller.selector);
        escrow.cancelGig(gigId);
    }

    function test_CancelGig_RevertsOnPendingRequest() public {
        vm.prank(client);
        uint256 gigId = escrow.createGig(freelancer, GIG_AMOUNT, REPO_OWNER, REPO_NAME, PR_ID);

        vm.prank(freelancer);
        escrow.verifyWork(gigId);

        vm.warp(block.timestamp + 24 hours + 1);

        vm.prank(client);
        vm.expectRevert(GigEscrow.GigEscrow__RequestAlreadyPending.selector);
        escrow.cancelGig(gigId);
    }

    function test_CancelGig_RevertsOnTooRecent() public {
        vm.prank(client);
        uint256 gigId = escrow.createGig(freelancer, GIG_AMOUNT, REPO_OWNER, REPO_NAME, PR_ID);

        // Try to cancel immediately (before 24 hours)
        vm.prank(client);
        vm.expectRevert(GigEscrow.GigEscrow__GigTooRecent.selector);
        escrow.cancelGig(gigId);
    }

    function test_CancelGig_RevertsOnClosedGig() public {
        vm.prank(client);
        uint256 gigId = escrow.createGig(freelancer, GIG_AMOUNT, REPO_OWNER, REPO_NAME, PR_ID);

        // Complete the gig first
        vm.prank(freelancer);
        bytes32 requestId = escrow.verifyWork(gigId);
        mockRouter.fulfillRequest(requestId, abi.encode(uint256(1)));

        vm.warp(block.timestamp + 24 hours + 1);

        // Try to cancel closed gig
        vm.prank(client);
        vm.expectRevert(GigEscrow.GigEscrow__GigNotOpen.selector);
        escrow.cancelGig(gigId);
    }

    // ============ Admin Functions Tests ============

    function test_UpdateSource_Success() public {
        string memory newSource = "return Functions.encodeUint256(0);";

        vm.prank(owner);
        escrow.updateSource(newSource);

        assertEq(escrow.s_source(), newSource);
    }

    function test_UpdateSource_RevertsOnNonOwner() public {
        vm.prank(randomUser);
        vm.expectRevert("Only callable by owner");
        escrow.updateSource("new source");
    }

    function test_UpdateSource_RevertsOnEmptySource() public {
        vm.prank(owner);
        vm.expectRevert(GigEscrow.GigEscrow__EmptySource.selector);
        escrow.updateSource("");
    }

    function test_UpdateChainlinkConfig_Success() public {
        uint64 newSubId = 999;
        bytes32 newDonId = bytes32("new-don-id");
        uint32 newGasLimit = 500000;

        vm.prank(owner);
        escrow.updateChainlinkConfig(newSubId, newDonId, newGasLimit);

        (uint64 subId, bytes32 donId, uint32 gasLimit) = escrow.getChainlinkConfig();
        assertEq(subId, newSubId);
        assertEq(donId, newDonId);
        assertEq(gasLimit, newGasLimit);
    }

    function test_UpdateChainlinkConfig_RevertsOnNonOwner() public {
        vm.prank(randomUser);
        vm.expectRevert("Only callable by owner");
        escrow.updateChainlinkConfig(999, bytes32("test"), 500000);
    }

    // ============ View Functions Tests ============

    function test_GetGig_RevertsOnInvalidId() public {
        vm.expectRevert(GigEscrow.GigEscrow__InvalidGigId.selector);
        escrow.getGig(0);

        vm.expectRevert(GigEscrow.GigEscrow__InvalidGigId.selector);
        escrow.getGig(999);
    }

    function test_GetGigCount_ReturnsCorrectCount() public {
        assertEq(escrow.getGigCount(), 0);

        vm.startPrank(client);
        escrow.createGig(freelancer, GIG_AMOUNT, REPO_OWNER, REPO_NAME, "1");
        assertEq(escrow.getGigCount(), 1);

        escrow.createGig(freelancer, GIG_AMOUNT, REPO_OWNER, REPO_NAME, "2");
        assertEq(escrow.getGigCount(), 2);
        vm.stopPrank();
    }

    // ============ Edge Cases & Security Tests ============

    function test_CannotVerifyClosedGig() public {
        vm.prank(client);
        uint256 gigId = escrow.createGig(freelancer, GIG_AMOUNT, REPO_OWNER, REPO_NAME, PR_ID);

        // Complete the gig
        vm.prank(freelancer);
        bytes32 requestId = escrow.verifyWork(gigId);
        mockRouter.fulfillRequest(requestId, abi.encode(uint256(1)));

        // Try to verify again
        vm.prank(freelancer);
        vm.expectRevert(GigEscrow.GigEscrow__GigNotOpen.selector);
        escrow.verifyWork(gigId);
    }

    function test_OnlyRouterCanFulfill() public {
        vm.prank(client);
        uint256 gigId = escrow.createGig(freelancer, GIG_AMOUNT, REPO_OWNER, REPO_NAME, PR_ID);

        vm.prank(freelancer);
        bytes32 requestId = escrow.verifyWork(gigId);

        // Try to call handleOracleFulfillment directly (not from router)
        vm.prank(randomUser);
        vm.expectRevert();
        escrow.handleOracleFulfillment(requestId, abi.encode(uint256(1)), "");
    }

    // ============ Fuzz Tests ============

    function testFuzz_CreateGig_VariousAmounts(uint256 amount) public {
        // Bound amount to reasonable values
        amount = bound(amount, 1, INITIAL_BALANCE);

        vm.prank(client);
        uint256 gigId = escrow.createGig(freelancer, amount, REPO_OWNER, REPO_NAME, PR_ID);

        GigEscrow.Gig memory gig = escrow.getGig(gigId);
        assertEq(gig.amount, amount);
        assertEq(mneeToken.balanceOf(address(escrow)), amount);
    }

    function testFuzz_CreateGig_VariousRepoInfo(
        string calldata repoOwner,
        string calldata repoName,
        string calldata prId
    ) public {
        // Skip if any string is empty
        vm.assume(bytes(repoOwner).length > 0);
        vm.assume(bytes(repoName).length > 0);
        vm.assume(bytes(prId).length > 0);

        vm.prank(client);
        uint256 gigId = escrow.createGig(freelancer, GIG_AMOUNT, repoOwner, repoName, prId);

        GigEscrow.Gig memory gig = escrow.getGig(gigId);
        assertEq(gig.repoOwner, repoOwner);
        assertEq(gig.repoName, repoName);
        assertEq(gig.prId, prId);
    }
}
