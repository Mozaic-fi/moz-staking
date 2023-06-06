import {expect} from 'chai';
import {ethers, network} from 'hardhat';
import {SignerWithAddress} from '@nomiclabs/hardhat-ethers/signers';

import {getAddr, deployNew} from '../scripts/util/helpers';
import { Contract } from 'ethers';

describe('MozToken Test', () => {
  let owner: SignerWithAddress,
      alice: SignerWithAddress,
      bob: SignerWithAddress;
  let lzEndpoint: Contract,
      mozToken: Contract;
  let sharedDecimals: number,
      chainId: number;
  before(async () => {
    ({owner, alice, bob} = await getAddr(ethers));
    sharedDecimals = 18;
    chainId = 1;
  });
  beforeEach(async () => {
    lzEndpoint = await deployNew('LZEndpointMock', [chainId]);
    mozToken = await deployNew('MozToken', [
      lzEndpoint.address,
      bob.address,
      sharedDecimals,
    ]);
    await mozToken.setAdmin(alice.address, true);
  });
  describe('setAdmin function test', () => {
    it('should set admin status for a user', async () => {
  
      // Initial admin status should be false
      const initialAdminStatus = await mozToken.isAdmin(bob.address);
      expect(initialAdminStatus).to.equal(false);
  
      // Set admin status to true
      await mozToken.setAdmin(bob.address, true);
  
      // Admin status should be updated to true
      const updatedAdminStatus = await mozToken.isAdmin(bob.address);
      expect(updatedAdminStatus).to.equal(true);
    });
  })
  describe('lockAndVestAndTransfer function test', () => {
    it('should lock and vest tokens for the specified address', async () => {
      const currentBlock = await ethers.provider.getBlock('latest');
      const currentTimestamp = currentBlock.timestamp;
      const amount = ethers.utils.parseEther('100');
      const lockStart = currentTimestamp + 60; // 1 minute from now
      const lockPeriod = 1; // 1 day
      const vestPeriod = 3; // 3 days
  
      await mozToken.lockAndVestAndTransfer(
        bob.address,
        amount,
        lockStart,
        lockPeriod,
        vestPeriod
      );

      const numberOfVestingAgreements = await mozToken.getNumberOfVestingAgreement(bob.address);
      expect(numberOfVestingAgreements).to.equal(1);
  
      const lockedAmount = await mozToken.getLocked(bob.address);
      expect(lockedAmount).to.equal(amount);
  
      // Wait for the lock period to pass
      await ethers.provider.send('evm_increaseTime', [2 * 86400 + 61]);
      await network.provider.send("evm_mine");

      const lockedAmountAfterLockPeriod = await mozToken.getLocked(bob.address);
      expect(lockedAmountAfterLockPeriod).to.equal(amount.div(3).mul(2).add(1));

      // Wait for the Vest period pass
      await ethers.provider.send('evm_increaseTime', [2 * 86400]);
      await network.provider.send("evm_mine");

      const lockedAmountAfterFinishVestPeriod = await mozToken.getLocked(bob.address);
      expect(lockedAmountAfterFinishVestPeriod).to.equal(0);

      await ethers.provider.send('evm_increaseTime', [-(4 * 86400 + 61)]);
      await network.provider.send("evm_mine");
      
    });
    it('should lock and vest tokens for the specified address with multi lock', async () => {
      const currentBlock = await ethers.provider.getBlock('latest');
      const currentTimestamp = currentBlock.timestamp;
      const amount = ethers.utils.parseEther('100');
      const lockStart = currentTimestamp + 60; // 1 minute from now
      const lockPeriod = 1; // 1 day
      const vestPeriod = 3; // 3 days

      await mozToken.lockAndVestAndTransfer(
        bob.address,
        amount,
        lockStart,
        lockPeriod,
        vestPeriod
      );

      const amount1 = ethers.utils.parseEther('100');
      const lockStart1 = currentTimestamp + 86400; // 1 day from now
      const lockPeriod1 = 2; // 2 day
      const vestPeriod1 = 5; // 5 days

      await mozToken.lockAndVestAndTransfer(
        bob.address,
        amount1,
        lockStart1,
        lockPeriod1,
        vestPeriod1
      );

      const numberOfVestingAgreements = await mozToken.getNumberOfVestingAgreement(bob.address);
      expect(numberOfVestingAgreements).to.equal(2);
  
      const lockedAmount = await mozToken.getLocked(bob.address);
      expect(lockedAmount).to.equal(amount.add(amount1));
  
      // Wait for the lock period to pass
      await ethers.provider.send('evm_increaseTime', [4 * 86400 + 61]);
      await network.provider.send("evm_mine");

      const lockedAmountAfterLockPeriod = await mozToken.getLocked(bob.address);
      expect(lockedAmountAfterLockPeriod).to.equal(amount1.div(5).mul(4));

      // Wait for the Vest period pass
      await ethers.provider.send('evm_increaseTime', [4 * 86400]);
      await network.provider.send("evm_mine");

      const lockedAmountAfterFinishVestPeriod = await mozToken.getLocked(bob.address);
      expect(lockedAmountAfterFinishVestPeriod).to.equal(0);

      await ethers.provider.send('evm_increaseTime', [-(8 * 86400 + 61)]);
      await network.provider.send("evm_mine");
    });
  });
  describe('multipleLockAndVestAndTransfer function test', () => {
    it('should lock and vest tokens for multiple addresses', async () => {
      const currentBlock = await ethers.provider.getBlock('latest');
      const currentTimestamp = currentBlock.timestamp;
      const amounts = [
        ethers.utils.parseEther('100'),
        ethers.utils.parseEther('200')
      ];
      const lockStart = currentTimestamp + 60; // 1 minute from now
      const lockPeriod = 1; // 1 day
      const vestPeriod = 3; // 3 days
  
      await mozToken.multipleLockAndVestAndTransfer(
        [alice.address, bob.address],
        amounts,
        lockStart,
        lockPeriod,
        vestPeriod
      );
  
      const numberOfVestingAgreements1 = await mozToken.getNumberOfVestingAgreement(alice.address);
      expect(numberOfVestingAgreements1).to.equal(1);
  
      const lockedAmount1 = await mozToken.getLocked(alice.address);
      expect(lockedAmount1).to.equal(amounts[0]);
  
      const numberOfVestingAgreements2 = await mozToken.getNumberOfVestingAgreement(bob.address);
      expect(numberOfVestingAgreements2).to.equal(1);
  
      const lockedAmount2 = await mozToken.getLocked(bob.address);
      expect(lockedAmount2).to.equal(amounts[1]);
  
      // Wait for the lock period to pass
      await ethers.provider.send('evm_increaseTime', [(lockPeriod + 1) * 86400 + 61]);
      await network.provider.send("evm_mine");
  
      const lockedAmount1AfterLockPeriod = await mozToken.getLocked(alice.address);
      expect(lockedAmount1AfterLockPeriod).to.equal(amounts[0].mul(2).div(3).add(1)); 
  
      const lockedAmount2AfterLockPeriod = await mozToken.getLocked(bob.address);
      expect(lockedAmount2AfterLockPeriod).to.equal(amounts[1].mul(2).div(3).add(1));
    });
  })
})