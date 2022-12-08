const hre = require("hardhat");
const { ethers } = require("hardhat");
const { parseEther } = require("ethers/lib/utils");
const uniswapABI = require("../uniswapABI.json");
const uniswapRouterABI = require("../uniswapRouter.json");
const uniPairABI = require("../uniPairABI.json");

//Main-net
const uniswapRouterAddress = "0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff";
const zeroAddress = "0x0000000000000000000000000000000000000000";
const usdcAddress = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174";
const wMaticAddress = "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270";
const uniswapFactoryAddress = "0x5757371414417b8C6CAad45bAeF941aBc7d3Ab32";
const chainlinkAddress = "0x187c42f6C0e7395AeA00B1B30CB0fF807ef86d5d"

const selfTaxPool = "0x220A27Ca16BF74Ade6BAFbecC9491f08b8Cae0E4";
const rightUpTaxPool = "0x2C44ed33B5e9c85d0990C89f67b6d283C5832C06";
const maintenancePool = "0x4Fcce3C09E7E89397Bee99C3982Aee96Eed939B1";
const devPool = "0xaC472B8CFF50d2A2Dbe37717654dC5BBF469d49F";
const rewardAllocationPool = "0xD54bd5d8df62bA80Af48C04FD6a98Edb3f44C0Fd";
const revenuePool = "0xF1fABBaf310b17daFf7e50013Af9aF5DB0FFFD17";
const marketingPool = "0x9E63e18a367A15bB07879e9BB8453cEADB576828";

const bronzeURI = "https://bafybeiaaezpxwrpdiwlo57y65wvad66d5v475lunxjyj7qpmhekpab5m44.ipfs.w3s.link/quotaBronzeNFT.json";
const silverURI = "https://bafybeidl4ldrulgmpxzuq5xyiwb3wih6yq3lpypyzynn32n6zryy7fcb7y.ipfs.w3s.link/quotaSilver.json";
const goldURI = "https://bafybeibdb3xj7wh25lm2lfh5lskalesbjqknvmb2amfxzyidsdwoudlbfi.ipfs.w3s.link/quotaGold.json";
const diamondURI = "https://bafybeibitrdgqk6jfgqdoyhbkoqdt72uetidiacep5odn7gfzdmriywmpi.ipfs.w3s.link/quotaDiamond.json";
const blackURI = "https://bafybeie6btbmrnwj2v7boaoephtwxhvrrefffxl43g7tx7bdj3f3hdjdhm.ipfs.w3s.link/quotaBlackNFT.json";

async function main() {
  const accounts = await ethers.getSigners();

  const ownerAccount = accounts[0];

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

  const TierEscrow = await hre.ethers.getContractFactory("Escrow");
  const tierescrow = await TierEscrow.deploy(etf.address);
  await tierescrow.deployed();
  console.log("Tier Pool escrow deployed to:", tierescrow.address);

  // DEPLOY & Setup TAX MANAGER
  const TaxManager = await hre.ethers.getContractFactory("TaxManager");
  const taxmanager = await TaxManager.deploy();
  await taxmanager.deployed();
  console.log("TaxManager deployed to:", taxmanager.address);

  await setupTaxManagerParameters(taxmanager);
  await taxmanager.setPerpetualPool(perpescrow.address);
  await taxmanager.setTierPool(tierescrow.address);

  // DEPLOY & Setup TIER MANAGER
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
  //await etf._setRebaser(rebaser.address);
  console.log("For Token Rebaser set to:", rebaser.address);

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
    bronzeURI
  );

  await factory.deployed();
  console.log("Factory deployed to:", factory.address);

  // DEPLOY MEMBERSHIP NFT
  const NFT = await hre.ethers.getContractFactory("MembershipNFT");
  const nft = await NFT.deploy(factory.address);
  await nft.deployed();
  console.log("NFT deployed to:", nft.address);

  //Deploy Rewarder
  const Rewarder = await hre.ethers.getContractFactory("Rewarder");
  const rewarder = await Rewarder.deploy();
  await rewarder.deployed();
  console.log("rewarder deployed to:", rewarder.address);

  await factory.setToken(etf.address);
  await factory.setNFTAddress(nft.address);
  await factory.setRebaser(rebaser.address);
  await factory.setTaxManager(taxmanager.address);
  await factory.setTierManager(tiermanager.address);
  await factory.setRewarder(rewarder.address);
  await etf._setNFT(nft.address);
  await etf._setFactory(factory.address);
  await etf.whitelistAddress(perpescrow.address);

  // DEPLOY APY ORACLE
  const ApyOracle = await hre.ethers.getContractFactory("ApyOracle");
  const apyoracle = await ApyOracle.deploy(
    uniswapRouterAddress,
    usdcAddress,
    wMaticAddress
  );
  await apyoracle.deployed();
  console.log("APYOracle deployed to:", apyoracle.address);
  // DEPLOY STAKING AGGREGATOR
  const StakingAggregator = await hre.ethers.getContractFactory(
    "StakingPoolAggregator"
  );
  const stakingaggregator = await StakingAggregator.deploy(etf.address);
  await stakingaggregator.deployed();
  console.log("StakingAggregator deployed to:", stakingaggregator.address);
  tiermanager.setStakingAggregator(stakingaggregator.address);
  stakingaggregator.setAPYOracle(apyoracle.address)

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

  // DEPLOY Liquidity Extension
  const Extension = await ethers.getContractFactory("LiquidityExtension");
  const extension = await Extension.deploy(uniswapRouterAddress);
  await extension.deployed();
  console.log("Liquidity Extension deployed to ", extension.address);
  await etf.whitelistAddress(extension.address)

  await setUpPools(ownerAccount, etf, wETH, wMATIC, USDC, extension, stakingfactory, notifier);
}

