import {ethers} from 'hardhat';
import {expect} from 'chai';
import {utils} from 'ethers';
import {BigNumber} from 'ethers';

export const getAddr = async (ethers: any) => {
  const [owner, proxyOwner, bob, alice, user3, user4, badUser1, badUser2, fakeContract, daoTreasury] = await ethers.getSigners();
  bob.name = 'bob';
  alice.name = 'alice';

  return {
    owner,
    proxyOwner,
    bob,
    alice,
    user3,
    user4,
    badUser1,
    badUser2,
    fakeContract,
    daoTreasury
  };
};

export const encodeParams = (types: string[], values: any[]) => {

    return ethers.utils.solidityPack(types, values)
}

export const getCurrentBlock = async () => {
    return (await ethers.provider.getBlock("latest")).number
}
export const deployNew = async (contractName: string, params: any[] = []) => {
    const C = await ethers.getContractFactory(contractName)
    return await C.deploy(...params)
}
