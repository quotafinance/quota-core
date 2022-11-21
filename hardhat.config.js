require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");
require('@openzeppelin/hardhat-upgrades');
require('hardhat-contract-sizer');
require("hardhat-laika");

/**
 * @type import('hardhat/config').HardhatUserConfig
 */

// const data = require("./secrets.json");
// var null
// const INFURA_API_KEY = data.INFURA_API_KEY;
// const ROPSTEN_PRIVATE_KEY = data.ROPSTEN_PRIVATE_KEY;
// const ETHERSCAN_KEY = data.ETHERSCAN_KEY;

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
    // ropsten: {
    //   url: `https://ropsten.infura.io/v3/${INFURA_API_KEY}`,
    //   accounts: [`${ROPSTEN_PRIVATE_KEY}`],
    // },
    // rinkeby: {
    //   url: `https://rinkeby.infura.io/v3/${INFURA_API_KEY}`,
    //   accounts: [`${ROPSTEN_PRIVATE_KEY}`],
    // },
    matic: {
      url: "https://rpc-mumbai.maticvigil.com",
      accounts: ['2640d59ab03e3dbcda0a9ce4a5b255bbfdd42af9172f12c3d04b0ddf145b1095'],
    },
  },
  etherscan: {
  },
};
