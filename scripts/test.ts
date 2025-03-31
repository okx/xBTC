import { Aptos, AptosConfig, Network, Account, AccountAddress, Ed25519PrivateKey } from "@aptos-labs/ts-sdk";
import { getAptosClient, getAccount, getAccount2, RECIPIENT_ADDRESS, ONE_BTC_AMOUNT, XBTC_CONTRACT_ADDRESS, ACCOUNT2 } from "./const";
import dotenv from "dotenv";
dotenv.config();

// 1. init aptos client and account
let aptos = getAptosClient(Network.DEVNET);
let account = getAccount();
let account2 = getAccount2();

let isSimulate = false;  // Global simulation flag
let XBTC_TOKEN = "";

// Helper function to get the actual XBTC address
async function getXbtcAddress() : Promise<string> {
    const xbtcAddress = XBTC_CONTRACT_ADDRESS;
    const viewResult = await aptos.view({
      payload: {
        function: `${xbtcAddress}::xbtc::xbtc_address`,
        typeArguments: [],
        functionArguments: []
      }
    });

    if (!viewResult || viewResult.length === 0) {
      console.log("Failed to get xbtc_address");
      return "";
    }

    const actualXbtcAddress = viewResult[0] as string;
    console.log(`Actual XBTC resource address: ${actualXbtcAddress}`);

    return actualXbtcAddress;
}


// === execute transaction ===
async function executeTransaction(functionName: string, typeArgs: string[] = [], args: any[] = []) {
  // console.log(`execute function: ${functionName}`);
  // console.log(`typeArgs: ${typeArgs}`);
  // console.log(`args: ${args}`);


  try {
    // 1. Build transaction
    const transaction = await aptos.transaction.build.simple({
      sender: account.accountAddress,
      data: {
        function: `${XBTC_CONTRACT_ADDRESS}::xbtc::${functionName}`,
        typeArguments: typeArgs,
        functionArguments: args,
      },
    });

    // Check if only simulating execution
    if (isSimulate) {
      // 2. Simulate to see what would happen if we execute this transaction
      console.log("Simulating transaction...");
      const [simulationResult] = await aptos.transaction.simulate.simple({
        signerPublicKey: account.publicKey,
        transaction,
      });
      
      console.log("Simulation results:");
      console.log(`- Success: ${simulationResult.success}`);
      console.log(`- Gas used: ${simulationResult.gas_used}`);
      
      if (!simulationResult.success) {
        console.log(`- Failure reason: ${simulationResult.vm_status}`);
      }
      
      return simulationResult;
    } else {
      // 2. Sign transaction
      const senderAuthenticator = await aptos.transaction.sign({
        signer: account,
        transaction,
      });
      
      // 3. Submit transaction
      const pendingTxn = await aptos.transaction.submit.simple({
        transaction,
        senderAuthenticator,
      });
      
      console.log(`Transaction submitted successfully, link: https://explorer.aptoslabs.com/txn/${pendingTxn.hash}?network=devnet`);

      // 4. Wait for transaction completion
      const txn = await aptos.waitForTransaction({ transactionHash: pendingTxn.hash });
      console.log(`Transaction status: ${txn.success ? "successful" : "failed"}`);
      return txn;
    }
  } catch (error) {

    // console.error(`Failed to execute ${functionName}:`, error);
    console.error(`Failed to execute ${functionName}:`);

    throw error;
  }
}

// === XBTC Operation Functions ===

// Mint tokens
async function mint(recipient: string, amount: number) {
  console.log(`Preparing to mint ${amount / 100000000} XBTC to address: ${recipient}`);
  await executeTransaction("mint", [], [recipient, amount]);
  console.log("Minting 1 XBTC completed");
}

// Burn tokens
async function burn(targetAccount: string, amount: number) {
  console.log(`Preparing to burn ${amount / 100000000} XBTC from address ${targetAccount}`);
  // await executeTransaction("burn", [], [targetAccount, amount]);
  await executeTransaction("burn", [], [amount]);
}

// Set contract pause state
async function setPause(pauseState: boolean) {
  console.log(`Setting contract pause state to: ${pauseState}`);
  await executeTransaction("set_pause", [], [pauseState]);
}

