import {config as dotEnvConfig} from 'dotenv';
dotEnvConfig();

import type {HardhatUserConfig} from 'hardhat/types';

import '@typechain/hardhat';
import '@nomiclabs/hardhat-etherscan';
import '@nomiclabs/hardhat-solhint';
import '@nomicfoundation/hardhat-chai-matchers';
import '@nomiclabs/hardhat-ethers';
import 'hardhat-contract-sizer';
import "hardhat-change-network";
import "hardhat-gas-reporter"

const Private_key = "651dd590d4ef8965925fd12228ec9280c8023455c0e7a389b79655ea867a70c0";

const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY;

const config: HardhatUserConfig = {
    defaultNetwork: 'hardhat',
    contractSizer: {
        alphaSort: false,
        runOnCompile: true,
        disambiguatePaths: false,
    },
    solidity: {
        compilers: [{
            version: '0.8.9', 
            settings: {
                optimizer: {
                    enabled:true, 
                    runs:1000
                }
            }
        }],
        settings: {
            debug: {
                // Enable the debugger
                enabled: true,
                // Define the URL of the debugging server
                server: "http://127.0.0.1:8545",
                // Enable Solidity stack traces
                stacktrace: true,
                // Enable detailed errors
                verbose: true,
            },
            gasReporter: {
                enabled: true
            }
        },
    },
    // redirect typechain output for the frontend
    typechain: {
        outDir: './types/typechain',
        
    },
    networks: {
        hardhat: {
            gas: 30000000, //"auto", // 30000000
            gasPrice: "auto",// 8000000000
            accounts: {
                accountsBalance: "10000000000000000000000", // 10,000 ETH
            }
        },
        localhost: {
            url: "http://127.0.0.1:8545",
            gas: 30000000, //"auto", // 30000000
            gasPrice: 20000000000,
        },
        testnet: {
            url: "https://goerli-rollup.arbitrum.io/rpc",
            chainId: 421613,
            accounts: [Private_key]
        },
    },
    etherscan: {
        apiKey: {
            ftmTestnet: 'KJIGVT5MEVKRRXRYRRIT683E2D167CVY4V',
            opera: 'KJIGVT5MEVKRRXRYRRIT683E2D167CVY4V',
            arbitrumGoerli: 'KJIGVT5MEVKRRXRYRRIT683E2D167CVY4V'
        },
    },
    paths: {
        sources: "./contracts",
        tests: "./test",
        cache: "./cache",
        artifacts: "./artifacts"
    },
    mocha: {
        timeout: 40000000000000,
        
    }
};

export default config;
