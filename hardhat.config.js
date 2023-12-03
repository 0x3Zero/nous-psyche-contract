// require("@nomicfoundation/hardhat-toolbox");
require("@nomicfoundation/hardhat-ethers");
require("@nomicfoundation/hardhat-verify");
require("@openzeppelin/hardhat-upgrades");

require("hardhat-gas-reporter");

require('dotenv').config();

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  gasReporter: {
    enabled: true
  },
  solidity: {
    version: "0.8.10",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  networks: {
    mumbai: {
      chainId: 80001,
      url: `https://polygon-mumbai.g.alchemy.com/v2/${process.env.ALCHEMY_API_KEY_MUMBAI}`,
      // url: 'https://rpc-mumbai.maticvigil.com/',
      accounts: [process.env.PRIVATE_KEY_PROD, process.env.PRIVATE_KEY_USER],
      gas: 5000000,
      // gasPrice: 50000000000
    },
    polygon: {
      chainId: 137,
      url: `https://polygon-mainnet.g.alchemy.com/v2/${process.env.ALCHEMY_API_KEY_POLYGON}`,
      accounts: [process.env.PRIVATE_KEY_PROD],
      gas: 5000000,
      // gasPrice: 50000000000
    },
    sepolia: {
      chainId: 11155111,
      url: `https://eth-sepolia.g.alchemy.com/v2/${process.env.ALCHEMY_API_KEY_SEPOLIA}`,
      accounts: [process.env.PRIVATE_KEY_PROD],
      gas: 5000000,
      // gasPrice: 50000000000
    },
    mainnet: {
      chainId: 1,
      url: `https://eth-mainnet.g.alchemy.com/v2/${process.env.ALCHEMY_API_KEY_MAINNET}`,
      accounts: [process.env.PRIVATE_KEY_PROD],
      gas: 'auto',
      // gasPrice: 50000000000
    },
    "base-mainnet": {
      chainId: 8453,
      url: `https://base-mainnet.g.alchemy.com/v2/${process.env.ALCHEMY_API_KEY_BASEMAINNET}`,
      accounts: [process.env.PRIVATE_KEY_MAINNET],
      // gasPrice: 1000000000,
    },
  },
  etherscan: {
    apiKey: {
      polygonMumbai: process.env.POLYGONSCAN_API_KEY,
      polygon: process.env.POLYGONSCAN_API_KEY,
      mainnet: process.env.ETHERSCAN_API_KEY,
      base: process.env.BASESCAN_API_KEY,
    }
  },
};
