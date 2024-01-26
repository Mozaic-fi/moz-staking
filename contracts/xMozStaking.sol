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

    // Mapping to store the last accumulated unit per share for each user and token
    mapping(address => mapping(address => uint256)) public lastAccUnitPerShare;

    // Address of the staked token
    address public immutable xMoz;

    // Total amount of staked tokens across all users
    uint256 public totalStakedAmount;

    // List of reward tokens
    address[] public rewardTokens;

    // Mapping to store reward amounts per week for each token
    mapping(address => uint256) public rewardAmountsPerWeek;

    // Time of the last update
    uint256 public lastUpdateTime;

    // Accumulated amount per share for each staked token
    mapping(address => uint256) public accUnitPerShare;

    // List of tokens to be skipped during certain operations
    address[] public skippedTokens;

    // Address of the treasury
    address public treasury;

    // Treasury fee in basis points (BP)
    uint256 public treasuryFeeBP;

    // Events to log changes in the contract state
    event RewardAmountUpdated(uint256[] updatedRewardAmountsPerWeek);
    event TreasurySet(address newTreasury);
    event FeeSet(uint256 newTreasuryFeeBP);
    event Stake(address user, uint256 amount);
    event Unstake(address user, uint256 amount);
    event ClaimReward(address user);
    event SetRouterConfig(address[] rewardTokens, uint256[] rewardAmountsPerWeek);
    event SetSkippedTokens(address[] skippedTokens);

    // Contract constructor
    constructor(address _xMoz, uint256 _startTime) {
        require(_xMoz != address(0), "Invalid reward token address");
        xMoz = _xMoz;
        initialize(_startTime);
    }

    // Function to set reward configuration with an array of reward tokens and corresponding amounts per week
    function setRewardConfig(address[] calldata _rewardTokens, uint256[] calldata _rewardAmountsPerWeek) external onlyOwner {
        // Ensure valid input lengths and that the contract has not been configured previously
        require(_rewardTokens.length == _rewardAmountsPerWeek.length && rewardTokens.length == 0 && _rewardTokens.length <= MAX_REWARD_LENGTH, "XMozStaking: Invalid length");
        // Update the contract state
        update();
        // Set reward tokens and amounts per week
        rewardTokens = _rewardTokens;
        for(uint256 i = 0 ; i < _rewardTokens.length; i++) {
            rewardAmountsPerWeek[_rewardTokens[i]] = _rewardAmountsPerWeek[i];
        }
        // Emit an event indicating the reward configuration has been updated
        emit SetRouterConfig(_rewardTokens, _rewardAmountsPerWeek);
    }

    // Function to set the list of skipped tokens
    function setSkippedTokens(address[] calldata _skippedTokens) external onlyOwner {
        // Set the list of skipped tokens
        skippedTokens = _skippedTokens;
        // Emit an event indicating the skipped tokens have been updated
        emit SetSkippedTokens(_skippedTokens);
    }

    // Function to add a new reward token with a specified amount per week
    function addRewardToken(address _rewardToken, uint256 _rewardAmountPerWeek) external onlyOwner {
        // Ensure the maximum number of reward tokens has not been exceeded and the token doesn't already exist
        require(rewardTokens.length + 1 <= MAX_REWARD_LENGTH, "XMozStaking: exceed the max reward token numbers");
        bool isExist = false;
        for(uint256 i = 0 ; i < rewardTokens.length; i++) {
            if(rewardTokens[i] == _rewardToken) {
                isExist = true;
                break;
            }
        }
        require(isExist == false, "XMozStaking: reward token already exist");
        // Update the contract state
        update();
        // Add the new reward token and set its amount per week
        rewardTokens.push(_rewardToken);
        rewardAmountsPerWeek[_rewardToken] = _rewardAmountPerWeek;
    }

    // Function to update reward amounts per week for existing reward tokens
    function updateRewardAmountPerweek(uint256[] calldata _rewardAmountsPerWeek) external onlyOwner {
        // Ensure the input length matches the number of existing reward tokens
        require(rewardTokens.length == _rewardAmountsPerWeek.length, "XMozStaking: Invalid length");
        // Update the contract state
        update();
        // Update reward amounts per week for each existing reward token
        for(uint256 i = 0 ; i < rewardTokens.length; i++) {
            rewardAmountsPerWeek[rewardTokens[i]] = _rewardAmountsPerWeek[i];
        }
        // Emit an event indicating the reward amounts per week have been updated
        emit RewardAmountUpdated(_rewardAmountsPerWeek);
    }

    // Function to set the treasury address
    function setTreasury(address _treasury) external onlyOwner {
        // Ensure the treasury address is valid
        require(_treasury != address(0), "XMozStaking: Invalid address");
        // Set the treasury address
        treasury = _treasury;
        // Emit an event indicating the treasury address has been set
        emit TreasurySet(_treasury);
    }

    // Function to set the treasury fee in basis points
    function setFee(uint256 _treasuryFeeBP) external onlyOwner {
        // Ensure the treasury fee is within the allowed limit
        require(_treasuryFeeBP <= MAX_FEE, "XMozStaking: fees > limit");
        // Set the treasury fee
        treasuryFeeBP = _treasuryFeeBP;
        // Emit an event indicating the treasury fee has been set
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

        updateLastAccUnitPerShare();
        emit Stake(msg.sender, _amount);
    }

    // Function to unstake tokens from the contract
    function unstake(uint256 _amount) external {
        require(block.timestamp - lastStakedTime[msg.sender] >= 1 weeks, "XMozStaking: Early unstake is not supported");
        require(_amount > 0, "XMozStaking: Invalid unstake amount");
        synchronizeXMozBalance(msg.sender);
        require(stakingInfo[msg.sender] >= _amount, "XMozStaking: Insufficient staked amount");
        update();
        accumulateReward();

        // Update user information
        stakingInfo[msg.sender] -= _amount;
        totalStakedAmount  = totalStakedAmount >= _amount ? totalStakedAmount - _amount : 0;
        updateLastAccUnitPerShare();
        // Distribute rewards to user
        distributeReward();
        emit Unstake(msg.sender, _amount);
    }

    // Function to claim pending rewards
    function claimReward() external {
        // Synchronize balances, update reward calculations
        synchronizeXMozBalance(msg.sender);
        update();
        accumulateReward();
        updateLastAccUnitPerShare();
        // Distribute rewards to user
        distributeReward();
        emit ClaimReward(msg.sender);
    }

    // Function to accumulate rewards for the user across all reward tokens
    function accumulateReward() internal {
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            address token = rewardTokens[i];
            uint256 userStake = stakingInfo[msg.sender];
            uint256 accPerShare = accUnitPerShare[token];
            uint256 lastAccPerShare = lastAccUnitPerShare[msg.sender][token];

            // Calculate the reward amount based on user's stake and accumulated per-share values
            uint256 rewardAmount = userStake.mul(accPerShare.sub(lastAccPerShare)).div(1e30);
            // Accumulate the reward amount for the user and token
            accumulatedRewardAmounts[msg.sender][token] += rewardAmount;
        }
    }

    // Function to distribute accumulated rewards to the user
    function distributeReward() internal {
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            address token = rewardTokens[i];
            uint256 userRewardAmount = accumulatedRewardAmounts[msg.sender][token];

            // Ensure the reward amount is greater than zero before transferring
            if (userRewardAmount > 0) {
                // Reset the accumulated reward amount
                accumulatedRewardAmounts[msg.sender][token] = 0;
                // Transfer the reward amount to the user
                safeRewardTransfer(token, msg.sender, userRewardAmount);
            }
        }
    }

    // Function to update the last accumulated per-share value for the user across all reward tokens
    function updateLastAccUnitPerShare() internal {
        for(uint i = 0; i < rewardTokens.length; i++) {
            address token = rewardTokens[i];
            // Update the last accumulated per-share value for the user and token
            lastAccUnitPerShare[msg.sender][token] = accUnitPerShare[token];
        }
    }

    // Function to allow the user to claim rewards for a specific token
    function claimRewardForToken(address token) external {
        // Retrieve the reward amount for the user and token
        uint256 rewardAmount = accumulatedRewardAmounts[msg.sender][token];
        // Reset the accumulated reward amount for the user and token
        accumulatedRewardAmounts[msg.sender][token] = 0;
        // Transfer the claimed reward amount to the user
        safeRewardTransfer(token, msg.sender, rewardAmount);
    }

    
    // Function to safely transfer rewards
    function safeRewardTransfer(address _rewardToken, address _to, uint256 _amount) internal {
        uint256 rewardBalance = IERC20(_rewardToken).balanceOf(address(this));
        uint256 transferAmount = (_amount < rewardBalance) ? _amount : rewardBalance;

        // Use SafeMath for fee calculation
        if(treasury == address(0)) {
            _safeTransfer(_rewardToken, _to, transferAmount);
            return;
        }
        uint256 fee = transferAmount.mul(treasuryFeeBP).div(BP_DENOMINATOR);
        uint256 rewardAmount = transferAmount.sub(fee);

        // Check if the contract has enough balance before transfers
        require(rewardAmount <= rewardBalance, "Insufficient reward balance");

        // Transfer the reward to user and treasury
        _safeTransfer(_rewardToken, _to, rewardAmount);
        _safeTransfer(_rewardToken, treasury, fee);
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

   // Function to synchronize the staked xMoz balance of a user with their actual xMoz token balance
    function synchronizeXMozBalance(address user) internal {
        // Retrieve the actual xMoz balance of the user
        uint256 userXMozBalance = IERC20(xMoz).balanceOf(user);

        // Check if the staked xMoz balance is greater than the actual xMoz balance
        if (stakingInfo[user] > userXMozBalance) {
            // Adjust the total staked amount by reducing the excess staked xMoz
            totalStakedAmount -= (stakingInfo[user] - userXMozBalance);
            // Update the staking info to match the actual xMoz balance
            stakingInfo[user] = userXMozBalance;
        }
    }


    // Function to initialize contract parameters
    function initialize(uint256 _startTime) internal {
        uint256 diff1 = _startTime % (1 weeks);
        uint256 diff2 = block.timestamp % (1 weeks);
        lastUpdateTime = block.timestamp + diff1 - diff2;
    }

   // Internal function to safely transfer tokens, with optional skipping for certain tokens
    function _safeTransfer(address token, address to, uint256 value) internal {
        // Ensure the token address has associated code
        require(token.code.length != 0, "token address has no code");
        // If the transfer value is zero, skip the transfer
        if (value == 0) return;

        // Skip the transfer if the token is in the list of skipped tokens
        for (uint256 i; i < skippedTokens.length; i++) {
            if (token == skippedTokens[i]) {
                return;
            }
        }

        // Execute the token transfer
        (bool success, bytes memory data) = token.call(abi.encodeCall(IERC20.transfer, (to, value)));
        // Ensure the transfer was successful and returned true
        require(success, "transfer reverted");
        require(data.length == 0 || abi.decode(data, (bool)), "transfer returned false");
    }

    // Function to get an array of reward tokens
    function getRewardTokens() public view returns (address[] memory) {
        return rewardTokens;
    }

    // Function to get an array of RewardInfo structs containing reward token information and amounts per week
    function getRewardAmountsPerWeek() public view returns (RewardInfo[] memory) {
        RewardInfo[] memory info = new RewardInfo[](rewardTokens.length);

        for (uint256 i = 0; i < rewardTokens.length; i++) {
            // Populate RewardInfo struct with token information
            info[i].token = rewardTokens[i];
            info[i].decimals = IERC20Metadata(rewardTokens[i]).decimals();
            info[i].name = IERC20Metadata(rewardTokens[i]).name();
            info[i].symbol = IERC20Metadata(rewardTokens[i]).symbol();
            // Set the amount per week from the contract's configuration
            info[i].amount = rewardAmountsPerWeek[rewardTokens[i]];
        }
        return info;
    }

    // Function to get an array of RewardInfo structs containing reward token information and current contract balances
    function getRewardAmounts() public view returns (RewardInfo[] memory) {
        RewardInfo[] memory info = new RewardInfo[](rewardTokens.length);

        for (uint256 i = 0; i < rewardTokens.length; i++) {
            // Populate RewardInfo struct with token information
            info[i].token = rewardTokens[i];
            info[i].decimals = IERC20Metadata(rewardTokens[i]).decimals();
            info[i].name = IERC20Metadata(rewardTokens[i]).name();
            info[i].symbol = IERC20Metadata(rewardTokens[i]).symbol();
            // Set the amount as the current balance of the contract for the reward token
            info[i].amount = IERC20(rewardTokens[i]).balanceOf(address(this));
        }
        return info;
    }

    // Function to get an array of RewardInfo structs containing claimable amounts for a specific user
    function getClaimableAmounts(address user) public view returns (RewardInfo[] memory) {
        uint256[] memory _accUnitPerShare = new uint256[](rewardTokens.length);
        RewardInfo[] memory info = new RewardInfo[](rewardTokens.length);

        // Calculate time since the last update
        uint256 timeSinceLastUpdate = block.timestamp - lastUpdateTime;
        // Calculate the number of periods since the last update (1 week periods)
        uint256 durationInPeriods = timeSinceLastUpdate / (1 weeks);

        uint256 supply = totalStakedAmount;
        uint256 xMozBalance = IERC20(xMoz).balanceOf(user);
        uint256 stakedBalance = stakingInfo[user];

        // Adjust supply and staked balance if staked balance exceeds xMoz balance
        if (stakedBalance > xMozBalance) {
            supply -= stakedBalance - xMozBalance;
            stakedBalance = xMozBalance;
        }

        for (uint256 i = 0; i < rewardTokens.length; i++) {
            // Populate RewardInfo struct with token information
            info[i].token = rewardTokens[i];
            info[i].decimals = IERC20Metadata(rewardTokens[i]).decimals();
            info[i].name = IERC20Metadata(rewardTokens[i]).name();
            info[i].symbol = IERC20Metadata(rewardTokens[i]).symbol();
            // Set the amount as the accumulated reward amount for the user and token
            info[i].amount = accumulatedRewardAmounts[user][rewardTokens[i]];
        }

        // Skip further calculations if supply or duration is zero
        if (supply == 0 || durationInPeriods == 0) {
            return info;
        }

        for (uint256 i = 0; i < rewardTokens.length; i++) {
            // Calculate reward in period for the reward token
            uint256 rewardInPeriod = durationInPeriods.mul(rewardAmountsPerWeek[rewardTokens[i]]);
            // Calculate reward per share for the reward token
            uint256 rewardPerShare = rewardInPeriod.mul(1e30).div(supply);
            _accUnitPerShare[i] += rewardPerShare + accUnitPerShare[rewardTokens[i]];
        }

        for (uint256 i = 0; i < rewardTokens.length; i++) {
            address token = rewardTokens[i];
            uint256 accPerShare = _accUnitPerShare[i];
            uint256 lastAccPerShare = lastAccUnitPerShare[user][token];

            // Update the amount by adding the reward for the staked balance
            info[i].amount += stakedBalance.mul(accPerShare.sub(lastAccPerShare)).div(1e30);
        }
        return info;
    }

}