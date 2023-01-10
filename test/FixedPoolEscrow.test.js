const {expect} = require("chai");
const {ethers} = require("hardhat");
const {parseEther} = require("ethers/lib/utils");

describe.only("Fixed Rate Staking", function () {
    let pool;
    let owner;
    let alice;
    let bob;

    let erc20;
    let fixedPoolEscrow;
    let etf;
    let taxManager;
    let handler;
    let depositBox;
    let nftFactory;

    let erc20_factory;
    let fixedPoolEscrow_factory;
    let etf_factory;
    let taxManager_factory;
    let handler_factory;
    let depositBox_factory;
    let nftFactory_factory;

    before(async () => {
        erc20_factory = await ethers.getContractFactory('ERC20Mock');
        fixedPoolEscrow_factory = await ethers.getContractFactory('FixedPoolEscrow');
        etf_factory = await ethers.getContractFactory('ETF');
        taxManager_factory = await ethers.getContractFactory('TaxManager');
        handler_factory = await ethers.getContractFactory('ReferralHandler');
        depositBox_factory = await ethers.getContractFactory('DepositBox');
        nftFactory_factory = await ethers.getContractFactory('NFTFactory');
    })

    beforeEach(async () => {
        [owner, pool, alice, bob] = await ethers.getSigners();

        // mock erc20 token
        erc20 = await erc20_factory.deploy('mock', 'mock', owner.address, 0);
        await erc20.deployed();

        // ETF token
        etf = await etf_factory.deploy();
        await etf.deployed();
        await etf["initialize(string,string,uint8,address,uint256)"](
            "Quota",
            "4.0",
            18,
            owner.address,
            ethers.utils.parseEther("8888")
        );

        // Tax manager
        taxManager = await taxManager_factory.deploy();
        await taxManager.deployed();
        await taxManager.setProtocolTaxRate(100);

        // Referral handler
        handler = await handler_factory.deploy();
        await handler.deployed();

        // Deposit box
        depositBox = await depositBox_factory.deploy();
        await depositBox.deployed();

        // NFT factory
        nftFactory = await nftFactory_factory.deploy(handler.address, depositBox.address, '.');
        await nftFactory.deployed();
        await nftFactory.setTaxManager(taxManager.address);

        // Fixed pool escrow
        fixedPoolEscrow = await fixedPoolEscrow_factory.deploy(pool.address, etf.address, nftFactory.address);
        await fixedPoolEscrow.deployed();
    })

    it('should init state variables', async () => {
        expect(await fixedPoolEscrow.pool()).eq(pool.address);
        expect(await fixedPoolEscrow.token()).eq(etf.address);
        expect(await fixedPoolEscrow.factory()).eq(nftFactory.address);
        expect(await fixedPoolEscrow.governance()).eq(owner.address);
    });

    describe('function: setGovernance()', () => {
        it('should revert if caller is not governance', async () => {
            await expect(fixedPoolEscrow.connect(alice).setGovernance(bob.address)).revertedWith("only governance")
        })

        it('should set new governance', async () => {
            await fixedPoolEscrow.setGovernance(alice.address);
            expect(await fixedPoolEscrow.governance()).eq(alice.address);
        })
    })

    describe('function: setFactory()', () => {
        it('should revert if caller is not governance', async () => {
            await expect(fixedPoolEscrow.connect(alice).setFactory(bob.address)).revertedWith('only governance')
        })

        it('should set new factory', async () => {
            await fixedPoolEscrow.setFactory(bob.address);
            expect(await fixedPoolEscrow.factory()).eq(bob.address);
        })
    })

    describe('function: recoverLeftoverTokens()', () => {
        it('should revert if caller is not governance', async () => {
            await expect(fixedPoolEscrow.connect(alice).recoverLeftoverTokens(erc20.address, owner.address)).revertedWith('only governance');
        })
        it('should transfer tokens', async () => {
            await erc20.mint(fixedPoolEscrow.address, parseEther('5'));
            await fixedPoolEscrow.recoverLeftoverTokens(erc20.address, owner.address);
            expect(await erc20.balanceOf(owner.address)).eq(parseEther('5'));
        })
    })

    describe('function: disperseRewards()', () => {
        it('should revert if caller is not pool', async () => {
            await expect(fixedPoolEscrow.disperseRewards(alice.address, 100)).revertedWith("only pool can release tokens");
        })
    })

})