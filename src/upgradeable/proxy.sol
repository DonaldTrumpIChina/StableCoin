//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

abstract contract proxy {
  
    fallback() external payable {
        _fallback();
    } 

    receive() external payable {    
        _fallback();
    }

    function _fallback() private {
        address target = getImplementation();
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), target, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    function getImplementation() internal view virtual returns (address) {
    }
}
