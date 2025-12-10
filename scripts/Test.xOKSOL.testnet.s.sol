// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {xOKSOL} from "./Deploy.xOKSOL.s.sol";
import "./StakedTokenTestUtils.sol";

/**
 * @title TestXOKSOL
 * @notice Comprehensive test script for xOKSOL staked token
 * @dev Inherits all test logic from StakedTokenTestUtils, only provides xOKSOL-specific configuration
 */
contract TestXOKSOL is StakedTokenTestUtils {
    xOKSOL public implementation;
    
    function run() external {
        runStakedTokenTests();
    }
    
    // Override: Return token name
    function getTokenName() internal pure override returns (string memory) {
        return "OKX Staked SOL";
    }
    
    // Override: Return token symbol
    function getTokenSymbol() internal pure override returns (string memory) {
        return "xOKSOL";
    }
    
    // Override: Return token decimals
    function getTokenDecimals() internal pure override returns (uint8) {
        return 9;
    }
    
    // Override: Return max supply
    function getMaxSupply() internal pure override returns (uint256) {
        return 1_000_000_000 * 10 ** 9;  // 1B with 9 decimals
    }
    
    // Override: Return initial exchange rate
    function getInitialExchangeRate() internal pure override returns (uint256) {
        return 1e18;
    }
    
    // Override: Return rate allowance (1% change allowed)
    function getRateAllowance() internal pure override returns (uint256) {
        return 1e16;
    }
    
    // Override: Return rate interval
    function getRateInterval() internal pure override returns (uint256) {
        return 1 days;
    }
    
    // Override: Deploy xOKSOL implementation
    function deployImplementation() internal override returns (address) {
        implementation = new xOKSOL();
        return address(implementation);
    }
}