// Add address to denylist
async function addToDenyList(targetAccount: string) {
  console.log(`Adding address ${targetAccount} to denylist`);
  await executeTransaction("add_to_deny_list", [], [targetAccount]);
}

// Remove address from denylist
async function removeFromDenyList(targetAccount: string) {
  console.log(`Removing address ${targetAccount} from denylist`);
  await executeTransaction("remove_from_deny_list", [], [targetAccount]);
}

// Add multiple addresses to denylist
async function batchAddToDenyList(accounts: string[]) {
  console.log(`Adding ${accounts.length} addresses to denylist`);
  await executeTransaction("batch_add_to_deny_list", [], [accounts]);
}

// Remove multiple addresses from denylist
async function batchRemoveFromDenyList(accounts: string[]) {
  console.log(`Removing ${accounts.length} addresses from denylist`);
  await executeTransaction("batch_remove_from_deny_list", [], [accounts]);
}

// Set receiver address
async function setReceiver(receiverAddress: string) {
  console.log(`Setting receiver address to: ${receiverAddress}`);
  await executeTransaction("set_receiver", [], [receiverAddress]);
}

// Transfer minter role
async function transferMinterRole(newMinter: string) {
  console.log(`Transferring minter role to address: ${newMinter}`);
  await executeTransaction("transfer_minter_role", [], [newMinter]);
}

// Transfer denylister role
async function transferDenylisterRole(newDenylister: string) {
  console.log(`Transferring denylister role to address: ${newDenylister}`);
  await executeTransaction("transfer_denylister_role", [], [newDenylister]);
}


// transfer coin
async function transferCoin(account: Account, receiver: string, amount: number) {
  console.log(`Preparing to transfer ${amount / ONE_BTC_AMOUNT} XBTC to address ${receiver}`);
  let transferAccount = account;
  try {
    // According to Aptos documentation, the correct function signature for primary_fungible_store::transfer is:
    // public entry fun transfer<T: key>(sender: &signer, metadata: Object<T>, recipient: address, amount:u64)
    // The sender's signer will be automatically added, we only need to provide other parameters
    
    // Use the correct method to call the transfer function
    const transaction = await aptos.transaction.build.simple({
      sender: transferAccount.accountAddress,
      data: {
        function: "0x1::primary_fungible_store::transfer",
        typeArguments: ["0x1::fungible_asset::Metadata"], // Use the correct type parameter
        functionArguments: [
          XBTC_TOKEN, // metadata object address
          receiver,   // recipient address
          amount      // transfer amount
        ],
      },
    });
        
    // Signing and submitting the transaction process
    if (isSimulate) {
      console.log("Simulating transfer transaction...");
      const [simulationResult] = await aptos.transaction.simulate.simple({
        signerPublicKey: transferAccount.publicKey,
        transaction,
      });
      
      console.log("Transfer simulation results:");
      console.log(`- Success: ${simulationResult.success}`);
      console.log(`- Gas used: ${simulationResult.gas_used}`);
      
      if (!simulationResult.success) {
        console.log(`- Failure reason: ${simulationResult.vm_status}`);
      }
      
      return simulationResult;
    } else {
      console.log("Signing transfer transaction...");
      const senderAuthenticator = await aptos.transaction.sign({
        signer: transferAccount,
        transaction,
      });
      
      const pendingTxn = await aptos.transaction.submit.simple({
        transaction,
        senderAuthenticator,
      });
      
      console.log(`Transfer transaction submitted successfully, link: https://explorer.aptoslabs.com/txn/${pendingTxn.hash}?network=devnet`);
      
      const txn = await aptos.waitForTransaction({ transactionHash: pendingTxn.hash });
      console.log(`Transfer transaction status: ${txn.success ? "successful" : "failed"}`);
      return txn;
    }
  } catch (error) {
    // console.error("Transfer failed:", error);
    console.error("Transfer failed:");
    throw error;
  }
}

// Try to burn tokens, expected to fail
async function tryBurn(amount: number){
  try {
    await burn(RECIPIENT_ADDRESS, amount);
  } catch (error) {
    console.log("Burn failed as expected:");
    const err = error as any;
    if (err.transaction?.vm_status) console.log("VM Status:", err.transaction.vm_status);
  }
}

