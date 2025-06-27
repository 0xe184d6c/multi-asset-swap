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




