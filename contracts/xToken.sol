// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import {ERC20PermitUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title xToken
 * @dev An upgradeable ERC-20 token contract for OKX x-Assets
 * Features:
 * - ERC-20 standard token functionality
 * - ERC-2612 gasless approvals (permit)
 * - Role-based access control (Deny Lister and Minter roles)
 * - Pausable transfers
 * - Deny list functionality for compliance
 */
contract xToken is
Initializable,
ERC20Upgradeable,
ERC20PausableUpgradeable,
ERC20PermitUpgradeable,
AccessControlUpgradeable
{
    /// @dev Role identifier for addresses that can mint and burn tokens
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    
    /// @dev Role identifier for addresses that can pause/unpause and manage deny list
    bytes32 public constant DENY_LISTER_ROLE = keccak256("DENY_LISTER_ROLE");

    /// @dev Maximum token supply set during initialization
    uint256 public MAX_SUPPLY;

    // Custom Errors
    error ZeroAddress();
    error NoAuthorizedReceiver();
    error ZeroAmount();
    error InsufficientBalance(uint256 available, uint256 required);
    error ExceedsMaxSupply(uint256 requested, uint256 maxSupply);
    error EmptyArray();
    error SameValue();

    error SenderInDenyList(address sender);
    error RecipientInDenyList(address recipient);

    /// @dev Mapping to track addresses that are denied from transfers
    mapping(address => bool) public denyList;

    /// @dev The address that receives newly minted tokens
    address public authorizedReceiver;

    event AddedToDenyList(address indexed account);
    event RemovedFromDenyList(address indexed account);
    event MinterTransferred(address indexed previousMinter, address indexed newMinter);
    event DenyListerTransferred(address indexed previousDenyLister, address indexed newDenyLister);
    event Mint(address indexed to, uint256 amount);
    event Burn(address indexed from, uint256 amount);
    event ReceiverSet(address indexed previousReceiver, address indexed newReceiver);

    /**
     * @dev Constructor that disables initializers to prevent initialization of the implementation contract
     * @custom:oz-upgrades-unsafe-allow constructor
     */
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initializes the upgradeable contract with token details and role assignments
     * @param name The name of the token (e.g., "xBTC")
     * @param symbol The symbol of the token (e.g., "xBTC")
     * @param admin The address that will receive DEFAULT_ADMIN_ROLE
     * @param denyLister The address that will receive DENY_LISTER_ROLE
     * @param minter The address that will receive MINTER_ROLE for minting/burning tokens
     * @param receiver The initial authorized receiver address for minting operations
     * @param maxSupply The maximum supply of tokens (with decimal places included)
     */
    function initialize(
        string calldata name,
        string calldata symbol,
        address admin,
        address denyLister,
        address minter,
        address receiver,
        uint256 maxSupply
    ) initializer external {
        __ERC20_init(name, symbol);
        __ERC20Pausable_init();
        __ERC20Permit_init(name);
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(DENY_LISTER_ROLE, denyLister);
        _grantRole(MINTER_ROLE, minter);

        // Set the initial authorized receiver
        if (receiver == address(0)) revert ZeroAddress();
        authorizedReceiver = receiver;
        emit ReceiverSet(address(0), receiver);

        // Set the maximum supply
        if (maxSupply == 0) revert ZeroAmount();
        MAX_SUPPLY = maxSupply;
    }

    /**
     * @dev Sets a new authorized receiver for minting operations
     * @param newReceiver The new address that will receive minted tokens
     * Requirements:
     * - Only addresses with DENY_LISTER_ROLE can call this function
     * - newReceiver cannot be the zero address
     */
    function setReceiver(address newReceiver) external onlyRole(DENY_LISTER_ROLE) {
        if (newReceiver == address(0)) revert ZeroAddress();
        address previousReceiver = authorizedReceiver;
        authorizedReceiver = newReceiver;
        emit ReceiverSet(previousReceiver, newReceiver);
    }


    /**
     * @dev Mints new tokens to the authorized receiver address
     * @param amount The amount of tokens to mint (in 8 decimal places)
     * Requirements:
     * - Only addresses with MINTER_ROLE can call this function
     * - Contract must not be paused
     * - Amount must be greater than 0
     * - Total supply after minting must not exceed MAX_SUPPLY
     * - Authorized receiver must be set
     */
    function mint(address receiver, uint256 amount)
    external
    onlyRole(MINTER_ROLE)
    whenNotPaused
    {
        if (amount == 0) revert ZeroAmount();
        // in this case, we double confirm the mint intention matched with the authorized receiver
        if (receiver != authorizedReceiver) revert NoAuthorizedReceiver();
        if (totalSupply() + amount > MAX_SUPPLY) revert ExceedsMaxSupply(totalSupply() + amount, MAX_SUPPLY);
        _mint(receiver, amount);
        emit Mint(receiver, amount);
    }

    /**
     * @dev Burns tokens from the caller's balance
     * @param amount The amount of tokens to burn (in 8 decimal places)
     * Requirements:
     * - Only addresses with MINTER_ROLE can call this function
     * - Contract must not be paused
     * - Amount must be greater than 0
     * - Caller must have sufficient balance to burn
     */
    function burn(uint256 amount)
    external
    onlyRole(MINTER_ROLE)
    whenNotPaused
    {
        if (amount == 0) revert ZeroAmount();
        uint256 balance = balanceOf(msg.sender);
        if (balance < amount) revert InsufficientBalance(balance, amount);
        _burn(msg.sender, amount);
        emit Burn(msg.sender, amount);
    }

    /**
     * @dev Pauses all token transfers and mint/burn operations
     * Requirements:
     * - Only addresses with DENY_LISTER_ROLE can call this function
     */
    function pause() external onlyRole(DENY_LISTER_ROLE) {
        _pause();
    }

    /**
     * @dev Unpauses all token transfers and mint/burn operations
     * Requirements:
     * - Only addresses with DENY_LISTER_ROLE can call this function
     */
    function unpause() external onlyRole(DENY_LISTER_ROLE) {
        _unpause();
    }

    /**
     * @dev Adds multiple addresses to the deny list in a single transaction
     * @param accounts Array of addresses to add to the deny list
     * Requirements:
     * - Only addresses with DENY_LISTER_ROLE can call this function
     * - Accounts array cannot be empty
     * - Cannot add zero address to deny list
     */
    function batchAddToDenyList(address[] calldata accounts) external onlyRole(DENY_LISTER_ROLE) {
        if (accounts.length == 0) revert EmptyArray();
        
        for (uint256 i = 0; i < accounts.length; i++) {
            address account = accounts[i];
            if (account == address(0)) revert ZeroAddress();
            
            if (!denyList[account]) {
                denyList[account] = true;
                emit AddedToDenyList(account);
            }
        }
    }

    /**
     * @dev Removes multiple addresses from the deny list in a single transaction
     * @param accounts Array of addresses to remove from the deny list
     * Requirements:
     * - Only addresses with DENY_LISTER_ROLE can call this function
     * - Accounts array cannot be empty
     */
    function batchRemoveFromDenyList(address[] calldata accounts) external onlyRole(DENY_LISTER_ROLE) {
        if (accounts.length == 0) revert EmptyArray();
        
        for (uint256 i = 0; i < accounts.length; i++) {
            address account = accounts[i];
            if (denyList[account]) {
                denyList[account] = false;
                emit RemovedFromDenyList(account);
            }
        }
    }

    /**
     * @dev Adds a single address to the deny list
     * @param account The address to add to the deny list
     * Requirements:
     * - Only addresses with DENY_LISTER_ROLE can call this function
     * - Cannot add zero address to deny list
     */
    function addToDenyList(address account) external onlyRole(DENY_LISTER_ROLE) {
        if (account == address(0)) revert ZeroAddress();

        denyList[account] = true;
        emit AddedToDenyList(account);
    }

    /**
     * @dev Removes a single address from the deny list
     * @param account The address to remove from the deny list
     * Requirements:
     * - Only addresses with DENY_LISTER_ROLE can call this function
     */
    function removeFromDenyList(address account) external onlyRole(DENY_LISTER_ROLE) {
        denyList[account] = false;
        emit RemovedFromDenyList(account);
    }


    /**
     * @dev Transfers the minter role from the current minter to a new address
     * @param newMinter The address that will receive the minter role
     * Requirements:
     * - Only current minter can transfer the minter role
     * - New minter cannot be zero address
     * - New minter cannot be the same as current minter
     */
    function transferMinter(address newMinter) external onlyRole(MINTER_ROLE) {
        if (newMinter == address(0)) revert ZeroAddress();
        if (newMinter == msg.sender) revert SameValue();

        address previousMinter = msg.sender;
        
        // Revoke minter role from current minter
        _revokeRole(MINTER_ROLE, previousMinter);
        
        // Grant minter role to new minter
        _grantRole(MINTER_ROLE, newMinter);
        
        emit MinterTransferred(previousMinter, newMinter);
    }

    /**
     * @dev Transfers the deny lister role from the current deny lister to a new address
     * @param newDenyLister The address that will receive the deny lister role
     * Requirements:
     * - Only current deny lister can transfer the deny lister role
     * - New deny lister cannot be zero address
     * - New deny lister cannot be the same as current deny lister
     */
    function transferDenyLister(address newDenyLister) external onlyRole(DENY_LISTER_ROLE) {
        if (newDenyLister == address(0)) revert ZeroAddress();
        if (newDenyLister == msg.sender) revert SameValue();

        address previousDenyLister = msg.sender;
        
        // Revoke deny lister role from current deny lister
        _revokeRole(DENY_LISTER_ROLE, previousDenyLister);
        
        // Grant deny lister role to new deny lister
        _grantRole(DENY_LISTER_ROLE, newDenyLister);
        
        emit DenyListerTransferred(previousDenyLister, newDenyLister);
    }

    /**
     * @dev Internal function to update token balances with deny list checks
     * @param from The address tokens are transferred from
     * @param to The address tokens are transferred to
     * @param value The amount of tokens being transferred
     * Requirements:
     * - Neither sender nor recipient can be in the deny list
     */
    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20Upgradeable, ERC20PausableUpgradeable) {
        if (denyList[from]) revert SenderInDenyList(from);
        if (denyList[to]) revert RecipientInDenyList(to);

        super._update(from, to, value);
    }

    /**
     * @dev Checks if the contract supports a given interface
     * @param interfaceId The interface identifier to check
     * @return True if the interface is supported, false otherwise
     */
    function supportsInterface(bytes4 interfaceId)
    public
    view
    override(AccessControlUpgradeable)
    returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns the version of the contract
     * @return The version string of the contract
     */
    function version() public pure returns (string memory) {
        return "1.0.0";
    }
}
