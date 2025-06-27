// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract XFTAssetSwaps is ReentrancyGuard {
    struct Swap {
        address initiator;
        address participant;
        IERC20 initiatorAsset;
        IERC20 participantAsset;
        uint256 initiatorAmount;
        uint256 participantAmount;
        bytes32 hashlock;
        uint256 timelock;
        bool initiatorDeposited;
        bool participantDeposited;
        bool completed;
        bool refunded;
    }

    mapping(bytes32 => Swap) public swaps;

    event SwapInitiated(
        bytes32 indexed swapId,
        address indexed initiator,
        address indexed participant,
        address initiatorAsset,
        uint256 initiatorAmount,
        bytes32 hashlock,
        uint256 timelock
    );
    event SwapParticipated(
        bytes32 indexed swapId,
        address indexed participant,
        address participantAsset,
        uint256 participantAmount
    );
    event SwapCompleted(
        bytes32 indexed swapId,
        bytes32 preimage
    );
    event SwapRefunded(
        bytes32 indexed swapId,
        address indexed refunder
    );

    modifier swapExists(bytes32 _swapId) {
        require(swaps[_swapId].initiator != address(0), "Swap does not exist");
        _;
    }

    modifier onlyInitiator(bytes32 _swapId) {
        require(msg.sender == swaps[_swapId].initiator, "Only initiator allowed");
        _;
    }

    modifier onlyParticipant(bytes32 _swapId) {
        require(msg.sender == swaps[_swapId].participant, "Only participant allowed");
        _;
    }

    function initiateSwap(
        bytes32 _swapId,
        address _participant,
        IERC20 _initiatorAsset,
        IERC20 _participantAsset,
        uint256 _initiatorAmount,
        uint256 _participantAmount,
        bytes32 _hashlock,
        uint256 _timelock
    ) external nonReentrant {
        require(swaps[_swapId].initiator == address(0), "Swap exists");
        require(_participant != address(0), "Invalid participant");
        require(_participant != msg.sender, "Self swap not allowed");
        require(_initiatorAmount > 0 && _participantAmount > 0, "Invalid amounts");
        require(_timelock > block.timestamp, "Timelock must be future");
        require(_hashlock != bytes32(0), "Invalid hashlock");

        swaps[_swapId] = Swap({
            initiator: msg.sender,
            participant: _participant,
            initiatorAsset: _initiatorAsset,
            participantAsset: _participantAsset,
            initiatorAmount: _initiatorAmount,
            participantAmount: _participantAmount,
            hashlock: _hashlock,
            timelock: _timelock,
            initiatorDeposited: false,
            participantDeposited: false,
            completed: false,
            refunded: false
        });

        require(
            _initiatorAsset.transferFrom(msg.sender, address(this), _initiatorAmount),
            "Initiator transfer failed"
        );
        swaps[_swapId].initiatorDeposited = true;

        emit SwapInitiated(
            _swapId,
            msg.sender,
            _participant,
            address(_initiatorAsset),
            _initiatorAmount,
            _hashlock,
            _timelock
        );
    }

    function participateSwap(bytes32 _swapId)
        external
        nonReentrant
        swapExists(_swapId)
        onlyParticipant(_swapId)
    {
        Swap storage swap = swaps[_swapId];
        require(!swap.participantDeposited, "Already participated");
        require(!swap.completed, "Swap completed");
        require(!swap.refunded, "Swap refunded");
        require(block.timestamp < swap.timelock, "Swap expired");

        require(
            swap.participantAsset.transferFrom(msg.sender, address(this), swap.participantAmount),
            "Participant transfer failed"
        );
        swap.participantDeposited = true;

        emit SwapParticipated(
            _swapId,
            msg.sender,
            address(swap.participantAsset),
            swap.participantAmount
        );
    }

    function claimSwap(bytes32 _swapId, bytes32 _preimage)
        external
        nonReentrant
        swapExists(_swapId)
    {
        Swap storage swap = swaps[_swapId];
        require(!swap.completed, "Swap completed");
        require(!swap.refunded, "Swap refunded");
        require(swap.initiatorDeposited && swap.participantDeposited, "Deposit missing");
        require(block.timestamp < swap.timelock, "Swap expired");
        require(sha256(abi.encodePacked(_preimage)) == swap.hashlock, "Bad preimage");

        swap.completed = true;

        require(
            swap.participantAsset.transfer(swap.initiator, swap.participantAmount),
            "To initiator failed"
        );
        require(
            swap.initiatorAsset.transfer(swap.participant, swap.initiatorAmount),
            "To participant failed"
        );

        emit SwapCompleted(_swapId, _preimage);
    }

    function refundSwap(bytes32 _swapId)
        external
        nonReentrant
        swapExists(_swapId)
    {
        Swap storage swap = swaps[_swapId];
        require(!swap.completed, "Swap completed");
        require(!swap.refunded, "Swap refunded");
        require(block.timestamp >= swap.timelock, "Too early");
        require(
            msg.sender == swap.initiator || msg.sender == swap.participant,
            "Not swap party"
        );

        swap.refunded = true;

        if (swap.initiatorDeposited) {
            require(
                swap.initiatorAsset.transfer(swap.initiator, swap.initiatorAmount),
                "Refund initiator failed"
            );
        }
        if (swap.participantDeposited) {
            require(
                swap.participantAsset.transfer(swap.participant, swap.participantAmount),
                "Refund participant failed"
            );
        }

        emit SwapRefunded(_swapId, msg.sender);
    }

    function getSwap(bytes32 _swapId)
        external
        view
        returns (
            address initiator,
            address participant,
            address initiatorAsset,
            address participantAsset,
            uint256 initiatorAmount,
            uint256 participantAmount,
            bytes32 hashlock,
            uint256 timelock,
            bool initiatorDeposited,
            bool participantDeposited,
            bool completed,
            bool refunded
        )
    {
        Swap storage swap = swaps[_swapId];
        return (
            swap.initiator,
            swap.participant,
            address(swap.initiatorAsset),
            address(swap.participantAsset),
            swap.initiatorAmount,
            swap.participantAmount,
            swap.hashlock,
            swap.timelock,
            swap.initiatorDeposited,
            swap.participantDeposited,
            swap.completed,
            swap.refunded
        );
    }
}
