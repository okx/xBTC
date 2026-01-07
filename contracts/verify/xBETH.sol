// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {StakedTokenV1} from "contracts/StakedTokenV1.sol";

/**
 * @title xBETH
 * @notice xBETH staked token with 18 decimals
 * @dev Extends StakedTokenV1 which includes exchange rate oracle functionality
 */
contract xBETH is StakedTokenV1 {
    function decimals() public pure override returns (uint8) {
        return 18;
    }
}
