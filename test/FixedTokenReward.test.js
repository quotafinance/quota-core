const {expect} = require("chai");
const {ethers} = require("hardhat");
const {parseEther, parseUnits} = require("ethers/lib/utils");
const {time} = require("@nomicfoundation/hardhat-network-helpers")
describe.only("Fixed Token Reward", function () {
    let owner;
    let alice;
    let bob;
    let user1;
    let user2;
    let user3;

    let maintenancePool;
    let rewardPool;
    let devPool;
    let revenuePool;
    let perpetualPool;

    let erc20;
    let etf;
    let handler;
    let depositBox;
    let nftFactory;
    let taxManager;
    let fixedStakingFactory;
    let fixedTokenRewarder;
    let rebaser;
    let nft;

    let erc20_factory;
    let etf_factory;
    let handler_factory;
    let depositBox_factory;
    let nftFactory_factory;
    let taxManager_factory;
    let fixedStakingFactory_factory;
    let fixedTokenRewarder_factory;
    let rebaser_factory;
    let nft_factory;

    before(async () => {
        erc20_factory = await ethers.getContractFactory('ERC20Mock');
        etf_factory = await ethers.getContractFactory('ETF');
        taxManager_factory = await ethers.getContractFactory('TaxManager');
        handler_factory = await ethers.getContractFactory('ReferralHandler');
        depositBox_factory = await ethers.getContractFactory('DepositBox');
        nftFactory_factory = await ethers.getContractFactory('NFTFactory');
        fixedStakingFactory_factory = await ethers.getContractFactory('FixedStakingFactory');
        fixedTokenRewarder_factory = await ethers.getContractFactory('FixedTokenRewarder');
        rebaser_factory = await ethers.getContractFactory('Rebaser');
        nft_factory = await ethers.getContractFactory('MembershipNFT');
    })

    beforeEach(async () => {
        [owner, alice, bob, maintenancePool, rewardPool, devPool, revenuePool, user1, user2, user3, perpetualPool] = await ethers.getSigners();

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
        await etf.whitelistAddress(owner.address);
        await etf.whitelistAddress(alice.address);
        await etf.whitelistAddress(user3.address);

        // Tax manager
        taxManager = await taxManager_factory.deploy();
        await taxManager.deployed();
        await taxManager.setProtocolTaxRate(1000);

        await taxManager.setMaintenancePool(maintenancePool.address);
        await taxManager.setMaintenanceTaxRate(100);

        await taxManager.setRewardAllocationPool(rewardPool.address);
        await taxManager.setRewardPoolTaxRate(100);

        await taxManager.setRevenuePool(revenuePool.address);

        await taxManager.setPerpetualPool(perpetualPool.address);
        await taxManager.setPerpetualPoolTaxRate(200);

        await taxManager.setDevPool(devPool.address);
        await taxManager.setRightUpTaxRate(1000);
        await taxManager.setBulkReferralRate(0, 100, 100, 100, 100);
        await taxManager.setBulkReferralRate(1, 100, 100, 100, 100);
        await taxManager.setBulkReferralRate(2, 100, 100, 100, 100);
        await taxManager.setBulkReferralRate(3, 100, 100, 100, 100);
        await taxManager.setBulkReferralRate(4, 100, 100, 100, 100);

        // Referral handler
        handler = await handler_factory.deploy();
        await handler.deployed();

        // Deposit box
        depositBox = await depositBox_factory.deploy();
        await depositBox.deployed();

        // Rebaser
        rebaser = await rebaser_factory.deploy(
            alice.address,
            alice.address,
            alice.address,
            etf.address,
            alice.address,
            alice.address,
            alice.address
        );
        await rebaser.deployed();

        // NFT factory
        nftFactory = await nftFactory_factory.deploy(handler.address, depositBox.address, '.');
        await nftFactory.deployed();
        await nftFactory.setTaxManager(taxManager.address);
        await nftFactory.setRebaser(rebaser.address);

        // NFT
        nft = await nft_factory.deploy(nftFactory.address);
        await nft.deployed();
        await nftFactory.setNFTAddress(nft.address);

        // Fixed staking factory
        fixedStakingFactory = await fixedStakingFactory_factory.deploy(etf.address, nftFactory.address);
        await fixedStakingFactory.deployed();
        await fixedStakingFactory.initialize();

        // Fixed reward token
        const [fixedTokenRewarderAddress] = await fixedStakingFactory.getPools();
        fixedTokenRewarder = await fixedTokenRewarder_factory.attach(fixedTokenRewarderAddress);
        await etf._setFactory(nftFactory.address);
        const [escrowPool] = await fixedStakingFactory.getEscrows();
        await nftFactory.addHandler(escrowPool);
        await etf.transfer(escrowPool, parseEther('100'));
    })

    const rewardRate = parseEther('1').div(parseUnits('3.154', 11)).mul(36500);

    it('should init state variables', async () => {
        expect(await fixedTokenRewarder.token()).eq(etf.address);
        expect(await fixedTokenRewarder.admin()).eq(owner.address);
    });

    describe('function setEscrow()', () => {
        it('should revert if set new escrow', async () => {
            await expect(fixedTokenRewarder.setEscrow(alice.address)).revertedWith('escrow already set')
        })
    });

    describe('function setRate()', () => {
        it('should revert if caller is not admin', async () => {
            await expect(fixedTokenRewarder.connect(alice).setRate(10)).revertedWith("only admin");
        })

        it('should set new rate', async () => {
            await fixedTokenRewarder.setRate(100);
            expect(await fixedTokenRewarder.yearlyRate()).eq(100);
        })
    })

    describe("function setAdmin()", () => {
        it('should revert if caller is not admin', async () => {
            await expect(fixedTokenRewarder.connect(bob).setAdmin(alice.address)).revertedWith('only admin');
        })

        it('should set new admin', async () => {
            await fixedTokenRewarder.setAdmin(alice.address);
            expect(await fixedTokenRewarder.admin()).eq(alice.address);
        })
    })

    describe('function rewardRate()', () => {
        it('should return reward rate', async () => {
            expect(await fixedTokenRewarder.rewardRate()).eq(rewardRate)
        })
    })

    describe('function stake()', () => {
        it('should revert if amount is less or equal zero', async () => {
            await expect(fixedTokenRewarder.stake(0)).revertedWith('amount is <= 0');
        })

        it('should revert if balance is less than amount', async () => {
            await expect(fixedTokenRewarder.connect(alice).stake(100)).revertedWith('balance is <= amount')
        })

        it('should stake', async () => {
            await etf.approve(fixedTokenRewarder.address, parseEther('100'));
            await fixedTokenRewarder.stake(parseEther('10'));
            expect(await fixedTokenRewarder.staked(owner.address)).eq(parseEther('10'))
        })
    })

    describe('function withdraw()', () => {
        it('should revert if amount is less or equal zero', async () => {
            await expect(fixedTokenRewarder.withdraw(0)).revertedWith("amount is <= 0");
        })

        it('should revert if amount is more than staked', async () => {
            await etf.approve(fixedTokenRewarder.address, parseEther('100'));
            await fixedTokenRewarder.stake(parseEther('10'));
            await expect(fixedTokenRewarder.withdraw(parseEther('15'))).revertedWith("amount is > staked")
        })

        it('should withdraw', async () => {
            await etf.approve(fixedTokenRewarder.address, parseEther('100'));
            await fixedTokenRewarder.stake(parseEther('10'));

            const prevBalance = await etf.balanceOf(owner.address);
            await fixedTokenRewarder.withdraw(parseEther('10'));

            expect(prevBalance.add(parseEther('10'))).eq(await etf.balanceOf(owner.address));
            expect(await fixedTokenRewarder.staked(owner.address)).eq(0)
        })
    })

    describe('function getReward()', () => {
        it('should increase rewards with time', async () => {
            await etf.approve(fixedTokenRewarder.address, parseEther('100'));

            await fixedTokenRewarder.stake(parseEther('10'));
            await time.increase(10);

            const expectedBalance = parseEther('10').mul(rewardRate).mul(10).div(parseEther('1'));
            expect(await fixedTokenRewarder.earned(owner.address)).eq(expectedBalance)
        })

        it('should increase rewards after second stake', async () => {
            await etf.approve(fixedTokenRewarder.address, parseEther('100'));
            await fixedTokenRewarder.stake(parseEther('10'));

            await time.increase(9);

            let expectedBalance = parseEther('10').mul(rewardRate).mul(10).div(parseEther('1'));
            await fixedTokenRewarder.stake(parseEther('10'));

            expect(await fixedTokenRewarder.earned(owner.address)).eq(expectedBalance)
            await time.increase(10)

            expectedBalance = expectedBalance.add(parseEther('20').mul(rewardRate).mul(10).div(parseEther('1')))
            expect(await fixedTokenRewarder.earned(owner.address)).eq(expectedBalance)
        })

        it('should transfer rewards', async () => {
            await etf.approve(fixedTokenRewarder.address, parseEther('100'));
            await fixedTokenRewarder.stake(parseEther('10'));

            const prevTime = await time.latest();

            const prevBalance = await etf.balanceOf(owner.address);
            const expectedBalance = parseEther('10').mul(rewardRate).mul(10).div(parseEther('1')).div(100).mul(80);

            await time.setNextBlockTimestamp(prevTime + 10);
            await fixedTokenRewarder.getReward();

            expect(await etf.balanceOf(owner.address)).eq(prevBalance.add(expectedBalance));
        })

        it('should allocate rewards to pools', async () => {
            await etf.approve(fixedTokenRewarder.address, parseEther('100'));
            await fixedTokenRewarder.stake(parseEther('10'));

            const maintenanceRewards = parseEther('10').mul(rewardRate).mul(10).div(parseEther('1')).div(100).mul(1);
            const rewards = parseEther('10').mul(rewardRate).mul(10).div(parseEther('1')).div(100).mul(1);
            const devRewards = parseEther('10').mul(rewardRate).mul(10).div(parseEther('1')).div(100).mul(8);
            const revenueRewards = parseEther('10').mul(rewardRate).mul(10).div(parseEther('1')).div(100).mul(8);
            const perpetualRewards = parseEther('10').mul(rewardRate).mul(10).div(parseEther('1')).div(100).mul(2);

            await time.increase(9);
            await fixedTokenRewarder.getReward();

            expect(await etf.balanceOf(maintenancePool.address)).eq(maintenanceRewards);
            expect(await etf.balanceOf(rewardPool.address)).eq(rewards);
            expect(await etf.balanceOf(devPool.address)).eq(devRewards);
            expect(await etf.balanceOf(revenuePool.address)).eq(revenueRewards);
            expect(await etf.balanceOf(perpetualPool.address)).eq(perpetualRewards);
        })

        it('should allocate rewards to referrers', async () => {
            await nftFactory.mint(ethers.constants.AddressZero);
            const handler = await nftFactory.getHandlerForUser(owner.address);
            await nftFactory.connect(alice).mint(handler);

            await etf.transfer(alice.address, parseEther('100'));
            await etf.connect(alice).approve(fixedTokenRewarder.address, parseEther('100'));
            await fixedTokenRewarder.connect(alice).stake(parseEther('10'));

            const expectedBalance = parseEther('10').mul(rewardRate).mul(10).div(parseEther('1')).div(100).mul(11);
            await time.increase(9);
            await fixedTokenRewarder.connect(alice).getReward();

            expect(await etf.balanceOf(handler)).eq(expectedBalance);
        })

        it('should allocate rewards to all referrers', async () => {
            await nftFactory.mint(ethers.constants.AddressZero);

            const handler0 = await nftFactory.getHandlerForUser(owner.address);
            await nftFactory.connect(alice).mint(handler0);

            const handler1 = await nftFactory.getHandlerForUser(alice.address);
            await nftFactory.connect(bob).mint(handler1);

            const handler2 = await nftFactory.getHandlerForUser(bob.address);
            await nftFactory.connect(user1).mint(handler2);

            const handler3 = await nftFactory.getHandlerForUser(user1.address);
            await nftFactory.connect(user2).mint(handler3);

            const handler4 = await nftFactory.getHandlerForUser(user2.address);
            await nftFactory.connect(user3).mint(handler4);

            await etf.transfer(user3.address, parseEther('100'));
            await etf.connect(user3).approve(fixedTokenRewarder.address, parseEther('100'));

            await fixedTokenRewarder.connect(user3).stake(parseEther('10'));
            await time.increase(9);
            await fixedTokenRewarder.connect(user3).getReward();

            const expectedBalance = parseEther('10').mul(rewardRate).mul(10).div(parseEther('1')).div(100).mul(11);
            const expectedBalance2 = parseEther('10').mul(rewardRate).mul(10).div(parseEther('1')).div(100).mul(1);

            expect(await etf.balanceOf(handler4)).eq(expectedBalance);
            expect(await etf.balanceOf(handler1)).eq(expectedBalance2);
            expect(await etf.balanceOf(handler2)).eq(expectedBalance2);
            expect(await etf.balanceOf(handler3)).eq(expectedBalance2);
        })
    })

})