async function setUpPools(ownerAccount ,etf, wETH, wMATIC, USDC, extension, stakingfactory, notifier) {
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
  await tx3.wait();

  // create ETF to wETH pool
  const tx4 = await uniswapFactory.createPair(
    etf.address,
    wETH.address);
  await tx4.wait();

  // create wMATIC to USDC pool
  const tx5 = await uniswapFactory.createPair(
    wMATIC.address,
    USDC.address
  );

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

  await etf.approve(extension.address, parseEther('1776'));
  await wMATIC.approve(extension.address, parseEther('2500000'))
  const uniswapAddLiquidityTx1 = await extension.addLiquidity(
    etf.address,
    wMATIC.address,
    parseEther('1776'),
    parseEther('2500000'),
    0,
    0
  );
  await uniswapAddLiquidityTx1.wait();

  await etf.approve(extension.address, parseEther('1776'));
  await wETH.approve(extension.address, parseEther('2500000'))
  const uniswapAddLiquidityTx2 = await extension.addLiquidity(
    etf.address,
    wETH.address,
    parseEther('1776'),
    parseEther('2500000'),
    0,
    0
  );
  await uniswapAddLiquidityTx2.wait();

  await USDC.approve(extension.address, 90000000000);
  await wMATIC.approve(extension.address, parseEther('100000'))
  const uniswapAddLiquidityTx3 = await extension.addLiquidity(
    USDC.address,
    wMATIC.address,
    900000000,
    parseEther('1000'),
    0,
    0
  );
  await uniswapAddLiquidityTx3.wait();

  console.log("Liquidity pools created, LP address", etfToMaticPool, etfToWethPool);
  // Create staking pools
  await stakingfactory.initialize(etfToMaticPool, parseEther('10'));
  await stakingfactory.initialize(etfToWethPool , parseEther('10'));

  const [pool1, pool2] = await stakingfactory.getPools();

  console.log("Staking Pools created, Token Rewards",[pool1, pool2]);
  const StakingPool = await ethers.getContractFactory("TokenRewards");
  const stakingpool1 = await StakingPool.attach(pool1);
  const stakingpool2 = await StakingPool.attach(pool2);

  const maticLP = new ethers.Contract(
    etfToMaticPool,
    uniPairABI,
    ownerAccount
  );

  const ethLP = new ethers.Contract(
    etfToWethPool,
    uniPairABI,
    ownerAccount
  );

  // Notify
  await etf.approve(notifier.address, parseEther('20')); // Enough tokens to add to two pool
  await notifier.notify([pool1, pool2], parseEther("10"), etf.address, parseEther("10"));
  // Start Staking
  console.log("Staking Period started");
  console.log("Staking pool Escrows", await stakingpool1.escrow(), await stakingpool2.escrow());
  // Early stages have whitelisting limit
  await maticLP.approve(pool1, 100);
  await stakingpool1.whitelistAddress(ownerAccount.address)
  await stakingpool1.stake(100, 1);
  await ethLP.approve(pool2, 100);
  await stakingpool2.whitelistAddress(ownerAccount.address)
  await stakingpool2.stake(100, 5);

}



async function setupTaxManagerParameters(taxmanager) {
  console.log("Tax pool", marketingPool);
  await taxmanager.setSelfTaxPool(selfTaxPool);
  await taxmanager.setRightUpTaxPool(rightUpTaxPool);
  await taxmanager.setMaintenancePool(maintenancePool);
  await taxmanager.setDevPool(devPool);
  await taxmanager.setRewardAllocationPool(rewardAllocationPool);
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
  await tiermanager.setTokenURI(0, bronzeURI);
  await tiermanager.setTokenURI(1, silverURI);
  await tiermanager.setTokenURI(2, goldURI);
  await tiermanager.setTokenURI(3, diamondURI);
  await tiermanager.setTokenURI(4, blackURI);
  await tiermanager.setConditions(1, parseEther('5'), 3, 3, 0, 0, 0);
  await tiermanager.setConditions(2, parseEther('20'), 5, 10, 5, 0, 0);
  await tiermanager.setConditions(3, parseEther('60'), 10, 20, 10, 5, 0);
  await tiermanager.setConditions(4, parseEther('150'), 14, 50, 20, 10, 5);
  await tiermanager.setTransferLimit(0, 20);
  await tiermanager.setTransferLimit(1, 20);
  await tiermanager.setTransferLimit(2, 30);
  await tiermanager.setTransferLimit(3, 40);
  await tiermanager.setTransferLimit(4, 50);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
