// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test,console} from "forge-std/Test.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/stableCoin.sol";
import {deployDSC} from "../../script/deployDSC.s.sol";
import {Config} from "../../script/config.s.sol";
import{ERC20Mock} from "@openzepplin/contracts/mocks/ERC20Mock.sol";
import {ERC20} from "@openzepplin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzepplin/contracts/token/ERC20/IERC20.sol";
import{MockV3Aggregator} from "../mock/MockV3Aggregator.sol";


contract DSCEngineTest is Test {
    deployDSC deployer;
    DecentralizedStableCoin dsc;
    DSCEngine engine;
    Config config;

    uint256 constant INIT_BANlANCE = 100 ether;
    address public bob = makeAddr("user");
    address public alice = makeAddr("alice");
    address weth;
    address wbtc;
    address wethPrciceFeed;
    address wbtcPrciceFeed;

    modifier depositeToken() {
        vm.startPrank(bob);
            engine.depositCollateral(weth, INIT_BANlANCE);
            engine.depositCollateral(wbtc, INIT_BANlANCE);
        vm.stopPrank();
        vm.startPrank(alice);
            engine.depositCollateral(weth, INIT_BANlANCE*2);
            engine.depositCollateral(wbtc, INIT_BANlANCE*2);
        vm.stopPrank();
        _;
    }

    modifier mintDSC(uint256 amount) {
        vm.startPrank(bob);
            engine.depositCollateral(weth, INIT_BANlANCE);
            engine.depositCollateral(wbtc, INIT_BANlANCE);
            engine.mintDsc(amount);
            dsc.approve(address(engine),amount);
        vm.stopPrank();
        vm.startPrank(alice);
            engine.depositCollateral(weth, INIT_BANlANCE*2);
            engine.depositCollateral(wbtc, INIT_BANlANCE*2);
            engine.mintDsc(amount);
            dsc.approve(address(engine),amount);
        vm.stopPrank();
        _;
    }
    function setUp() external {
        console.log("DSCEnngineTest setUp");
        deployer = new deployDSC();
        (dsc,engine,config) = deployer.run();
        (wethPrciceFeed,wbtcPrciceFeed,weth,wbtc,) = config.activeConfig();
        ERC20Mock(weth).mint(bob,INIT_BANlANCE);
        ERC20Mock(wbtc).mint(bob,INIT_BANlANCE);
        vm.startPrank(bob);
        IERC20(weth).approve(address(engine),INIT_BANlANCE);
        IERC20(wbtc).approve(address(engine),INIT_BANlANCE);
        vm.stopPrank();
        
        ERC20Mock(weth).mint(alice,INIT_BANlANCE*2);
        ERC20Mock(wbtc).mint(alice,INIT_BANlANCE*2);
        vm.startPrank(alice);
        IERC20(weth).approve(address(engine),INIT_BANlANCE*2);
        IERC20(wbtc).approve(address(engine),INIT_BANlANCE*2);
        vm.stopPrank();
        
    }
    function test_setUpISOK() view external {
        uint256 amount = ERC20(weth).balanceOf(bob);
        console.log("get amout:",amount);
        assertEq(INIT_BANlANCE, amount);
    }

    /////////////////////////////////
    //////// deposite //////////
    /////////////////////////////////
    function test_deposite_revertInvaildToken() external {
        address testToken = address(0);
        uint256 amount = 1;
        vm.expectRevert(DSCEngine.DSCEngine_InvalidCollateralType.selector);
        engine.depositCollateral(testToken,amount);

        testToken = address(1);
        vm.expectRevert(DSCEngine.DSCEngine_InvalidCollateralType.selector);
        engine.depositCollateral(testToken,amount);
    }
    function test_deposite_revertZeroAddress() external {
        vm.expectRevert(DSCEngine.DSCEngine_ZeroAddress.selector);
        vm.prank(address(0));
        engine.mintDsc(10);
    }
    function test_deposite_revertNotEounghValue() external 
    depositeToken()
    {
        vm.startPrank(bob);
        vm.expectRevert(DSCEngine.DSCEngine_moreThanZero.selector);
        engine.depositCollateral(weth, 0);
        vm.stopPrank();   
    }
    function test_deposite_IsOk() external 
    depositeToken()
    {
        uint256 value = engine.getTotalCollateralValue(bob);
        console.log("total value is:",value);
        assertEq(value, 300000 ether);
    }

    /////////////////////////////////
    //////// redeemCollateral //////////
    /////////////////////////////////
    function test_redeemCollateral_noEnoughCollateral() external {
        vm.expectRevert(DSCEngine.DSCEngine_noEnoughCollateral.selector);
        vm.prank(bob);
        engine.redeemCollateral(weth,10);
    }
    function test_redeemCollateral_noEnoughDSC() external 
    depositeToken()
    {
        vm.expectRevert(DSCEngine.DSCEngine_noEnoughDSC.selector);
        vm.prank(bob);
        engine.redeemCollateral(weth,10);
    }
    function test_redeemCollateral_emitEvent() external
    depositeToken()
    {

    }
    /////////////////////////////////
    //////// mintDSC //////////
    /////////////////////////////////
    function test_revertDSCEngine_noEnoughCollateralToMint() external  
    depositeToken()
    {
        uint256 mintDSCAmount = 150001 ether;
        vm.expectRevert(DSCEngine.DSCEngine_noEnoughCollateralToMint.selector);
        vm.prank(bob);
        engine.mintDsc(mintDSCAmount);
    }
    function test_revertAferRevertNotHealth() external  
    depositeToken()
    {
        uint256 mintDSCAmount = 150001 ether;
        vm.prank(bob);
        vm.expectRevert(DSCEngine.DSCEngine_noEnoughCollateralToMint.selector);
        engine.mintDsc(mintDSCAmount);
        assertEq(0,engine.getTotalMintedDSC(bob));
        assertEq(300000 ether,engine.getTotalCollateralValue(bob));
    }
    function test_emitDSCEngine_MintDSC() external
    depositeToken()
    {
        uint256 mintDSCAmount = 1500 ether;
        vm.prank(bob);
        // vm.expectEmit(true,false,false,false);
        // emit DSCEngine.DSCEngine_MintDSC(bob,mintDSCAmount);     
        engine.mintDsc(mintDSCAmount);
        assertEq(mintDSCAmount, engine.getTotalMintedDSC(bob));
    }

    /////////////////////////////////
    //////// burnDSC //////////
    /////////////////////////////////
    function test_burnDSC() external
    mintDSC(1500 ether)
    {
        engine.burnDSC(bob, 500 ether);
        uint256 amoutInfact = engine.getTotalMintedDSC(bob);
        console.log("get amoutInfact:",amoutInfact);
        assertEq(1000 ether, amoutInfact);
    }
    
    /////////////////////////////////
    //////// liquidate //////////
    /////////////////////////////////
    function test_IsHealth() external
    mintDSC(1500 ether)
    {
        uint256 debt = engine.getTotalMintedDSC(bob);
        vm.expectRevert(DSCEngine.DSCEngine_UserIsHealthy.selector);
        engine.liquidate(bob,debt);
    }
    
    function test_liquidate() external
    mintDSC(150000 ether)
    {
        uint256 debt = engine.getTotalMintedDSC(bob);
        MockV3Aggregator(wethPrciceFeed).updateAnswer(1000e8);
        MockV3Aggregator(wbtcPrciceFeed).updateAnswer(500e8);
        vm.prank(alice);
        engine.liquidate(bob,debt);
        uint256 bobAmount = engine.getTotalMintedDSC(bob);
        uint256 bobCollateralValue = engine.getTotalCollateralValue(bob);
        console.log("bobAmount:",bobAmount);
        console.log("bobCollateralValue:",bobCollateralValue);
        
        uint256 aliceAmount = engine.getTotalMintedDSC(alice);
        console.log("aliceAmount:",aliceAmount);
        uint256 wethBalance = ERC20(weth).balanceOf(alice);
        uint256 wbtcBalance = ERC20(wbtc).balanceOf(alice);
        console.log("alice wethBalance:",wethBalance);
        console.log("alice wbtcBalance:",wbtcBalance);
    }
    /////////////////////////////////
    //////// healthyFactor //////////
    /////////////////////////////////
    function test_getHealthyFactor() external 
    mintDSC(150000 ether)
    {
        uint256 coll = engine.getHealthFactor(bob);
        console.log("coll is :", coll);
    }
    /////////////////////////////////
    //////// getTokenValue //////////
    /////////////////////////////////
    function test_getETHUSDValue() view external {
        uint256 result = engine.getTokenValue(weth, 1 ether);
        assertEq(2000 ether, result);
    }

    function test_getBTCUSDValue() view external {
        uint256 result = engine.getTokenValue(wbtc, 1 ether);
        assertEq(1000 ether, result);
    }
    
    /////////////////////////////////
    //////// getCollateralAmount /////////
    /////////////////////////////////
    function test_getCollateralAmount()  external 
    depositeToken()
    {
       uint256 amount = engine.getCollateralAmount(weth,bob);
        console.log("get collateral:",amount);
        assertEq(INIT_BANlANCE,amount);
    }

    /////////////////////////////////
    //////// internal funcs /////////
    /////////////////////////////////
    function test_valueToDSC() view external {
        uint256 value = 1 ether;
        assertEq(5*10**17,engine.valueToDSC(value));
    }
    function test_getTotalColateralValue()  external 
    depositeToken()
    {
        uint256 valueInfact = engine.getTotalCollateralValue(bob);
        int256 mid = (config.ETH_USD_PRICE() + config.BTC_USD_PRICE());
        uint256 valueExpected = INIT_BANlANCE * uint256(mid) / 10**8;
        console.log("get total collateral:",valueInfact);
        console.log("valueExpected:",valueExpected);
        assertEq(valueExpected,valueInfact);
    }
    /////////////////////////////////
    //////// utils funcs /////////
    /////////////////////////////////
    function test_updatePriceFeed() external{
        int256 wethPrcice = MockV3Aggregator(wethPrciceFeed).latestAnswer();
        int256 wbtcPrcice = MockV3Aggregator(wbtcPrciceFeed).latestAnswer();
        console.log("get wethPrcice:",wethPrcice);
        console.log("get wbtcPrcice:",wbtcPrcice);
        MockV3Aggregator(wethPrciceFeed).updateAnswer(1000e8);
        MockV3Aggregator(wbtcPrciceFeed).updateAnswer(500e8);
        wethPrcice = MockV3Aggregator(wethPrciceFeed).latestAnswer();
        wbtcPrcice = MockV3Aggregator(wbtcPrciceFeed).latestAnswer();
        console.log("get wethPrcice:",wethPrcice);
        console.log("get wbtcPrcice:",wbtcPrcice);
        uint256 result = engine.getTokenValue(weth, 1 ether);
        console.log(" ETH value: ",result);
        result = engine.getTokenValue(wbtc, 1 ether);
        console.log(" BTC value: ",result);
    }

}