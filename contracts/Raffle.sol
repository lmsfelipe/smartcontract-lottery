// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";

error Raffle__SendMoreToEnterRaffle();
error Raffle__TransferFailed();
error Raffle__RaffleNotOpen();
error Raffle__UpkeepNotNeeded(
  uint256 currentBalance,
  uint256 numPlayers,
  uint256 raffleState
);

/**
 * @title A sample Raffle Contract
 * @author Felipe Lima
 * @notice This contract is for creating an untamperable decentralized smart  contract
 * @dev This implements Chainlink VRF v2 and Chainlink Automation
 */

contract Raffle is VRFConsumerBaseV2, AutomationCompatibleInterface {
  /** Type declarations */
  enum RaffleState {
    OPEN,
    CALCULATING
  }

  /** State Variable */
  VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
  bytes32 private immutable i_gasLane;
  uint64 private immutable i_subscriptionId;
  uint32 private immutable i_callbackGasLimit;
  uint32 private constant NUM_WORDS = 1;
  uint16 private constant REQUEST_CONFIRMATIONS = 3;

  // Lottery variables
  uint256 private immutable i_interval;
  uint256 private immutable i_entranceFee;
  uint256 private s_lastTimestamp;
  address private s_recentWinner;
  address payable[] private s_players;
  RaffleState private s_raffleState;

  /** Events */
  event RequestedRaffleWinner(uint256 indexed requestId);
  event RaffleEnter(address indexed player);
  event WinnerPicked(address indexed player);

  /** Functions */
  constructor(
    address vrfCoordinatorV2address, // contract
    uint256 entranceFee,
    bytes32 gasLane,
    uint64 subscriptionId,
    uint32 callbackGasLimit,
    uint256 interval
  ) VRFConsumerBaseV2(vrfCoordinatorV2address) {
    i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2address);
    i_entranceFee = entranceFee;
    i_gasLane = gasLane;
    i_subscriptionId = subscriptionId;
    i_callbackGasLimit = callbackGasLimit;
    s_raffleState = RaffleState.OPEN;
    s_lastTimestamp = block.timestamp;
    i_interval = interval;
  }

  function enterRaffle() public payable {
    if (msg.value < i_entranceFee) {
      revert Raffle__SendMoreToEnterRaffle();
    }

    if (s_raffleState != RaffleState.OPEN) {
      revert Raffle__RaffleNotOpen();
    }

    s_players.push(payable(msg.sender));
    emit RaffleEnter(msg.sender);
  }

  /**
   * @dev This is the  that ChainLink Keeper nodes call
   * they look for the `upKeedNeeded` to return true
   * The following should be true in order to return true:
   * 1. Our time interval should have passed
   * 2 The lottery should have at least 1 player, and have some ETH
   * 3. Our subscription is funded with LINK
   * 4. Lottery should be in "open" state
   */
  function checkUpkeep(
    bytes memory /* checkData */
  )
    public
    view
    override
    returns (bool upkeepNeeded, bytes memory /* performData */)
  {
    bool isOpen = RaffleState.OPEN == s_raffleState;
    bool timePassed = ((block.timestamp - s_lastTimestamp) > i_interval);
    bool hasPlayers = s_players.length > 0;
    bool hasBalance = address(this).balance > 0;
    upkeepNeeded = (timePassed && isOpen && hasBalance && hasPlayers);

    return (upkeepNeeded, "0x0");
  }

  /**
   * After you register the contract as an upkeep, the Chainlink Automation Network
   * simulates our checkUpkeep off-chain during every block to determine if the updateInterval
   * time has passed since the last increment (timestamp). When checkUpkeep returns true,
   * the Chainlink Automation Network calls performUpkeep on-chain and increments the counter.
   * This cycle repeats until the upkeep is cancelled or runs out of funding.
   */
  function performUpkeep(bytes calldata /* performData */) external override {
    (bool upkeepNeeded, ) = checkUpkeep("");

    if (!upkeepNeeded) {
      revert Raffle__UpkeepNotNeeded(
        address(this).balance,
        s_players.length,
        uint256(s_raffleState)
      );
    }

    s_raffleState = RaffleState.CALCULATING;

    uint256 requestId = i_vrfCoordinator.requestRandomWords(
      i_gasLane,
      i_subscriptionId,
      REQUEST_CONFIRMATIONS,
      i_callbackGasLimit,
      NUM_WORDS
    );

    /**
     * It is redundant because an event is already been sended
     * in the VRF contract
     */
    emit RequestedRaffleWinner(requestId);
  }

  function fulfillRandomWords(
    uint256 /* requestId */,
    uint256[] memory randomWords
  ) internal override {
    uint256 indexOfWinner = randomWords[0] % s_players.length;
    address payable recentWinner = s_players[indexOfWinner];
    s_recentWinner = recentWinner;
    s_raffleState = RaffleState.OPEN;
    s_players = new address payable[](0);
    s_lastTimestamp = block.timestamp;

    (bool success, ) = recentWinner.call{value: address(this).balance}("");

    if (!success) {
      revert Raffle__TransferFailed();
    }

    emit WinnerPicked(recentWinner);
  }

  /* View / Pure Functions */
  function getEntranceFee() public view returns (uint256) {
    return i_entranceFee;
  }

  function getInterval() public view returns (uint256) {
    return i_interval;
  }

  function getPlayer(uint256 index) public view returns (address) {
    return s_players[index];
  }

  function getRecentWinner() public view returns (address) {
    return s_recentWinner;
  }

  function getRaffleState() public view returns (RaffleState) {
    return s_raffleState;
  }

  function getNumWords() public pure returns (uint256) {
    return NUM_WORDS;
  }

  function getNumberOfPlayers() public view returns (uint256) {
    return s_players.length;
  }

  function getLastTimeStamp() public view returns (uint256) {
    return s_lastTimestamp;
  }

  function getRequestConfirmations() public pure returns (uint256) {
    return REQUEST_CONFIRMATIONS;
  }
}
