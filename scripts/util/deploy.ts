
import {utils} from 'ethers';


export const deployNew = async (contractName: string, params: any[] = [], libraries: any = {}): Promise<Contract> => {
    const C = await ethers.getContractFactory(contractName, {libraries: libraries});
    return await C.deploy(...params);
}
