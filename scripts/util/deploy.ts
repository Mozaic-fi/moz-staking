import { ethers } from "hardhat"
import { deployNew } from "./helpers";

async function main() {
    const [deployer] = await ethers.getSigners();
    // console.log("Deploying contracts with the account:", deployer.address);
    // const xmozAddress = "0x288734c9d9db21C5660B6b893F513cb04B6cD2d6";
    
    // const xMozStaking = await deployNew("XMozStaking", []);
    // console.log(xMozStaking.address);
    // await xMozStaking.setXMoz(xmozAddress);
    // console.log("finished");
    const xmoz = await deployNew("MockToken", ["XMOZ", "xmoz", 18]);
    console.log(xmoz.address);
    const usdc = await deployNew("MockToken", ["USDC", "usdc", 18]);
    const usdt = await deployNew("MockToken", ["USDT", "usdt", 18]);
    console.log(usdc.address, usdt.address);
    const xMozStaking = await deployNew("XMozStaking", [xmoz.address, 0]);
    await xMozStaking.setRewardConfig([usdc.address, usdt.address], ["1000000000000000000", "1500000000000000000"]);
    await xMozStaking.setFee(150);
    await xMozStaking.setTreasury(deployer.address);
    console.log(xMozStaking.address);
    await usdc.mint(xMozStaking.address, "100000000000000000000000");
    await usdt.mint(xMozStaking.address, "100000000000000000000000");
  }
  
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });