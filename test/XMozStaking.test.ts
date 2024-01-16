import { ethers, network } from "hardhat";
import { expect } from "chai";
import { deployNew } from "../scripts/util/helpers";

describe("XMozStaking", async () => {
    let owner: any, user: any, user0: any, user1: any, user2: any, user3: any, user4: any, user5: any;
    let xMozStaking: any;
    let xMozToken: any;
    let usdc: any, usdt: any;
    before(async () => {
        [owner, user, user0, user1, user2, user3, user4, user5] = await ethers.getSigners();
        xMozToken = await deployNew("MockToken", ["XMOZ", "XMOZ", 18]);
        usdc = await deployNew("MockToken", ["USDC", "USDC", 18]);
        usdt = await deployNew("MockToken", ["USDT", "USDT", 18]);

        xMozStaking = await deployNew("XMozStaking", [xMozToken.address, 0]);

        await xMozStaking.setRewardConfig([usdc.address, usdt.address],["1000000000000000000", "1000000000000000000"]);
        const rewardAmount = ethers.utils.parseEther("1000000");
        await usdc.mint(xMozStaking.address, rewardAmount);
        await usdt.mint(xMozStaking.address, rewardAmount);
    })

    describe("Config", async () => {
        it("should update reward amount per week", async function () {
            // Define updated reward amounts
            const updatedRewardAmountsPerWeek = [300, 400];
        
            // Call updateRewardAmountPerweek function with the owner's address
            await expect(xMozStaking.connect(owner).updateRewardAmountPerweek(updatedRewardAmountsPerWeek))
              // Expect an event to be emitted with the specified name and arguments
              .to.emit(xMozStaking, "RewardAmountUpdated")
              .withArgs(updatedRewardAmountsPerWeek);
        
            // Verify that the reward amounts have been updated correctly
            for (let i = 0; i < updatedRewardAmountsPerWeek.length; i++) {
              const token = xMozStaking.rewardTokens(i);
              const amount = await xMozStaking.rewardAmountsPerWeek(token);
              expect(amount).to.equal(updatedRewardAmountsPerWeek[i]);
            }
          });
    
        it("should set treasury address", async function () {
            // Define a new treasury address
            const newTreasury = user.address;
        
            // Call setTreasury function with the owner's address
            await expect(xMozStaking.connect(owner).setTreasury(newTreasury))
                // Expect an event to be emitted with the specified name and arguments
                .to.emit(xMozStaking, "TreasurySet")
                .withArgs(newTreasury);
        
            // Verify that the treasury address has been set correctly
            const treasury = await xMozStaking.treasury();
            expect(treasury).to.equal(newTreasury);
        });
    
        it("should set fee", async function () {
            // Define a new treasury fee in basis points
            const newTreasuryFeeBP = 500;
        
            // Call setFee function with the owner's address
            await expect(xMozStaking.connect(owner).setFee(newTreasuryFeeBP))
                // Expect an event to be emitted with the specified name and arguments
                .to.emit(xMozStaking, "FeeSet")
                .withArgs(newTreasuryFeeBP);
        
            // Verify that the fee has been set correctly
            const treasuryFeeBP = await xMozStaking.treasuryFeeBP();
            expect(treasuryFeeBP).to.equal(newTreasuryFeeBP);
        });
        it("should revert setting reward configuration if not called by the owner", async function () {
            // Define reward tokens and amounts
            const rewardTokens = [ethers.constants.AddressZero, ethers.constants.AddressZero];
            const rewardAmountsPerWeek = [100, 200];
        
            // Call setRewardConfig function with the user's address
            await expect(xMozStaking.connect(user).setRewardConfig(rewardTokens, rewardAmountsPerWeek))
              // Expect the transaction to be reverted with the specified error message
              .to.be.revertedWith("Ownable: caller is not the owner");
          });
        
        it("should revert updating reward amount per week if not called by the owner", async function () {
            // Define updated reward amounts
            const updatedRewardAmountsPerWeek = [300, 400];
        
            // Call updateRewardAmountPerweek function with the user's address
            await expect(xMozStaking.connect(user).updateRewardAmountPerweek(updatedRewardAmountsPerWeek))
              // Expect the transaction to be reverted with the specified error message
              .to.be.revertedWith("Ownable: caller is not the owner");
        });
        
        it("should revert setting treasury address if not called by the owner", async function () {
            // Define a new treasury address
            const newTreasury = user.address;
        
            // Call setTreasury function with the user's address
            await expect(xMozStaking.connect(user).setTreasury(newTreasury))
              // Expect the transaction to be reverted with the specified error message
              .to.be.revertedWith("Ownable: caller is not the owner");
        });
        
        it("should revert setting fee if not called by the owner", async function () {
            // Define a new treasury fee in basis points
            const newTreasuryFeeBP = 500;
        
            // Call setFee function with the user's address
            await expect(xMozStaking.connect(user).setFee(newTreasuryFeeBP))
              // Expect the transaction to be reverted with the specified error message
              .to.be.revertedWith("Ownable: caller is not the owner");
        });
        
        it("should revert setting reward configuration if lengths are not equal", async function () {
            // Define reward tokens and amounts with different lengths
            const rewardTokens = [ethers.constants.AddressZero];
            const rewardAmountsPerWeek = [100, 200];
        
            // Call setRewardConfig function with the owner's address
            await expect(xMozStaking.connect(owner).setRewardConfig(rewardTokens, rewardAmountsPerWeek))
              // Expect the transaction to be reverted with the specified error message
              .to.be.revertedWith("XMozStaking: Invalid length");
        });
        
        it("should revert updating reward amount per week if lengths are not equal", async function () {
            // Define updated reward amounts with different lengths
            const updatedRewardAmountsPerWeek = [300];
        
            // Call updateRewardAmountPerweek function with the owner's address
            await expect(xMozStaking.connect(owner).updateRewardAmountPerweek(updatedRewardAmountsPerWeek))
              // Expect the transaction to be reverted with the specified error message
              .to.be.revertedWith("XMozStaking: Invalid length");
        });
        
        it("should revert setting treasury address if provided with zero address", async function () {
            // Call setTreasury function with zero address
            await expect(xMozStaking.connect(owner).setTreasury(ethers.constants.AddressZero))
              // Expect the transaction to be reverted with the specified error message
              .to.be.revertedWith("XMozStaking: Invalid address");
        });
        
          it("should revert setting fee if fee exceeds the limit", async function () {
            // Call setFee function with a fee greater than the limit
            const invalidFee = 10000;
        
            await expect(xMozStaking.connect(owner).setFee(invalidFee))
              // Expect the transaction to be reverted with the specified error message
              .to.be.revertedWith("XMozStaking: fees > limit");
        });
    })
    describe("Staking, UnStaking and Claim Reward", async () => {
        before(async () => {
            xMozToken = await deployNew("MockToken", ["XMOZ", "XMOZ", 18]);
            usdc = await deployNew("MockToken", ["USDC", "USDC", 18]);
            usdt = await deployNew("MockToken", ["USDT", "USDT", 18]);
            xMozStaking = await deployNew("XMozStaking", [xMozToken.address, 0]);
    
            await xMozStaking.setRewardConfig([usdc.address, usdt.address],["1000000000000000000", "1000000000000000000"]);
            const rewardAmount = ethers.utils.parseEther("1000000");
            await usdc.mint(xMozStaking.address, rewardAmount);
            await usdt.mint(xMozStaking.address, rewardAmount);

        })
        it("should allow users to stake", async function () {
            // User1 stakes 100 XMoz tokens
            const mintAmount = ethers.utils.parseEther("100");
            await xMozToken.mint(user0.address, mintAmount);
            await xMozToken.mint(user1.address, mintAmount);
            await xMozStaking.connect(user0).stake( ethers.utils.parseEther("50"));
            await xMozStaking.connect(user1).stake(mintAmount);
    
            let totalStakedAmount = await xMozStaking.totalStakedAmount();
            expect(totalStakedAmount).to.be.equal(ethers.utils.parseEther("150"));
        
            // Check user0's staked balance
            const user1Balance = await xMozStaking.balanceOf(user1.address);
            let user1StakedAmount = await xMozStaking.stakingInfo(user1.address);
            expect(user1Balance).to.equal(0);
            expect(user1StakedAmount).to.equal(ethers.utils.parseEther("100"));
        
            // const unstakeAmount = ethers.utils.parseEther("50");
            // // User0 unstakes 50 XMoz tokens
            // await xMozStaking.connect(user0).unstake(unstakeAmount);
    
            // totalStakedAmount = await xMozStaking.totalStakedAmount();
            // expect(totalStakedAmount).to.be.equal(ethers.utils.parseEther("150"));
        
            // // Check user0's staked balance after unstaking
            // const user0NewBalance = await xMozStaking.balanceOf(user0.address);
            // expect(user0NewBalance).to.equal(unstakeAmount);
            // let user0StakedAmount = await xMozStaking.stakingInfo(user0.address);
            // expect(user0StakedAmount).to.equal(ethers.utils.parseEther("50"));
        });
    
        it("should distribute rewards to stakers", async function () {
            let currentTimestamp = (await ethers.provider.getBlock("latest")).timestamp;
    
            // Advance time to simulate a week passing
            await network.provider.send("evm_increaseTime", [60 * 60 * 24 * 7]);
            await network.provider.send("evm_mine");
    
            currentTimestamp = (await ethers.provider.getBlock("latest")).timestamp;
            
            let user0UsdcBalance = await usdc.balanceOf(user0.address);
            let user0UsdtBalance = await usdt.balanceOf(user0.address);

            expect(user0UsdcBalance).to.be.equal(0);
            expect(user0UsdtBalance).to.be.equal(0);

            // claim rewards
            await xMozStaking.connect(user0).claimReward();
            await xMozStaking.connect(user1).claimReward();
        
            // Check user0's reward balance
            user0UsdcBalance = await usdc.balanceOf(user0.address);
            user0UsdtBalance = await usdt.balanceOf(user0.address);

            expect(user0UsdcBalance).to.be.equal("333333333333333333");
            expect(user0UsdtBalance).to.be.equal("333333333333333333");

            let user1UsdcBalance = await usdc.balanceOf(user1.address);
            let user1UsdtBalance = await usdt.balanceOf(user1.address);
            
            expect(user1UsdcBalance).to.be.equal("666666666666666666");
            expect(user1UsdtBalance).to.be.equal("666666666666666666");
    
            const updatedRewardAmountsPerWeek = ["2000000000000000000", "1000000000000000000"];
            xMozStaking.connect(owner).updateRewardAmountPerweek(updatedRewardAmountsPerWeek);
            await xMozStaking.connect(user0).stake(ethers.utils.parseEther("50"));
            await network.provider.send("evm_increaseTime", [60 * 60 * 24 * 7]);
            await network.provider.send("evm_mine");
    
            // claim rewards
            await xMozStaking.connect(user0).claimReward();
            await xMozStaking.connect(user1).claimReward();
    
            user0UsdcBalance = await usdc.balanceOf(user0.address);
            user0UsdtBalance = await usdt.balanceOf(user0.address);

            expect(user0UsdcBalance).to.be.equal("1333333333333333333");
            expect(user0UsdtBalance).to.be.equal("833333333333333333");

            user1UsdcBalance = await usdc.balanceOf(user1.address);
            user1UsdtBalance = await usdt.balanceOf(user1.address);
            expect(user1UsdcBalance).to.be.equal("1666666666666666666");
            expect(user1UsdtBalance).to.be.equal("1166666666666666666");
        });

        it("should allow users to unstake", async function () {
            const unstakeAmount = ethers.utils.parseEther("50");
            // User0 unstakes 50 XMoz tokens
            await xMozStaking.connect(user0).unstake(unstakeAmount);
    
            const totalStakedAmount = await xMozStaking.totalStakedAmount();
            expect(totalStakedAmount).to.be.equal(ethers.utils.parseEther("150"));
        
            // Check user0's staked balance after unstaking
            const user0NewBalance = await xMozStaking.balanceOf(user0.address);
            expect(user0NewBalance).to.equal(unstakeAmount);
            let user0StakedAmount = await xMozStaking.stakingInfo(user0.address);
            expect(user0StakedAmount).to.equal(unstakeAmount);

        });
        it('should not allow staking more than available xMoz balance', async function () {
            // Attempt to stake an amount greater than the user's xMoz balance
            const amountToStake = ethers.utils.parseEther('1000');
            await expect(xMozStaking.connect(user1).stake(amountToStake)).to.be.revertedWith('XMozStaking: Insufficient staked tokens');
        });
    
        it('should not allow staking zero xMoz', async function () {
            // Attempt to stake zero amount
            const amountToStake = 0;
            await expect(xMozStaking.connect(user1).stake(amountToStake)).to.be.revertedWith('XMozStaking: Invalid stake amount');
        });
    
        it('should not allow unstaking zero xMoz', async function () {
            // Attempt to unstake  zero amount
            const amountToUnstake = 0;
            await expect(xMozStaking.connect(user1).unstake(amountToUnstake)).to.be.revertedWith('XMozStaking: Invalid unstake amount');
        });
    })
})