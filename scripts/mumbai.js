// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");
const {ethers} = require("hardhat");
const {parseEther} = require("ethers/lib/utils");
const uniswapABI = require("../uniswapABI.json");

async function main() {

    const wMatic = '0x9c3C9283D3e44854697Cd22D3Faa240Cfb032889';
    const wETH = '0xA6FA4fB5f76172d178d61B04b0ecd319C5d1C0aa';
    const zeroAddress = "0x0000000000000000000000000000000000000000";

    const accounts = await ethers.getSigners();
    const ownerAccount = accounts[0];

    const ETF = await hre.ethers.getContractFactory("ETF");
    const etf = await ETF.deploy();
    await etf.deployed();
    console.log("Token deployed to:", etf.address);
    await etf["initialize(string,string,uint8,address,uint256)"]("Quota", "4.0", 18, ownerAccount.address, ethers.utils.parseEther("8888"));

    const TaxManager = await hre.ethers.getContractFactory("TaxManager");
    const taxmanager = await TaxManager.deploy();
    await taxmanager.deployed();
    console.log("TaxManager deployed to:", taxmanager.address);

    const TierManager = await hre.ethers.getContractFactory("TierManager");
    const tiermanager = await TierManager.deploy();
    await tiermanager.deployed();
    console.log("TierManager deployed to:", tiermanager.address);

    const ChainLink = await hre.ethers.getContractFactory("ChainLinkAggregator");
    const chainlink = await ChainLink.deploy();
    await chainlink.deployed();
    console.log("ChainLink Oracle deployed to:", chainlink.address);

    const Rebaser = await hre.ethers.getContractFactory("Rebaser");
    const rebaser = await Rebaser.deploy(etf.address, zeroAddress, chainlink.address, taxmanager.address);
    await rebaser.deployed();
    console.log("Rebaser deployed to:", rebaser.address);
    await etf._setRebaser(rebaser.address);
    console.log("For Token Rebaser set to:", rebaser.address);

    const Handler = await hre.ethers.getContractFactory("ReferralHandler");
    const handler = await Handler.deploy();
    await handler.deployed();
    console.log("Implementation of Handler deployed to:", handler.address);

    const DepositBox = await hre.ethers.getContractFactory("DepositBox");
    const depositbox = await DepositBox.deploy();
    await depositbox.deployed();
    console.log("Implementation of DepositBox deployed to:", depositbox.address);

    const NFTFactory = await hre.ethers.getContractFactory("NFTFactory");
    const factory = await NFTFactory.deploy(handler.address, depositbox.address, "One");
    await factory.deployed();
    console.log("Factory deployed to:", factory.address);

    const NFT = await hre.ethers.getContractFactory("MembershipNFT");
    const nft = await NFT.deploy(factory.address);
    await nft.deployed();
    console.log("NFT deployed to:", nft.address);

    await factory.setNFTAddress(nft.address);
    await factory.setRebaser(rebaser.address);
    await factory.setTaxManager(taxmanager.address);
    await factory.setTierManager(tiermanager.address);
    console.log("NFT, Rebaser, Tax Manager and Tier Manager addresses set in factory");

    // quickswap router 0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff
    // usdc 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174
    // wMatic 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270

    const ApyOracle = await hre.ethers.getContractFactory("ApyOracle");
    const apyoracle = await ApyOracle.deploy("0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff", "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174", "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270");
    await apyoracle.deployed();
    console.log("APYOracle deployed to:", apyoracle.address);
    // Test
    //console.log(await apyoracle.tokenPerLP("0x369582d2010B6eD950B571F4101e3bB9b554876F", "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270"));

    const StakingAggregator = await hre.ethers.getContractFactory("StakingPoolAggregator");
    const stakingaggregator = await StakingAggregator.deploy(etf.address);
    await stakingaggregator.deployed();
    console.log("StakingPoolAggregator deployed to:", stakingaggregator.address);

    const notifierFactory = await ethers.getContractFactory('Notifier');
    const notifier = await notifierFactory.deploy();
    await notifier.deployed();
    console.log("Notifier deployed to:", notifier.address);

    const stakingFactory = await ethers.getContractFactory('StakingFactory');
    const stakingfactory = await stakingFactory.deploy(etf.address, notifier.address, factory.address);
    await stakingfactory.deployed()
    console.log("Staking Factory deployed to:", stakingfactory.address);

    const tokenFactory = await ethers.getContractFactory('MockERC');
    const lp = await tokenFactory.deploy();
    await lp.deployed();

    const lp2 = await tokenFactory.deploy();
    await lp2.deployed();

    const tx1 = await stakingfactory.initialize(lp.address, parseEther('10'));
    const tx2 = await stakingfactory.initialize(lp2.address, parseEther('10'));

    await tx1.wait();
    await tx2.wait();

    const [pool1, pool2] = await stakingfactory.getPools();

    console.log("Staking pool 1 deployed to:", pool1);
    console.log("Staking pool 2 deployed to:", pool2);

    const uniswapFactory = new ethers.Contract('0x1F98431c8aD98523631AE4a59f267346ea31F984', uniswapABI, ownerAccount);

    const tx3 = await uniswapFactory.createPool(etf.address, wMatic, 3000);
    const tx4 = await uniswapFactory.createPool(etf.address, wETH, 3000);

    await tx3.wait();
    await tx4.wait();

    const etfToMaticPool = await uniswapFactory.getPool(etf.address, wMatic, 3000);
    const etfToWethPool = await uniswapFactory.getPool(etf.address, wETH, 3000);

    console.log("ETF to Matic liquidity pool deployed to", etfToMaticPool);
    console.log("ETF to WETH liquidity pool deployed to", etfToWethPool);

}


// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
