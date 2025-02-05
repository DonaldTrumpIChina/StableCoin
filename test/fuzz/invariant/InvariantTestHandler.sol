
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {Test,console} from "forge-std/Test.sol";
import {DSCEngine} from "../../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../../src/stableCoin.sol";
import {deployDSC} from "../../../script/deployDSC.s.sol";
import {Config} from "../../../script/config.s.sol";
import{ERC20Mock} from "@openzepplin/contracts/mocks/ERC20Mock.sol";
import {ERC20} from "@openzepplin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzepplin/contracts/token/ERC20/IERC20.sol";
import{MockV3Aggregator} from "../../mock/MockV3Aggregator.sol";
import{ InvariantTest } from "./invariant.t.sol"; 

pragma solidity ^0.8.0;

contract OpenInvariantTest is StdInvariant,Test {

    deployDSC deployer;
    DecentralizedStableCoin dsc;
    DSCEngine engine;
    Config config;

    address weth;
    address wbtc;
    address wethPrciceFeed;
    address wbtcPrciceFeed;
    InvariantTest test_instance;

    function setUp() external {
        deployer = new deployDSC();
        (dsc,engine,config) = deployer.run();
        (wethPrciceFeed,wbtcPrciceFeed,weth,wbtc,) = config.activeConfig();   
        test_instance = new InvariantTest(dsc,engine,weth,wbtc,wethPrciceFeed,wbtcPrciceFeed);
        targetContract(address(test_instance));
    }
    function invariant_testDSCAwaysLessThanCollateral() view external{
        uint256 totalDSC = dsc.totalSupply();
        uint256 totalWeth = ERC20(weth).balanceOf(address(engine));
        uint256 totalWbtc = ERC20(wbtc).balanceOf(address(engine));
        uint256 totalWethValue = engine.getTokenValue(weth, totalWeth);
        uint256 totalWbtcValue = engine.getTokenValue(wbtc, totalWbtc);
        uint256 totalCollateral =  totalWethValue + totalWbtcValue;
        console.log("totalCollateral is: ",totalCollateral);
        console.log("totalDSC is: ",totalDSC);
        assert(totalCollateral >= totalDSC);
    }
}