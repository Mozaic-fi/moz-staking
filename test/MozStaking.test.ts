import {expect} from 'chai';
import {ethers, network} from 'hardhat';
import {SignerWithAddress} from '@nomiclabs/hardhat-ethers/signers';

import {getAddr, deployNew} from '../scripts/util/helpers';

describe('MozStaking Test',() => {
  let lzEndpoint: any;

  let threshold: number;
  let multiSig: any, xMozToken: any;
  let owners: Array<any>;
  let chainId: number;
  let decimals: number;
  let mozStaking: any, mozToken: any;
  let owner: any, bob: any, alice: any, user1: any, user2: any, badUser1: any, daoTreasury:any 
  before(async () => {
    [owner, bob, alice, user1, user2, badUser1, daoTreasury] = await ethers.getSigners();

    owners = [owner.address, alice.address, bob.address, user1.address, user2.address];
    threshold = 4;
    decimals = 18;
    chainId = 1;
  });
  beforeEach(async () => {
    lzEndpoint = await deployNew('LZEndpointMock', [chainId]);
    lzEndpoint = await deployNew('LZEndpointMock', [chainId]);
    mozStaking = await deployNew('MozStaking', [
      daoTreasury.address
    ]);
    xMozToken = await deployNew('XMozToken', [
        lzEndpoint.address,
        badUser1.address,
        mozStaking.address,
        decimals,
    ]);

    mozToken = await deployNew('MozToken', [
        lzEndpoint.address,
        mozStaking.address,
        decimals,
    ]);

    await mozStaking.initialize(mozToken.address, xMozToken.address);
    await mozToken.setAdmin(user1.address, true);
    await xMozToken.connect(owner).transfer(user1.address, ethers.utils.parseEther("100000"));

  });
  describe("updateRedeemSettings function test", () => {
    it ('updateRedeemSettings()', async () => {
      // Set New RedeemSetting
      const minRatio = 40;
      const medRatio = 70;
      const maxRatio = 100;
      const minDur = 10;
      const medDur = 20;
      const maxDur = 30;

      // Update Redeem Settings
      let tx = await mozStaking.connect(owner).updateRedeemSettings(
        minRatio,
        medRatio,
        maxRatio,
        minDur,
        medDur,
        maxDur
      );
      await tx.wait();

      expect(await mozStaking.minRedeemRatio()).to.eq(minRatio);
      expect(await mozStaking.mediumRedeemRatio()).to.eq(medRatio);
      expect(await mozStaking.maxRedeemRatio()).to.eq(maxRatio);
      expect(await mozStaking.minRedeemDuration()).to.eq(minDur);
      expect(await mozStaking.mediumRedeemDuration()).to.eq(medDur);
      expect(await mozStaking.maxRedeemDuration()).to.eq(maxDur);
    });
    it("should revert if called by a non-owner", async function () {
      const nonOwner = (await ethers.getSigners())[1];
      
      // Set New RedeemSetting
      const minRatio = 40;
      const medRatio = 70;
      const maxRatio = 100;
      const minDur = 10;
      const medDur = 20;
      const maxDur = 30;
      
      // Update Redeem Settings
      await expect(mozStaking.connect(nonOwner).updateRedeemSettings(
        minRatio,
        medRatio,
        maxRatio,
        minDur,
        medDur,
        maxDur
      ))
      .to.be.revertedWith("Ownable: caller is not the owner");
    });
  });

  describe("convert function test", () => {
    it('should convert Mozaic Token to xMOZ', async function () {
      // Get XMoz and Moz Balance before convert.
      const xMozBalanceBefore = await xMozToken.balanceOf(owner.address);
      const mozBalanceBefore = await mozToken.balanceOf(owner.address);
      // Set MozStaking Address
      const amount = ethers.utils.parseEther("100");

      // Approve Amount to mozStaking
      let tx = await mozToken.connect(owner).approve(mozStaking.address, amount);
      await tx.wait();

      // Convert
      tx = await mozStaking.convert(amount);
      await tx.wait();

      expect((await xMozToken.balanceOf(owner.address)).sub(xMozBalanceBefore)).to.eq(amount);
      expect((mozBalanceBefore).sub(await mozToken.balanceOf(owner.address))).to.eq(amount);
    });

  });
  describe("redeem function test", () => {
    it ('redeem()', async () => {
      const xMozAmount = ethers.utils.parseEther("100");
      const duration = 1296000; //  30 days
      await xMozToken.connect(owner).approve(mozStaking.address, xMozAmount);
      // Redeem to owner
      await mozStaking.connect(owner).redeem(xMozAmount, duration);
      expect(await mozStaking.getMozByVestingDuration(xMozAmount, duration)).to.eq(ethers.utils.parseEther("50"));
      const xMozBalancesAfter = await mozStaking.xMozRedeemingBalances(owner.address);
      expect(xMozBalancesAfter).to.eq(ethers.utils.parseEther("100"));
    });
  });
  describe("cancelRedeem function test", () => {
    it ('cancelRedeem()', async () => {
      let beforeXMozBalance = await xMozToken.balanceOf(user1.address);
      const xMozAmount = ethers.utils.parseEther("100");
      const duration = 1296000; //  30 days
      await xMozToken.connect(user1).approve(mozStaking.address, xMozAmount);
      // Redeem to owner
      await mozStaking.connect(user1).redeem(xMozAmount, duration);
      expect(await mozStaking.getMozByVestingDuration(xMozAmount, duration)).to.eq(ethers.utils.parseEther("50"));
      const xMozBalancesAfter = await mozStaking.xMozRedeemingBalances(user1.address);
      expect(xMozBalancesAfter).to.eq(ethers.utils.parseEther("100"));
      expect(beforeXMozBalance.sub(await xMozToken.balanceOf(user1.address))).to.eq(ethers.utils.parseEther("100"));

      // Cancel Redeem
      await mozStaking.connect(user1).cancelRedeem(0);
      
      expect(await xMozToken.balanceOf(user1.address)).to.eq(beforeXMozBalance);
    });
  });
  describe("finalizeRedeem function test", () => {
    it('should finalize a redeem', async () => {
      // Set MozStaking Address
      let beforeXMozBalance = await xMozToken.balanceOf(user1.address);
      const xMozAmount = ethers.utils.parseEther("100");
      const duration = 1296000; //  30 days
      await xMozToken.connect(user1).approve(mozStaking.address, xMozAmount);
      // Redeem to owner
      await mozStaking.connect(user1).redeem(xMozAmount, duration);
      expect(await mozStaking.getMozByVestingDuration(xMozAmount, duration)).to.eq(ethers.utils.parseEther("50"));
      const xMozBalancesAfter = await mozStaking.xMozRedeemingBalances(user1.address);
      expect(xMozBalancesAfter).to.eq(ethers.utils.parseEther("100"));
      expect(beforeXMozBalance.sub(await xMozToken.balanceOf(user1.address))).to.eq(ethers.utils.parseEther("100"));

      // Wait for 15 days
      await ethers.provider.send('evm_increaseTime', [1296000]);
      await network.provider.send('evm_mine', []);
      const befRedeem = await mozToken.balanceOf(user1.address);
      // Finalize Redeem
      await mozStaking.connect(user1).finalizeRedeem(0);
      const afterRedeem = await mozToken.balanceOf(user1.address);
      expect(afterRedeem.sub(befRedeem)).to.eq(ethers.utils.parseEther("50"));
      await ethers.provider.send('evm_increaseTime', [-1296000]);
      await network.provider.send('evm_mine', []);
    });
  });
  describe("transferOwnership", () => {
    it('transfer ownership to alice', async () => {
      // Get Current OwnerShip
      const currentOwner = await mozStaking.owner();
      expect(currentOwner).to.eq(owner.address);

      // Transfer OwnerShip
      await mozStaking.connect(owner).transferOwnership(alice.address);
      expect(await mozStaking.owner()).to.eq(alice.address);
    })
  })
})