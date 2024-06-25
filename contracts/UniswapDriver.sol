// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-core/contracts/libraries/LowGasSafeMath.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";


/**
 * @title UniswapDriver: This contract is used for managing liquidity pools and swaps on Uniswap V3
 * @notice *DO NOT DEPLOY* This contract is not ready for deployment yet, the purpose of this contract at this stage is to separate the code
 * related to uniswap from the moz token contract. It requires review and refactoring before deployment.
 */

 interface IERC721Receiver {
    function onERC721Received(
        address operator,
        address from,
        uint tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

contract UniswapDriver is Ownable, IERC721Receiver  {

    address public mozStaking;
    address public treasury;

    address private constant SwapRouter = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address private constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    INonfungiblePositionManager public nonfungiblePositionManager =
        INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);

    uint256 public positionTokenId = type(uint256).max;
    uint128 public currentLiquidity;


    /***********************************************/
	/****************** CONSTRUCTOR ****************/
	/***********************************************/

  	constructor(
		address _layerZeroEndpoint,
        address _mozStaking,
		uint8 _sharedDecimal
        )
    {
        require(_mozStaking != address(0x0), "Invalid address");
		_mint(msg.sender, 1000000000 * 10 ** _sharedDecimals);
        mozStaking = _mozStaking;
        liquidityFee = 125; // 1.25%
        treasuryFee = 125; // 1.25%
        totalFees = liquidityFee + treasuryFee;
        swapTokensAtAmount = 20000 * 10 ** _sharedDecimals; // 20k Moz token
    }


    /***********************************************/
	/********************* EVENT *******************/
	/***********************************************/

    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiquidity
    );


	/*****************************************************************/
	/******************  EXTERNAL FUNCTIONS  *************************/
	/*****************************************************************/
   
    function onERC721Received(
        address operator,
        address from,
        uint tokenId,
        bytes calldata
    ) external returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    /*****************************************************************/
	/**************  Liqudity management functions  ******************/
	/*****************************************************************/
    function addLiquidity(uint256 tokenAmount, uint256 wethAmount) private {
        // Create new position if positionTokenId is not set
        if(positionTokenId == type(uint256).max) {
            positionTokenId = mintNewPosition(tokenAmount, wethAmount);
        } else {
            // Claim fee for the position
            collectAllFees(positionTokenId);
            // Add liquidity
            increaseLiquidityCurrentRange(positionTokenId, tokenAmount, wethAmount);
        }
    }

    function mintNewPosition(
        uint amount0ToAdd,
        uint amount1ToAdd
    ) private returns (uint256 tokenId) {

        _approve(address(this), address(nonfungiblePositionManager), amount0ToAdd);
        IWETH(WETH).approve(address(nonfungiblePositionManager), amount1ToAdd);

        INonfungiblePositionManager.MintParams
            memory params = INonfungiblePositionManager.MintParams({
                token0: address(this),
                token1: WETH,
                fee: 3000,
                tickLower: (-887272 / 60) * 60,
                tickUpper: (887272 / 60) * 60,
                amount0Desired: amount0ToAdd,
                amount1Desired: amount1ToAdd,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: block.timestamp
            });

        (tokenId, , , ) = nonfungiblePositionManager.mint(
            params
        );
    }

    function collectAllFees(
        uint tokenId
    ) private {
        INonfungiblePositionManager.CollectParams
            memory params = INonfungiblePositionManager.CollectParams({
                tokenId: tokenId,
                recipient: address(this),
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            });

        nonfungiblePositionManager.collect(params);
    }

    function increaseLiquidityCurrentRange(
        uint tokenId,
        uint amount0ToAdd,
        uint amount1ToAdd
    ) private {
        _approve(address(this), address(nonfungiblePositionManager), amount0ToAdd);
        IWETH(WETH).approve(address(nonfungiblePositionManager), amount1ToAdd);

        INonfungiblePositionManager.IncreaseLiquidityParams
            memory params = INonfungiblePositionManager.IncreaseLiquidityParams({
                tokenId: tokenId,
                amount0Desired: amount0ToAdd,
                amount1Desired: amount1ToAdd,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp
            });

        (currentLiquidity, ,) = nonfungiblePositionManager.increaseLiquidity(
            params
        );
    }

    function decreaseLiquidityCurrentRange(uint128 liquidity)
        external
        onlyOwner
        returns (uint256 amount0, uint256 amount1)
    {
        INonfungiblePositionManager.DecreaseLiquidityParams memory params =
        INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: positionTokenId,
                liquidity: liquidity,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp
            });

        (amount0, amount1) =
            nonfungiblePositionManager.decreaseLiquidity(params);
    }

    // change the minimum amount of tokens to sell from fees
    function updateSwapTokensAtAmount(uint256 newAmount)
        external
        onlyOwner
        returns (bool)
    {
        require(
            newAmount >= (totalSupply() * 1) / 100000,
            "Swap amount cannot be lower than 0.001% total supply."
        );
        swapTokensAtAmount = newAmount;
        return true;
    }
    
    function swapBack() external {

        uint256 contractBalance = balanceOf(address(this));
        require(contractBalance >= swapTokensAtAmount, "Insufficient moz balance");

        uint256 totalTokensToSwap = tokensForLiquidity + tokensForTreasury;

        bool success;

        if (totalTokensToSwap == 0) {
            return;
        }

        // Halve the amount of liquidity tokens
        uint256 liquidityTokens = (contractBalance * tokensForLiquidity) / totalTokensToSwap / 2;
        uint256 treasuryMozToken = (contractBalance * tokensForTreasury) / totalTokensToSwap / 2;
        uint256 amountToSwapForETH = contractBalance / 2;


        swapTokensForEth(amountToSwapForETH);
        uint256 ethBalance = IWETH(WETH).balanceOf(address(this));
        uint256 ethForTreasury = (ethBalance * tokensForTreasury) / totalTokensToSwap / 2;
        uint256 ethForLiquidity = ethBalance - ethForTreasury;
        tokensForLiquidity = 0;
        tokensForTreasury = 0;
        IWETH(WETH).withdraw(ethForTreasury);
        (success, ) = address(treasury).call{value: ethForTreasury}("");
        require(success);
        _transfer(address(this), treasury, treasuryMozToken);
        if (liquidityTokens > 0 && ethForLiquidity > 0) {
            addLiquidity(liquidityTokens, ethForLiquidity);
            emit SwapAndLiquify(
                amountToSwapForETH,
                ethForLiquidity,
                tokensForLiquidity
            );
        }
    }


    function swapTokensForEth(uint256 tokenAmount) private {

        _approve(address(this), SwapRouter, tokenAmount);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: address(this),
                tokenOut: WETH,
                fee: 3000,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: tokenAmount,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
        });
        ISwapRouter(SwapRouter).exactInputSingle(params);
    }

    /*****************************************************************/
    /******************  receive-fallback  ***************************/
    /*****************************************************************/

    fallback() external payable {}

    receive() external payable {}

    
    function withdrawStuckEth(address toAddr) external onlyOwner {
        (bool success, ) = toAddr.call{
            value: address(this).balance
        } ("");
        require(success);
    }
}

