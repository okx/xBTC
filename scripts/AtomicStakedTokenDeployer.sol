// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Proxy} from "contracts/Proxy.sol";
import {xToken} from "contracts/xToken.sol";
import {StakedTokenV1} from "contracts/StakedTokenV1.sol";
import {ExchangeRateUpdater} from "contracts/ExchangeRateUpdater.sol";

/**
 * @title ISingletonFactory
 * @notice Minimal interface for EIP-2470 Singleton Factory (CREATE2 deployer)
 */
interface ISingletonFactory {
    function deploy(bytes memory _initCode, bytes32 _salt) external returns (address payable createdContract);
}

/**
 * @title AtomicStakedTokenDeployer
 * @notice Single-transaction deployment + oracle configuration for StakedTokenV1 via EIP-2470 proxy deployment.
 *
 * Notes:
 * - Implementation address can be deployed in a separate transaction (per requirement).
 * - Proxy deployment + initialize + oracle/updater wiring + admin handoff happen atomically in this constructor.
 */
contract AtomicStakedTokenDeployer {
    address public proxy;
    address public exchangeRateUpdater;

    event AtomicDeployComplete(
        address indexed proxy,
        address indexed implementation,
        address indexed proxyAdmin,
        address tokenAdmin,
        address exchangeRateUpdater,
        address oracleOwner,
        address oracleCaller
    );

    constructor(
        address implementation,
        address proxyAdmin,
        // token config
        string memory name,
        string memory symbol,
        address tokenAdmin,
        address denyLister,
        address minter,
        address receiver,
        uint256 maxSupply,
        // oracle config
        address oracleOwner,
        address oracleCaller,
        uint256 initialExchangeRate,
        uint256 rateAllowance,
        uint256 rateInterval,
        // deterministic deployment
        address singletonFactory,
        bytes32 proxySalt
    ) {
        // Temporarily set token DEFAULT_ADMIN_ROLE to this deployer contract so we can finish wiring in this tx.
        bytes memory initData = abi.encodeCall(
            xToken.initialize,
            (name, symbol, address(this), denyLister, minter, receiver, maxSupply)
        );

        bytes memory proxyInitCode = abi.encodePacked(
            type(Proxy).creationCode,
            abi.encode(implementation, proxyAdmin, initData)
        );

        ISingletonFactory factory = ISingletonFactory(singletonFactory);
        address predicted = getAddress(singletonFactory, proxyInitCode, proxySalt);
        require(predicted.code.length == 0, "ATOMIC: proxy already deployed");

        address deployedProxy = factory.deploy(proxyInitCode, proxySalt);
        require(deployedProxy == predicted, "ATOMIC: proxy addr mismatch");
        proxy = deployedProxy;

        StakedTokenV1 token = StakedTokenV1(deployedProxy);

        // Set oracle to this contract so we can set initial rate immediately (same tx).
        token.updateOracle(address(this));
        token.updateExchangeRate(initialExchangeRate);

        // Deploy updater owned by this deployer, initialize, configure, then transfer ownership to oracleOwner.
        ExchangeRateUpdater updater = new ExchangeRateUpdater(address(this));
        updater.initialize(address(this), deployedProxy);
        updater.configureCaller(oracleCaller, rateAllowance, rateInterval);

        token.updateOracle(address(updater));
        updater.transferOwnership(oracleOwner);
        exchangeRateUpdater = address(updater);

        // Hand off token admin and remove this deployer from admin set.
        bytes32 adminRole = token.DEFAULT_ADMIN_ROLE();
        token.grantRole(adminRole, tokenAdmin);
        token.revokeRole(adminRole, address(this));

        emit AtomicDeployComplete(
            deployedProxy,
            implementation,
            proxyAdmin,
            tokenAdmin,
            address(updater),
            oracleOwner,
            oracleCaller
        );

    }

    /**
     * @notice Predict deterministic proxy address for EIP-2470 SingletonFactory CREATE2 deployment
     * @dev Mirrors `getAddress(initCode, salt)` behavior: address = keccak256(0xff ++ factory ++ salt ++ keccak256(initCode))[12:]
     */
    function getAddress(address singletonFactory, bytes memory initCode, bytes32 salt) public pure returns (address) {
        bytes32 initCodeHash = keccak256(initCode);
        bytes32 raw = keccak256(abi.encodePacked(bytes1(0xff), singletonFactory, salt, initCodeHash));
        return address(uint160(uint256(raw)));
    }
}


