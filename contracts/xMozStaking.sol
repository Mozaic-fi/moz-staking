// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract XMozStaking is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    uint256 public constant BP_DENOMINATOR = 10_000;
    uint256 public constant MAX_FEE = 1000;
    uint256 public constant MAX_REWARD_LENGTH = 10;

    struct RewardInfo {
        address token;
        string  name;
        string  symbol;
        uint8   decimals;
        uint256 amount;
    }
    // Mapping to store user staking information
    mapping(address => uint256) public stakingInfo;

    // Mapping to store user's last staked time
    mapping(address => uint256) public lastStakedTime;

    // Mapping to store the accumulated reward amounts (user => token => amount)
    mapping(address => mapping(address => uint256)) public accumulatedRewardAmounts;

    // (user => token => amount)
    mapping(address => mapping(address => uint256)) public lastAccUnitPerShare;

    // Address of the staked token
    address public immutable xMoz;

    uint256 public totalStakedAmount;

    address[] public rewardTokens;

    mapping(address => uint256) public rewardAmountsPerWeek;

    // Time of the last update
    uint256 public lastUpdateTime;

    // Accumulated amount per share for each staked token
    mapping(address => uint256) public accUnitPerShare;

    address public treasury;
    uint256 public treasuryFeeBP;

    event RewardAmountUpdated(uint256[] updatedRewardAmountsPerWeek);
    event TreasurySet(address newTreasury);
    event FeeSet(uint256 newTreasuryFeeBP);
    event Stake(address user, uint256 amount);
    event Unstake(address user, uint256 amount);
    event ClaimReward(address user);
    event setRouterConfig(address[] rewardTokens, uint256[] rewardAmountsPerWeek);


    // Contract constructor
    constructor(address _xMoz, uint256 _startTime) {
        require(_xMoz != address(0), "Invalid reward token address");
        xMoz = _xMoz;
        initialize(_startTime);
    }

    function setRewardConfig(address[] calldata _rewardTokens, uint256[] calldata _rewardAmountsPerWeek) external onlyOwner {
        require(_rewardTokens.length == _rewardAmountsPerWeek.length && rewardTokens.length == 0 && _rewardTokens.length <= MAX_REWARD_LENGTH, "XMozStaking: Invalid length");
        update();
        rewardTokens = _rewardTokens;
        for(uint256 i = 0 ; i < _rewardTokens.length; i++) {
            rewardAmountsPerWeek[_rewardTokens[i]] = _rewardAmountsPerWeek[i];
        }
        emit setRouterConfig(_rewardTokens, _rewardAmountsPerWeek);
    }

    function addRewardToken(address _rewardToken, uint256 _rewardAmountPerWeek) external onlyOwner {
        require(rewardTokens.length + 1 <= MAX_REWARD_LENGTH, "XMozStaking: exceed the max reward token numbers");
        bool isExist = false;
        for(uint256 i = 0 ; i < rewardTokens.length; i++) {
            if(rewardTokens[i] == _rewardToken) {
                isExist = true;
                break;
            }
        }
        require(isExist == false, "XMozStaking: reward token already exist");
        rewardTokens.push(_rewardToken);
        rewardAmountsPerWeek[_rewardToken] = _rewardAmountPerWeek;
    }
    
    function updateRewardAmountPerweek(uint256[] calldata _rewardAmountsPerWeek) external onlyOwner {
        require(rewardTokens.length == _rewardAmountsPerWeek.length, "XMozStaking: Invalid length");
        update();
        for(uint256 i = 0 ; i < rewardTokens.length; i++) {
            rewardAmountsPerWeek[rewardTokens[i]] = _rewardAmountsPerWeek[i];
        }
        emit RewardAmountUpdated(_rewardAmountsPerWeek);
    }

    function setTreasury(address _treasury) external onlyOwner {
        require(_treasury != address(0), "XMozStaking: Invalid address");
        treasury = _treasury;
        emit TreasurySet(_treasury);
    }

    function setFee(uint256 _treasuryFeeBP) external onlyOwner {
        require(_treasuryFeeBP <= MAX_FEE, "XMozStaking: fees > limit");
        treasuryFeeBP = _treasuryFeeBP;
        emit FeeSet((_treasuryFeeBP));
    }

    // Function to check the available balance of staked tokens for a specific user
    function balanceOf(address _account) external view returns (uint256) {
        uint256 xMozBalance = IERC20(xMoz).balanceOf(_account);
        return xMozBalance < stakingInfo[_account] ? 0 : xMozBalance - stakingInfo[_account];
    }

    // Function to stake tokens into the contract
    function stake(uint256 _amount) external {
        require(_amount > 0, "XMozStaking: Invalid stake amount");
        synchronizeXMozBalance(msg.sender);
        require(
            stakingInfo[msg.sender] + _amount <= IERC20(xMoz).balanceOf(msg.sender),
            "XMozStaking: Insufficient staked tokens"
        );
        update();
        if (stakingInfo[msg.sender] > 0) {
            accumulateReward();
        }
        // Update user information
        lastStakedTime[msg.sender] = block.timestamp;
        stakingInfo[msg.sender] += _amount;
        totalStakedAmount += _amount;
        for(uint i = 0; i < rewardTokens.length; i++) {
            address token = rewardTokens[i];
            lastAccUnitPerShare[msg.sender][token] = accUnitPerShare[token];
        }
        emit Stake(msg.sender, _amount);
    }

    // Function to unstake tokens from the contract
    function unstake(uint256 _amount) external {
        require(block.timestamp - lastStakedTime[msg.sender] >= 1 weeks, "XMozStaking: Early unstake is not supported");
        require(_amount > 0, "XMozStaking: Invalid unstake amount");
        // StakingInfo storage user = stakingInfo[msg.sender];
        synchronizeXMozBalance(msg.sender);
        require(stakingInfo[msg.sender] >= _amount, "XMozStaking: Insufficient staked amount");
        update();
        accumulateReward();
        distributeReward();
        // Update user information
        stakingInfo[msg.sender] -= _amount;
        totalStakedAmount  = totalStakedAmount >= _amount ? totalStakedAmount - _amount : 0;
        for(uint i = 0; i < rewardTokens.length; i++) {
            address token = rewardTokens[i];
            lastAccUnitPerShare[msg.sender][token] = accUnitPerShare[token];
        }
        emit Unstake(msg.sender, _amount);
    }

    // Function to claim pending rewards
    function claimReward() external {
        // Synchronize balances, update reward calculations, and distribute rewards
        synchronizeXMozBalance(msg.sender);
        update();
        accumulateReward();
        distributeReward();

        // Update user's reward debts
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            address token = rewardTokens[i];
            lastAccUnitPerShare[msg.sender][token] = accUnitPerShare[token];
        }
        emit ClaimReward(msg.sender);
    }

    function accumulateReward() internal {
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            address token = rewardTokens[i];
            uint256 userStake = stakingInfo[msg.sender];
            uint256 accPerShare = accUnitPerShare[token];
            uint256 lastAccPerShare = lastAccUnitPerShare[msg.sender][token];

            uint256 rewardAmount = userStake.mul(accPerShare.sub(lastAccPerShare)).div(1e30);
            accumulatedRewardAmounts[msg.sender][token] += rewardAmount;
        }
    }

    function distributeReward() internal {
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            address token = rewardTokens[i];
            uint256 userRewardAmount = accumulatedRewardAmounts[msg.sender][token];

            // Ensure the reward amount is greater than zero before transferring
            if (userRewardAmount > 0) {
                accumulatedRewardAmounts[msg.sender][token] = 0;  // Reset the accumulated reward amount
                safeRewardTransfer(token, msg.sender, userRewardAmount);
            }
        }
    }

    function claimRewardForToken(address token) external {
        uint256 rewardAmount = accumulatedRewardAmounts[msg.sender][token];
        accumulatedRewardAmounts[msg.sender][token] = 0;
        safeRewardTransfer(token, msg.sender, rewardAmount);
    }
    
    // Function to safely transfer rewards
    function safeRewardTransfer(address _rewardToken, address _to, uint256 _amount) internal {
        uint256 rewardBalance = IERC20(_rewardToken).balanceOf(address(this));
        uint256 transferAmount = (_amount < rewardBalance) ? _amount : rewardBalance;

        // Use SafeMath for fee calculation
        uint256 fee = transferAmount.mul(treasuryFeeBP).div(BP_DENOMINATOR);
        uint256 rewardAmount = transferAmount.sub(fee);

        // Check if the contract has enough balance before transfers
        require(rewardAmount <= rewardBalance, "Insufficient reward balance");

        // Use try-catch to handle transfer failures
        if(rewardAmount > 0) {
            try IERC20(_rewardToken).transfer(_to, rewardAmount) {
            } catch {}
        }

        // Check if fee is greater than 0 before transferring to treasury
        if (fee > 0) {
            try IERC20(_rewardToken).transfer(treasury, fee) {
            } catch {}
        }
    }
    
    // Function to update reward distribution information
    function update() internal {
        uint256 timeSinceLastUpdate = block.timestamp - lastUpdateTime;
        uint256 durationInPeriods = timeSinceLastUpdate / (1 weeks);
        uint256 remainingTimeInCurrentPeriod = timeSinceLastUpdate % (1 weeks);

        if (totalStakedAmount == 0) {
            lastUpdateTime = block.timestamp - remainingTimeInCurrentPeriod;
            return;
        }

        uint256 supply = totalStakedAmount;

        for (uint256 i = 0; i < rewardTokens.length; i++) {
            uint256 rewardInPeriod = durationInPeriods.mul(rewardAmountsPerWeek[rewardTokens[i]]);
            uint256 rewardPerShare = rewardInPeriod.mul(1e30).div(supply);
            accUnitPerShare[rewardTokens[i]] += rewardPerShare;
        }

        lastUpdateTime = block.timestamp - remainingTimeInCurrentPeriod;
    }

    function synchronizeXMozBalance(address user) internal {
        uint256 userXMozBalance = IERC20(xMoz).balanceOf(user);

        // Check if the staked xMoz balance is greater than the actual xMoz balance
        if (stakingInfo[user] > userXMozBalance) {
            // Adjust the total staked amount and update the staking info
            totalStakedAmount -= (stakingInfo[user] - userXMozBalance);
            stakingInfo[user] = userXMozBalance;
        }
    }

    // Function to initialize contract parameters
    function initialize(uint256 _startTime) internal {
        uint256 diff1 = _startTime % (1 weeks);
        uint256 diff2 = block.timestamp % (1 weeks);
        lastUpdateTime = block.timestamp + diff1 - diff2;
    }

    function getRewardTokens() public view returns (address[] memory) {
        return rewardTokens;
    }

    function getRewardAmountsPerWeek() public view returns(RewardInfo[] memory) {
        RewardInfo[] memory info = new RewardInfo[](rewardTokens.length);
        
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            info[i].token = rewardTokens[i];
            info[i].decimals = IERC20Metadata(rewardTokens[i]).decimals();
            info[i].name = IERC20Metadata(rewardTokens[i]).name();
            info[i].symbol = IERC20Metadata(rewardTokens[i]).symbol();
            info[i].amount = rewardAmountsPerWeek[rewardTokens[i]];
        }
        return info;
    }

    function getRewardAmounts() public view returns(RewardInfo[] memory) {
        RewardInfo[] memory info = new RewardInfo[](rewardTokens.length);
        
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            info[i].token = rewardTokens[i];
            info[i].decimals = IERC20Metadata(rewardTokens[i]).decimals();
            info[i].name = IERC20Metadata(rewardTokens[i]).name();
            info[i].symbol = IERC20Metadata(rewardTokens[i]).symbol();
            info[i].amount = IERC20(rewardTokens[i]).balanceOf(address(this));
        }
        return info;
    }

    // Retrieves the claimable amounts for a specific user and all reward tokens
    function getClaimableAmounts(address user) public view returns (RewardInfo[] memory) {
        uint256[] memory _accUnitPerShare = new uint256[](rewardTokens.length);
        RewardInfo[] memory info = new RewardInfo[](rewardTokens.length);

        uint256 timeSinceLastUpdate = block.timestamp - lastUpdateTime;
        uint256 durationInPeriods = timeSinceLastUpdate / (1 weeks);

        uint256 supply = totalStakedAmount;
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            info[i].token = rewardTokens[i];
            info[i].decimals = IERC20Metadata(rewardTokens[i]).decimals();
            info[i].name = IERC20Metadata(rewardTokens[i]).name();
            info[i].symbol = IERC20Metadata(rewardTokens[i]).symbol();
            info[i].amount = accumulatedRewardAmounts[user][rewardTokens[i]];
        }
        if(supply == 0 || durationInPeriods == 0) {
            return info;
        }
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            uint256 rewardInPeriod = durationInPeriods.mul(rewardAmountsPerWeek[rewardTokens[i]]);
            uint256 rewardPerShare = rewardInPeriod.mul(1e30).div(supply);
            _accUnitPerShare[i] += rewardPerShare + accUnitPerShare[rewardTokens[i]];
        }

        uint256 xMozBalance = IERC20(xMoz).balanceOf(user);
        uint256 stakedBalance = stakingInfo[user];
        uint256 userStake = stakedBalance > xMozBalance ? xMozBalance : stakedBalance;
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            address token = rewardTokens[i];
            uint256 accPerShare = _accUnitPerShare[i];
            uint256 lastAccPerShare = lastAccUnitPerShare[user][token];

           info[i].amount += userStake.mul(accPerShare.sub(lastAccPerShare)).div(1e30);
        }
        return info;
    }
}