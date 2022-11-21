// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");
const {ethers} = require("hardhat");
const {parseEther} = require("ethers/lib/utils");

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

  setupTaxManagerParameters(taxmanager);

  const TierManager = await hre.ethers.getContractFactory("TierManager");
  const tiermanager = await TierManager.deploy();
  await tiermanager.deployed();
  console.log("Implementation of TierManager deployed to:", tiermanager.address);

  setupTierManagerParameters(tiermanager);

  // Test only
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

  const tokenFactory = await ethers.getContractFactory('MockERC');
  const lp = await tokenFactory.deploy();
  await lp.deployed();

  const lp2 = await tokenFactory.deploy();
  await lp2.deployed();

  await staking.initialize(lp.address, parseEther('10'));
  await staking.initialize(lp2.address, parseEther('10'));

  const [pool1, pool2] = await staking.getPools();

  console.log("Pool1 deployed to:", pool1);
  console.log("Pool2 deployed to:", pool2);

  //Test stuff
  const mint = await factory.mint("0x0000000000000000000000000000000000000000");
  //const handler1 = await factory.NFT();
  const txReceipt = await mint.wait()
  let handlerAddress, depositAddress;
  for (const event of txReceipt.events) {
    if(event.event === "NewIssuance") {
      const { handler, depositBox } = event.args;
      handlerAddress = handler;
      depositAddress = depositBox;
    }
  }
  console.log("Handler and Deposit", handlerAddress, depositAddress);
  const handler1 = await handler.attach(handlerAddress);
  console.log("Referral and Deposit", await handler1.referredBy(), await handler1.getDepositBox());
  // First mint complete
  console.log(await nft.getTransferLimit(1));
  await handler1.setTier(4);
  console.log(await nft.getTransferLimit(1));
}

async function setupTierManagerParameters(tiermanager) {
  //Test only, replace with real URIs
  await tiermanager.setTokenURI(1, "One");
  await tiermanager.setTokenURI(2, "Two");
  await tiermanager.setTokenURI(3, "Three");
  await tiermanager.setTokenURI(4, "Four");
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

async function setupTaxManagerParameters(taxmanager) {
  // // Test only, replace with real addresses
  // const accounts = await ethers.getSigners();
  // const selfTaxPool = accounts[3];
  // const rightUpTaxPool = accounts[4];
  // const maintenancePool = accounts[5];
  // const devPool = accounts[6];
  // const rewardAllocationPool = accounts[7];
  // const perpetualPool = accounts[8];
  // const tierPool = accounts[9];
  // const revenuePool = accounts[10];
  // const marketingPool = accounts[11];
  // // End of test
  // await taxmanager.setSelfTaxPool(selfTaxPool);
  // await taxmanager.setRightUpTaxPool(rightUpTaxPool);
  // await taxmanager.setMaintenancePool(maintenancePool);
  // await taxmanager.setDevPool(devPool);
  // await taxmanager.setRewardAllocationPool(rewardAllocationPool);
  // await taxmanager.setPerpetualPool(perpetualPool);
  // await taxmanager.setTierPool(tierPool);
  // await taxmanager.setRevenuePool(revenuePool);
  // await taxmanager.setMarketingPool(marketingPool);
  await taxmanager.setSelfTaxRate(0);
  await taxmanager.setRightUpTaxRate(0);
  await taxmanager.setMaintenanceTaxRate(100);
  await taxmanager.setProtocolTaxRate(2500);
  await taxmanager.setPerpetualPoolTaxRate(450);
  await taxmanager.setDevPoolTaxRate(50);
  await taxmanager.setRewardPoolTaxRate(50);
  await taxmanager.setTierPoolRate(1450);
  await taxmanager.setBulkReferralRate(0, 0, 0, 0, 0);
  await taxmanager.setBulkReferralRate(1, 450, 100, 20, 4);
  await taxmanager.setBulkReferralRate(2, 700, 150, 30, 6);
  await taxmanager.setBulkReferralRate(3, 950, 200, 40, 8);
  await taxmanager.setBulkReferralRate(4, 1200, 250, 50, 10);

  console.log("Tax set", await taxmanager.getReferralRate(1, 4));
  console.log("Tax set", await taxmanager.getReferralRate(2, 4));
}

  // We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
