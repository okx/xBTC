// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {xETH} from "./Deploy.xETH.s.sol";
import "./xTokenTestUtils.sol";

/**
 * @title TestXETH
 * @notice Comprehensive test script for xETH token
 * @dev Inherits all test logic from TestUtils, only provides xETH-specific configuration
 */
contract TestXETH is TestUtils {
    xETH public implementation;
    
    function run() external {
        runTests();
    }
    
    // Override: Return token name
    function getTokenName() internal pure override returns (string memory) {
        return "xETH";
    }
    
    // Override: Return token symbol
    function getTokenSymbol() internal pure override returns (string memory) {
        return "xETH";
    }
    
    // Override: Return token decimals
    function getTokenDecimals() internal pure override returns (uint8) {
        return 18;
    }
    
    // Override: Return max supply
    function getMaxSupply() internal pure override returns (uint256) {
        return 100_000_000 * 10 ** 18;
    }
    
    // Override: Deploy xETH implementation
    function deployImplementation() internal override returns (address) {
        implementation = new xETH();
        return address(implementation);
    }
}

