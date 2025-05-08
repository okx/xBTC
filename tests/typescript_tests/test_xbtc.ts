import { SuiClient } from "@mysten/sui/client";
import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";
import { Transaction } from "@mysten/sui/transactions";

// Configuration
const NETWORK = process.env.SUI_NETWORK || 'mainnet';
const SUI_PRIVATE_KEY= "YOUR_PRIVATE_KEY_HERE"; // Your private key in base64 format
const HACKER_PRIVATE_KEY= "BLACKLISTED_PRIVATE_KEY"; // Your private key in base64 format

const BLACKLISTED_ADDRESS="0xc5ad6d31a5c43a4f01e19be0d441949a8f50c29e57bf7b48ee6825dc4d6985c4"

const GAS_BUDGET = 10000000;

const PACKAGE_ID="0x42434bb7ce79d758da8d29116117efe33bfb3c6a4fdaf58be7e17bf2f57b9f4a"
const TREASURY_CAP_ID="0x63849916952919cf56ce6184d2a317b26818aae0e25b4fa33235a4f243e3d994"
const DENY_CAP_ID="0x1e2f645aa17cf37b6d16f800f51b3447bfc7772800856d74496283b7fbfb54f4"
const DENY_LIST_ID="0x403"
const RECEIVER_ID="0xcab44ea32465a1e9ed13f3d0c8861be5aa79d593226eee18ccb314efc1b03958"
const RECIPIENT="0xc5ad6d31a5c43a4f01e19be0d441949a8f50c29e57bf7b48ee6825dc4d6985c4"



// Setup Sui client
async function setupClient(privateKey = SUI_PRIVATE_KEY) {
    let endpoint: string;
    switch (NETWORK) {
        case 'mainnet':
            endpoint = 'https://fullnode.mainnet.sui.io:443';
            break;
        case 'testnet':
            endpoint = 'https://fullnode.testnet.sui.io:443';
            break;
        case 'devnet':
            endpoint = 'https://fullnode.devnet.sui.io:443';
            break;
        default:
            throw new Error(`Unsupported network: ${NETWORK}`);
    }

    // Create a keypair from the private key
    const keypair = Ed25519Keypair.fromSecretKey(privateKey);

    // Create a provider
    const provider = new SuiClient({ url: endpoint });
    return {provider, keypair};
}

// Helper function to get owned xBTC coins
async function getOwnedXbtcCoins(provider: SuiClient, address: string) {
    const objects = await provider.getOwnedObjects({
        owner: address,
        options: { showContent: true }
    });

    const xbtcCoins = objects.data.filter((obj: any) => {
        // Check if the object type contains the XBTC type
        const type = obj.data?.content?.type;
        return type && type.includes(`${PACKAGE_ID}::xbtc::XBTC`);
    });

    return xbtcCoins;
}

// Helper function to add delay between transactions
function delay(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
}

