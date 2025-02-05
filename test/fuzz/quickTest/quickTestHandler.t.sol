

// import {Test,console} from "forge-std/Test.sol";
// import {DSCEngine} from "../../../src/DSCEngine.sol";
// import {DecentralizedStableCoin} from "../../../src/stableCoin.sol";
// import {deployDSC} from "../../../script/deployDSC.s.sol";
// import {Config} from "../../../script/config.s.sol";
// import{ERC20Mock} from "@openzepplin/contracts/mocks/ERC20Mock.sol";
// import {ERC20} from "@openzepplin/contracts/token/ERC20/ERC20.sol";
// import {IERC20} from "@openzepplin/contracts/token/ERC20/IERC20.sol";
// import{MockV3Aggregator} from "../../mock/MockV3Aggregator.sol";



// pragma solidity ^0.8.0;
// contract InvariantTest is Test {

//     DecentralizedStableCoin dsc;
//     DSCEngine engine;
    
//     address weth;
//     address wbtc;
//     address wethPrciceFeed;
//     address wbtcPrciceFeed;
//     uint256 constant INIT_BANlANCE = 100 ether;
  

//     constructor(DecentralizedStableCoin _dsc,
//     DSCEngine _engine,    
//     address _weth,
//     address _wbtc,
//     address _wethPrciceFeed,
//     address _wbtcPrciceFeed) 
//     {
//         dsc=_dsc;
//         engine=_engine;
//         weth=_weth;
//         wbtc=_wbtc;
//         wethPrciceFeed=_wethPrciceFeed;
//         wbtcPrciceFeed=_wbtcPrciceFeed;
//     }

//     function testDeposite(address randomToken, uint256 amount) external
//     {
//         ERC20Mock(randomToken).mint(msg.sender,INIT_BANlANCE);
//         vm.startPrank(msg.sender);
//         ERC20(randomToken).approve(address(engine), INIT_BANlANCE);
//         engine.depositCollateral(randomToken,amount);
//         vm.stopPrank();
//     }

//     function testRedeemCollateral(address randomToken, uint256 amount) external 
//     {
//         address user = msg.sender;
//         vm.startPrank(user);
//         engine.redeemCollateral(randomToken,amount);
//         vm.stopPrank();
//     }

//     function testMintDSC(uint256 amount) external 
//     {
//         address user = msg.sender;
//         vm.startPrank(user);
//         engine.mintDsc(amount);
//         dsc.approve(address(engine),amount);
//         vm.stopPrank();
//     }

//     function testBurnDSC(uint256 amount) external 
//     {
//         vm.startPrank(msg.sender);
//         engine.burnDSC(msg.sender,amount);
//         vm.stopPrank();
//     }
//     function testLiquidate(address user) external
//     {
//         address liquidator = msg.sender;
//         MockV3Aggregator(wethPrciceFeed).updateAnswer(1000e8);
//         MockV3Aggregator(wbtcPrciceFeed).updateAnswer(500e8);
//         uint256 debt = engine.getTotalCollateralValue(user);
//         vm.prank(liquidator);
//         engine.liquidate(user, debt);
//     }
// }