interface INonfungiblePositionManager {
    struct MintParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint amount0Desired;
        uint amount1Desired;
        uint amount0Min;
        uint amount1Min;
        address recipient;
        uint deadline;
    }

    function mint(
        MintParams calldata params
    )
        external
        payable
        returns (uint tokenId, uint128 liquidity, uint amount0, uint amount1);

    struct IncreaseLiquidityParams {
        uint tokenId;
        uint amount0Desired;
        uint amount1Desired;
        uint amount0Min;
        uint amount1Min;
        uint deadline;
    }

    function increaseLiquidity(
        IncreaseLiquidityParams calldata params
    ) external payable returns (uint128 liquidity, uint amount0, uint amount1);

    struct DecreaseLiquidityParams {
        uint tokenId;
        uint128 liquidity;
        uint amount0Min;
        uint amount1Min;
        uint deadline;
    }

    function decreaseLiquidity(
        DecreaseLiquidityParams calldata params
    ) external payable returns (uint amount0, uint amount1);

    struct CollectParams {
        uint tokenId;
        address recipient;
        uint128 amount0Max;
        uint128 amount1Max;
    }

    function collect(
        CollectParams calldata params
    ) external payable returns (uint amount0, uint amount1);
}

interface IWETH is IERC20 {
    function deposit() external payable;

    function withdraw(uint amount) external;
}
