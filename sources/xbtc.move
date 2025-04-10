// Copyright (c) xBTC Developers
// SPDX-License-Identifier: Apache-2.0

#[allow(duplicate_alias)]
module xbtc::xbtc {
    use std::option;
    use sui::coin::{Self, TreasuryCap, DenyCapV2};
    use sui::deny_list::DenyList;
    use sui::transfer;
    use sui::tx_context;
    use sui::object;
    use sui::event;

    /// One-time witness for xBTC
    public struct XBTC has drop {}

    /// Stores the fixed receiver address for minting
    public struct XBTCReceiver has key, store {
        id: object::UID,
        receiver: address
    }

    // === Event structures ===

    /// Emitted when xBTC tokens are minted
    public struct MintEvent has copy, drop {
        minter: address,
        receiver: address,
        amount: u64,
    }

    /// Emitted when xBTC tokens are burned
    public struct BurnEvent has copy, drop {
        account: address,
        amount: u64,
    }

    /// Emitted when an address is added to the deny list
    public struct AddDenyListEvent has copy, drop {
        denylister: address,
        account: address,
    }

    /// Emitted when an address is removed from the deny list
    public struct RemoveDenyListEvent has copy, drop {
        denylister: address,
        account: address,
    }

    /// Emitted when multiple addresses are added to the deny list
    public struct BatchAddDenyListEvent has copy, drop {
        denylister: address,
        accounts: vector<address>
    }

    /// Emitted when multiple addresses are removed from the deny list
    public struct BatchRemoveDenyListEvent has copy, drop {
        denylister: address,
        accounts: vector<address>
    }

    /// Emitted when global pause is enabled/disabled
    public struct PauseEvent has copy, drop {
        pauser: address,
        paused: bool,
    }

    /// Emitted when the receiver address is set
    public struct SetReceiverEvent has copy, drop {
        minter: address,
        old_receiver: address,
        new_receiver: address,
    }

    /// Emitted when the minter role is transferred
    public struct TransferMinterRoleEvent has copy, drop {
        old_minter: address,
        new_minter: address,
    }

    /// Emitted when the denylister role is transferred
    public struct TransferDenylisterRoleEvent has copy, drop {
        old_denylister: address,
        new_denylister: address,
    }

    /// Error codes
    const EInvalidAmount: u64 = 1;
    const EInvalidReceiver: u64 = 2;
    const EZeroAddress: u64 = 3;
    const EInvalidVectorAccounts: u64 = 4;

    // Constants
    const ZERO_ADDRESS: address = @0x0;

    // ===== Initialize functions =====
    /// Module initializer - creates the coin and capabilities
    fun init(otw: XBTC, ctx: &mut tx_context::TxContext) {
        // Create a regulated currency with deny list and global pause support
        let (treasury_cap, deny_cap, metadata) = coin::create_regulated_currency_v2(
            otw,
            8,                                  // 8 decimals like Bitcoin
            b"xBTC",                            // Symbol
            b"Regulated Bitcoin",               // Name
            b"A regulated Bitcoin representation on Sui with compliance features", // Description
            option::none(),                     // Icon URL, will fixed when deployed
            true,                               // Allow global pause for emergencies
            ctx
        );

        // Create initial receiver with the sender address
        // When initialized, the receiver is zero address, then we will pass the minter to the asset-management dept.
        let xbtc_receiver = XBTCReceiver {
            id: object::new(ctx),
            receiver: ZERO_ADDRESS
        };

        // Transfer capabilities to the deployer
        transfer::public_transfer(treasury_cap, @minter);
        transfer::public_transfer(deny_cap, @denylister);

        // since we use the TreasuryCap to make the auth control, we use xbtc_receiver as a sharedObject
        transfer::share_object(xbtc_receiver);

        // Freeze the metadata object
        transfer::public_freeze_object(metadata);
    }

    // ===== Entry functions =====

    /// Mint new xBTC tokens (TreasuryCap owner only)
    public entry fun mint(
        treasury_cap: &mut TreasuryCap<XBTC>,
        xbtc_receiver: &XBTCReceiver,
        amount: u64,
        receiver_addr: address,
        ctx: &mut tx_context::TxContext
    ) {
        // Validate amount is non-zero
        assert!(amount > 0, EInvalidAmount);
        assert!(receiver_addr != ZERO_ADDRESS, EZeroAddress);

        // Validate receiver matches the configured receiver
        assert!(receiver_addr == xbtc_receiver.receiver, EInvalidReceiver);

        let minter = tx_context::sender(ctx);

        // Mint and transfer coins
        coin::mint_and_transfer(treasury_cap, amount, receiver_addr, ctx);

        // Emit mint event
        event::emit(MintEvent {
            minter,
            receiver: receiver_addr,
            amount
        });
    }

    /// Burn xBTC tokens (only the TreasuryCap owner can burn tokens)
    public entry fun burn(
        treasury_cap: &mut TreasuryCap<XBTC>,
        coin: coin::Coin<XBTC>,
        ctx: &mut tx_context::TxContext
    ) {
        let amount = coin::value(&coin);
        let account = tx_context::sender(ctx);

        coin::burn(treasury_cap, coin);

        // Emit burn event
        event::emit(BurnEvent {
            account,
            amount
        });
    }

