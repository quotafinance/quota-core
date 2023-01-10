const {expect} = require("chai");
const {ethers} = require("hardhat");
const {parseEther} = require("ethers/lib/utils");

describe.only("Fixed Staking Factory", function () {
    let owner;
    let alice;
    let bob;

    let erc20;
    let etf;
    let handler;
    let depositBox;
    let nftFactory;
    let fixedStakingFactory

    let erc20_factory;
    let etf_factory;
    let handler_factory;
    let depositBox_factory;
    let nftFactory_factory;
    let fixedStakingFactory_factory;

    before(async () => {
        erc20_factory = await ethers.getContractFactory('ERC20Mock');
        etf_factory = await ethers.getContractFactory('ETF');
        handler_factory = await ethers.getContractFactory('ReferralHandler');
        depositBox_factory = await ethers.getContractFactory('DepositBox');
        nftFactory_factory = await ethers.getContractFactory('NFTFactory');
        fixedStakingFactory_factory = await ethers.getContractFactory('FixedStakingFactory');
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

        // Referral handler
        handler = await handler_factory.deploy();
        await handler.deployed();

        // Deposit box
        depositBox = await depositBox_factory.deploy();
        await depositBox.deployed();

        // NFT factory
        nftFactory = await nftFactory_factory.deploy(handler.address, depositBox.address, '.');
        await nftFactory.deployed();

        // Fixed staking factory
        fixedStakingFactory = await fixedStakingFactory_factory.deploy(etf.address, nftFactory.address);
        await fixedStakingFactory.deployed();
    })

    it('should init state variables', async () => {
        expect(await fixedStakingFactory.token()).eq(etf.address);
        expect(await fixedStakingFactory.nftFactory()).eq(nftFactory.address);
        expect(await fixedStakingFactory.owner()).eq(owner.address);
    });


    describe('function initialize()', () => {
        beforeEach(async () => {
            await fixedStakingFactory.initialize()
        })

        it('should create pools', async () => {
            const [pool] = await fixedStakingFactory.getPools();
            const [escrow] = await fixedStakingFactory.getEscrows();

            expect(pool).exist.and.not.eq(ethers.constants.AddressZero);
            expect(escrow).exist.and.not.eq(ethers.constants.AddressZero);
        })
    })
})