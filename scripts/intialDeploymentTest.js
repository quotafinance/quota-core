// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");
const {ethers} = require("hardhat");

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  const accounts = await ethers.getSigners();
  const ownerAccount = accounts[0];
  const secondAccount = accounts[1];
  const thirdAccount = accounts[2];
  const zeroAddress = "0x0000000000000000000000000000000000000000";
  console.log("Signers", ownerAccount.address, secondAccount.address, thirdAccount.address);


  const ETF = await hre.ethers.getContractFactory("ETF");
  const etf = await ETF.deploy();
  await etf.deployed();
  console.log("Implementation of Token deployed to:", etf.address);
  await etf["initialize(string,string,uint8,address,uint256)"]("Quota", "4.0", 18, ownerAccount.address, ethers.utils.parseEther("8888"));

  const TaxManager = await hre.ethers.getContractFactory("TaxManager");
  const taxmanager = await TaxManager.deploy();
  await taxmanager.deployed();
  console.log("Implementation of TaxManager deployed to:", taxmanager.address);

  const TierManager = await hre.ethers.getContractFactory("TierManager");
  const tiermanager = await TierManager.deploy();
  await tiermanager.deployed();
  console.log("Implementation of TierManager deployed to:", tiermanager.address);

  // Test only
  await tiermanager.setTokenURI(1, "One");
  await tiermanager.setTokenURI(2, "Two");
  await tiermanager.setTokenURI(4, "Four");

  const ChainLink = await hre.ethers.getContractFactory("ChainLinkAggregator");
  const chainlink = await ChainLink.deploy();
  await chainlink.deployed();
  console.log("Implementation of ChainLink Oracle deployed to:", chainlink.address);

  const Rebaser = await hre.ethers.getContractFactory("Rebaser");
  const rebaser = await Rebaser.deploy(etf.address, zeroAddress, chainlink.address, taxmanager.address);
  await rebaser.deployed();
  console.log("Implementation of Rebaser deployed to:", rebaser.address);
  console.log("Price of SNP", await rebaser.getPriceSNP());
  // End of Test only

  // For Mainnet
  // const Rebaser = await hre.ethers.getContractFactory("Rebaser");
  // // The mainnet oracle address: 0x187c42f6C0e7395AeA00B1B30CB0fF807ef86d5d
  // const rebaser = await Rebaser.deploy(etf.address, zeroAddress, "0x187c42f6C0e7395AeA00B1B30CB0fF807ef86d5d", taxmanager.address);
  // await rebaser.deployed();
  // console.log("Implementation of Rebaser deployed to:", rebaser.address);
  // console.log("Price of SNP", await rebaser.getPriceSNP());

  await etf._setRebaser(rebaser.address);
  console.log("Rebaser set to:", rebaser.address);

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
  console.log(await factory.admin())

  const NFT = await hre.ethers.getContractFactory("MembershipNFT");
  const nft = await NFT.deploy(factory.address);
  await nft.deployed();
  console.log("NFT deployed to:", nft.address);

  await factory.setNFTAddress(nft.address);
  await factory.setRebaser(rebaser.address);
  await factory.setTaxManager(taxmanager.address);
  await factory.setTierManager(tiermanager.address);
  console.log("NFT, Rebaser, Tax Manager and Tier Manager addresses set in factory");

  const StakingAggregator = await hre.ethers.getContractFactory("StakingPoolAggregator");
  const stakingaggregator = await StakingAggregator.deploy(etf.address);
  await stakingaggregator.deployed();
  console.log("StakingPoolAggregator deployed to:", stakingaggregator.address);

  const notifierFactory = await ethers.getContractFactory('Notifier');
  const notifier = await notifierFactory.deploy();
  await notifier.deployed();
  console.log("Notifier deployed to:", notifier.address);

  const stakingFactory = await ethers.getContractFactory('StakingFactory');
  const staking = await stakingFactory.deploy(etf.address, notifier.address, taxmanager.address);
  await staking.deployed()
  console.log("Staking deployed to:", staking.address);

}
  // We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
