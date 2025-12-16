// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {xToken} from "contracts/xToken.sol";

/**
 * @title xETH
 * @notice xETH token with 18 decimals
 */
contract xETH is xToken {
    function decimals() public pure override returns (uint8) {
        return 18;
    }
}
