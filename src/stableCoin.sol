// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

// SPDX-License-Identifier: MIT


pragma solidity ^0.8.10;
import "@openzepplin/contracts/token/ERC20/ERC20.sol";
import "@openzepplin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzepplin/contracts/access/Ownable.sol";
/** 
*  @title A DecentralizedStableCoin Contract 
*  @author lang lee                       
*  @notice Decentralized Stable Coin                      
*/
contract DecentralizedStableCoin is ERC20Burnable, Ownable {
    error DecentralizedStableCoin_MustBeMoreThanZero();
    error DecentralizedStableCoin_NotEnoughBalanceToBurn();
    error DecentralizedStableCoin_ZeroAddress();

    constructor() ERC20("DecentralizedStableCoin","DSC") {}
    
    function burn(uint256 _amount) public override onlyOwner {
        if (_amount <= 0 ){
            revert DecentralizedStableCoin_MustBeMoreThanZero();
        }
        if (msg.sender.balance < _amount){
            revert DecentralizedStableCoin_NotEnoughBalanceToBurn();
        }
        super.burn(_amount);
    }

    function mint(address _to, uint256 _amount) external onlyOwner returns(bool){
       if (_to == address(0)){
            revert DecentralizedStableCoin_ZeroAddress();
       }
       if ( _amount<=0 ){
            revert DecentralizedStableCoin_MustBeMoreThanZero();
       }
        _mint(_to, _amount);
        return true;
    }
}