    /// Set a new receiver address (TreasuryCap owner only)
    public entry fun set_receiver(
        _treasury_cap: &TreasuryCap<XBTC>, // Only the treasury cap owner can call this, not used, use understore to indentify it.
        xbtc_receiver: &mut XBTCReceiver,
        new_receiver_address: address,
        ctx: &mut tx_context::TxContext
    ) {
        assert!(new_receiver_address != ZERO_ADDRESS, EZeroAddress);

        let old_receiver_address = xbtc_receiver.receiver;
        let minter = tx_context::sender(ctx);

        // Update receiver address
        xbtc_receiver.receiver = new_receiver_address;

        event::emit(SetReceiverEvent {
            minter,
            old_receiver: old_receiver_address,
            new_receiver: new_receiver_address
        });
    }

    /// Set the global pause state - controls whether xBTC tokens can be used as inputs
    public entry fun set_pause(
        deny_list: &mut DenyList,
        deny_cap: &mut DenyCapV2<XBTC>,
        paused: bool,
        ctx: &mut tx_context::TxContext
    ) {
        let pauser = tx_context::sender(ctx);

        if (paused) {
            coin::deny_list_v2_enable_global_pause(deny_list, deny_cap, ctx);
        } else {
            coin::deny_list_v2_disable_global_pause(deny_list, deny_cap, ctx);
        };

        // Emit pause event with the new pause state
        event::emit(PauseEvent {
            pauser,
            paused
        });
    }

    /// Add an address to the deny list (admin only)
    public entry fun add_to_deny_list(
        deny_list: &mut DenyList,
        deny_cap: &mut DenyCapV2<XBTC>,
        account: address,
        ctx: &mut tx_context::TxContext
    ) {
        let denylister = tx_context::sender(ctx);

        coin::deny_list_v2_add(deny_list, deny_cap, account, ctx);

        event::emit(AddDenyListEvent {
            denylister,
            account
        });
    }

    /// Remove an address from the deny list (admin only)
    public entry fun remove_from_deny_list(
        deny_list: &mut DenyList,
        deny_cap: &mut DenyCapV2<XBTC>,
        account: address,
        ctx: &mut tx_context::TxContext
    ) {
        let denylister = tx_context::sender(ctx);

        coin::deny_list_v2_remove(deny_list, deny_cap, account, ctx);

        event::emit(RemoveDenyListEvent {
            denylister,
            account
        });
    }

    /// Batch add addresses to deny list
    public entry fun batch_add_to_deny_list(
        deny_list: &mut DenyList,
        deny_cap: &mut DenyCapV2<XBTC>,
        accounts: vector<address>,
        ctx: &mut tx_context::TxContext
    ) {
        let count = std::vector::length(&accounts);
        assert!(count > 0, EInvalidVectorAccounts);

        let denylister = tx_context::sender(ctx);

        let mut i = 0;

        while (i < count) {
            let account = *std::vector::borrow(&accounts, i);
            coin::deny_list_v2_add(deny_list, deny_cap, account, ctx);
            i = i + 1;
        };

        event::emit(BatchAddDenyListEvent {
            denylister,
            accounts
        });
    }

    /// Batch remove addresses from deny list
    public entry fun batch_remove_from_deny_list(
        deny_list: &mut DenyList,
        deny_cap: &mut DenyCapV2<XBTC>,
        accounts: vector<address>,
        ctx: &mut tx_context::TxContext
    ) {
        let count = std::vector::length(&accounts);
        assert!(count > 0, EInvalidVectorAccounts);

        let denylister = tx_context::sender(ctx);

        let mut i = 0;

        while (i < count) {
            let account = *std::vector::borrow(&accounts, i);
            coin::deny_list_v2_remove(deny_list, deny_cap, account, ctx);
            i = i + 1;
        };

        event::emit(BatchRemoveDenyListEvent {
            denylister,
            accounts
        });
    }


    // ===== Role transfer functions =====

    /// Transfer the minter role (TreasuryCap and XBTCReceiver) to a new address
    public entry fun transfer_minter_role(
        treasury_cap: TreasuryCap<XBTC>,
        new_minter: address,
        ctx: &mut tx_context::TxContext
    ) {
        assert!(new_minter != ZERO_ADDRESS, EZeroAddress);

        let old_minter = tx_context::sender(ctx);

        // Transfer the treasury cap to the new minter
        transfer::public_transfer(treasury_cap, new_minter);

        // Emit the transfer event
        event::emit(TransferMinterRoleEvent {
            old_minter,
            new_minter
        });
    }

    /// Transfer the denylister role (DenyCapV2) to a new address
    public entry fun transfer_denylister_role(
        deny_cap: DenyCapV2<XBTC>,
        new_denylister: address,
        ctx: &mut tx_context::TxContext
    ) {
        assert!(new_denylister != ZERO_ADDRESS, EZeroAddress);

        let old_denylister = tx_context::sender(ctx);

        // Transfer the deny cap to the new denylister
        transfer::public_transfer(deny_cap, new_denylister);

        // Emit the transfer event
        event::emit(TransferDenylisterRoleEvent {
            old_denylister,
            new_denylister
        });
    }

    // === Test functions ===

    #[test_only]
    /// Create xBTC for testing
    public fun init_for_testing(ctx: &mut tx_context::TxContext) {
        init(XBTC {}, ctx);
    }
}