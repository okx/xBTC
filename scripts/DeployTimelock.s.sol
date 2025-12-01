// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";

/**
 * @title ISingletonFactory
 * @notice Interface for EIP-2470 Singleton Factory
 */
interface ISingletonFactory {
    function deploy(bytes memory _initCode, bytes32 _salt) external returns (address payable createdContract);
}

/**
 * @title DeployTimelock
 * @notice Script to deploy TimelockController using EIP-2470 deterministic deployment
 */
contract DeployTimelock is Script {
    // EIP-2470 SingletonFactory address (same on all chains)
    address public constant SINGLETON_FACTORY = 0xFaC897544659Fb136C064d5428947f5BC9cC1Fa2;

    // Deployment configuration
    uint256 public constant MIN_DELAY = 3 days; // Minimum delay for timelock operations

    // Salt for deterministic deployment (modify this to get different addresses)
    bytes32 public constant DEPLOYMENT_SALT = keccak256(abi.encodePacked("okx-TimelockController-v5.4.0"));

    function run() external {
        // Step 1: Deploy TimelockController using EIP-2470
        vm.startBroadcast();

        address timelockAddress = deployTimelockControllerDeterministic();
        console.log("TimelockController deployed at:", timelockAddress);
        console.log("Deployment is deterministic using EIP-2470 SingletonFactory");
        console.log("Factory address:", SINGLETON_FACTORY);
        console.log("");

        vm.stopBroadcast();
    }

    /**
     * @notice Deploys the TimelockController using EIP-2470 deterministic deployment
     * @return Address of the deployed TimelockController
     */
    function deployTimelockControllerDeterministic() internal returns (address) {
        address[] memory proposers = new address[](1);
        address[] memory executors = new address[](1);

        proposers[0] = vm.envAddress("PRIVILEGED_ADDRESS");
        executors[0] = vm.envAddress("PRIVILEGED_ADDRESS");

        // Prepare constructor arguments
        bytes memory constructorArgs = abi.encode(MIN_DELAY, proposers, executors, address(0));

        // Get the creation bytecode with constructor arguments
        bytes memory initCode = abi.encodePacked(type(TimelockController).creationCode, constructorArgs);

        // Predict the deployment address before deploying
        address predictedAddress = _computeCreate2Address(DEPLOYMENT_SALT, keccak256(initCode), SINGLETON_FACTORY);
        console.log("Predicted address:", predictedAddress);

        // Check if already deployed
        if (predictedAddress.code.length > 0) {
            console.log("Contract already deployed at predicted address");
            return predictedAddress;
        }

        // Deploy using EIP-2470 SingletonFactory
        ISingletonFactory factory = ISingletonFactory(SINGLETON_FACTORY);
        address deployedAddress = factory.deploy(initCode, DEPLOYMENT_SALT);

        require(deployedAddress == predictedAddress, "Deployment address mismatch");

        return deployedAddress;
    }

    /**
     * @notice Computes the CREATE2 address for a given salt and init code
     * @param salt The salt for CREATE2
     * @param initCodeHash The keccak256 hash of the init code
     * @param deployer The deployer address (SingletonFactory)
     * @return The computed CREATE2 address
     */
    function _computeCreate2Address(bytes32 salt, bytes32 initCodeHash, address deployer)
        internal
        pure
        returns (address)
    {
        return address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), deployer, salt, initCodeHash)))));
    }
}