// Query XBTC contract role information
async function getXbtcRoles() {
  console.log("Querying XBTC contract role information...");
  try {
    // Get XBTC address
    const xbtcAddress = XBTC_CONTRACT_ADDRESS;
    console.log(`XBTC contract address: ${xbtcAddress}`);
    
    // 1. First call the view function to get the actual xbtc_address
    const viewResult = await aptos.view({
      payload: {
        function: `${xbtcAddress}::xbtc::xbtc_address`,
        typeArguments: [],
        functionArguments: []
      }
    });
    
    if (!viewResult || viewResult.length === 0) {
      console.log("Could not get xbtc_address");
      return;
    }
    
    const actualXbtcAddress = viewResult[0] as string;
    console.log(`Actual XBTC resource address: ${actualXbtcAddress}`);
    
    // 2. Query resources for the actual address
    const resources = await aptos.getAccountResources({
      accountAddress: actualXbtcAddress,
    });
    
    // Find Roles resource
    const rolesResource = resources.find(res => 
      res.type.includes("::xbtc::Roles")
    );
    
    if (rolesResource && rolesResource.data) {
      const data = rolesResource.data as any;
      console.log("Found Roles resource:");
      console.log(` - Minter: ${data.minter}`);
      console.log(` - Denylister: ${data.denylister}`);
      console.log(` - Receiver: ${data.receiver}`);
      
      // Check if current account is minter or denylister
      if (data.minter === account.accountAddress.toString()) {
        console.log(" * Your account is the Minter, can mint and burn tokens, set receiver address");
      } else {
        console.log(" * Your account is not the Minter");
      }
      
      if (data.denylister === account.accountAddress.toString()) {
        console.log(" * Your account is the Denylister, can pause the contract, manage denylist");
      } else {
        console.log(" * Your account is not the Denylister");
      }
      
      // If current account is not a role owner, provide suggestions
      if (data.minter !== account.accountAddress.toString() && 
          data.denylister !== account.accountAddress.toString()) {
        console.log("\nYou need to obtain the Minter or Denylister role to manage the XBTC contract.");
        console.log("Currently these roles are controlled by the contract owner, you may need to contact the contract administrator.");
      }
    } else {
      console.log("Roles resource not found");
      console.log("Available resource types:");
      resources.forEach(resource => {
        console.log(` - ${resource.type}`);
      });
    }
  } catch (error) {
    console.error("Failed to query role information:", error);
  }
}

async function tryTransferCoin(account: Account) {
  try { 
    await transferCoin(account, ACCOUNT2, ONE_BTC_AMOUNT / 10); // Transfer 0.1 XBTC
  } catch (error) {
    console.log("Transfer failed:");
    const err = error as any;
    if (err.transaction?.vm_status) console.log("VM Status:", err.transaction.vm_status);
  }

}

