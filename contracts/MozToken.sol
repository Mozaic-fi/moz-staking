// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@layerzerolabs/solidity-examples/contracts/token/oft/v2/OFTV2.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MOZ is Mozaic's native ERC20 token based on LayerZero OmnichainFungibleToken.
 * @notice Use this contract only on the BASE CHAIN. It locks tokens on source, on outgoing send(), and unlocks tokens when receiving from other chains.
 * It has an hard cap and manages its own emissions and allocations.
 */
contract MozToken is Ownable, OFTV2 {

 	mapping(address => uint256) public userUnlockTime;
    mapping(address => bool) public isAdmin;
    address public mozStaking;
	struct VestingAgreement {
		uint256 lockStart; // timestamp at which locking starts, acts as a locking delay
        uint256 lockPeriod; // time period over which locking occurs. The unit is Day
        uint256 vestPeriod; // time period over which vesting occurs. The unit is Day
        uint256 totalAmount; // total KAP amount to which the beneficiary is promised
    }

    mapping(address => VestingAgreement[]) public vestingAgreements;

	/***********************************************/
	/****************** CONSTRUCTOR ****************/
	/***********************************************/

  	constructor(
		address _layerZeroEndpoint,
        address _mozStaking,
		uint8 _sharedDecimals
	) OFTV2("Mozaic Token", "MOZ", _sharedDecimals, _layerZeroEndpoint) {
        require(_mozStaking != address(0x0), "Invalid address");
		_mint(msg.sender, 545000000 * 10 ** _sharedDecimals); // 54.5% of 1000000000
		isAdmin[msg.sender] = true;
        mozStaking = _mozStaking;
    }

    /***********************************************/
	/********************* EVENT *******************/
	/***********************************************/

    event LockAndVestAndTransfer(address walletAddress, uint256 amount, uint256 lockStart, uint256 lockPeriod, uint256 vestPeriod);

    /***********************************************/
	/****************** MODIFIERS ******************/
	/***********************************************/

	/**
	* @dev Throws error if called by any account other than the master
	*/
    modifier onlyAdmin() {
        require(isAdmin[msg.sender], "Admin is only allowed!");
        _;
    }

    modifier onlyStakingContract() {
        require(msg.sender == mozStaking, "Invalid caller");
        _;
    }

	/*****************************************************************/
	/******************  EXTERNAL FUNCTIONS  *************************/
	/*****************************************************************/

	function setAdmin(address user, bool value) external onlyOwner {
        require(user != address(0x0), "Invalid address");
        isAdmin[user] = value;
    }

	function lockAndVestAndTransfer(
		address walletAddress, 
		uint256 amount, 
		uint256 lockStart,
		uint256 lockPeriod,
		uint256 vestPeriod
	)  public onlyAdmin returns (bool) {
		require(lockStart > block.timestamp, "Lock Start Date should be later than now");
        require(lockPeriod > 0, "Lock Period is too short");
        require(vestPeriod > 0, "Vest Period is too short");
        vestingAgreements[walletAddress].push(VestingAgreement({
			lockStart: lockStart,
			lockPeriod: lockPeriod,
            vestPeriod: vestPeriod,
            totalAmount: amount
        }));
        _transfer(_msgSender(), walletAddress, amount);
        return true;
        emit LockAndVestAndTransfer(walletAddress, amount, lockStart, lockPeriod, vestPeriod);
    }

    function multipleLockAndVestAndTransfer(address[] memory walletAddresses, 
		uint256[] memory amounts, 
		uint256 lockStart,	
		uint256 lockPeriod, 
		uint256 vestPeriod
	)  public onlyAdmin returns (bool) {
        require(lockStart > block.timestamp, "Lock Start Date should be later than now");
        require(lockPeriod > 0, "Lock Period is too short");
        require(vestPeriod > 0, "Vest Period is too short");
        require(walletAddresses.length == amounts.length, "The number of addresses must be equal with the number of amount");
        for (uint256 i = 0; i < walletAddresses.length; i++) {
            vestingAgreements[walletAddresses[i]].push(VestingAgreement({
				lockStart: lockStart,
				lockPeriod: lockPeriod,
                vestPeriod: vestPeriod,
                totalAmount: amounts[i]
            }));
            _transfer(_msgSender(), walletAddresses[i], amounts[i]);
        }
        return true;
    }

    function getNumberOfVestingAgreement(address walletAddress) public view returns (uint256) {
        
        return vestingAgreements[walletAddress].length;
    }

    function getLocked(address walletAddress) public view returns (uint256) {
        uint256 lockedAmount = 0;
    
        for (uint i = 0; i < vestingAgreements[walletAddress].length; i++) {
            lockedAmount += getLockedPerAgreement(walletAddress,i);
        }
        return lockedAmount;
    }

    function getLockedPerAgreement(address walletAddress, uint index) public view returns (uint256) {
        uint256 lockedAmount = 0;
        uint256 unLockedAmount = 0;
		uint256 vestStart = 0;
        VestingAgreement memory currentVest = vestingAgreements[walletAddress][index];
        unLockedAmount = 0;
        vestStart = currentVest.lockStart + currentVest.lockPeriod * 86400;
        if (block.timestamp > vestStart) {
            if (((block.timestamp - vestStart) / 86400) <= currentVest.vestPeriod) {
                unLockedAmount = currentVest.totalAmount * ((block.timestamp - vestStart) / 86400) / currentVest.vestPeriod;
                lockedAmount = currentVest.totalAmount - unLockedAmount;
            } else {
				lockedAmount = 0;
			}
        }
        else {
            lockedAmount = currentVest.totalAmount;
        }
        return lockedAmount;
    }

	function _beforeTokenTransfer( address from, address to, uint256 amount ) internal override {
        require(amount > 0, "Amount must not be 0");
    
        uint256 lockedAmount = 0;
        uint256 lockedAmountPerAgreement = 0;
        if (from == owner() || from == address(0) || isAdmin[msg.sender]) {
            return;
        }
    
        for (uint i = 0; i < vestingAgreements[from].length; i++) {
            lockedAmountPerAgreement = getLockedPerAgreement(from,i);
            lockedAmount += lockedAmountPerAgreement;
        }
        require(balanceOf(from) - lockedAmount >= amount, "Transfer Amount exceeds allowance");
    }
    function burn(uint256 amount, address from) external onlyStakingContract {
        _burn(from, amount);
    }

    function mint(uint256 _amount, address _to) external onlyStakingContract {
        _mint(_to, _amount);
    }
}
