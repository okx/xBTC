// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {xBETH} from "./Deploy.xBETH.s.sol";
import "./StakedTokenTestUtils.sol";

/**
 * @title TestXBETH
 * @notice Comprehensive test script for xBETH staked token
 * @dev Inherits all test logic from StakedTokenTestUtils, only provides xBETH-specific configuration
 */
contract TestXBETH is StakedTokenTestUtils {
    xBETH public implementation;
    
    function run() external {
        runStakedTokenTests();
    }
    
    // Override: Return token name
    function getTokenName() internal pure override returns (string memory) {
        return "OKX Staked ETH";
    }
    
    // Override: Return token symbol
    function getTokenSymbol() internal pure override returns (string memory) {
        return "xBETH";
    }
    
    // Override: Return token decimals
    function getTokenDecimals() internal pure override returns (uint8) {
        return 18;
    }
    
    // Override: Return max supply
    function getMaxSupply() internal pure override returns (uint256) {
        return 1_000_000_000 * 10 ** 18;  // 1B with 18 decimals
    }
    
    // Override: Return initial exchange rate
    function getInitialExchangeRate() internal pure override returns (uint256) {
        return 1e18;  // 1:1 ratio
    }
    
    // Override: Return rate allowance (1% change allowed)
    function getRateAllowance() internal pure override returns (uint256) {
        return 1e16;  // 1% of 1e18
    }
    
    // Override: Return rate interval
    function getRateInterval() internal pure override returns (uint256) {
        return 1 days;
    }
    
    // Override: Deploy xBETH implementation
    function deployImplementation() internal override returns (address) {
        implementation = new xBETH();
        return address(implementation);
    }
}

