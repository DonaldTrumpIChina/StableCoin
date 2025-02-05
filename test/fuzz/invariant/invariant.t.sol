

import {Test,console} from "forge-std/Test.sol";
import {DSCEngine} from "../../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../../src/stableCoin.sol";
import {deployDSC} from "../../../script/deployDSC.s.sol";
import {Config} from "../../../script/config.s.sol";
import{ERC20Mock} from "@openzepplin/contracts/mocks/ERC20Mock.sol";
import {ERC20} from "@openzepplin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzepplin/contracts/token/ERC20/IERC20.sol";
import{MockV3Aggregator} from "../../mock/MockV3Aggregator.sol";



pragma solidity ^0.8.0;
contract InvariantTest is Test {

    DecentralizedStableCoin dsc;
    DSCEngine engine;
    
    address weth;
    address wbtc;
    address wethPrciceFeed;
    address wbtcPrciceFeed;
    uint256 constant INIT_BANlANCE = 100 ether;
    mapping(address => bool) haveDeposited;

    modifier mustInMap(address user) {
        if ( !haveDeposited[user] ){
            return;
        }else{
            _;
        }
    }
    modifier mustMinted(address user) {
        if ( engine.getTotalMintedDSC(user) == 0 ){
            return;
        }else{
            _;
        }
    }

    constructor(DecentralizedStableCoin _dsc,
    DSCEngine _engine,    
    address _weth,
    address _wbtc,
    address _wethPrciceFeed,
    address _wbtcPrciceFeed) 
    {
        dsc=_dsc;
        engine=_engine;
        weth=_weth;
        wbtc=_wbtc;
        wethPrciceFeed=_wethPrciceFeed;
        wbtcPrciceFeed=_wbtcPrciceFeed;
    }

    function testDeposite(uint256 randomToken, uint256 amount) external
    {
        address token = _randomTokenToAddress(randomToken);
        amount=_boundAmount(amount,INIT_BANlANCE);
        if ( amount == 0 ){
            return;
        }
        ERC20Mock(token).mint(msg.sender,INIT_BANlANCE);
        vm.startPrank(msg.sender);
        ERC20(token).approve(address(engine), INIT_BANlANCE);
        engine.depositCollateral(token,amount);
        vm.stopPrank();
        haveDeposited[msg.sender]=true;
    }

    function testRedeemCollateral(uint256 randomToken, uint256 amount) external 
    mustInMap(msg.sender)
    {
        address user = msg.sender;
        address token = _randomTokenToAddress(randomToken);
        uint256 maxAmount = engine.getCollateralAmount(token, user);
        amount=_boundAmount(amount,maxAmount);

        uint256 collateralVale = engine.getTokenValue(token, amount);
        uint256 dscMinted = engine.getTotalMintedDSC(user);
        if (collateralVale > dscMinted*2){
            return;
        }
        
        if (dscMinted ==0 ){
            return; 
        }
        if ( amount == 0 ){
            return;
        }
        vm.startPrank(msg.sender);
        engine.redeemCollateral(token,amount);
        vm.stopPrank();
    }

    function testMintDSC(uint256 amount) external 
    mustInMap(msg.sender)
    {
        address user = msg.sender;
        uint256 value = engine.getTotalCollateralValue(user);
        uint256 dscMinted = engine.getTotalMintedDSC(user);
        if (value ==0 ){
            return;
        }
        amount=_boundAmount(amount,(value/2-dscMinted));
        if ( amount == 0 ){
            return;
        }
        vm.startPrank(msg.sender);
        engine.mintDsc(amount);
        dsc.approve(address(engine),amount);
        vm.stopPrank();
    }

    function testBurnDSC(uint256 amount) external 
    mustInMap(msg.sender)
    {
        address user = msg.sender;
        uint256 dscMinted = engine.getTotalMintedDSC(user);
        if (dscMinted ==0 ){
            return;
        }
        amount=_boundAmount(amount,dscMinted);
        if ( amount == 0 ){
            return;
        }
        vm.startPrank(msg.sender);
        engine.burnDSC(user,amount);
        vm.stopPrank();
    }
    function testLiquidate(address user) external
    mustInMap(user)
    mustInMap(msg.sender)
    {
        address liquidator = msg.sender;
        MockV3Aggregator(wethPrciceFeed).updateAnswer(1000e8);
        MockV3Aggregator(wbtcPrciceFeed).updateAnswer(500e8);
        
        if (engine.getHealthFactor(user) <= 1 ){
            uint256 debt = engine.getTotalCollateralValue(user);
            uint256 dscNeed = engine.getTotalMintedDSC(liquidator);
            if (dscNeed < debt) {
                return;
            }
            vm.prank(liquidator);
            engine.liquidate(user, debt);
        }
    }




    ///////////////////////
    //////util func///////
    ///////////////////////
    function _randomTokenToAddress(uint256 randomToken) private view returns(address){
        if (randomToken % 2 == 1 ){
            return weth;
        }
        return wbtc;
    }

    function _boundAmount(uint256 amount,uint256 max) private pure returns(uint256){
        return bound(amount,0,max);
    }
}