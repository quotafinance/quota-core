require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");
require('@openzeppelin/hardhat-upgrades');
require('hardhat-contract-sizer');
require("hardhat-laika");

require('dotenv').config()
/**
 * @type import('hardhat/config').HardhatUserConfig
 */

task("accounts", "Prints the list of accounts", async () => {
  const accounts = await ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.8.4",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
      {
        version: "0.7.3",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
      {
        version: "0.5.16",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
  },
  //defaultNetwork: 'hardhat',
  networks: {
    hardhat: {
      gasPrice: 878000000,
      mining: {
        auto: true,
        interval: 0,
      },
      blockGasLimit: 12000000,
    },
    mumbai: {
      url: `https://rpc-mumbai.maticvigil.com`,
      accounts: [process.env.PRIVATE_KEY, process.env.PRIVATE_KEY1, process.env.PRIVATE_KEY2],
    }
  },
  etherscan: {
    apiKey: process.env.POLYGONSCAN_KEY,
  },
};
