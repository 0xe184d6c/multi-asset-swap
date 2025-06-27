# multi-asset-swap


### FEATURES

- **initiateSwap**: Alice locks tokens and sets parameters
- **participateSwap**: Bob locks his tokens using same hashlock
- **claimSwap**: Either party claims by revealing preimage (executes full swap)
- **refundSwap**: Returns tokens after timeout if swap incomplete
- **Atomic execution**: All-or-nothing with no counterparty risk
- **ERC20 compatible**: Works with any standard ERC20 token
- **Reentrancy protection**: Uses OpenZeppelin's ReentrancyGuard

Deploy with proper ERC20 token addresses for your USDX and JPMD tokens on Sepolia.





```
PUBLIC AND EXTERNAL FUNCTIONS
initiateSwap(bytes32 swapId, address participant, IERC20 initiatorAsset, IERC20 participantAsset, uint256 initiatorAmount, uint256 participantAmount, bytes32 hashlock, uint256 timelock): Starts a swap, locks initiator asset.
participateSwap(bytes32 swapId): Participant locks their asset into the swap.
claimSwap(bytes32 swapId, bytes32 preimage): Any party claims both assets by revealing preimage, if hash matches, before timelock.
refundSwap(bytes32 swapId): After timelock, either party can refund their deposited assets if unclaimed.
getSwap(bytes32 swapId): Returns all swap details for a given swapId (struct fields).

PRIVATE AND INTERNAL FUNCTIONS
N/A (all core logic is public/external; no explicit internal-only helpers in minimal contract)

EVENTS
SwapInitiated(bytes32 indexed swapId, address indexed initiator, address indexed participant, address initiatorAsset, uint256 initiatorAmount, bytes32 hashlock, uint256 timelock): Emitted when swap is initiated.
SwapParticipated(bytes32 indexed swapId, address indexed participant, address participantAsset, uint256 participantAmount): Emitted when participant deposits asset.
SwapCompleted(bytes32 indexed swapId, bytes32 preimage): Emitted on successful atomic swap.
SwapRefunded(bytes32 indexed swapId, address indexed refunder): Emitted on refund after timelock.
```



### USAGE

**Usage overview (least words):**

* Both users must approve XFTAssetSwaps contract for 500 tokens.
* User1: calls `initiateSwap` (locks 500 USDX).
* User2 (ADMIN): calls `participateSwap` (locks 500 JPMD).
* User1: calls `claimSwap` (reveals preimage, swaps).
* If timeout, either can call `refundSwap`.

---

**run-swap.js**

```javascript
// scripts/run-swap.js
// npx hardhat run scripts/run-swap.js --network sepolia

require('dotenv').config();
const hre = require("hardhat");
const { ethers } = hre;

const USDX = "0x421C76cd7C1550c4fcc974F4d74c870150c45995";
const JPMD = "0xb5dbB65CD34B49388C67Acb8065C97044B83Eb12";
const XFT_ASSET_SWAPS = "0x38C02A1505d14776526eFff46A855963D7967b35";
const AMOUNT = ethers.utils.parseUnits("500", 18); // adjust decimals if needed

const provider = new ethers.providers.JsonRpcProvider(process.env.SEPOLIA_RPC_URL);
const user = new ethers.Wallet(process.env.USER_PRIVATE_KEY, provider);
const admin = new ethers.Wallet(process.env.ADMIN_PRIVATE_KEY, provider);

async function main() {
  // Contracts
  const XFTAssetSwaps = await hre.artifacts.readArtifact("XFTAssetSwaps");
  const IERC20 = await hre.artifacts.readArtifact("@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20");
  const swap = new ethers.Contract(XFT_ASSET_SWAPS, XFTAssetSwaps.abi, provider);
  const usdx = new ethers.Contract(USDX, IERC20.abi, provider);
  const jpmd = new ethers.Contract(JPMD, IERC20.abi, provider);

  // Setup swapId and preimage/hashlock
  const preimage = ethers.utils.formatBytes32String("secret"); // use secure random in prod
  const hashlock = ethers.utils.sha256(preimage);
  const swapId = ethers.utils.keccak256(ethers.utils.defaultAbiCoder.encode(
    ["address", "address", "address", "address", "uint256", "uint256", "bytes32", "uint256"],
    [user.address, admin.address, USDX, JPMD, AMOUNT, AMOUNT, hashlock, Math.floor(Date.now()/1000)+3600]
  ));

  // Approve tokens
  await (await usdx.connect(user).approve(XFT_ASSET_SWAPS, AMOUNT)).wait();
  await (await jpmd.connect(admin).approve(XFT_ASSET_SWAPS, AMOUNT)).wait();

  // Initiate swap by user
  await (await swap.connect(user).initiateSwap(
    swapId,
    admin.address,
    USDX,
    JPMD,
    AMOUNT,
    AMOUNT,
    hashlock,
    Math.floor(Date.now()/1000)+3600
  )).wait();

  // Participate swap by admin
  await (await swap.connect(admin).participateSwap(swapId)).wait();

  // Claim swap by user with preimage
  await (await swap.connect(user).claimSwap(swapId, preimage)).wait();

  console.log("Swap complete. 500 USDX for 500 JPMD, atomic and trustless.");
}

main().catch((err) => {
  console.error("Swap failed:", err);
  process.exit(1);
});
```

**Summary:**

* Approve XFTAssetSwaps for both tokens.
* User: `initiateSwap`
* Admin: `participateSwap`
* User: `claimSwap`
* 1:1 atomic, no counterparty risk.

