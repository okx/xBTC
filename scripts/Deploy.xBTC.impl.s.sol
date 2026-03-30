// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Script.sol";
import {xbtc} from "contracts/xbtc.sol";

contract DeployXBTCImpl is Script {
    function run() external {
        vm.startBroadcast();
        xbtc xbtcImpl = new xbtc();
        console.log("xbtc implementation deployed at:", address(xbtcImpl));
        vm.stopBroadcast();
    }
}