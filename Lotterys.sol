pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";

contract Lottery is Ownable {
    uint256 public entryFee;
    address[] public participants;

    uint256 public randomResult;
    bool public isLotteryActive = false;

    event LotteryEntered(address participant);
    event WinnerSelected(address winner);
    event LotteryStarted();
    event LotteryStopped();
    event LotteryCancelled();

    constructor(uint256 _entryFee) Ownable(msg.sender) {
        require(_entryFee > 0, "Entry fee must be greater than zero");
        entryFee = _entryFee;
    }

    function enterLottery() public payable {
        require(isLotteryActive, "Lottery is not active");
        require(msg.value == entryFee, "Incorrect entry fee");
        for (uint256 i = 0; i < participants.length; i++) {
            require(participants[i] != msg.sender, "Already entered");
        }
        participants.push(msg.sender);
        emit LotteryEntered(msg.sender);
    }

    function generateRandomNumber() public view returns (uint256) {
        // Use the hash of the block N blocks ago; N can be, e.g., 1, to refer to the last block
        bytes32 blockHash = blockhash(block.number - 1);

        // Combine the hash with the current block timestamp and sender's address
        bytes32 combinedHash = keccak256(
            abi.encodePacked(blockHash, block.timestamp, msg.sender)
        );

        // Convert the hash to a uint256 to get a pseudo-random number
        return uint256(combinedHash);
    }

    // Callback function used by Chainlink VRF to return the randomness
    function pickWinner(uint256) internal {
        require(isLotteryActive, "Lottery is not active");
        randomResult = generateRandomNumber();
        uint256 randomIndex = randomResult % participants.length;
        address winner = participants[randomIndex];
        uint256 prizeAmount = address(this).balance;
        (bool success, ) = winner.call{value: prizeAmount}("");
        require(success, "Failed to send Ether to the winner");

        emit WinnerSelected(winner);
        delete participants;
    }

    // Start the lottery
    function startLottery() external onlyOwner {
        require(!isLotteryActive, "Lottery is already active");
        isLotteryActive = true;
        emit LotteryStarted();
    }

    // Stop the lottery
    function stopLottery() external onlyOwner {
        require(isLotteryActive, "Lottery is not active");
        isLotteryActive = false;
        emit LotteryStopped();
    }

    // Cancel the lottery and refund participants
    function cancelLottery() external onlyOwner {
        require(isLotteryActive, "Lottery is not active");
        isLotteryActive = false;

        for (uint256 i = 0; i < participants.length; i++) {
            address participant = participants[i];
            (bool success, ) = participant.call{value: entryFee}("");
            require(success, "Failed to refund participant");
        }
        delete participants;

        emit LotteryCancelled();
    }
}
