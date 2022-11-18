const {ethers, run} = require("hardhat");

async function main() {

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

    console.log('NFTFactory', NFTFactory.address)
    console.log('MembershipNFT', membershipNFT.address)
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
