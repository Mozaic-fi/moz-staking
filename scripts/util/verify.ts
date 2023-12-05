
const hre = require("hardhat");
async function main() {

    console.log("xmoz");
    await hre.run("verify:verify", {
        address: "0x3a2d5415b7893921Da0384AFEe8D683dDFFedB1e",
        constructorArguments: [
            "XMOZ",
            "xmoz",
            18
        ],
    });
    await hre.run("verify:verify", {
        address: "0xd6Fd59E8B1fE40a8974099056369f9e09Cec8d7c",
        constructorArguments: [
            "USDC",
            "usdc",
            18
        ],
    });
    await hre.run("verify:verify", {
        address: "0x24CB39d272bF5975dC38991eF3eBfd6f4159D12C",
        constructorArguments: [
            "USDT",
            "usdt",
            18
        ],
    });
    console.log("staking");
    await hre.run("verify:verify", {
        address: "0x43Ad3f8e2A36493871bC05FeD31c4A8E545B3Fc0",
        constructorArguments: [
            "0x3a2d5415b7893921Da0384AFEe8D683dDFFedB1e",
            0
        ],
    }); 

        await hre.run("verify:verify", {
        address: "0xFF66ccE6F8F9E57bEBe4dBFD5D9f68B9B1a448bc",
        constructorArguments: [],
    });
}
main()
    .then(() => process.exit(0))
    .catch((error) => {
    console.error(error);
    process.exit(1);
});