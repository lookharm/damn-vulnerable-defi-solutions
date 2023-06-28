const { ethers } = require('hardhat');
const { expect } = require('chai');

describe('[Challenge] The rewarder', function () {
    const TOKENS_IN_LENDER_POOL = 1000000n * 10n ** 18n; // 1 million tokens
    let users, deployer, alice, bob, charlie, david, player;
    let liquidityToken, flashLoanPool, rewarderPool, rewardToken, accountingToken;

    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */

        [deployer, alice, bob, charlie, david, player] = await ethers.getSigners();
        users = [alice, bob, charlie, david];

        const FlashLoanerPoolFactory = await ethers.getContractFactory('FlashLoanerPool', deployer);
        const TheRewarderPoolFactory = await ethers.getContractFactory('TheRewarderPool', deployer);
        const DamnValuableTokenFactory = await ethers.getContractFactory('DamnValuableToken', deployer);
        const RewardTokenFactory = await ethers.getContractFactory('RewardToken', deployer);
        const AccountingTokenFactory = await ethers.getContractFactory('AccountingToken', deployer);

        liquidityToken = await DamnValuableTokenFactory.deploy();
        flashLoanPool = await FlashLoanerPoolFactory.deploy(liquidityToken.address);

        // Set initial token balance of the pool offering flash loans
        await liquidityToken.transfer(flashLoanPool.address, TOKENS_IN_LENDER_POOL);

        // ROUND #1
        rewarderPool = await TheRewarderPoolFactory.deploy(liquidityToken.address); 
        rewardToken = RewardTokenFactory.attach(await rewarderPool.rewardToken());
        accountingToken = AccountingTokenFactory.attach(await rewarderPool.accountingToken());

        // Check roles in accounting token
        expect(await accountingToken.owner()).to.eq(rewarderPool.address);
        const minterRole = await accountingToken.MINTER_ROLE();
        const snapshotRole = await accountingToken.SNAPSHOT_ROLE();
        const burnerRole = await accountingToken.BURNER_ROLE();
        expect(await accountingToken.hasAllRoles(rewarderPool.address, minterRole | snapshotRole | burnerRole)).to.be.true;

        // Alice, Bob, Charlie and David deposit tokens
        // NOTE:
        // alice    = 100
        // bob      = 100
        // charlie  = 100
        // david    = 100
        // rewardPool have allowence of users' DVT  = 100
        // users depoosit to rewardPool             = 100
        let depositAmount = 100n * 10n ** 18n; 
        for (let i = 0; i < users.length; i++) {
            await liquidityToken.transfer(users[i].address, depositAmount);
            await liquidityToken.connect(users[i]).approve(rewarderPool.address, depositAmount);
            await rewarderPool.connect(users[i]).deposit(depositAmount);
            // console.log("accountingToken", (await accountingToken.balanceOf(users[i].address)).toString());
            // console.log("rewardToken", (await rewardToken.balanceOf(users[i].address)).toString());
            expect(
                await accountingToken.balanceOf(users[i].address)
            ).to.be.eq(depositAmount);
        }
        // depositAmount * BigInt(users.length) = 100 * 4 = 400
        expect(await accountingToken.totalSupply()).to.be.eq(depositAmount * BigInt(users.length));
        expect(await rewardToken.totalSupply()).to.be.eq(0);

        // Advance time 5 days so that depositors can get rewards
        await ethers.provider.send("evm_increaseTime", [5 * 24 * 60 * 60]); // 5 days
        
        // ROUND #2
        // Each depositor gets reward tokens
        // Alice    = 25
        // Bob      = 25
        // Charlie  = 25
        // David    = 25
        let rewardsInRound = await rewarderPool.REWARDS();
        for (let i = 0; i < users.length; i++) {
            await rewarderPool.connect(users[i]).distributeRewards();
            // console.log("rewardToken", (await rewardToken.balanceOf(users[i].address)).toString());
            expect(
                await rewardToken.balanceOf(users[i].address)
            ).to.be.eq(rewardsInRound.div(users.length));
        }
        expect(await rewardToken.totalSupply()).to.be.eq(rewardsInRound);

        // Player starts with zero DVT tokens in balance
        expect(await liquidityToken.balanceOf(player.address)).to.eq(0);
        
        // Two rounds must have occurred so far
        expect(await rewarderPool.roundNumber()).to.be.eq(2);
    });

    it('Execution', async function () {
        /** CODE YOUR SOLUTION HERE */

        await ethers.provider.send("evm_increaseTime", [5 * 24 * 60 * 60]); // 5 days
        const ReceiverFactory = await ethers.getContractFactory('Receiver', player);
        receiver = await ReceiverFactory.deploy(flashLoanPool.address, rewarderPool.address, liquidityToken.address, rewardToken.address, player.address); 
        await receiver.run();
    });

    after(async function () {
        /** SUCCESS CONDITIONS - NO NEED TO CHANGE ANYTHING HERE */
        // Only one round must have taken place
        expect(
            await rewarderPool.roundNumber()
        ).to.be.eq(3);

        // Users should get neglegible rewards this round
        for (let i = 0; i < users.length; i++) {
            await rewarderPool.connect(users[i]).distributeRewards();
            const userRewards = await rewardToken.balanceOf(users[i].address);
            console.log("userRewards", userRewards.toString())
            // delta = (userRewards - rewarderPool) / len(users)
            // delta = (50 - 100) / 4
            const delta = userRewards.sub((await rewarderPool.REWARDS()).div(users.length)); 
            console.log("delta", delta.toString());
            expect(delta).to.be.lt(10n ** 16n) // < 0.009 ether
        }
        // 0.009 * 4 = 0.036
        // 100-0.036 = 99.964
        // (x+400)/x = 99.964
        // x+400 = x99.964
        // 

        // 1 Alice deposit 100, Bob deposit 100
        // AC[Alice]    = 100 
        // AC[Bob]      = 100
        // accountingTotal   = 200
        // rewardTotalSupply = 0

        // 2 Alice distribute
        // AC[Alice]    = 100
        // AC[Bob]      = 100
        // accountingTotal   = 200
        // RT[Alice]    = 50
        // rewardTotalSupply = 50

        // 3 Alice deposit 300, Alice and Bob distribute
        // AC[Alice]    = 400
        // AC[Bob]      = 100
        // accountingTotal   = 500
        // RT[Alice]    = 130
        // RT[Alice]    = 20
        // rewardTotalSupply = 250

        
        // Rewards must have been issued to the player account
        expect(await rewardToken.totalSupply()).to.be.gt(await rewarderPool.REWARDS());
        const playerRewards = await rewardToken.balanceOf(player.address);
        console.log("playerRewards", playerRewards.toString());
        expect(playerRewards).to.be.gt(0);

        // The amount of rewards earned should be close to total available amount
        const delta = (await rewarderPool.REWARDS()).sub(playerRewards);
        expect(delta).to.be.lt(10n ** 17n); // < 0.1 ether

        // Balance of DVT tokens in player and lending pool hasn't changed
        expect(await liquidityToken.balanceOf(player.address)).to.eq(0);
        expect(
            await liquidityToken.balanceOf(flashLoanPool.address)
        ).to.eq(TOKENS_IN_LENDER_POOL);
    });
});
