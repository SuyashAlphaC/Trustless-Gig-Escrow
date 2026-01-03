// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IFunctionsRouter} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/interfaces/IFunctionsRouter.sol";
import {IFunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/interfaces/IFunctionsClient.sol";
import {FunctionsResponse} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsResponse.sol";

/**
 * @title MockFunctionsRouter
 * @notice A mock Chainlink Functions Router for testing
 * @dev Simulates the Chainlink DON behavior for unit tests
 */
contract MockFunctionsRouter is IFunctionsRouter {
    // Counter for generating unique request IDs
    uint256 private s_requestCounter;

    // Mapping of request ID to the client that made the request
    mapping(bytes32 => address) public s_requestToClient;

    // Mapping of request ID to the data sent
    mapping(bytes32 => bytes) public s_requestData;

    // Events for testing
    event RequestSent(
        bytes32 indexed requestId,
        address indexed client,
        uint64 subscriptionId,
        bytes data
    );

    event ResponseFulfilled(
        bytes32 indexed requestId,
        bytes response,
        bytes err
    );

    /**
     * @notice Simulates sending a Chainlink Functions request
     * @dev Stores the request and returns a deterministic request ID
     */
    function sendRequest(
        uint64 subscriptionId,
        bytes calldata data,
        uint16, // dataVersion - unused in mock
        uint32, // callbackGasLimit - unused in mock
        bytes32 // donId - unused in mock
    ) external override returns (bytes32 requestId) {
        s_requestCounter++;
        requestId = keccak256(abi.encodePacked(msg.sender, s_requestCounter, block.timestamp));

        s_requestToClient[requestId] = msg.sender;
        s_requestData[requestId] = data;

        emit RequestSent(requestId, msg.sender, subscriptionId, data);

        return requestId;
    }

    /**
     * @notice Simulates the DON fulfilling a request with a successful response
     * @dev Calls handleOracleFulfillment on the client contract
     * @param requestId The request ID to fulfill
     * @param response The response data (encoded uint256: 1 for merged, 0 for not merged)
     */
    function fulfillRequest(bytes32 requestId, bytes memory response) external {
        address client = s_requestToClient[requestId];
        require(client != address(0), "Request not found");

        // Clear the request
        delete s_requestToClient[requestId];
        delete s_requestData[requestId];

        // Call the client's callback function
        IFunctionsClient(client).handleOracleFulfillment(requestId, response, "");

        emit ResponseFulfilled(requestId, response, "");
    }

    /**
     * @notice Simulates the DON fulfilling a request with an error
     * @dev Calls handleOracleFulfillment on the client contract with error data
     * @param requestId The request ID to fulfill
     * @param err The error data
     */
    function fulfillRequestWithError(bytes32 requestId, bytes memory err) external {
        address client = s_requestToClient[requestId];
        require(client != address(0), "Request not found");

        // Clear the request
        delete s_requestToClient[requestId];
        delete s_requestData[requestId];

        // Call the client's callback function with error
        IFunctionsClient(client).handleOracleFulfillment(requestId, "", err);

        emit ResponseFulfilled(requestId, "", err);
    }

    /**
     * @notice Helper to encode a uint256 response (simulates Functions.encodeUint256)
     * @param value The value to encode
     * @return The ABI encoded bytes
     */
    function encodeResponse(uint256 value) external pure returns (bytes memory) {
        return abi.encode(value);
    }

    /**
     * @notice Returns the client address for a given request ID
     * @param requestId The request ID to query
     * @return The client address
     */
    function getRequestClient(bytes32 requestId) external view returns (address) {
        return s_requestToClient[requestId];
    }

    /**
     * @notice Returns the request data for a given request ID
     * @param requestId The request ID to query
     * @return The request data bytes
     */
    function getRequestData(bytes32 requestId) external view returns (bytes memory) {
        return s_requestData[requestId];
    }

    // ============ IFunctionsRouter Interface Stubs ============
    // These are required by the interface but not used in testing

    function sendRequestToProposed(
        uint64,
        bytes calldata,
        uint16,
        uint32,
        bytes32
    ) external pure override returns (bytes32) {
        revert("Not implemented in mock");
    }

    function fulfill(
        bytes memory,
        bytes memory,
        uint96,
        uint96,
        address,
        FunctionsResponse.Commitment memory
    ) external pure override returns (FunctionsResponse.FulfillResult, uint96) {
        revert("Not implemented in mock");
    }

    function isValidCallbackGasLimit(uint64, uint32) external pure override {
        // No-op for mock
    }

    function getAdminFee() external pure override returns (uint72) {
        return 0;
    }

    function getAllowListId() external pure override returns (bytes32) {
        return bytes32(0);
    }

    function setAllowListId(bytes32) external pure override {
        // No-op for mock
    }

    function getProposedContractById(bytes32) external pure override returns (address) {
        return address(0);
    }

    function getContractById(bytes32) external pure override returns (address) {
        return address(0);
    }

    function getProposedContractSet() external pure override returns (bytes32[] memory, address[] memory) {
        bytes32[] memory ids = new bytes32[](0);
        address[] memory addrs = new address[](0);
        return (ids, addrs);
    }

    function proposeContractsUpdate(bytes32[] memory, address[] memory) external pure override {
        // No-op for mock
    }

    function updateContracts() external pure override {
        // No-op for mock
    }

    function pause() external pure override {
        // No-op for mock
    }

    function unpause() external pure override {
        // No-op for mock
    }
}
