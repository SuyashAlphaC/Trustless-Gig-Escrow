# MNEE Gig Escrow - Trustless Freelance Payment System

A decentralized escrow system where clients deposit MNEE tokens (ERC20) that are automatically released to freelancers when a specific GitHub Pull Request is merged. Verification is done trustlessly using **Chainlink Functions**.

## 🏗️ Architecture

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│     Client      │────▶│   GigEscrow.sol  │────▶│   Freelancer    │
│  (Deposits MNEE)│     │   (Smart Contract)│     │ (Receives MNEE) │
└─────────────────┘     └────────┬─────────┘     └─────────────────┘
                                 │
                                 │ verifyWork()
                                 ▼
                        ┌──────────────────┐
                        │ Chainlink DON    │
                        │ (Decentralized   │
                        │  Oracle Network) │
                        └────────┬─────────┘
                                 │
                                 │ HTTP Request
                                 ▼
                        ┌──────────────────┐
                        │   GitHub API     │
                        │ /repos/{owner}/  │
                        │ {repo}/pulls/{pr}│
                        └──────────────────┘
```

## 🚀 Features

- **Trustless Verification**: PR merge status verified by Chainlink's decentralized oracle network
- **Automatic Payment Release**: Funds released instantly when PR is confirmed merged
- **Secure Escrow**: Funds locked in smart contract until conditions are met
- **Retry Mechanism**: Failed verifications can be retried without losing funds
- **Client Protection**: 24-hour cancellation window for clients
- **Multi-Network Support**: Deployable on Sepolia, Mainnet, Polygon, Arbitrum, Base, and more

## 📁 Project Structure

```
mnee-gig-escrow/
├── src/
│   └── GigEscrow.sol          # Main escrow contract
|   └── MockMNEE.sol           # Mock MNEE token for Demo
├── test/
│   ├── GigEscrow.t.sol        # Comprehensive test suite
│   └── mocks/
│       ├── MockERC20.sol      # Mock MNEE token
│       └── MockFunctionsRouter.sol  # Mock Chainlink Router
├── script/
│   └── Deploy.s.sol           # Deployment scripts for the Escrow Contract
|   └── DeployMockMNEE.s.sol   # Deployment script for the Mock MNEE Token on testnets 
├── functions/
│   └── github-check.js        # Chainlink Functions source
├── foundry.toml               # Foundry configuration
├── remappings.txt             # Import remappings
└── README.md
```

## 🛠️ Installation

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- [Git](https://git-scm.com/)

### Setup

```bash
# Clone the repository
cd mnee-gig-escrow

# Install dependencies
forge install

# Copy environment file
cp .env.example .env

# Edit .env with your configuration
```

## 🧪 Testing

```bash
# Run all tests
forge test

# Run tests with verbosity
forge test -vvv

# Run specific test
forge test --match-test testSuccessfulRelease -vvv

# Run tests with gas report
forge test --gas-report

# Run coverage
forge coverage
```

## 📦 Deployment

### Local (Anvil)

```bash
# Start local node
anvil

# Deploy with local script
forge script script/DeployMockMNEE.s.sol:DeployMockMNEE --rpc-url http://localhost:8545 --broadcast
forge script script/Deploy.s.sol:DeployGigEscrowLocal --rpc-url http://localhost:8545 --broadcast
```



### Testnet (Sepolia)

```bash
# Set environment variables
export SEPOLIA_RPC_URL="your_rpc_url"
export PRIVATE_KEY="your_private_key"
export CHAINLINK_SUBSCRIPTION_ID="your_subscription_id"
export MNEE_TOKEN_ADDRESS="your_mnee_token_address"

# Deploy
forge script script/DeployMockMNEE.s.sol:DeployMockMNEE --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY 
forge script script/Deploy.s.sol:DeployGigEscrow --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --broadcast --verify
```

### Post-Deployment Steps

1. **Add Contract as Consumer**: Add the deployed GigEscrow address to your Chainlink Functions subscription
2. **Fund Subscription**: Ensure your subscription has enough LINK tokens
3. **Verify Contract**: Verify on Etherscan for transparency

## 📖 Usage

### Creating a Gig (Client)

```solidity
// 1. Approve MNEE tokens
mneeToken.approve(gigEscrowAddress, amount);

// 2. Create the gig
uint256 gigId = gigEscrow.createGig(
    freelancerAddress,  // Freelancer's wallet
    100 ether,          // Payment amount in MNEE
    "ethereum",         // GitHub repo owner
    "go-ethereum",      // Repository name
    "12345"             // Pull Request number
);
```

### Verifying Work (Freelancer/Client/Owner)

```solidity
// Request verification from Chainlink
bytes32 requestId = gigEscrow.verifyWork(gigId);

