// SPDX-License-Identifier: BUSL-1.1
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// pragma solidity 0.7.6;
pragma solidity ^0.8.0;

contract TestnetFaucet {

    mapping(address => uint8) public acceptedTokens;
    uint256 constant public AIRDROP_AMOUNT = 10 ;

    constructor(
        address[] memory acceptedTokens_,
        uint8[] memory decimals_
    ) {
        
     for(uint256 i=0; i<acceptedTokens_.length; i++) {
        acceptedTokens[acceptedTokens_[i]] = decimals_[i];
     }

    }

    function airDropTokens(address _token, address _to) public {
        require(acceptedTokens[_token] != 0, "Not supported token");
        IERC20(_token).transfer(_to, AIRDROP_AMOUNT * 10 ** acceptedTokens[_token]);
    }

    receive() external payable {}

    function airDropNativeToken() public {
        amount = 0.01 ether;
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Vault: Failed to send Ether");
    }
}