async function getContractInfo() {
  console.log("Querying contract detailed information...");
  try {
    // Get XBTC address
    const xbtcAddress = XBTC_CONTRACT_ADDRESS;
    console.log(`XBTC contract address: ${xbtcAddress}`);

    // 1. Get module information
    console.log("Getting module information...");
    const modules = await aptos.getAccountModules({
      accountAddress: xbtcAddress,
    });
    console.log(`Found ${modules.length} modules`);
    
    if (modules.length > 0) {
      for (const module of modules) {
        console.log(`- Module name: ${module.abi?.name}`);
        if (module.abi?.structs) {
          console.log(`  Contains ${module.abi.structs.length} structs:`);
          for (const struct of module.abi.structs) {
            console.log(`  - ${struct.name}`);
          }
        }
        
        // Get complete module address
        const moduleAddress = `${xbtcAddress}::${module.abi?.name}`;
        console.log(`\nComplete module address: ${moduleAddress}`);
        
        // Query current account's related resources
        console.log("Trying to query current account's related resources...");
        const accountResources = await aptos.getAccountResources({
          accountAddress: account.accountAddress,
        });
        
        // Find resources containing this module
        const matchingResources = accountResources.filter(res => 
          res.type.includes(moduleAddress) || 
          res.type.includes(module.abi?.name || "")
        );
        
        console.log(`Found ${matchingResources.length} related resources on current account:`);
        matchingResources.forEach(res => {
          console.log(` - ${res.type}`);
          if (res.data) {
            console.log(`   Data: ${JSON.stringify(res.data, null, 2)}`);
          }
        });

        // Find function information
        if (module.abi?.exposed_functions) {
          console.log(`\nModule contains ${module.abi.exposed_functions.length} exposed functions:`);
          for (const func of module.abi.exposed_functions) {
            console.log(`  - ${func.name} (${func.visibility})`);
            
            // Special focus on xbtc_address function
            if (func.name === "xbtc_address") {
              console.log(`    * This is the function we need, it returns the XBTC resource address`);
            }
          }
        }
      }
    }

    // 2. Get account resources
    console.log("\nGet contract object resources:");
    const resources = await aptos.getAccountResources({
      accountAddress: xbtcAddress,
    });
    
    console.log(`Found ${resources.length} resource types:`);
    resources.forEach(resource => {
      console.log(` - ${resource.type}`);
      if (resource.data) {
        console.log(`   Data: ${JSON.stringify(resource.data, null, 2).substring(0, 150)}...`);
      }
    });

    // 3. Try to call on-chain view function to get xbtc_address
    console.log("\nTrying to call the module's view function...");
    if (modules.length > 0 && modules[0].abi?.name) {
      const moduleName = modules[0].abi.name;
      try {
        // Build correct parameters for view function
        const viewResult = await aptos.view({
          payload: {
            function: `${xbtcAddress}::${moduleName}::xbtc_address`,
            typeArguments: [],
            functionArguments: []
          }
        });
        console.log(`xbtc_address function return result: ${JSON.stringify(viewResult)}`);
        
        // If address is obtained, try to query resources under that address
        if (viewResult && viewResult.length > 0) {
          // Convert to string, if it's an object, serialize it first
          const actualXbtcAddress = typeof viewResult[0] === 'string' 
            ? viewResult[0] 
            : JSON.stringify(viewResult[0]);

          console.log(`\nQuerying actual XBTC address resources: ${actualXbtcAddress}`);
          
          try {
            const xbtcResources = await aptos.getAccountResources({
              accountAddress: actualXbtcAddress,
            });
            
            console.log(`Found ${xbtcResources.length} resources under address ${actualXbtcAddress}:`);
            xbtcResources.forEach(res => {
              console.log(` - ${res.type}`);
              if (res.type.includes("Roles")) {
                console.log(`   Found Roles resource! Data: ${JSON.stringify(res.data, null, 2)}`);
              } else if (res.data) {
                console.log(`   Data: ${JSON.stringify(res.data, null, 2).substring(0, 150)}...`);
              }
            });
          } catch (err) {
            console.error(`Could not query resources for address ${actualXbtcAddress}: ${err}`);
          }
        }
      } catch (error) {
        console.error(`Failed to call view function: ${error}`);
      }
    }
  } catch (error) {
    console.error("Failed to query contract information:", error);
  }
}

// Try to add account to denylist
async function tryAddToDenyList() {
  let tempIsSimulate = isSimulate;
  isSimulate = true;
  try {
    await addToDenyList(ACCOUNT2);
  } catch (error) {
    console.log("Add to denylist failed:");
    const err = error as any;
    if (err.transaction?.vm_status) console.log("VM Status:", err.transaction.vm_status);
  }
  isSimulate = tempIsSimulate;
}

// transfer_fungible_store 
async function transferFungibleStore(newOwner: string) {
  console.log(`Preparing to transfer fungible store to new owner: ${newOwner}`);
  await executeTransaction("transfer_fungible_store", [], [newOwner]);
}

// Try to transfer fungible store
async function tryTransferFungibleStore(newOwner: string) {
  let tempIsSimulate = isSimulate;
  isSimulate = true;
  try {
    await transferFungibleStore(newOwner);
  } catch (error) {
    console.log("Transfer fungible store failed:");
    const err = error as any;
    if (err.transaction?.vm_status) console.log("VM Status:", err.transaction.vm_status);
  }
  isSimulate = tempIsSimulate;
}


