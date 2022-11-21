const {ethers, run} = require("hardhat");

async function main() {

    const taxManagerFactory = await ethers.getContractFactory('TaxManager');
    const taxManager = await taxManagerFactory.deploy();
    await taxManager.deployed();

    const tokenFactory = await ethers.getContractFactory('MockERC');
    const token = await tokenFactory.deploy();
    await token.deployed();

    const lp = await tokenFactory.deploy();
    await lp.deployed();



    const notifierFactory = await ethers.getContractFactory('Notifier');
    const notifier = await notifierFactory.deploy();
    await notifier.deployed();

    const stakingFactory = await ethers.getContractFactory('StakingFactory');
    const staking = await stakingFactory.deploy(token.address, notifier.address, taxManager.address);
    await staking.deployed()

    const NFTFactoryFactory = await ethers.getContractFactory("NFTFactoryTest");
    const NFTFactory = await NFTFactoryFactory.deploy();
    await NFTFactory.deployed();

    const membershipNFTFactory = await ethers.getContractFactory('MembershipNFTTest');
    const membershipNFT = await membershipNFTFactory.deploy(NFTFactory.address);
    await membershipNFT.deployed();

    const tx = await NFTFactory.setNFTAddress(membershipNFT.address);
    await tx.wait();

    await run("laika-sync", {
        contract: "NFTFactory",
        address: NFTFactory.address,
    })

    await run("laika-sync", {
        contract: "MembershipNFT",
        address: membershipNFT.address,
    })

    await run("laika-sync", {
        contract: "Notifier",
        address: notifier.address,
    })

    await run("laika-sync", {
        contract: "StakingFactory",
        address: staking.address,
    })

    console.log('NFTFactory', NFTFactory.address)
    console.log('MembershipNFT', membershipNFT.address)
    console.log('Notifier', notifier.address)
    console.log('Staking', staking.address)
    console.log('LP', lp.address)
    console.log('TOKEN', token.address)
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
