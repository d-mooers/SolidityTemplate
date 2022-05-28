import "@typechain/hardhat";
import "@nomiclabs/hardhat-ethers";
import "@nomiclabs/hardhat-etherscan";
import "@nomiclabs/hardhat-solhint";
import "@nomiclabs/hardhat-waffle";
import "hardhat-deploy";
import { fornoURLs, ICeloNetwork } from "@ubeswap/hardhat-celo";
import "dotenv/config";
import "hardhat-abi-exporter";
import { removeConsoleLog } from "hardhat-preprocessor";
import { HardhatUserConfig, task } from "hardhat/config";
import { HDAccountsUserConfig } from "hardhat/types";
import "solidity-coverage";

// task("test", "Test the contracts", async () => {});
const accounts: HDAccountsUserConfig = {
  mnemonic:
    process.env.MNEMONIC ||
    "test test test test test test test test test test test junk",
};

// , async (args, hre, runSuper) => {
//   const launch = <NodeLaunch>await hre.ethers.getContract("NodeLaunch");
//   await launch.setBaseURI(
//     "https://raw.githubusercontent.com/Node-Fi/NodeLaunch/main/metadata/"
//   );
// });

// const accounts = [`0x${process.env.PRIVATE_KEY_DEV}`];

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
export default {
  abiExporter: {
    path: "./build/abi",
    flat: true,
  },
  defaultNetwork: "hardhat",
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
  networks: {
    mainnet: {
      url: fornoURLs[ICeloNetwork.MAINNET],
      accounts,
      chainId: ICeloNetwork.MAINNET,
      live: true,
      gasPrice: 0.5 * 10 ** 9,
      gas: 10000000,
    },
    alfajores: {
      url: fornoURLs[ICeloNetwork.ALFAJORES],
      accounts,
      chainId: ICeloNetwork.ALFAJORES,
      live: true,
      gasPrice: 0.5 * 10 ** 9,
      gas: 8000000,
    },
    hardhat: {
      chainId: 31337,
      accounts,
    },
  },
  paths: {
    deploy: "deploy",
    sources: "./src",
    tests: "./integration_test",
    cache: "./build/cache",
    artifacts: "./build/artifacts",
    imports: "imports",
    deployments: "deployments",
  },
  preprocess: {
    eachLine: removeConsoleLog(
      (bre) =>
        bre.network.name !== "hardhat" && bre.network.name !== "localhost"
    ),
  },
  solidity: {
    version: "0.8.1",
    settings: {
      optimizer: {
        enabled: true,
        runs: 5000,
      },
    },
  },
  spdxLicenseIdentifier: {
    overwrite: false,
    runOnCompile: true,
  },
  tenderly: {
    project: process.env.TENDERLY_PROJECT,
    username: process.env.TENDERLY_USERNAME,
  },
  watcher: {
    compile: {
      tasks: ["compile"],
      files: ["./contracts"],
      verbose: true,
    },
  },
  namedAccounts: {
    deployer: 0,
  },
} as HardhatUserConfig;