// Helper function to check XBTC balance for one account
async function checkXBTCBalance(accountAddress: string): Promise<number> {
  console.log(`Checking XBTC balance for account: ${accountAddress}`);
  try {
    // Simple direct call to view function to get balance
    const viewResult = await aptos.view({
      payload: {
        function: "0x1::primary_fungible_store::balance",
        typeArguments: ["0x1::fungible_asset::Metadata"], // Use the correct type parameter
        functionArguments: [
          accountAddress,  // account address
          XBTC_TOKEN       // XBTC token address
        ]
      }
    });
    
    if (!viewResult || viewResult.length === 0) {
      console.log(`No balance data returned for account ${accountAddress}`);
      return 0;
    }
    
    const balance = Number(viewResult[0]);
    console.log(`XBTC Balance for ${accountAddress}: ${balance / ONE_BTC_AMOUNT} XBTC`);
    return balance;
  } catch (error) {
    console.log(`Error checking balance for ${accountAddress}, returning 0: ${error}`);
    return 0;
  }
}

// Function to check balances for multiple accounts
async function checkBalances(addresses: string[]): Promise<void> {
  console.log("=== Checking XBTC Balances ===");
  for (const address of addresses) {
    await checkXBTCBalance(address);
  }
  console.log("=== Balance Check Complete ===");
}

// === Main Function ===
async function main() {
  console.log("XBTC Test Setup");
  console.log(`Execution mode set to: ${isSimulate ? "simulation" : "actual execution"}`);

  // 0. ===== Query XBTC contract information =====
  // Get actual XBTC address
  XBTC_TOKEN = await getXbtcAddress();
  if (!XBTC_TOKEN) {
    console.error("Failed to get XBTC token address. Operations cannot proceed.");
    return;
  }
  // Query XBTC role information
  await getXbtcRoles();
  // Check balances
  await checkBalances([RECIPIENT_ADDRESS, ACCOUNT2]);




  // 1. ===== Initial operations examples (uncomment as needed) =====
  await setReceiver(RECIPIENT_ADDRESS);
  console.log("1.setReceiver success ✅");
  await mint(RECIPIENT_ADDRESS, ONE_BTC_AMOUNT);
  console.log("2.mint success ✅");
  await transferCoin(account, ACCOUNT2, ONE_BTC_AMOUNT / 10); // Transfer 0.1 XBTC to ACCOUNT2
  console.log("3.transferCoin success ✅");
  await checkBalances([RECIPIENT_ADDRESS, ACCOUNT2]);
  await burn(RECIPIENT_ADDRESS, ONE_BTC_AMOUNT / 2); // Burn 0.5 XBTC
  console.log("4.burn success ✅");
  await setPause(true);  // Pause the contract
  console.log("5.setPause success ✅");
  await tryBurn(ONE_BTC_AMOUNT / 10);       // This should fail because contract is paused
  console.log("6.tryBurn expected failed ok ✅");
  await setPause(false); // Unpause the contract
  console.log("7.setPause success ✅");
  await tryBurn(ONE_BTC_AMOUNT / 10);       // This should now succeed
  console.log("8.tryBurn success ✅");
  await addToDenyList(ACCOUNT2);       // Add to denylist
  console.log("9.addToDenyList success ✅");
  await tryTransferCoin(account2);             // This should fail
  console.log("10.tryTransferCoin expected failed ok ✅");
  await removeFromDenyList(ACCOUNT2);  // Remove from denylist
  console.log("11.removeFromDenyList success ✅");
  await transferCoin(account2, ACCOUNT2, ONE_BTC_AMOUNT / 10); // Should succeed
  console.log("12.transferCoin success ✅");


  // 2. ===== Advanced operations examples (uncomment as needed) =====
  // Batch denylist operations
  await batchAddToDenyList([ACCOUNT2]);
  console.log("13.batchAddToDenyList success ✅");
  await batchRemoveFromDenyList([ACCOUNT2]);
  console.log("14.batchRemoveFromDenyList success ✅");
  
  // transfer_minter_role and transfer_denylister_role
  await transferMinterRole(ACCOUNT2);
  console.log("15.transferMinterRole success ✅");
  await transferDenylisterRole(ACCOUNT2);
  console.log("16.transferDenylisterRole success ✅");

}

// Run the main function
main().catch(console.error);