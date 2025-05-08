module xbtc_aptos::xbtc {
    use aptos_framework::dispatchable_fungible_asset;
    use aptos_framework::event;
    use aptos_framework::function_info;
    use aptos_framework::fungible_asset::{Self, MintRef, TransferRef, BurnRef, Metadata, FungibleAsset};
    use aptos_framework::object::{Self, Object};
    use aptos_framework::primary_fungible_store;
    use aptos_std::big_ordered_map::{Self, BigOrderedMap};
    use std::option;
    use std::signer;
    use std::string::{Self, utf8};
    use std::vector;

    // ===== Error codes =====
    /// Caller is not authorized to make this call
    const EUnauthorized: u64 = 1;
    /// No operations are allowed when contract is paused
    const EPaused: u64 = 2;
    /// The account is denylisted
    const EDenylisted: u64 = 3;
    /// Invalid address
    const EInvalidAddress: u64 = 4;
    /// Invalid amount
    const EInvalidAmount: u64 = 5;

    // ===== Token metadata constants =====
    const TOKEN_NAME: vector<u8> = b"Regulated Bitcoin";
    const TOKEN_SYMBOL: vector<u8> = b"xBTC";
    const TOKEN_DECIMALS: u8 = 8;
    const TOKEN_URI: vector<u8> = b"";
    const PROJECT_URI: vector<u8> = b"";
    /// Zero address constant
    const ZERO_ADDRESS: address = @0x0;

    // ===== Resource groups =====
    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct Roles has key {
        minter: address,
        denylister: address,
        receiver: address,
    }
    
    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct XBTCToken has key {
        mint_ref: MintRef,
        burn_ref: BurnRef,
        transfer_ref: TransferRef,
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct State has key {
        paused: bool,
        denylist: BigOrderedMap<address, bool>,
    }

    // ===== Event types =====
    #[event]
    struct MintEvent has drop, store {
        minter: address,
        receiver: address,
        amount: u64,
    }

    #[event]
    struct BurnEvent has drop, store {
        account: address,
        amount: u64,
    }

    #[event]
    struct PauseEvent has drop, store {
        pauser: address,
        paused: bool,
    }

    #[event]
    struct AddDenyListEvent has drop, store {
        denylister: address,
        account: address,
    }

    #[event]
    struct RemoveDenyListEvent has drop, store {
        denylister: address,
        account: address,
    }

    #[event]
    struct BatchAddDenyListEvent has drop, store {
        denylister: address,
        accounts: vector<address>,
    }

    #[event]
    struct BatchRemoveDenyListEvent has drop, store {
        denylister: address,
        accounts: vector<address>,
    }

    #[event]
    struct SetReceiverEvent has drop, store {
        denylister: address,
        old_receiver: address,
        new_receiver: address,
    }

    #[event]
    struct TransferMinterRoleEvent has drop, store {
        old_minter: address,
        new_minter: address,
    }

    #[event]
    struct TransferDenylisterRoleEvent has drop, store {
        old_denylister: address,
        new_denylister: address,
    }

    // ===== Initialize functions =====
    fun init_module(xbtc_signer: &signer) {
        let constructor_ref = &object::create_named_object(xbtc_signer, TOKEN_SYMBOL);
        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            constructor_ref,
            option::none(),   /* total supply */
            utf8(TOKEN_NAME), /* name */
            utf8(TOKEN_SYMBOL), /* symbol */
            TOKEN_DECIMALS, /* decimals */
            utf8(TOKEN_URI), /* icon */
            utf8(PROJECT_URI), /* project */
        );

        // Set ALL stores for the fungible asset to untransferable.
        fungible_asset::set_untransferable(constructor_ref);

        // All resources created will be kept in the asset metadata object.
        let metadata_object_signer = &object::generate_signer(constructor_ref);
        move_to(metadata_object_signer, Roles {
            minter: @minter,
            denylister: @denylister,
            receiver: ZERO_ADDRESS,
        });

        // Create mint/burn/transfer refs to allow creator to manage the xbtc.
        move_to(metadata_object_signer, XBTCToken {
            mint_ref: fungible_asset::generate_mint_ref(constructor_ref),
            burn_ref: fungible_asset::generate_burn_ref(constructor_ref),
            transfer_ref: fungible_asset::generate_transfer_ref(constructor_ref),
        });

        move_to(metadata_object_signer, State {
            paused: false,
            denylist: big_ordered_map::new(),
        });

        // Override the deposit and withdraw functions which mean overriding transfer.
        // This ensures all transfer will call withdraw and deposit functions in this module and perform the necessary checks.
        let deposit = function_info::new_function_info(
            xbtc_signer,
            string::utf8(b"xbtc"),
            string::utf8(b"deposit"),
        );
        let withdraw = function_info::new_function_info(
            xbtc_signer,
            string::utf8(b"xbtc"),
            string::utf8(b"withdraw"),
        );
        dispatchable_fungible_asset::register_dispatch_functions(
            constructor_ref,
            option::some(withdraw),
            option::some(deposit),
            option::none(),
        );
    }

    // ===== Transfer functions =====
    /// Deposit function override to ensure that the account is not denylisted and the xbtc is not paused.
    public fun deposit<T: key>(
        store: Object<T>,
        fa: FungibleAsset,
        transfer_ref: &TransferRef,
    ) acquires State {
        assert_not_paused();
        assert_not_denylisted(object::owner(store));
        fungible_asset::deposit_with_ref(transfer_ref, store, fa);
    }

    /// Withdraw function override to ensure that the account is not denylisted and the xbtc is not paused.
    public fun withdraw<T: key>(
        store: Object<T>,
        amount: u64,
        transfer_ref: &TransferRef,
    ): FungibleAsset acquires State {
        assert_not_paused();
        assert_not_denylisted(object::owner(store));
        fungible_asset::withdraw_with_ref(transfer_ref, store, amount)
    }

    // ===== Entry functions =====
    /// Mint new tokens to the specified account. This checks that the caller is a minter, the xbtc is not paused,
    /// and the account is not denylisted.
    public entry fun mint(minter: &signer, receiver: address, amount: u64) acquires XBTCToken, Roles, State {
        assert_is_minter(minter);
        assert_not_zero_address(receiver);
        assert_amount_greater_than_zero(amount);

        let roles = borrow_global<Roles>(xbtc_address());
        assert!(receiver == roles.receiver, EInvalidAddress);
        
        // Simplified implementation without redundant conditions
        let token = borrow_global<XBTCToken>(xbtc_address());
        let tokens = fungible_asset::mint(&token.mint_ref, amount);
        deposit(primary_fungible_store::ensure_primary_store_exists(receiver, metadata()), tokens, &token.transfer_ref);

        event::emit(MintEvent {
            minter: signer::address_of(minter),
            receiver,
            amount,
        });
    }

    /// Burn tokens from the minter's store. 
    /// This checks that the caller is a minter and the xbtc is not paused.
    public entry fun burn(
        minter: &signer,
        amount: u64
    ) acquires XBTCToken, Roles, State {
        assert_is_minter(minter);
        assert_not_paused();
        assert_amount_greater_than_zero(amount);
        
        // Get user's primary store
        let account = signer::address_of(minter);
        let store = primary_fungible_store::ensure_primary_store_exists(account, metadata());
        
        // Burn tokens
        let token = borrow_global<XBTCToken>(xbtc_address());
        fungible_asset::burn_from(&token.burn_ref, store, amount);
        
        // Emit event
        event::emit(BurnEvent {
            account,
            amount,
        });
    }

    /// Set or update the receiver address. This checks that the caller is the minter.
    public entry fun set_receiver(denylister: &signer, new_receiver: address) acquires Roles {
        assert_is_denylister(denylister);
        assert_not_zero_address(new_receiver);

        let roles = borrow_global_mut<Roles>(xbtc_address());
        let old_receiver = roles.receiver;
        roles.receiver = new_receiver;

        event::emit(SetReceiverEvent {
            denylister: signer::address_of(denylister),
            old_receiver,
            new_receiver,
        });
    }

    /// Pause or unpause the xbtc. This checks that the caller is the denylister.
    public entry fun set_pause(denylister: &signer, paused: bool) acquires Roles, State {
        assert_is_denylister(denylister);

        let state = borrow_global_mut<State>(xbtc_address());
        state.paused = paused;

        event::emit(PauseEvent {
            pauser: signer::address_of(denylister),
            paused,
        });
    }

    /// Add an account to the DenyList. This checks that the caller is the denylister.
    public entry fun add_to_deny_list(denylister: &signer, account: address) acquires XBTCToken, Roles, State {
        assert_is_denylister(denylister);

        let state = borrow_global_mut<State>(xbtc_address());
        big_ordered_map::add(&mut state.denylist, account, true);

        let freeze_ref = &borrow_global<XBTCToken>(xbtc_address()).transfer_ref;
        primary_fungible_store::set_frozen_flag(freeze_ref, account, true);

        event::emit(AddDenyListEvent {
            denylister: signer::address_of(denylister),
            account,
        });
    }

    /// Remove an account from the DenyList. This checks that the caller is the denylister.
    public entry fun remove_from_deny_list(denylister: &signer, account: address) acquires XBTCToken, Roles, State {
        assert_is_denylister(denylister);
        
        let state = borrow_global_mut<State>(xbtc_address());
        big_ordered_map::remove(&mut state.denylist, &account);

        let freeze_ref = &borrow_global<XBTCToken>(xbtc_address()).transfer_ref;
        primary_fungible_store::set_frozen_flag(freeze_ref, account, false);

        event::emit(RemoveDenyListEvent {
            denylister: signer::address_of(denylister),
            account,
        });
    }

    /// Add multiple accounts to the DenyList. This checks that the caller is the denylister.
    public entry fun batch_add_to_deny_list(denylister: &signer, accounts: vector<address>) acquires XBTCToken, Roles, State {
        assert_is_denylister(denylister);
        assert_not_empty_accounts(accounts);
        
        let denylister_addr = signer::address_of(denylister);
        let state = borrow_global_mut<State>(xbtc_address());
        let freeze_ref = &borrow_global<XBTCToken>(xbtc_address()).transfer_ref;
        
        let i = 0;
        let len = vector::length(&accounts);
        
        while (i < len) {
            let account = *vector::borrow(&accounts, i);
            // Add to denylist table
            big_ordered_map::add(&mut state.denylist, account, true);
            // Freeze primary store
            primary_fungible_store::set_frozen_flag(freeze_ref, account, true);
            i = i + 1;
        };
        
        // emit event
        event::emit(BatchAddDenyListEvent {
            denylister: denylister_addr,
            accounts,
        });
    }

    /// Remove multiple accounts from the DenyList. This checks that the caller is the denylister.
    public entry fun batch_remove_from_deny_list(denylister: &signer, accounts: vector<address>) acquires XBTCToken, Roles, State {
        assert_is_denylister(denylister);
        assert_not_empty_accounts(accounts);
        
        let denylister_addr = signer::address_of(denylister);
        let state = borrow_global_mut<State>(xbtc_address());
        let freeze_ref = &borrow_global<XBTCToken>(xbtc_address()).transfer_ref;
        
        let i = 0;
        let len = vector::length(&accounts);
        
        while (i < len) {
            let account = *vector::borrow(&accounts, i);
            // Remove from denylist table
            if (big_ordered_map::contains(&state.denylist, &account)) {
                big_ordered_map::remove(&mut state.denylist, &account);
                // Unfreeze primary store
                primary_fungible_store::set_frozen_flag(freeze_ref, account, false);
            };
            
            i = i + 1;
        };
        
        // emit event
        event::emit(BatchRemoveDenyListEvent {
            denylister: denylister_addr,
            accounts,
        });
    }

    
    // ===== Role transfer functions =====
    /// Transfer minter role to a new address. This checks that the caller is the current minter.
    public entry fun transfer_minter_role(minter_signer: &signer, new_minter: address) acquires Roles {
        assert_is_minter(minter_signer);
        assert_not_zero_address(new_minter);
        let roles = borrow_global_mut<Roles>(xbtc_address());
        let old_minter = roles.minter;
        roles.minter = new_minter;

        event::emit(TransferMinterRoleEvent {
            old_minter,
            new_minter,
        });
    }

    /// Transfer denylister role to a new address. This checks that the caller is the current denylister.
    public entry fun transfer_denylister_role(denylister_signer: &signer, new_denylister: address) acquires Roles {
        assert_is_denylister(denylister_signer);
        assert_not_zero_address(new_denylister);
        let roles = borrow_global_mut<Roles>(xbtc_address());
        let old_denylister = roles.denylister;
        roles.denylister = new_denylister;

        event::emit(TransferDenylisterRoleEvent {
            old_denylister,
            new_denylister,
        });
    }

    // ===== View functions =====
    #[view]
    public fun xbtc_address(): address {
        object::create_object_address(&@xbtc_aptos, TOKEN_SYMBOL)
    }

    // ===== Helper functions =====
    fun metadata(): Object<Metadata> {
        object::address_to_object(xbtc_address())
    }

    fun assert_is_minter(minter: &signer) acquires Roles {
        let roles = borrow_global<Roles>(xbtc_address());
        let minter_addr = signer::address_of(minter);
        assert!(minter_addr == roles.minter, EUnauthorized);
    }

    fun assert_is_denylister(denylister: &signer) acquires Roles {
        let roles = borrow_global<Roles>(xbtc_address());
        let denylister_addr = signer::address_of(denylister);
        assert!(denylister_addr == roles.denylister, EUnauthorized);
    }

    fun assert_not_paused() acquires State {
        let state = borrow_global<State>(xbtc_address());
        assert!(!state.paused, EPaused);
    }

    fun assert_not_denylisted(account: address) acquires State {
        let state = borrow_global<State>(xbtc_address());
        assert!(!big_ordered_map::contains(&state.denylist, &account), EDenylisted);
    }

    /// Asserts that the given address is not the zero address
    fun assert_not_zero_address(addr: address) {
        assert!(addr != ZERO_ADDRESS, EInvalidAddress);
    }

    /// Asserts that the given amount is not zero
    fun assert_amount_greater_than_zero(amount: u64) {
        assert!(amount > 0, EInvalidAmount);
    }

    fun assert_not_empty_accounts(accounts: vector<address>) {
        assert!(vector::length(&accounts) > 0, EInvalidAddress);
    }


    #[test_only]
    use aptos_framework::account;

    #[test_only]
    public fun init_for_test() {
        init_module(&account::create_signer_for_test(@xbtc_aptos));
    }
}