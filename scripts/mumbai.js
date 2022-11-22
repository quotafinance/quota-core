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
    const usdc = '0xe6b8a5CF854791412c1f6EFC7CAf629f5Df1c747';
    const router = '0xE592427A0AEce92De3Edee1F18E0157C05861564';

    const accounts = await ethers.getSigners();
    const ownerAccount = accounts[0];

    const ETF = await hre.ethers.getContractFactory("ETF");
    const etf = await ETF.deploy();
    await etf.deployed();
    console.log("Token deployed to:", etf.address);
    await etf["initialize(string,string,uint8,address,uint256)"]("Quota", "4.0", 18, ownerAccount.address, ethers.utils.parseEther("8888"));

    const apyOracleFactory = await hre.ethers.getContractFactory("ApyOracle");
    const apyOracle = await apyOracleFactory.deploy(router, usdc, wMatic);
    await apyOracle.deployed();
    console.log("APY oracle deployed to:", apyOracle.address);

    const uniswapOracleFactory = await hre.ethers.getContractFactory("UniswapOracle");
    const uniswapOracle = await uniswapOracleFactory.deploy(etf.address);
    await uniswapOracle.deployed();
    console.log("Uniswap oracle deployed to:", uniswapOracle.address);

    console.log('Token deployed to:', etf.address);

    const uniswapFactory = new ethers.Contract('0x1F98431c8aD98523631AE4a59f267346ea31F984', uniswapABI, ownerAccount);

    const tx1 = await uniswapFactory.createPool(etf.address, wMatic, 3000);
    const tx2 = await uniswapFactory.createPool(etf.address, wETH, 3000);

    await tx1.wait();
    await tx2.wait();

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
