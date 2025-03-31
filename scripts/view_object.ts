import { Aptos, AptosConfig, Network } from "@aptos-labs/ts-sdk";
import { XBTC_CONTRACT_ADDRESS } from "./const";

// object address

async function main() {
  // config aptos client
  const config = new AptosConfig({ network: Network.DEVNET });
  const aptos = new Aptos(config);

  console.log(`query object info: ${XBTC_CONTRACT_ADDRESS}`);

  try {
    // get object resources
    const resources = await aptos.getAccountResources({
      accountAddress: XBTC_CONTRACT_ADDRESS,
    });
    
    console.log("object resources list:");
    console.log(JSON.stringify(resources, null, 2));

    // get object owner info
    const objectInfo = resources.find(
      (r) => r.type === "0x1::object::ObjectCore"
    );
    
    if (objectInfo) {
      console.log("\nobject core info:");
      console.log(JSON.stringify(objectInfo, null, 2));
    }

    // get module info
    const moduleData = await aptos.getAccountModules({
      accountAddress: XBTC_CONTRACT_ADDRESS,
    });

    console.log("\nmodule info:");
    for (const module of moduleData) {
      console.log(`module name: ${module.abi?.name}`);
      console.log(`function list: ${module.abi?.exposed_functions.map(f => f.name).join(', ')}`);
    }

  } catch (error) {
    console.error("query failed:", error);
  }
}

main(); 