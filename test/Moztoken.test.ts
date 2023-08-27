import { expect } from "chai";
import { ethers } from "hardhat";
import { ZERO_ADDRESS } from "../scripts/util/constants";

describe("MozToken", () => {
  let MozToken;
  let mozToken: any;
  let owner: any, bob: any, alice: any, daoTreasury: any, lzAddress: any, mozStaking: any;
  beforeEach(async () => {
    [owner, bob, alice, daoTreasury, lzAddress, mozStaking] = await ethers.getSigners();
    MozToken = await ethers.getContractFactory("MozToken");
    mozToken = await MozToken.deploy(lzAddress.address, mozStaking.address, 6);
    await mozToken.deployed();
  });

  it("should have correct initial supply", async () => {
    const initialSupply = await mozToken.totalSupply();
    expect(initialSupply).to.equal(ethers.utils.parseUnits("545000000", 6));
  });

  it("should allow owner to update fees", async function () {
    const newLiquidityFee = 150; // 1.5%
    const newTreasuryFee = 50;   // 0.5%

    await mozToken.connect(owner).updateFees(newLiquidityFee, newTreasuryFee);

    const updatedLiquidityFee = await mozToken.liquidityFee();
    const updatedTreasuryFee = await mozToken.treasuryFee();
    const updatedTotalFees = await mozToken.totalFees();

    expect(updatedLiquidityFee).to.equal(newLiquidityFee);
    expect(updatedTreasuryFee).to.equal(newTreasuryFee);
    expect(updatedTotalFees).to.equal(newLiquidityFee + newTreasuryFee);
  });

  it("should revert when non-owner tries to update fees", async function () {
    const newLiquidityFee = 150; // 1.5%
    const newTreasuryFee = 50;   // 0.5%

    await expect(mozToken.connect(alice).updateFees(newLiquidityFee, newTreasuryFee))
      .to.be.revertedWith("Ownable: caller is not the owner");
  });

  it("should revert if total fees exceed max fee", async function () {
    const maxFee = await mozToken.maxFee();
    const invalidTotalFees = maxFee.add(1); // Exceeds max fee

    await expect(mozToken.connect(owner).updateFees(invalidTotalFees, 0))
      .to.be.revertedWith("Buy fees must be <= 5%.");
  });

  it("should allow owner to update treasury wallet", async function () {
    const newTreasury = alice.address;

    await mozToken.connect(owner).updateTreasuryWallet(newTreasury);

    const updatedTreasury = await mozToken.treasury();
    expect(updatedTreasury).to.equal(newTreasury);
  });

  it("should revert when non-owner tries to update treasury wallet", async function () {
    const newTreasury = alice.address;

    await expect(mozToken.connect(alice).updateTreasuryWallet(newTreasury))
      .to.be.revertedWith("Ownable: caller is not the owner");
  });

  it("should allow owner to update swap tokens at amount", async function () {
    const newAmount = await mozToken.totalSupply() / 1000; // 0.1% of total supply

    await mozToken.connect(owner).updateSwapTokensAtAmount(newAmount);

    const updatedAmount = await mozToken.swapTokensAtAmount();
    expect(updatedAmount).to.equal(newAmount);
  });

  it("should revert when non-owner tries to update swap tokens at amount", async function () {
    const newAmount = await mozToken.totalSupply() / 1000; // 0.1% of total supply

    await expect(mozToken.connect(alice).updateSwapTokensAtAmount(newAmount))
      .to.be.revertedWith("Ownable: caller is not the owner");
  });

  it("should revert when setting swap tokens at amount below lower limit", async function () {
    const lowerLimit = await mozToken.totalSupply() / 100000; // 0.001% of total supply

    await expect(mozToken.connect(owner).updateSwapTokensAtAmount(lowerLimit - 1))
      .to.be.revertedWith("Swap amount cannot be lower than 0.001% total supply.");
  });

  it("should revert when setting swap tokens at amount above upper limit", async function () {
    const upperLimit = await mozToken.totalSupply()/ 200; // 0.5% of total supply

    await expect(mozToken.connect(owner).updateSwapTokensAtAmount(upperLimit + 1))
      .to.be.revertedWith("Swap amount cannot be higher than 0.5% total supply.");
  });


  it("should allow owner to set automated market maker pair", async function () {
    const pairAddress = alice.address;

    await mozToken.connect(owner).setAutomatedMarketMakerPair(pairAddress, true);

    const isAutomatedPair = await mozToken.automatedMarketMakerPairs(pairAddress);
    expect(isAutomatedPair).to.equal(true);
  });

  it("should revert when non-owner tries to set automated market maker pair", async function () {
    const pairAddress = alice.address;

    await expect(mozToken.connect(alice).setAutomatedMarketMakerPair(pairAddress, true))
      .to.be.revertedWith("Ownable: caller is not the owner");
  });

  it("should revert when setting automated market maker pair to address(0)", async function () {
    await expect(mozToken.connect(owner).setAutomatedMarketMakerPair(ethers.constants.AddressZero, true))
      .to.be.revertedWith("The pair cannot be zero address");
  });
  
  it("should allow transfers", async function () {
    const sender = alice.address;
    const receiver = bob.address;
    const amount = ethers.utils.parseUnits("100", 6);

    mozToken.connect(mozStaking).mint(sender, amount);
    await mozToken.transfer(receiver, amount);
    const balance = await mozToken.balanceOf(receiver);
    expect(balance).to.equal(amount);
  });

  it("should correctly update fees by the owner", async function () {
    const newLiquidityFee = 150; // 1.5%
    const newTreasuryFee = 50;   // 0.5%

    await mozToken.connect(owner).updateFees(newLiquidityFee, newTreasuryFee);

    const updatedLiquidityFee = await mozToken.liquidityFee();
    const updatedTreasuryFee = await mozToken.treasuryFee();

    expect(updatedLiquidityFee).to.equal(newLiquidityFee);
    expect(updatedTreasuryFee).to.equal(newTreasuryFee);
  });

  it("should revert updating fees by non-owner", async function () {
    const newLiquidityFee = 150; // 1.5%
    const newTreasuryFee = 50;   // 0.5%

    await expect(mozToken.connect(alice).updateFees(newLiquidityFee, newTreasuryFee))
      .to.be.revertedWith("Ownable: caller is not the owner");
  });

  it("should correctly calculate and distribute fees on transfers", async function () {
    const sender = owner;
    const receiver = alice;
    const transferAmount = ethers.utils.parseUnits("100", 6);
    const totalSupply = await mozToken.totalSupply();

    await mozToken.setAutomatedMarketMakerPair(receiver.address, true);

    // Transfer tokens from owner to receiver
    await mozToken.transfer(receiver.address, transferAmount);

    // Calculate expected fees
    const expectedLiquidityFee = (transferAmount.mul(await mozToken.liquidityFee())).div(10000);
    const expectedTreasuryFee = (transferAmount.mul(await mozToken.treasuryFee())).div(10000);

    // Check balances after transfer
    const senderBalance = await mozToken.balanceOf(sender.address);
    const receiverBalance = await mozToken.balanceOf(receiver.address);
    const contractBalance = await mozToken.balanceOf(mozToken.address);

    expect(senderBalance).to.equal(totalSupply.sub(transferAmount));
    expect(receiverBalance).to.equal(transferAmount.sub(expectedLiquidityFee).sub(expectedTreasuryFee));
    expect(contractBalance).to.equal(expectedLiquidityFee.add(expectedTreasuryFee));
  });




  it("should allow owner to withdraw stuck MOZ tokens", async function () {
    const initialBalance = await mozToken.balanceOf(owner.address);
    const transferAmount = initialBalance / 2;

    // Transfer MOZ tokens to the contract
    await mozToken.transfer(mozToken.address, transferAmount);

    await mozToken.connect(owner).withdrawStuckMoz();

    const finalBalance = await mozToken.balanceOf(owner.address);
    expect(finalBalance).to.equal(initialBalance);
  });

  it("should allow owner to withdraw stuck tokens", async function () {
    const MockERC20: any = await ethers.getContractFactory("MockToken");
    const mockToken = await MockERC20.deploy("MOCK", "mock", 6);

    const initialBalance = await mockToken.balanceOf(owner.address);
    const transferAmount = initialBalance / 2;

    // Transfer tokens to the contract
    await mockToken.transfer(mozToken.address, transferAmount);

    await mozToken.connect(owner).withdrawStuckToken(mockToken.address, owner.address);

    const finalBalance = await mockToken.balanceOf(owner.address);
    expect(finalBalance).to.equal(initialBalance);
  });

  it("should allow owner to withdraw stuck ETH", async function () {
    const initialBalance = await ethers.provider.getBalance(owner.address);

    // Send ETH to the contract
    await owner.sendTransaction({ to: mozToken.address, value: ethers.utils.parseUnits("1", 6) });

    await mozToken.connect(owner).withdrawStuckEth(owner.address);

    const finalBalance = await ethers.provider.getBalance(owner.address);
    expect(finalBalance.gt(initialBalance)).to.equal(false);
  });

  it("should allow staking contract to burn tokens", async function () {
    const initialBalance = await mozToken.balanceOf(owner.address);
    const burnAmount = initialBalance / 2;

    await mozToken.connect(mozStaking).burn(burnAmount, owner.address);

    const finalBalance = await mozToken.balanceOf(owner.address);
    expect(finalBalance).to.equal(initialBalance - burnAmount);
  });

  it("should allow staking contract to mint tokens", async function () {
    const mintAmount = ethers.utils.parseUnits("100", 6);

    await mozToken.connect(mozStaking).mint(mintAmount, bob.address);

    const finalBalance = await mozToken.balanceOf(bob.address);
    expect(finalBalance).to.equal(mintAmount);
  });

});