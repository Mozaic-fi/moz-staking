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

    using SafeERC20 for IERC20;
    address public mozStaking;
    address public treasury;


    bool public taxEnabled = false;

    uint256 public maxFee = 1000; // 10%
    uint256 internal totalFees;
    uint256 public liquidityFee;
    uint256 public treasuryFee;


    uint256 public tokensForLiquidity;
    uint256 public tokensForTreasury;

    // store addresses that a automatic market maker pairs

    mapping(address => bool) public automatedMarketMakerPairs;

	/***********************************************/
	/****************** CONSTRUCTOR ****************/
	/***********************************************/

  	constructor(
		address _layerZeroEndpoint,
        address _mozStaking,
		uint8 _sharedDecimals
	) OFTV2("Mozaic Token", "MOZ", _sharedDecimals, _layerZeroEndpoint) {
        require(_mozStaking != address(0x0), "Invalid address");
		_mint(msg.sender, 1000000000 * 10 ** _sharedDecimals);
        mozStaking = _mozStaking;
        liquidityFee = 125; // 1.25%
        treasuryFee = 125; // 1.25%
        totalFees = liquidityFee + treasuryFee;
    }

    receive() external payable {}

    /***********************************************/
	/********************* EVENT *******************/
	/***********************************************/

    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);

    event TreasuryWalletUpdated(
        address indexed newWallet,
        address indexed oldWallet
    );

    /***********************************************/
	/****************** MODIFIERS ******************/
	/***********************************************/

    modifier onlyStakingContract() {
        require(msg.sender == mozStaking, "Invalid caller");
        _;
    }

    /***********************************************/
    /********** Administrative functions ***********/
    /***********************************************/

    // only use to disable tax if absolutely necessary (emergency use only)
    function updateTaxEnabled(bool enabled) external onlyOwner {
        taxEnabled = enabled;
    }

    function updateFees(
        uint256 _liquidityFee,
        uint256 _treasuryFee
    ) external onlyOwner {
        liquidityFee = _liquidityFee;
        treasuryFee = _treasuryFee;
        totalFees = liquidityFee + treasuryFee;
        require(totalFees <= maxFee, "Buy fees must be <= 5%.");
    }

    function updateTreasuryWallet(address newTreasury) external onlyOwner {
        treasury = newTreasury;
        emit TreasuryWalletUpdated(newTreasury, treasury);
    }

    function setAutomatedMarketMakerPair(address pair, bool value) 
        public 
        onlyOwner
    {
        require(
            pair != address(0x0),
            "The pair cannot be zero address"
        );

        automatedMarketMakerPairs[pair] = value;
        emit SetAutomatedMarketMakerPair(pair, value);

    }

    function withdrawStuckToken(address token,address _to) external onlyOwner {
        require(_to != address(0), "Zero address");
        uint256 _contractMozBalance = balanceOf(address(this));
        uint256 _contractTokenBalance = IERC20(token).balanceOf(address(this));
        IERC20(address(this)).transfer(_to, _contractMozBalance);
        IERC20(WETH).safeTransfer(_to, _contractTokenBalance);
    }

    function withdrawStuckEth(address toAddr) external onlyOwner {
        (bool success, ) = toAddr.call{
            value: address(this).balance
        } ("");
        require(success);
    }

    /***********************************************/
    /********** Tokenomics functions ***************/
    /***********************************************/

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {

        uint256 fees = 0;
        // only take fees on buys/sells, do not take on wallet transfers
        if (taxEnabled && amount > 0) {
            if(automatedMarketMakerPairs[to] || automatedMarketMakerPairs[from]) {
                if(totalFees > 0) {
                    fees = (amount * totalFees) / 10000;
                    tokensForLiquidity += (fees * liquidityFee) / totalFees;
                    tokensForTreasury += (fees * treasuryFee) / totalFees;
                }
            }
        }

        if(fees > 0) {
            super._transfer(from, address(this), fees);
            amount -= fees;
        }
        super._transfer(from, to, amount);
    }

    function burn(uint256 amount, address from) external onlyStakingContract {
        _burn(from, amount);
    }

    function mint(uint256 _amount, address _to) external onlyStakingContract {
        _mint(_to, _amount);
    }
}

