// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract ERC1967Interface {
    
    error ERC1967_ZeroAddress();
    
    bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    
    modifier notZero(address addr){
        if(addr == address(0)){
            revert ERC1967_ZeroAddress();
        }
        _;
    }
    
    function _getImplementation() internal view returns (address){
        address imp;
        assembly {
            imp := sload(_IMPLEMENTATION_SLOT)
        }
        return imp;
    }
    
    function _setImplementation(address newImplementation) internal 
    notZero(newImplementation)
    {
        assembly {
            sstore(_IMPLEMENTATION_SLOT, newImplementation)
        }
    }
}