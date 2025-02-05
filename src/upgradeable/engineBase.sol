// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {DecentralizedStableCoin} from "../stableCoin.sol";
import {IERC20} from "@openzepplin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzepplin/contracts/security/ReentrancyGuard.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {OracleLib} from "../lib/OrcleLib.sol";


contract engineBase {
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
    
    uint256 constant PRICE_FEED_DECIMAL = 1e10;
    uint256 constant TOKEN_DECIMAL = 1e18;
    uint256 constant LIQUIDATION_THRESHOLD = 50;//1$ collateral get 0.5 DSC
    uint256 constant LIQUIDATION_PRECISION = 100;
    uint256 constant HEALTH_FACTOR_THRESHOLD = 1;
    DecentralizedStableCoin immutable  i_DSCInstance;
    address[] internal _s_tokensSupplied;
    mapping(address token => address) internal _s_exchangeRateToDSC;
    // _s_userAllCollateral[user][token] is n * ether
    mapping(address user => mapping(address token => uint256)) internal _s_userAllCollateral;
    // _s_haveMintDSC[user] is n * ether
    mapping(address user => uint256) internal _s_haveMintDSC;
   

    event DSCEngine_DpositeCollateral(address indexed user, address indexed token, uint256 amount);
    event DSCEngine_ReedmCollateral(address indexed user, address indexed token, uint256 amout);
    event DSCEngine_MintDSC(address indexed user,uint256 amount);
    event delegtor_upgraded(address indexed oldTarget, address indexed newTarget);

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
}