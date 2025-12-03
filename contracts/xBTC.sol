// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Token} from "./Token.sol";

contract xBTC is Token {
    function decimals() public pure override returns (uint8) {
        return 8;
    }
}
