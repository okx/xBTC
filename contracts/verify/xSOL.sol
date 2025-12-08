// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {xToken} from "../xToken.sol";

/**
 * @title xSOL
 * @notice xSOL token with 9 decimals
 */
contract xSOL is xToken {
    function decimals() public pure override returns (uint8) {
        return 9;
    }
}