const { expect } = require("chai");
const { ethers } = require("hardhat");
const { parseEther } = require("ethers/lib/utils");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
const uniswapABI = require("../uniswapABI.json");
const uniswapRouterABI = require("../uniswapRouter.json");
const uniPairABI = require("../uniPairABI.json");

const uniswapRouterAddress = "0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff";
const zeroAddress = "0x0000000000000000000000000000000000000000";
const usdcAddress = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174";
const wMaticAddress = "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270";
const uniswapFactoryAddress = "0x5757371414417b8C6CAad45bAeF941aBc7d3Ab32";
const chainlinkAddress = "0x187c42f6C0e7395AeA00B1B30CB0fF807ef86d5d"

const selfTaxPool = "0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff";
const rightUpTaxPool = "0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff";
const maintenancePool = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174";
const devPool = "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270";
const rewardAllocationPool = "0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff";
const tierPool = "0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff";
const revenuePool = "0x187c42f6C0e7395AeA00B1B30CB0fF807ef86d5d";
const marketingPool = "0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff";

const bronzeURI =  "https://bafybeiaaezpxwrpdiwlo57y65wvad66d5v475lunxjyj7qpmhekpab5m44.ipfs.w3s.link/quotaBronzeNFT.json";
const silverURI = "https://bafybeidl4ldrulgmpxzuq5xyiwb3wih6yq3lpypyzynn32n6zryy7fcb7y.ipfs.w3s.link/quotaSilver.json";
const goldURI = "https://bafybeibdb3xj7wh25lm2lfh5lskalesbjqknvmb2amfxzyidsdwoudlbfi.ipfs.w3s.link/quotaGold.json";
const diamondURI = "https://bafybeibitrdgqk6jfgqdoyhbkoqdt72uetidiacep5odn7gfzdmriywmpi.ipfs.w3s.link/quotaDiamond.json";
const blackURI = "https://bafybeie6btbmrnwj2v7boaoephtwxhvrrefffxl43g7tx7bdj3f3hdjdhm.ipfs.w3s.link/quotaBlackNFT.json";