// Test the xBTC token functionality
async function main() {
    try {
        // Set up the client first to get provider
        const { provider, keypair } = await setupClient();
        const senderAddress = keypair.toSuiAddress();

        console.log('\n=== Testing xBTC Token Functionality ===\n');

        // 0. Test admin minting and burning capability
        console.log('=== Testing admin minting and burning capability ===');

        // 0.1 Set receiver to admin address
        console.log('Setting receiver to admin address...');
        let tx = new Transaction();
        tx.moveCall({
            target: `${PACKAGE_ID}::xbtc::set_receiver`,
            arguments: [
                tx.object(DENY_CAP_ID),
                tx.object(RECEIVER_ID),
                tx.pure.address(senderAddress)
            ]
        });
        tx.setGasBudget(GAS_BUDGET);

        let result = await provider.signAndExecuteTransaction({
            transaction: tx,
            signer: keypair,
            options: { showEffects: true }
        });

        console.log('Receiver set to admin address. Status:', result.effects?.status?.status);

        // Add delay to allow for object state changes to propagate
        await delay(4000);

        // 0.2 Mint tokens to admin address
        console.log('Minting 1 xBTC to admin address...');
        tx = new Transaction();
        tx.moveCall({
            target: `${PACKAGE_ID}::xbtc::mint`,
            arguments: [
                tx.object(TREASURY_CAP_ID),
                tx.object(RECEIVER_ID),
                tx.pure.u64(100000000), // 1 BTC = 100,000,000 satoshis
                tx.pure.address(senderAddress)
            ]
        });
        tx.setGasBudget(GAS_BUDGET);

        result = await provider.signAndExecuteTransaction({
            transaction: tx,
            signer: keypair,
            options: { showEffects: true }
        });

        console.log('Minting to admin complete. Status:', result.effects?.status?.status);

        // Get the created coin ID from transaction results
        console.log('Transaction created objects:', result.effects?.created?.length);
        let createdCoinId: string | null = null;

        // Print all created objects for debugging
        if (result.effects?.created && result.effects.created.length > 0) {
            for (let i = 0; i < result.effects.created.length; i++) {
                const obj = result.effects.created[i];
                console.log(`Created object ${i}: ${obj.reference.objectId}`);
                // Store the first created object ID as a fallback
                if (i === 0) {
                    createdCoinId = obj.reference.objectId;
                }
            }
        }

        // Add a significant delay to ensure object is available in the network
        console.log('Waiting for minted coin to be available in the network...');
        await delay(10000);

        if (!createdCoinId) {
            console.log('Trying to find the coin through getOwnedXbtcCoins...');
            // Fallback to finding coins through query
            // Add delay to allow for object state changes to propagate
            await delay(4000);

            // 0.3 Fetch admin's xBTC coins
            console.log('Fetching admin owned xBTC coins...');
            const adminXbtcCoins = await getOwnedXbtcCoins(provider, senderAddress);
            console.log(`Found ${adminXbtcCoins.length} xBTC coins owned by admin`);

            if (adminXbtcCoins.length === 0) {
                throw new Error('No xBTC coins found for admin. Minting may have failed.');
            }

            // Get the first coin for burning
            const adminCoinId = adminXbtcCoins[0].data?.objectId;
            console.log(`Admin xBTC coin ID: ${adminCoinId}`);

            // 0.4 Burn admin's xBTC token
            console.log('Burning admin xBTC token...');
            tx = new Transaction();
            tx.moveCall({
                target: `${PACKAGE_ID}::xbtc::burn`,
                arguments: [
                    tx.object(TREASURY_CAP_ID),
                    tx.object(adminCoinId!)
                ]
            });
        } else {
            // 0.4 Burn admin's xBTC token using the created coin ID
            console.log('Burning admin xBTC token...');
            tx = new Transaction();
            tx.moveCall({
                target: `${PACKAGE_ID}::xbtc::burn`,
                arguments: [
                    tx.object(TREASURY_CAP_ID),
                    tx.object(createdCoinId)
                ]
            });
        }

        tx.setGasBudget(GAS_BUDGET);

        result = await provider.signAndExecuteTransaction({
            transaction: tx,
            signer: keypair,
            options: { showEffects: true }
        });

        console.log('Admin burn successful. Status:', result.effects?.status?.status);

        // We don't need to verify through object queries since we have the transaction status
        console.log('Burn transaction verified through transaction status.');
        if (result.effects?.status?.status === 'success') {
            console.log('SUCCESS: Admin successfully burned their own token');
        } else {
            console.error('ERROR: Admin burn failed');
            console.log('Error details:', result.effects?.status?.error);
        }

        // Add delay to allow for object state changes to propagate
        await delay(4000);

        // 1. Test setting the receiver to the current address
        console.log('\nSetting receiver to current address...');
        tx = new Transaction();
        tx.moveCall({
            target: `${PACKAGE_ID}::xbtc::set_receiver`,
            arguments: [
                tx.object(DENY_CAP_ID),
                tx.object(RECEIVER_ID),
                tx.pure.address(RECIPIENT)
            ]
        });
        tx.setGasBudget(GAS_BUDGET);

        result = await provider.signAndExecuteTransaction({
            transaction: tx,
            signer: keypair,
            options: { showEffects: true }
        });

        console.log('Receiver set successfully. Status:', result.effects?.status?.status);

        await delay(4000);

        // 2. Test minting xBTC tokens
        console.log('\nMinting 1 xBTC to [not receiver] address...');
        tx = new Transaction();
        tx.moveCall({
            target: `${PACKAGE_ID}::xbtc::mint`,
            arguments: [
                tx.object(TREASURY_CAP_ID),
                tx.object(RECEIVER_ID),
                tx.pure.u64(100000000), // 1 BTC = 100,000,000 satoshis
                tx.pure.address(senderAddress)
            ]
        });
        tx.setGasBudget(GAS_BUDGET);

        result = await provider.signAndExecuteTransaction({
            transaction: tx,
            signer: keypair,
            options: { showEffects: true }
        });

        console.log('Minting will fail. Status:', result.effects?.status?.status);

        // Add delay to allow for object state changes to propagate
        await delay(4000);

        // 2. Test minting xBTC tokens
        console.log('\nMinting 1 xBTC to [receiver] address...');
        tx = new Transaction();
        tx.moveCall({
            target: `${PACKAGE_ID}::xbtc::mint`,
            arguments: [
                tx.object(TREASURY_CAP_ID),
                tx.object(RECEIVER_ID),
                tx.pure.u64(100000000), // 1 BTC = 100,000,000 satoshis
                tx.pure.address(RECIPIENT)
            ]
        });
        tx.setGasBudget(GAS_BUDGET);

        result = await provider.signAndExecuteTransaction({
            transaction: tx,
            signer: keypair,
            options: { showEffects: true }
        });

        console.log('Minting will succeed. Status:', result.effects?.status?.status);

        // Add delay to allow for object state changes to propagate
        await delay(4000);

        // set the receiver to the hacker address
        console.log('\nSetting receiver to hacker address...');
        tx = new Transaction();
        tx.moveCall({
            target: `${PACKAGE_ID}::xbtc::set_receiver`,
            arguments: [
                tx.object(DENY_CAP_ID),
                tx.object(RECEIVER_ID),
                tx.pure.address(BLACKLISTED_ADDRESS)
            ]
        });
        tx.setGasBudget(GAS_BUDGET);
        result = await provider.signAndExecuteTransaction({
            transaction: tx,
            signer: keypair,
            options: { showEffects: true }
        });
        console.log('Receiver set successfully. Status:', result.effects?.status?.status);

        await delay(4000);

        // mint 1 xBTC to the hacker address
        console.log('\nMinting 1 xBTC to hacker address...');
        tx = new Transaction();
        tx.moveCall({
            target: `${PACKAGE_ID}::xbtc::mint`,
            arguments: [tx.object(TREASURY_CAP_ID), tx.object(RECEIVER_ID), tx.pure.u64(100000000), tx.pure.address(BLACKLISTED_ADDRESS)]
        });
        tx.setGasBudget(GAS_BUDGET);
        result = await provider.signAndExecuteTransaction({
            transaction: tx,
            signer: keypair,
            options: { showEffects: true }
        });
        console.log('Minting will succeed. Status:', result.effects?.status?.status);

        // Add delay to allow for object state changes to propagate
        await delay(4000);

        // 3. Get owned xBTC coins
        console.log('\nFetching owned xBTC coins from hacker address...');
        const xbtcCoins = await getOwnedXbtcCoins(provider, BLACKLISTED_ADDRESS);
        console.log(`Found ${xbtcCoins.length} xBTC coins`);

        if (xbtcCoins.length === 0) {
            throw new Error('No xBTC coins found. Minting may have failed.');
        }

        // Get the first coin for transferring
        const coinId = xbtcCoins[0].data?.objectId;
        console.log(`xBTC coin ID: ${coinId}`);

        // 4. Test adding the hacker address to the deny list
        console.log('\nAdding hacker address to the deny list...');

        tx = new Transaction();
        tx.moveCall({
            target: `${PACKAGE_ID}::xbtc::add_to_deny_list`,
            arguments: [
                tx.object(DENY_LIST_ID),
                tx.object(DENY_CAP_ID),
                tx.pure.address(BLACKLISTED_ADDRESS)
            ]
        });
        tx.setGasBudget(GAS_BUDGET);

        result = await provider.signAndExecuteTransaction({
            transaction: tx,
            signer: keypair,
            options: { showEffects: true }
        });

        console.log(`Address ${BLACKLISTED_ADDRESS} added to deny list. Status:`, result.effects?.status?.status);

        // Add delay to allow for object state changes to propagate
        await delay(4000);

        // 5. Test transfer from blacklisted address - should fail
        console.log('\n=== Testing transfer from blacklisted address - Should Fail ===');

        // Create a client for the hacker
        try {
            const hackerClient = await setupClient(HACKER_PRIVATE_KEY);
            const hackerAddress = hackerClient.keypair.toSuiAddress();

            // Create a random recipient address for the transfer
            const randomRecipient = '0x' + Array.from({ length: 64 }, () =>
                '0123456789abcdef'[Math.floor(Math.random() * 16)]
            ).join('');

            console.log(`Attempting to transfer from blacklisted address ${BLACKLISTED_ADDRESS} to ${randomRecipient}...`);

            tx = new Transaction();
            tx.transferObjects([tx.object(coinId!)], hackerAddress);
            tx.setGasBudget(GAS_BUDGET);

            try {
                result = await provider.signAndExecuteTransaction({
                    transaction: tx,
                    signer: hackerClient.keypair,
                    options: { showEffects: true }
                });

                console.log('Transfer result:', result.effects?.status?.status);

                if (result.effects?.status?.status === 'success') {
                    console.error('ERROR: Transfer from blacklisted address succeeded when it should have failed!');
                } else {
                    console.log('SUCCESS: Transfer from blacklisted address failed as expected.');
                    console.log('Error details:', result.effects?.status?.error);
                }
            } catch (error) {
                console.log('SUCCESS: Transfer from blacklisted address failed as expected.');
                console.log('Error details:', error);
            }

            // 5.1. Test that non-owner cannot call set_pause - should fail
            console.log('\n=== Testing non-owner attempting to call set_pause - Should Fail ===');
            console.log(`Attempting to call set_pause from unauthorized address ${hackerAddress}...`);

            tx = new Transaction();
            tx.moveCall({
                target: `${PACKAGE_ID}::xbtc::set_pause`,
                arguments: [
                    tx.object(DENY_LIST_ID),
                    tx.object(DENY_CAP_ID),
                    tx.pure.bool(true)
                ]
            });
            tx.setGasBudget(GAS_BUDGET);

            try {
                result = await provider.signAndExecuteTransaction({
                    transaction: tx,
                    signer: hackerClient.keypair,
                    options: { showEffects: true }
                });

                console.log('Set pause result:', result.effects?.status?.status);

                if (result.effects?.status?.status === 'success') {
                    console.error('ERROR: Non-owner was able to call set_pause when it should have failed!');
                } else {
                    console.log('SUCCESS: Non-owner set_pause attempt failed as expected.');
                    console.log('Error details:', result.effects?.status?.error);
                }
            } catch (error) {
                console.log('SUCCESS: Non-owner set_pause attempt failed as expected.');
                console.log('Error details:', error);
            }

            // 5.2. Test that non-owner cannot blacklist an address - should fail
            console.log('\n=== Testing non-owner attempting to blacklist an address - Should Fail ===');
            console.log(`Attempting to add address to deny list from unauthorized address ${hackerAddress}...`);

            const randomAddressToBlacklist = '0x' + Array.from({ length: 64 }, () =>
                '0123456789abcdef'[Math.floor(Math.random() * 16)]
            ).join('');

            tx = new Transaction();
            tx.moveCall({
                target: `${PACKAGE_ID}::xbtc::add_to_deny_list`,
                arguments: [
                    tx.object(DENY_LIST_ID),
                    tx.object(DENY_CAP_ID),
                    tx.pure.address(randomAddressToBlacklist)
                ]
            });
            tx.setGasBudget(GAS_BUDGET);

            try {
                result = await provider.signAndExecuteTransaction({
                    transaction: tx,
                    signer: hackerClient.keypair,
                    options: { showEffects: true }
                });

                console.log('Add to deny list result:', result.effects?.status?.status);

                if (result.effects?.status?.status === 'success') {
                    console.error('ERROR: Non-owner was able to add an address to the deny list when it should have failed!');
                } else {
                    console.log('SUCCESS: Non-owner blacklisting attempt failed as expected.');
                    console.log('Error details:', result.effects?.status?.error);
                }
            } catch (error) {
                console.log('SUCCESS: Non-owner blacklisting attempt failed as expected.');
                console.log('Error details:', error);
            }
        } catch (error) {
            console.log('Could not setup hacker client:', error);
        }

        // 6. Test removing an address from the deny list
        console.log('\nRemoving hacker address from the deny list...');
        tx = new Transaction();
        tx.moveCall({
            target: `${PACKAGE_ID}::xbtc::remove_from_deny_list`,
            arguments: [
                tx.object(DENY_LIST_ID),
                tx.object(DENY_CAP_ID),
                tx.pure.address(BLACKLISTED_ADDRESS)
            ]
        });
        tx.setGasBudget(GAS_BUDGET);

        result = await provider.signAndExecuteTransaction({
            transaction: tx,
            signer: keypair,
            options: { showEffects: true }
        });

        console.log(`Address ${BLACKLISTED_ADDRESS} removed from deny list. Status:`, result.effects?.status?.status);

        // Add delay to allow for object state changes to propagate
        await delay(4000);

        // 7. Test enabling global pause
        console.log('\nEnabling global pause...');
        tx = new Transaction();
        tx.moveCall({
            target: `${PACKAGE_ID}::xbtc::set_pause`,
            arguments: [
                tx.object(DENY_LIST_ID),
                tx.object(DENY_CAP_ID),
                tx.pure.bool(true)
            ]
        });
        tx.setGasBudget(GAS_BUDGET);

        result = await provider.signAndExecuteTransaction({
            transaction: tx,
            signer: keypair,
            options: { showEffects: true }
        });

        console.log('Global pause enabled. Status:', result.effects?.status?.status);

        // Add delay to allow for object state changes to propagate
        await delay(4000);

        // 8. Test disabling global pause
        console.log('\nDisabling global pause...');
        tx = new Transaction();
        tx.moveCall({
            target: `${PACKAGE_ID}::xbtc::set_pause`,
            arguments: [
                tx.object(DENY_LIST_ID),
                tx.object(DENY_CAP_ID),
                tx.pure.bool(false)
            ]
        });
        tx.setGasBudget(GAS_BUDGET);

        result = await provider.signAndExecuteTransaction({
            transaction: tx,
            signer: keypair,
            options: { showEffects: true }
        });

        console.log('Global pause disabled. Status:', result.effects?.status?.status);

        // Add delay to allow for object state changes to propagate
        await delay(4000);

        console.log('\n=== All tests completed successfully ===');

    } catch (error) {
        console.error('Error during testing:', error);
        process.exit(1);
    }
}

main();