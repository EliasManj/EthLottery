// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.6/VRFConsumerBase.sol";

contract Lottery is Ownable, VRFConsumerBase {
    address payable[] public players;
    uint public usdEnterFee;
    AggregatorV3Interface internal ethUsdPriceFeed;
    address payable public recentWinner;
    uint256 public randomness;

    uint256 public fee;
    bytes32 public keyhash;

    enum LOTTERY_STATE {
        OPEN,
        CLOSED,
        CALCULATING_WINNER
    }

    LOTTERY_STATE public lottery_state;

    constructor(
        address _priceFeedAddress,
        address _vrfCoordinator,
        address _linkToken,
        uint256 fee,
        bytes32 keyhash
    ) public VRFConsumerBase(_vrfCoordinator, _linkToken) {
        usdEnterFee = 50 * (10 ** 18);
        ethUsdPriceFeed = AggregatorV3Interface(_priceFeedAddress);
        lottery_state = LOTTERY_STATE.CLOSED;
        fee = fee;
        keyhash = keyhash;
    }

    function enter() public payable {
        require(lottery_state == LOTTERY_STATE.OPEN, "Lottery is not open");
        require(msg.value >= getEntranceFee(), "Not enough ETH");
        players.push(msg.sender);
    }

    function getEntranceFee() public view returns (uint256) {
        (, int price, , , ) = ethUsdPriceFeed.latestRoundData();
        uint adjustedPrice = uint256(price) * 10 ** 10;
        uint costToEnter = (usdEnterFee * 10 ** 18) / adjustedPrice;
        return costToEnter;
    }

    function startLottery() public onlyOwner {
        require(
            lottery_state == LOTTERY_STATE.CLOSED,
            "Lottery is already open"
        );
        lottery_state = LOTTERY_STATE.OPEN;
    }

    function endLottery() public onlyOwner {
        lottery_state = LOTTERY_STATE.CALCULATING_WINNER;
        bytes32 requestId = requestRandomness(keyhash, fee);
    }

    function fulfillRandomness(
        bytes32 requestId,
        uint256 randomness
    ) internal override {
        require(
            lottery_state == LOTTERY_STATE.CALCULATING_WINNER,
            "Lottery is not open"
        );
        require(randomness > 0, "Random not found");
        uint256 winnerIndex = randomness % players.length;
        recentWinner = players[winnerIndex];
        recentWinner.transfer(address(this).balance);
        players = new address payable[](0);
        lottery_state = LOTTERY_STATE.CLOSED;
        randomness = randomness;
    }
}
