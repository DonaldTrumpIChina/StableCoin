
// SPDX-License-Identifier: MIT


pragma solidity ^0.8.10;
import {DecentralizedStableCoin} from "../stableCoin.sol";
import {IERC20} from "@openzepplin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzepplin/contracts/security/ReentrancyGuard.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {OracleLib} from "../lib/OrcleLib.sol";
import {engineBase} from "./engineBase.sol";

contract DSCEngine is ReentrancyGuard, engineBase {
    
    using OracleLib for AggregatorV3Interface;
 
    constructor(address[] memory tokens,
     address[] memory priceFeed, 
     address DSCAddress)
     {
        if (tokens.length != priceFeed.length){
            revert engineBase.DSCEngine_InvalidInitData();
        }
        i_DSCInstance = DecentralizedStableCoin(DSCAddress);
        for (uint i=0;i<tokens.length;i++){
            _s_exchangeRateToDSC[tokens[i]] = priceFeed[i];
            _s_tokensSupplied.push(tokens[i]);
        }
    }
   function depositCollateral
        (address token, uint256 amount)
        external
        engineBase.mustValidCollateralType(token)
        engineBase.moreThanZero(amount) 
        nonReentrant 
    {
        _getCollateral(msg.sender,token,address(this), amount);
        emit engineBase.DSCEngine_DpositeCollateral(msg.sender, token, amount);
        
    }

    function redeemCollateral(address token,uint256 amout) external 
    engineBase.mustValidCollateralType(token)
    engineBase.moreThanZero(amout)
    engineBase.avoidZeroAddress(msg.sender)
    nonReentrant
    {
        _redeemCollateral(msg.sender, token, amout);
    }    

    function redeemDSC() external{
        
    }
    
    function mintDsc(uint256 amount)
    external
    engineBase.avoidZeroAddress(msg.sender) 
    engineBase.moreThanZero(amount)
    nonReentrant
    {
        if (!_checkHaveEnoughCollateral(msg.sender, amount)){
            revert engineBase.DSCEngine_noEnoughCollateralToMint();
        }
        _s_haveMintDSC[msg.sender] += amount;
        _revertIfNotHealth(msg.sender);
        bool success = i_DSCInstance.mint(msg.sender, amount);
        if (!success) {
            revert engineBase.DSCEngine_mintError();
        }
        emit engineBase.DSCEngine_MintDSC(msg.sender, amount);
    }
   function burnDSC(address user,uint256 amount) public 
   engineBase.mustEnoughDSC(user,amount)
   {
        _burnDsc(user,amount);
   }

    function liquidate(address user, uint256 debt) public
    engineBase.moreThanZero(debt)
    engineBase.avoidZeroAddress(user)
    {
        uint256 startHealthFactor = _getHealthFactor(user);
        if (startHealthFactor >= HEALTH_FACTOR_THRESHOLD){ 
            revert engineBase.DSCEngine_UserIsHealthy();
        }
        uint256 length = _s_tokensSupplied.length;
        uint256 noRepaidDebt = debt;
        for(uint256 i=0;i<length;i++){
            address token = _s_tokensSupplied[i];
            if ( _s_userAllCollateral[user][token]> 0){
                uint256 result = _liquidate(token,user,noRepaidDebt, msg.sender);
                if (result==0){
                    noRepaidDebt = 0;
                    break;
                }
                noRepaidDebt = result;
            }
        }
        if (noRepaidDebt > 0){
            revert engineBase.DSCEngine_BadDebt();
        }
        _burnDsc(user, debt);
    }
    
  
    function exchangeRateMonitor() external {}

    function _revertIfNotHealth(address user) view private {
        uint256 healthFactor = _getHealthFactor(user);
        if (healthFactor < HEALTH_FACTOR_THRESHOLD){
            revert engineBase.DSCEngine_notHealth();
        }
    }

    function _updateExchangeRateToDSC() private {}

    function getHealthFactor(address user) external view returns (uint256){
       return _getHealthFactor(user); 
    }
    function _getHealthFactor(address user) private view returns (uint256){
        uint256 totalMintedValue = _getTotalMintedDSC(user);
        if (totalMintedValue == 0){
            return type(uint256).max;
        }
        uint256 totalCollateralValue = _getTotalCollateralValue(user);
        return _valueToDSC(totalCollateralValue) / totalMintedValue;   
        
    }
    function getTotalCollateralValue(address user) external view returns (uint256){
        return _getTotalCollateralValue(user);
    }     

    function _getTotalCollateralValue(address user) private view returns (uint256){
        uint256 length = _s_tokensSupplied.length;
        uint256 totalValue=0;
        for(uint256 i=0;i<length;i++){
            uint256 tokenAmount = _s_userAllCollateral[user][_s_tokensSupplied[i]];
            totalValue = totalValue + getTokenValue(_s_tokensSupplied[i],tokenAmount);
        }
        return totalValue;
    }
   
    function _getTotalMintedDSC(address user) private view returns (uint256){
        return _s_haveMintDSC[user];
    }

    function valueToDSC(uint256 value) external pure returns (uint256){
        return _valueToDSC(value);
    }
    function _valueToDSC(uint256 value) private pure returns (uint256){
        return ((value * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION);
    }
    function _burnDsc(address user, uint256 value) private
    {
        _s_haveMintDSC[user] -= value;
        _getCollateral(user, address(i_DSCInstance), address(this), value);
    }
    function _getCollateral(address user,address token,address liqudater, uint256 value) private {
        bool success = IERC20(token).transferFrom(user,liqudater,value);    
        if (!success) {
            revert engineBase.DSCEngine_collateralTokenTrancferError();
        }
        _s_userAllCollateral[user][token] += value;
        
    }
    function _transferToken(address liqudater,uint256 amount,address token) private{
        bool success = IERC20(token).transfer(liqudater, amount);
        if (!success) {
            revert engineBase.DSCEngine_collateralTokenTrancferError();
        }
    }
    function _liquidate(address token, address user, uint256 debt, address liquidator) private 
    returns(uint256)
    {
        uint256 collateralPrice = getTokenValue(token,1 ether);
        uint256 tokenAmount = getCollateralAmount(token, user);
        uint256 tokenValue = (tokenAmount * collateralPrice)/ TOKEN_DECIMAL; 
        if ( _getTotalMintedDSC(liquidator)<tokenValue ){
            revert engineBase.DSCEngine_liquidatorNotEnoughDSC();
        }
        if (tokenValue <= debt){
            _s_userAllCollateral[user][token]=0;
            _transferToken(liquidator, tokenAmount, token);
            _burnDsc(liquidator, tokenValue);
            return debt - tokenValue;
        }else{
            uint256 debtTokenAmount = debt*TOKEN_DECIMAL/collateralPrice;
            _transferToken(liquidator,tokenAmount,token);
            _burnDsc(liquidator, tokenValue);
            _s_userAllCollateral[user][token] -= debtTokenAmount;
            return 0;
        }    
    }

    function _redeemCollateral(address user, address token, uint256 amout) 
    private
    {
        if (_s_userAllCollateral[user][token] < amout){
            revert engineBase.DSCEngine_noEnoughCollateral();
        }

        uint256 value = getTokenValue(token,amout);
        uint256 returnDsc = _valueToDSC(value); 
        
        burnDSC(user,returnDsc);

        _transferToken(user,amout,token);

        emit engineBase.DSCEngine_ReedmCollateral(user, token, amout);    
        
    }

    function getTokenValue(address value,uint256 amount) public view returns(uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(_s_exchangeRateToDSC[value]);
        (,int256 price,,,) = priceFeed.staleCheckLatestRoundData();
        return ((uint256(price)*PRICE_FEED_DECIMAL)*amount)/TOKEN_DECIMAL;
    }
    function getCollateralAmount(address token, address user) public view returns (uint256){
        return _s_userAllCollateral[user][token];
    }

    function getTotalMintedDSC(address user) external view returns (uint256){
        return  _getTotalMintedDSC(user);
    }

    function _checkHaveEnoughCollateral( address user, uint256 amout) private view returns (bool){
       uint256 expectedValue = amout/LIQUIDATION_THRESHOLD*LIQUIDATION_PRECISION;
       return (expectedValue <= _getTotalCollateralValue(user));
    }
}