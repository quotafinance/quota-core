const hre = require("hardhat");
const { ethers } = require("hardhat");
const { parseEther } = require("ethers/lib/utils");


async function main() {
  const accounts = await ethers.getSigners();
  const ownerAccount = accounts[0];
  const ETF = await hre.ethers.getContractFactory("ETF");
  const etf = await ETF.attach("0xb14674A76D1885e5ae66D2Ee2d33C964eF7a4902");

  const NFTFactory = await hre.ethers.getContractFactory("NFTFactory");
  const factory = await NFTFactory.attach("0x05D3e6c208B488aBBd35897151A28a0d0f3f9985");

  // DEPLOY STAKING FACTORY
  const FixedFactory = await ethers.getContractFactory("FixedStakingFactory");
  const fixedFactory = await FixedFactory.deploy(
    etf.address,
    factory.address
  );
  await fixedFactory.deployed();
  console.log("Staking pool factory deployed at :", fixedFactory.address);
  await fixedFactory.initialize();
  console.log("Staking pool deployed")
  const [escrow] = await fixedFactory.getEscrows();
  await factory.addHandler(escrow);
  console.log("Added Escrow address to Factory");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });