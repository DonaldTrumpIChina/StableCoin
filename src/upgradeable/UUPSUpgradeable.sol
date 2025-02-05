// SPDX-License-Identifier: MIT

import {ERC1967Interface} from "./ERC1967.sol";

pragma solidity ^0.8.19;


contract UUPSUpgrateable is ERC1967Interface {
    
    error UUPSUpgrateable_NotOwner();

    address owner;

    modifier onlyOnwer(address){
        if(msg.sender != owner){
            revert UUPSUpgrateable_NotOwner();
        }
        _;
    }

    function upgradeTo(address newImplementation) external onlyOnwer(newImplementation){
        _authorizeUpgrade(newImplementation);
        _setImplementation(newImplementation);    
    }

    function _authorizeUpgrade(address newImplementation) internal virtual {
        
    }
} 