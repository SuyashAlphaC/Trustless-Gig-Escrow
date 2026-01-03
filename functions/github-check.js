/**
 * @title GitHub PR Merge Status Checker
 * @notice This script is executed by the Chainlink DON (Decentralized Oracle Network)
 * @dev Chainlink Functions script to verify if a GitHub Pull Request has been merged
 * 
 * Arguments:
 *   args[0] - owner: GitHub username/organization (e.g., "ethereum")
 *   args[1] - repo: Repository name (e.g., "go-ethereum")
 *   args[2] - prNumber: Pull Request number (e.g., "12345")
 * 
 * Returns:
 *   - 1 (uint256) if the PR is merged
 *   - 0 (uint256) if the PR is not merged or doesn't exist
 */

// Validate that all required arguments are provided
if (!args || args.length < 3) {
  throw Error("Missing required arguments: owner, repo, prNumber");
}

const owner = args[0];
const repo = args[1];
const prNumber = args[2];

// Validate arguments are not empty
if (!owner || !repo || !prNumber) {
  throw Error("Arguments cannot be empty");
}

// Validate prNumber is a valid number
if (isNaN(parseInt(prNumber))) {
  throw Error("prNumber must be a valid number");
}

// Construct the GitHub API URL for the Pull Request
const apiUrl = `https://api.github.com/repos/${owner}/${repo}/pulls/${prNumber}`;

console.log(`Fetching PR status from: ${apiUrl}`);

// Make the HTTP GET request to GitHub API
// Note: GitHub API has rate limits (60 requests/hour for unauthenticated requests)
// For production, consider using a GitHub token via secrets
const response = await Functions.makeHttpRequest({
  url: apiUrl,
  method: "GET",
  headers: {
    "Accept": "application/vnd.github.v3+json",
    "User-Agent": "Chainlink-Functions-GigEscrow"
  }
});

// Handle HTTP errors
if (response.error) {
  console.error(`HTTP request failed: ${response.error}`);
  // Return 0 for any error (PR not verified as merged)
  return Functions.encodeUint256(0);
}

// Check if the response status indicates success
if (response.status !== 200) {
  console.error(`GitHub API returned status ${response.status}`);
  // Return 0 if PR doesn't exist or other API error
  return Functions.encodeUint256(0);
}

// Parse the response data
const prData = response.data;

// Log PR details for debugging (visible in Chainlink Functions logs)
console.log(`PR #${prNumber} - Title: ${prData.title}`);
console.log(`PR State: ${prData.state}`);
console.log(`PR Merged: ${prData.merged}`);

// Check if the PR has been merged
// The 'merged' field is a boolean that indicates if the PR was merged
const isMerged = prData.merged === true;

console.log(`Returning: ${isMerged ? 1 : 0}`);

// Return 1 if merged, 0 if not merged
// The result is encoded as a uint256 for the smart contract to decode
return Functions.encodeUint256(isMerged ? 1 : 0);
