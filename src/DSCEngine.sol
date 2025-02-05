
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
import {DecentralizedStableCoin} from "./stableCoin.sol";
import {IERC20} from "@openzepplin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzepplin/contracts/security/ReentrancyGuard.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {OracleLib} from "./lib/OrcleLib.sol";
/** 
*  @notice we need a modifier to avoid reentrancy?
*  @notice we do not resolve that if bad debt occurs.
*  @notice we need a modifier to avoid no enough collateral?
*  @title A DecentralizedStableCoin Contract 
*  @author lang lee                       
*  @notice This is DecentralizedStableCoin's core.      
*  The system is designed to maintain  1DSC == 1$ peg.
*   Some properties:
*   - 1DSC == 1$
*   - Exogenous supply of DSC
*   - Minimal                 
*   - Algorithmically Stable
*/
contract DSCEngine is ReentrancyGuard {
    /////////////////////////////////////////////////////
    //  Errors  //
    /////////////////////////////////////////////////////
    error DSCEngine_ZeroAddress();
    error DSCEngine_InvalidCollateralType();
    error DSCEngine_moreThanZero();
    error DSCEngine_InvalidInitData();
    error DSCEngine_noEnoughCollateral();
    error DSCEngine_collateralTokenTrancferError(); 
    error DSCEngine_notHealth();
    error DSCEngine_mintError();
    error DSCEngine_DSCTrancferError();
    error DSCEngine_noEnoughDSC();
    error DSCEngine_UserIsHealthy();
    error DSCEngine_BadDebt();
    error DSCEngine_noEnoughCollateralToMint();
    error DSCEngine_liquidatorNotEnoughDSC();
    /////////////////////////////////////////////////////
    //  State Variables //
    /////////////////////////////////////////////////////
    //TODO there will have a threshold of collateral.
    uint256 constant PRICE_FEED_DECIMAL = 1e10;
    uint256 constant TOKEN_DECIMAL = 1e18;
    uint256 constant LIQUIDATION_THRESHOLD = 50;//1$ collateral get 0.5 DSC
    uint256 constant LIQUIDATION_PRECISION = 100;
    uint256 constant HEALTH_FACTOR_THRESHOLD = 1;
    DecentralizedStableCoin immutable  i_DSCInstance;
    address[] private _s_tokensSupplied;
    mapping(address token => address) private _s_exchangeRateToDSC;
    // _s_userAllCollateral[user][token] is n * ether
    mapping(address user => mapping(address token => uint256)) private _s_userAllCollateral;
    // _s_haveMintDSC[user] is n * ether
    mapping(address user => uint256) private _s_haveMintDSC;
    /////////////////////////////////////////////////////
    //  Events //
    /////////////////////////////////////////////////////
    event DSCEngine_DpositeCollateral(address indexed user, address indexed token, uint256 amount);
    event DSCEngine_ReedmCollateral(address indexed user, address indexed token, uint256 amout);
    event DSCEngine_MintDSC(address indexed user,uint256 amount);
    /////////////////////////////////////////////////////
    //  Modifiers   //
    /////////////////////////////////////////////////////
    modifier avoidZeroAddress(address to) {
        if ( to == address(0) ){
            revert DSCEngine_ZeroAddress();
        }
        _;
    }
    modifier moreThanZero(uint256 amount) {
        if ( amount <= 0 ){
            revert DSCEngine_moreThanZero();
        }
        _;
    }
    modifier mustValidCollateralType(address collateralType) {
        if ( _s_exchangeRateToDSC[collateralType] == address(0) ){
            revert DSCEngine_InvalidCollateralType();
        }
        _;
    }
    modifier mustEnoughDSC(address user,uint256 amount){
        if (_s_haveMintDSC[user] < amount){
            revert DSCEngine_noEnoughDSC();
        }
        _;
    }
    using OracleLib for AggregatorV3Interface;
     /////////////////////////////////////////////////////
    //  Functions   //
    /////////////////////////////////////////////////////
    constructor(address[] memory tokens,
     address[] memory priceFeed, 
     address DSCAddress)
     {
        //USD Price Feeds
        if (tokens.length != priceFeed.length){
            revert DSCEngine_InvalidInitData();
        }
        i_DSCInstance = DecentralizedStableCoin(DSCAddress);
        for (uint i=0;i<tokens.length;i++){
            _s_exchangeRateToDSC[tokens[i]] = priceFeed[i];
            _s_tokensSupplied.push(tokens[i]);
        }
    }

    // deposit：存款
    // collateral:押金
    /**@notice deposit collateral token */
    function depositCollateral
        (address token, uint256 amount)
        external
        mustValidCollateralType(token)
        moreThanZero(amount) 
        nonReentrant 
    {
        _getCollateral(msg.sender,token,address(this), amount);
        emit DSCEngine_DpositeCollateral(msg.sender, token, amount);
        
    }
    //redeem：赎回
    /**@notice It will break healthy factor?
     */
    function redeemCollateral(address token,uint256 amout) external 
    mustValidCollateralType(token)
    moreThanZero(amout)
    avoidZeroAddress(msg.sender)
    nonReentrant
    {
        _redeemCollateral(msg.sender, token, amout);
    }    

    function redeemDSC() external{
        
    }
    

    /**@param amount: The number of DSC user want to mint  */
    /**@notice check out to make sure that collateral'value is more than the threshold. 
    * if not, go to liquidatre().
    */
    /**@notice follow the CEI(check,effects,interactions) */
    function mintDsc(uint256 amount)
    external
    avoidZeroAddress(msg.sender) 
    moreThanZero(amount)
    nonReentrant
    {
        //TODO check _s_haveMintValue[msg.sender]+amout <= threshold
        /**@notice we should test the _s_haveMintDSC[user] will 
                    not change if _revertIfNotHealth  works;
          */
        if (!_checkHaveEnoughCollateral(msg.sender, amount)){
            revert DSCEngine_noEnoughCollateralToMint();
        }
        _s_haveMintDSC[msg.sender] += amount;
        _revertIfNotHealth(msg.sender);
        bool success = i_DSCInstance.mint(msg.sender, amount);
        if (!success) {
            revert DSCEngine_mintError();
        }
        emit DSCEngine_MintDSC(msg.sender, amount);
    }
    /**
        @notice there is a bug that any one can call this function to
        burn anybody's dsc.
    */
   function burnDSC(address user,uint256 amount) public 
   mustEnoughDSC(user,amount)
   {
        _burnDsc(user,amount);
   }
    //liquidate：清算
    //if your collateral is less than your DSC*exchangRate
    //you will be liquidated
    //anybody can pay some DSC which has same value to your DSC to get your collateral coin.
    //your collateral will be liquidated to 0.
    /**
        @param user: the user who break health factor;
        @param debt: the amount of DSC you want to burn to make healthy.
        @notice you can get bonus for taking the user's collateral funds.
        @notice this function is to assume that the protocol will be roughly 
        overcollateralized in order for this work.
        words: roughly粗略地，粗糙地
        
        @notice work principle: 
        @notice when the collateral depreciated to the same value of
        user's DSC(1:1 or less) suddenly, cannot to liquidate. This
        be called "Bad Debt".

        when "Bad Debt" occurs, MakerDAO will auction MKR to pay
        debt. MKR will depreciate. So the bad debt will be repaid
        by MKR holder(usually the protocol).

        I have 20 ETH as collateral, each ETH is worth 1000 USD.
        I get a loan of 10,000 DSC.(the rate is 200% > 150%, it's healthy)
        But recently ETH depreciated to 600 USD.(the rate is 120% < 150%, it's unhealthy)
        So my collateral will be liquidated.
        
        liquidation like Dutch Auction, anyone can pay DSC to buy
        my ETH(less than normal price), utill the loan(10,000DSC) is repaid.
        you will lose (10,000/600 = 16.66666666+fine) ETH. And you
        DAI will be empty.
     */
    function liquidate(address user, uint256 debt) public
    moreThanZero(debt)
    avoidZeroAddress(user)
    {
        uint256 startHealthFactor = _getHealthFactor(user);
        if (startHealthFactor >= HEALTH_FACTOR_THRESHOLD){ 
            revert DSCEngine_UserIsHealthy();
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
            /**
                @notice we can sell MKR to resolve the bad debt.
             */
            revert DSCEngine_BadDebt();
        }
        _burnDsc(user, debt);
        // we not send back the collateral to user if more than debt.
        // we just take off the collateral which have a same value to debt.
        // Even we do not solve the bad debt. 
    }
    
  
    function exchangeRateMonitor() external {}
   
    /////////////////////////////////
    //////// private funcs /////////
    /////////////////////////////////
    function _revertIfNotHealth(address user) view private {
        uint256 healthFactor = _getHealthFactor(user);
        if (healthFactor < HEALTH_FACTOR_THRESHOLD){
            revert DSCEngine_notHealth();
        }
    }

    function _updateExchangeRateToDSC() private {}
    
    /**
        @notice totalMintedValue has TOKEN_DECIMAL
    */
    //test
    function getHealthFactor(address user) external view returns (uint256){
       return _getHealthFactor(user); 
    }
    function _getHealthFactor(address user) private view returns (uint256){
        //TODO get total minted DSC
        // uint256 totalMintedDsc = _getTotalMintedDSC(user);
        // uint256 totalMintedValue = totalMintedDsc; 
        uint256 totalMintedValue = _getTotalMintedDSC(user);
        if (totalMintedValue == 0){
            return type(uint256).max;
        }
        //TODO get total collateral it will be n * price * ether
        uint256 totalCollateralValue = _getTotalCollateralValue(user);
        return _valueToDSC(totalCollateralValue) / totalMintedValue;   
        
    }
    //test func
    function getTotalCollateralValue(address user) external view returns (uint256){
        return _getTotalCollateralValue(user);
    }     
    //done 
    function _getTotalCollateralValue(address user) private view returns (uint256){
        //TODO get total collateral
        uint256 length = _s_tokensSupplied.length;
        uint256 totalValue=0;
        for(uint256 i=0;i<length;i++){
            uint256 tokenAmount = _s_userAllCollateral[user][_s_tokensSupplied[i]];
            totalValue = totalValue + getTokenValue(_s_tokensSupplied[i],tokenAmount);
        }
        return totalValue;
    }
   
    //done
    function _getTotalMintedDSC(address user) private view returns (uint256){
        //TODO get total minted DSC
        return _s_haveMintDSC[user];
    }
    //test func
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
        //we assert user has approve(address(this)) in front.
        bool success = IERC20(token).transferFrom(user,liqudater,value);    
        if (!success) {
            revert DSCEngine_collateralTokenTrancferError();
        }
        _s_userAllCollateral[user][token] += value;
        
    }
    function _transferToken(address liqudater,uint256 amount,address token) private{
        bool success = IERC20(token).transfer(liqudater, amount);
        if (!success) {
            revert DSCEngine_collateralTokenTrancferError();
        }
    }
    // event liqudate_tokenValue(uint256 amount);
    // event liqudate_debt(uint256 amount);
    function _liquidate(address token, address user, uint256 debt, address liquidator) private 
    returns(uint256)
    {
        // emit liqudate_debt(debt);
        uint256 collateralPrice = getTokenValue(token,1 ether);
        // _s_haveMintDSC[user] and price have decimal 18
        uint256 tokenAmount = getCollateralAmount(token, user);
        uint256 tokenValue = (tokenAmount * collateralPrice)/ TOKEN_DECIMAL; 
        // emit liqudate_tokenValue(tokenValue);
        if ( _getTotalMintedDSC(liquidator)<tokenValue ){
            revert DSCEngine_liquidatorNotEnoughDSC();
        }
        if (tokenValue <= debt){
            _s_userAllCollateral[user][token]=0;
            //TODO transfer
            _transferToken(liquidator, tokenAmount, token);
            _burnDsc(liquidator, tokenValue);
            return debt - tokenValue;
        }else{
            //assert debt has decimal 18;
            uint256 debtTokenAmount = debt*TOKEN_DECIMAL/collateralPrice;
            //TODO transfer
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
            revert DSCEngine_noEnoughCollateral();
        }

        uint256 value = getTokenValue(token,amout);
        uint256 returnDsc = _valueToDSC(value); 
        
        burnDSC(user,returnDsc);

        _transferToken(user,amout,token);

        emit DSCEngine_ReedmCollateral(user, token, amout);    
        
    }

    /////////////////
    /////views///////
    /////////////////
    function getTokenValue(address value,uint256 amount) public view returns(uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(_s_exchangeRateToDSC[value]);
        // assert  ETH = n dollar, 8 is the pricefeed decimal
        // the price will be n*10^8
        // the token's decimal usually is 18
        // so the amout will be m * 10^18
        // Eventually the result will be n(n = the value to dollar) * 10**18
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