describe("Token contract", function () {

  async function deployTokenFixture() {

    const accounts = await ethers.getSigners();

    const ownerAccount = accounts[0];
    const secondAccount = accounts[1];
    // DEPLOY TOKENS
    const tokenFactory = await ethers.getContractFactory("MockERC");
    // mock wETH
    const wETH = await tokenFactory.deploy("Wrapped Ether", "wETH", 18);
    await wETH.deployed();
    const mintwETH = await wETH.mint(ownerAccount.address, ethers.utils.parseEther("3000000"));


    // mock wMATIC
    const wMATIC = await tokenFactory.deploy("Wrapped MATIC", "wMATIC", 18);
    await wMATIC.deployed();
    const mintwMATIC = await wMATIC.mint(ownerAccount.address, ethers.utils.parseEther("55000000"));

    // mock USDC
    const USDC = await tokenFactory.deploy("USDC", "USDC", 6);
    await USDC.deployed();
    const mintUSDC = await USDC.mint(ownerAccount.address, ethers.utils.parseEther("30000000"));


    // DEPLOY ETF token
    const ETF = await hre.ethers.getContractFactory("ETF");
    const etf = await ETF.deploy();
    await etf.deployed();
    console.log("Token deployed to:", etf.address);
    await etf["initialize(string,string,uint8,address,uint256)"](
    "Quota",
    "4.0",
    18,
    ownerAccount.address,
    ethers.utils.parseEther("8888")
    );

    // Deploy Perpetual Staking Pool Escrow
    const PerpEscrow = await hre.ethers.getContractFactory("Escrow");
    const perpescrow = await PerpEscrow.deploy(etf.address);
    await perpescrow.deployed();
    console.log("Perpetual Pool escrow deployed to:", perpescrow.address);

    // DEPLOY TAX MANAGER
    const TaxManager = await hre.ethers.getContractFactory("TaxManager");
    const taxmanager = await TaxManager.deploy();
    await taxmanager.deployed();
    console.log("TaxManager deployed to:", taxmanager.address);

    await setupTaxManagerParameters(taxmanager);
    await taxmanager.setPerpetualPool(perpescrow.address);

    // DEPLOY TIER MANAGER
    const TierManager = await hre.ethers.getContractFactory("TierManager");
    const tiermanager = await TierManager.deploy();
    await tiermanager.deployed();
    console.log("TierManager deployed to:", tiermanager.address);

    await setupTierManagerParameters(tiermanager);


    // DEPLOY REBASER
    const Rebaser = await hre.ethers.getContractFactory("Rebaser");
    const rebaser = await Rebaser.deploy(
    uniswapRouterAddress,
    USDC.address,
    wMATIC.address,
    etf.address,
    perpescrow.address,
    chainlinkAddress,
    taxmanager.address
    );
    await rebaser.deployed();
    console.log("Rebaser deployed to:", rebaser.address);

    // DEPLOY REFERRAL HANDLER
    const Handler = await hre.ethers.getContractFactory("ReferralHandler");
    const handler = await Handler.deploy();
    await handler.deployed();
    console.log("Implementation of Handler deployed to:", handler.address);

    // DEPLOY DEPOSIT BOX
    const DepositBox = await hre.ethers.getContractFactory("DepositBox");
    const depositbox = await DepositBox.deploy();
    await depositbox.deployed();
    console.log("Implementation of DepositBox deployed to:", depositbox.address);

    // DEPLOY NFT FACTORY
    const NFTFactory = await hre.ethers.getContractFactory("NFTFactory");
    const factory = await NFTFactory.deploy(
    handler.address,
    depositbox.address,
    "One"
    );
    await factory.deployed();
    console.log("Factory deployed to:", factory.address);

    // DEPLOY MEMBERSHIP NFT
    const NFT = await hre.ethers.getContractFactory("MembershipNFT");
    const nft = await NFT.deploy(factory.address);
    await nft.deployed();
    console.log("NFT deployed to:", nft.address);

    // SETUP
    await factory.setNFTAddress(nft.address);
    await factory.setRebaser(rebaser.address);
    await factory.setTaxManager(taxmanager.address);
    await factory.setTierManager(tiermanager.address);
    await etf._setNFT(nft.address);
    await etf._setFactory(factory.address);
    await etf.whitelistAddress(perpescrow.address);
    console.log(
    "NFT, Rebaser, Tax Manager and Tier Manager addresses set in factory"
    );

    // DEPLOY APY ORACLE
    const ApyOracle = await hre.ethers.getContractFactory("ApyOracle");
    const apyoracle = await ApyOracle.deploy(
    uniswapRouterAddress,
    USDC.address,
    wMATIC.address
    );
    await apyoracle.deployed();
    console.log("APYOracle deployed to:", apyoracle.address);
    // DEPLOY STAKING AGGREGATOR
    const StakingAggregator = await hre.ethers.getContractFactory(
      "StakingPoolAggregator"
    );
    const stakingaggregator = await StakingAggregator.deploy(etf.address);
    await stakingaggregator.deployed();

    // DEPLOY NOTIFIER FACTORY
    const notifierFactory = await ethers.getContractFactory("Notifier");
    const notifier = await notifierFactory.deploy();
    await notifier.deployed();
    console.log("Notifier deployed to:", notifier.address);

    // DEPLOY STAKING FACTORY
    const stakingFactory = await ethers.getContractFactory("StakingFactory");
    const stakingfactory = await stakingFactory.deploy(
      etf.address,
      notifier.address,
      factory.address
    );
    await stakingfactory.deployed();
    console.log("Staking Factory deployed to:", stakingfactory.address);


    console.log("StakingPoolAggregator deployed to:", stakingaggregator.address);
  // create uniswap factory
    const uniswapFactory = new ethers.Contract(
      uniswapFactoryAddress,
      uniswapABI,
      ownerAccount
    );
    console.log("Factory initialized");
  // create router
    const uniswapRouter = new ethers.Contract(
      uniswapRouterAddress,
      uniswapRouterABI,
      ownerAccount
    );

    // create ETF to wMATIC pool
    const tx3 = await uniswapFactory.createPair(
      etf.address,
      wMATIC.address
    );
    // await tx3.wait();

    // create ETF to wETH pool
    const tx4 = await uniswapFactory.createPair(
      etf.address,
      wETH.address);
    // await tx4.wait();

    // create wMATIC to USDC pool
    const tx5 = await uniswapFactory.createPair(
      wMATIC.address,
      USDC.address
    );
    // await tx5.wait();

    const etfToMaticPool = await uniswapFactory.getPair(
      etf.address,
      wMATIC.address
    );
    const etfToWethPool = await uniswapFactory.getPair(
      etf.address,
      wETH.address
    );
    const wMaticToUsdcPool = await uniswapFactory.getPair(
      wMATIC.address,
      USDC.address
    );

    // console.log("ETF to Matic liquidity pool deployed to", etfToMaticPool);
    // console.log("ETF to WETH liquidity pool deployed to", etfToWethPool);
    // console.log("wMATIC to USDC liquidity pool deployed to", wMaticToUsdcPool);

    return {ownerAccount, etf, taxmanager, tiermanager,
      rebaser, handler, factory, nft, stakingaggregator,
      notifier, stakingfactory,
      uniswapRouter, secondAccount,
      wMATIC, wETH, USDC,
      etfToMaticPool, etfToWethPool, wMaticToUsdcPool
    };
  }


  it("Test transfer and TransferFrom ", async function () {
    const { ownerAccount, etf } = await loadFixture(
      deployTokenFixture
    );
    await etf.approve(ownerAccount.address, parseEther('2777'));
    await etf.transferFrom(ownerAccount.address, marketingPool, parseEther('1776'));
    await etf.transfer(marketingPool, parseEther('1') );
    expect(await etf.balanceOf(ownerAccount.address)).to.equal(parseEther('7111'));
    expect(await etf.balanceOf(marketingPool)).to.equal(parseEther('1777'));
  })

  it("Test default transfer limit", async function () {

    const { ownerAccount, etf } = await loadFixture(
      deployTokenFixture
    );
    await etf.approve(ownerAccount.address, parseEther('2777'));
    await etf.transferFrom(ownerAccount.address, marketingPool, parseEther('1776'));
    await etf.transferFrom(ownerAccount.address, marketingPool, parseEther('1') );
    await expect(etf.transferFrom(ownerAccount.address, marketingPool, parseEther('1'))).to.be.revertedWith("Transfer above daily limit");
  });

  it("Test whitelisting", async function () {

    const { ownerAccount, etf } = await loadFixture(
      deployTokenFixture
    );
    await etf.approve(ownerAccount.address, parseEther('2777'));
    await etf.transferFrom(ownerAccount.address, marketingPool, parseEther('1776'));
    await etf.transferFrom(ownerAccount.address, marketingPool, parseEther('1') );
    await expect(etf.transferFrom(ownerAccount.address, marketingPool, parseEther('1'))).to.be.revertedWith("Transfer above daily limit");
    await etf.whitelistAddress(ownerAccount.address);
    await etf.transfer(marketingPool, parseEther('1777'));
    expect(await etf.balanceOf(marketingPool)).to.equal(parseEther('3554'));
  });

  it("Test Mint, Set Tier and Change of transfer Limits", async function () {

    const { ownerAccount, handler, nft, factory } = await loadFixture(
      deployTokenFixture
    );
    await factory.mint(zeroAddress);
    expect (await nft.belongsTo(ownerAccount.address)).to.equal(1);
    const handlerAddress = await factory.getHandler(1);
    const handler1 = handler.attach(handlerAddress);
    expect (await handler1.getTier()).to.equal(0);
    expect (await handler1.getTransferLimit()).to.equal(20);
    await handler1.setTier(4);
    expect (await handler1.getTier()).to.equal(4);
    expect (await handler1.getTransferLimit()).to.equal(50);
  });

  it("Create Staking Pools and start them", async function () {

    const { stakingfactory, notifier, etfToMaticPool, etfToWethPool, etf } = await loadFixture(
      deployTokenFixture
    );
    const tx1 = await stakingfactory.initialize(etfToMaticPool, parseEther("555.5"));
    const tx2 = await stakingfactory.initialize(etfToWethPool, parseEther("555.5"));

    const [pool1, pool2] = await stakingfactory.getPools();
    await etf.approve(notifier.address, parseEther('1111'));
    await notifier.notify([pool1, pool2], parseEther("555.5"), etf.address, parseEther("555.5"));

  });

  it("Test Rebaser", async function () {
    const {ownerAccount, wMATIC, wETH, USDC, wMaticToUsdcPool,
      uniswapRouter, factory, rebaser,
      etfToMaticPool, etfToWethPool, etf } = await loadFixture(
      deployTokenFixture
    );

    await wMATIC.approve(uniswapRouterAddress, parseEther('5000000'));
    await USDC.approve(uniswapRouterAddress, 50000000000000);
      // ADD LIQUIDITY WMATIC/USDC
      const uniswapAddLiquidityTx3 = await uniswapRouter.addLiquidity(
        wMATIC.address,
        USDC.address,
        parseEther('50000'),
        5000000000000,
        0,
        0,
        ownerAccount.address,
        Date.now()
      );

    await uniswapAddLiquidityTx3.wait();
    console.log("USDC/wMatic added");

    await etf.whitelistAddress(ownerAccount.address)
    await etf.approve(uniswapRouterAddress, parseEther('1777'));
    await wMATIC.approve(uniswapRouterAddress, parseEther('250000'))
    const uniswapAddLiquidityTx1 = await uniswapRouter.addLiquidity(
      etf.address,
      wMATIC.address,
      parseEther('1777'),
      parseEther('250000'),
      0,
      0,
      ownerAccount.address,
      Date.now()
      );

    await uniswapAddLiquidityTx1.wait();
    console.log("ETF/wMatic added");
    // ADD LIQUIDITY ETF/WETH
    await etf.approve(uniswapRouterAddress, parseEther('5'));
    await wETH.approve(uniswapRouterAddress, parseEther('50000'))
    const uniswapAddLiquidityTx2 = await uniswapRouter.addLiquidity(
      etf.address,
      wETH.address,
      parseEther('5'),
      parseEther('50000'),
      0,
      0,
      ownerAccount.address,
      Date.now()
    );
    await uniswapAddLiquidityTx2.wait();
    console.log("ETF/WETH added");

    console.log(await rebaser.getPriceSNP());
    console.log(await rebaser.getPriceETF());
    await rebaser.setPair(etfToMaticPool);
    await etf._setRebaser(rebaser.address);
    await etf.transfer(marketingPool, parseEther('1'));
    const ethLP = new ethers.Contract(
      etfToWethPool,
      uniPairABI,
      ownerAccount
    );
    const ethLPBalance = await ethLP.balanceOf(ownerAccount.address);
    console.log("Remove Liquidity")
    // const uniswapAddLiquidityTx4 = await uniswapRouter.removeLiquidity(
    //   etf.address,
    //   wETH.address,
    //   ethLPBalance,
    //   0,
    //   0,
    //   ownerAccount.address,
    //   Date.now()
    // );
    // await uniswapAddLiquidityTx4.wait();
    console.log("Adding Trade pair")
    await etf.addTradePair(etfToWethPool);
    const uniswapAddLiquidityTx5 = await uniswapRouter.removeLiquidity(
      etf.address,
      wETH.address,
      ethLPBalance,
      0,
      0,
      ownerAccount.address,
      Date.now()
    );
    await uniswapAddLiquidityTx5.wait();

  });

  it("Create LP Pool, Add lp to Staking Pool, Whitelisting and Rewards distribution", async function () {
    const {ownerAccount, secondAccount, wMATIC, wETH, USDC, wMaticToUsdcPool,
      uniswapRouter, factory, stakingfactory, notifier, nft, handler,
      etfToMaticPool, etfToWethPool, etf } = await loadFixture(
      deployTokenFixture
    );

    await etf.whitelistAddress(ownerAccount.address)
    // ADD LIQUIDITY ETF/WETH
    await etf.approve(uniswapRouterAddress, parseEther('5'));
    await wETH.approve(uniswapRouterAddress, parseEther('50000'))
    const uniswapAddLiquidityTx2 = await uniswapRouter.addLiquidity(
      etf.address,
      wETH.address,
      parseEther('5'),
      parseEther('50000'),
      0,
      0,
      ownerAccount.address,
      Date.now()
    );
    await uniswapAddLiquidityTx2.wait();
    console.log("ETF/WETH added");
    await etf.approve(uniswapRouterAddress, parseEther('1777'));
    await wMATIC.approve(uniswapRouterAddress, parseEther('250000'))
    const uniswapAddLiquidityTx1 = await uniswapRouter.addLiquidity(
      etf.address,
      wMATIC.address,
      parseEther('1777'),
      parseEther('250000'),
      0,
      0,
      ownerAccount.address,
      Date.now()
      );

    await uniswapAddLiquidityTx1.wait();
    console.log("ETF/wMatic added");
    const tx1 = await stakingfactory.initialize(etfToMaticPool, parseEther("555.5"));
    const tx2 = await stakingfactory.initialize(etfToWethPool, parseEther("555.5"));

    const [pool1, pool2] = await stakingfactory.getPools();
    await etf.approve(notifier.address, parseEther('1111'));
    await notifier.notify([pool1, pool2], parseEther("555.5"), etf.address, parseEther("555.5"));

    const maticLP = new ethers.Contract(
      etfToMaticPool,
      uniPairABI,
      ownerAccount
    );
    const maticLPBalance = await maticLP.balanceOf(ownerAccount.address)
    const ethLP = new ethers.Contract(
      etfToWethPool,
      uniPairABI,
      ownerAccount
    );
    const ethLPBalance = await ethLP.balanceOf(ownerAccount.address);
    const TokenRewards = await hre.ethers.getContractFactory("TokenRewards");
    const maticPool = TokenRewards.attach(pool1);
    const ethPool = TokenRewards.attach(pool2);
    console.log(await maticPool.earned(ownerAccount.address));
    await maticLP.approve(pool1, maticLPBalance)
    await ethLP.approve(pool2, ethLPBalance)
    console.log("Approved");

    await expect(maticPool.stake(maticLPBalance, 1)).to.be.revertedWith("Currently only Whitelisted Addresses can stake");
    await expect(ethPool.stake(ethLPBalance, 1)).to.be.revertedWith("Currently only Whitelisted Addresses can stake");

    await maticPool.whitelistAddress(ownerAccount.address);
    await maticPool.stake(maticLPBalance, 1);
    await ethPool.setStatus(false);
    await ethPool.stake(ethLPBalance, 1);
    await factory.connect(secondAccount).mint(zeroAddress);
    expect (await nft.belongsTo(secondAccount.address)).to.equal(1);
    const handlerAddress = await factory.getHandler(1);
    console.log("Handler address", handlerAddress);
    const handler1 = handler.attach(handlerAddress);
    await factory.mint(handlerAddress);

    await handler1.setTier(4);
    await factory.addHandler(await maticPool.escrow());
    console.log("Matic pool, Matic Escrow", maticPool.address, await maticPool.escrow());
    console.log("Rewards Earned", await maticPool.earned(ownerAccount.address));
    console.log("Rewards Earned Tokens", await maticPool.earnedTokens(ownerAccount.address));
    console.log("Balance of Escrow", await etf.balanceOf(await maticPool.escrow()));
    console.log("This done");
    await maticPool.getReward();
    console.log("maybe this");
    console.log(await etf.balanceOf(revenuePool))
    console.log(await etf.balanceOf(devPool));
    console.log(await etf.balanceOf(maintenancePool))
    console.log(await etf.balanceOf(handler1.address));
  });

  async function setupTaxManagerParameters(taxmanager) {
    // // Test only, replace with real addresses
    // // End of test
    console.log("Tax pool", marketingPool);
    await taxmanager.setSelfTaxPool(selfTaxPool);
    await taxmanager.setRightUpTaxPool(rightUpTaxPool);
    await taxmanager.setMaintenancePool(maintenancePool);
    await taxmanager.setDevPool(devPool);
    await taxmanager.setRewardAllocationPool(rewardAllocationPool);
    await taxmanager.setTierPool(tierPool);
    await taxmanager.setRevenuePool(revenuePool);
    await taxmanager.setMarketingPool(marketingPool);
    await taxmanager.setSelfTaxRate(500);
    await taxmanager.setRightUpTaxRate(0);
    await taxmanager.setMaintenanceTaxRate(100);
    await taxmanager.setProtocolTaxRate(2500);
    await taxmanager.setPerpetualPoolTaxRate(450);
    await taxmanager.setMarketingTaxRate(450);
    await taxmanager.setRewardPoolTaxRate(50);
    await taxmanager.setTierPoolRate(1450);
    await taxmanager.setBulkReferralRate(0, 0, 0, 0, 0);
    await taxmanager.setBulkReferralRate(1, 450, 100, 20, 4);
    await taxmanager.setBulkReferralRate(2, 700, 150, 30, 6);
    await taxmanager.setBulkReferralRate(3, 950, 200, 40, 8);
    await taxmanager.setBulkReferralRate(4, 1200, 250, 50, 10);
  }

  async function setupTierManagerParameters(tiermanager) {
    //Test only, replace with real URIs
    await tiermanager.setTokenURI(0, bronzeURI);
    await tiermanager.setTokenURI(1, silverURI);
    await tiermanager.setTokenURI(2, goldURI);
    await tiermanager.setTokenURI(3, diamondURI);
    await tiermanager.setTokenURI(4, blackURI);
    // End of test
    await tiermanager.setConditions(1, 5, 3, 3, 0, 0, 0);
    await tiermanager.setConditions(2, 20, 5, 10, 5, 0, 0);
    await tiermanager.setConditions(3, 60, 10, 20, 10, 5, 0);
    await tiermanager.setConditions(4, 150, 14, 50, 20, 10, 5);
    await tiermanager.setTransferLimit(0, 20);
    await tiermanager.setTransferLimit(1, 20);
    await tiermanager.setTransferLimit(2, 30);
    await tiermanager.setTransferLimit(3, 40);
    await tiermanager.setTransferLimit(4, 50);
  }
})
  async function addLiquidity(deployTokenFixture) {
    const {ownerAccount, wMATIC, wETH, USDC, wMaticToUsdcPool,
      uniswapRouter, factory,
      etfToMaticPool, etfToWethPool, etf } = await loadFixture(
      deployTokenFixture
    );

    await wMATIC.approve(uniswapRouterAddress, parseEther('5000000'));
    await USDC.approve(uniswapRouterAddress, 50000000000000);
      // ADD LIQUIDITY WMATIC/USDC
      const uniswapAddLiquidityTx3 = await uniswapRouter.addLiquidity(
        wMATIC.address,
        USDC.address,
        parseEther('50000'),
        5000000000000,
        0,
        0,
        ownerAccount.address,
        Date.now()
      );

    await uniswapAddLiquidityTx3.wait();
    console.log("USDC/wMatic added");
    await factory.mint(zeroAddress);
    await etf.whitelistAddress(ownerAccount.address)
    await etf.approve(uniswapRouterAddress, parseEther('1777'));
    await wMATIC.approve(uniswapRouterAddress, parseEther('250000'))
    const uniswapAddLiquidityTx1 = await uniswapRouter.addLiquidity(
      etf.address,
      wMATIC.address,
      parseEther('1777'),
      parseEther('250000'),
      0,
      0,
      ownerAccount.address,
      Date.now()
      );

    await uniswapAddLiquidityTx1.wait();
    console.log("ETF/wMatic added");
    // ADD LIQUIDITY ETF/WETH
    await etf.approve(uniswapRouterAddress, parseEther('5'));
    await wETH.approve(uniswapRouterAddress, parseEther('50000'))
    const uniswapAddLiquidityTx2 = await uniswapRouter.addLiquidity(
      etf.address,
      wETH.address,
      parseEther('5'),
      parseEther('50000'),
      0,
      0,
      ownerAccount.address,
      Date.now()
    );
    await uniswapAddLiquidityTx2.wait();
    console.log("ETF/WETH added");
  }