// SPDX-License-Identifier: MIT


pragma solidity ^0.8.10;

import{Script,console} from "forge-std/Script.sol";
import{DecentralizedStableCoin} from "../src/stableCoin.sol";
import{DSCEngine} from "../src/DSCEngine.sol";
import{Config} from "./config.s.sol";

contract deployDSC is Script{
    address[] tokens;
    address[] priceFeeds;
    function run() external returns(DecentralizedStableCoin,DSCEngine,Config){    
        Config config = new Config();
        
        (address wethUsdPriceFeed, address wbtcUsdPriceFeed,
        address weth, address wbtc, uint256 deployerKey) = 
        config.activeConfig();
        
        tokens = [weth, wbtc];
        priceFeeds = [wethUsdPriceFeed, wbtcUsdPriceFeed];

        vm.startBroadcast();
        DecentralizedStableCoin _dsc = new DecentralizedStableCoin();
        DSCEngine _dscEngine = new DSCEngine(tokens, priceFeeds, address(_dsc));
        _dsc.transferOwnership(address(_dscEngine));
        vm.stopBroadcast();
        return (_dsc,_dscEngine,config);
    }
}