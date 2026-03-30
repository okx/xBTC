// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./DeployUtils.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";

/**
 * @title TimelockDeployUtils
 * @notice Base contract with reusable timelock deployment utilities
 * @dev Extends DeployUtils to use deterministic deployment methods (EIP-2470)
 */
abstract contract TimelockDeployUtils is DeployUtils {
    // Timelock configuration
    uint256 public constant TIMELOCK_MIN_DELAY = 3 days;

    /**
     * @notice Deploys the TimelockController using EIP-2470 deterministic deployment
     * @param timelockCaller Address that will be both proposer and executor
     * @return Address of the deployed TimelockController
     */
    function _deployTimelockDeterministic(address timelockCaller) internal returns (address) {
        address[] memory proposers = new address[](1);
        address[] memory executors = new address[](1);

        proposers[0] = timelockCaller;
        executors[0] = timelockCaller;

        // Prepare constructor arguments
        bytes memory constructorArgs = abi.encode(TIMELOCK_MIN_DELAY, proposers, executors, address(0));

        // Get the creation bytecode with constructor arguments
        bytes memory initCode = abi.encodePacked(type(TimelockController).creationCode, constructorArgs);

        return _deployDeterministic(initCode, _salt());
    }
}

/**
 * @title DeployTimelock
 * @notice Standalone script to deploy TimelockController using EIP-2470 deterministic deployment
 */
contract DeployTimelock is TimelockDeployUtils {
    function run() external {
        address timelockCaller = vm.envAddress("TIMELOCK_CALLER");

        vm.startBroadcast();

        address timelockAddress = _deployTimelockDeterministic(timelockCaller);
        console.log("TimelockController deployed at:", timelockAddress);
        console.log("Proposer:", timelockCaller);
        console.log("Executor:", timelockCaller);
        console.log("Factory address:", _singletonFactory());
        console.log("Salt:");
        console.logBytes32(_salt());
        console.log("");

        vm.stopBroadcast();
    }
}