// Chainlink DON will:
// 1. Execute github-check.js
// 2. Fetch PR status from GitHub API
// 3. Call fulfillRequest() with result
// 4. If merged, automatically release payment
```

### Cancelling a Gig (Client Only)

```solidity
// After 24 hours, client can cancel if PR not merged
gigEscrow.cancelGig(gigId);
```

## 🔧 Configuration

### Chainlink Functions Networks

| Network | Chain ID | Router Address |
|---------|----------|----------------|
| Sepolia | 11155111 | `0xb83E47C2bC239B3bf370bc41e1459A34b41238D0` |
| Mainnet | 1 | `0x65Dcc24F8ff9e51F10DCc7Ed1e4e2A61e6E14bd6` |
| Polygon | 137 | `0xdc2AAF042Aeff2E68B3e8E33F19e4B9fA7C73F10` |
| Arbitrum Sepolia | 421614 | `0x234a5fb5Bd614a7AA2FfAB244D603abFA0Ac5C5C` |
| Base Sepolia | 84532 | `0xf9B8fc078197181C841c296C876945aaa425B278` |

### Environment Variables

```bash
# Required
SEPOLIA_RPC_URL=           # RPC endpoint
PRIVATE_KEY=               # Deployer private key
CHAINLINK_SUBSCRIPTION_ID= # Your Functions subscription ID
MNEE_TOKEN_ADDRESS=        # MNEE token contract address

# Optional
ETHERSCAN_API_KEY=         # For contract verification
```

## 🔒 Security Considerations

1. **ReentrancyGuard**: All state-changing functions protected
2. **CEI Pattern**: Checks-Effects-Interactions followed
3. **Access Control**: Only authorized parties can verify/cancel
4. **Immutable Token**: MNEE token address cannot be changed
5. **SafeERC20**: Safe token transfer operations

## 📄 Contract Interface

### Key Functions

| Function | Description | Access |
|----------|-------------|--------|
| `createGig()` | Create and fund a new gig | Anyone |
| `verifyWork()` | Request PR merge verification | Client/Freelancer/Owner |
| `cancelGig()` | Cancel gig and refund (after 24h) | Client only |
| `updateSource()` | Update JS verification source | Owner only |
| `updateChainlinkConfig()` | Update Chainlink settings | Owner only |

### Events

- `GigCreated`: New gig created and funded
- `GigFunded`: Tokens deposited to escrow
- `WorkVerificationRequested`: Chainlink request sent
- `WorkVerified`: Chainlink response received
- `PaymentReleased`: Funds transferred to freelancer
- `GigCancelled`: Gig cancelled, funds returned

## 🧩 Chainlink Functions Source

The `github-check.js` script:

1. Accepts `owner`, `repo`, `prNumber` as arguments
2. Fetches PR data from GitHub API
3. Checks the `merged` boolean field
4. Returns `1` if merged, `0` otherwise

```javascript
// Simplified version
const response = await Functions.makeHttpRequest({
  url: `https://api.github.com/repos/${owner}/${repo}/pulls/${prNumber}`
});
return Functions.encodeUint256(response.data.merged ? 1 : 0);
```

## 🚀 Mainnet Deployment Guide

For this hackathon submission, we used a **Mock MNEE Token** on Sepolia Testnet to simulate the payment flow.

To deploy this project on **Ethereum Mainnet** using the official MNEE Stablecoin, follow these simple steps:

1. **Locate the Official MNEE Contract:**
The official MNEE token address on Ethereum Mainnet is:
`0x8ccedbae4916b79da7f3f612efb2eb93a2bfd6cf`
2. **Update Configuration:**
Modify your `.env` file to point to the live Mainnet address instead of the Mock address:
```bash
# .env
MNEE_TOKEN_ADDRESS=0x8ccedbae4916b79da7f3f612efb2eb93a2bfd6cf
```


3. **Deploy:**
Run the deployment script targeting Mainnet. The script is already configured to detect the chain ID and use the address provided in the environment variable.
```bash
forge script script/Deploy.s.sol:DeployGigEscrow --rpc-url $MAINNET_RPC_URL --broadcast
```



---

## 📜 Contract Addresses (Sepolia)

* **GigEscrow:** `0x...` (Update after deployment)
* **Mock MNEE:** `0x...` (Update after deployment)


## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Write tests for new functionality
4. Submit a pull request

## 📜 License

MIT License - see [LICENSE](LICENSE) for details.

## 🔗 Resources

- [Chainlink Functions Documentation](https://docs.chain.link/chainlink-functions)
- [Foundry Book](https://book.getfoundry.sh/)
- [GitHub REST API](https://docs.github.com/en/rest/pulls/pulls)
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts)
