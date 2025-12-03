// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {StakedTokenV1} from "./StakedTokenV1.sol";

contract xBETH is StakedTokenV1 {
    function decimals() public pure override returns (uint8) {
        return 18;
    }
}