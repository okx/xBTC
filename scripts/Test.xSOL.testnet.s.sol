// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {xSOL} from "./Deploy.xSOL.s.sol";
import "./xTokenTestUtils.sol";

/**
 * @title TestXSOL
 * @notice Comprehensive test script for xSOL token
 * @dev Inherits all test logic from TestUtils, only provides xSOL-specific configuration
 */
contract TestXSOL is TestUtils {
    xSOL public implementation;
    
    function run() external {
        runTests();
    }
    
    // Override: Return token name
    function getTokenName() internal pure override returns (string memory) {
        return "xSOL";
    }
    
    // Override: Return token symbol
    function getTokenSymbol() internal pure override returns (string memory) {
        return "xSOL";
    }
    
    // Override: Return token decimals
    function getTokenDecimals() internal pure override returns (uint8) {
        return 9;
    }
    
    // Override: Return max supply
    function getMaxSupply() internal pure override returns (uint256) {
        return 1_000_000_000 * 10 ** 9;  // 1B with 9 decimals
    }
    
    // Override: Deploy xSOL implementation
    function deployImplementation() internal override returns (address) {
        implementation = new xSOL();
        return address(implementation);
    }
}


