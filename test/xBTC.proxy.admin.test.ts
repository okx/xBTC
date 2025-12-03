import { expect } from "chai";
import hre from "hardhat";

const { ethers } = hre;

describe("xBTC Proxy Admin Transfer Tests", function () {
  let implementation: any;
  let proxy: any;
  let xBTC: any;
  let proxyAdmin: any;
  let admin: string;
  let minter: string;
  let user: string;
  let newAdmin: string;
  let adminSigner: any;
  let newAdminSigner: any;

  const TOKEN_NAME = "Cross-Chain Bitcoin";
  const TOKEN_SYMBOL = "xBTC";
  const MAX_SUPPLY = 21_000_000n * 10n ** 8n;

  let denyLister: string;
  let denyListerSigner: any;
  
  beforeEach(async function () {
    const signers = await ethers.getSigners();
    admin = await signers[0].getAddress();
    denyLister = await signers[1].getAddress();
    minter = await signers[2].getAddress();
    user = await signers[3].getAddress();
    newAdmin = await signers[4].getAddress();
    adminSigner = signers[0];
    denyListerSigner = signers[1];
    newAdminSigner = signers[4];

    // Deploy implementation
    implementation = await ethers.deployContract("Token");
    await implementation.waitForDeployment();

    // Prepare initialization data
    const initData = implementation.interface.encodeFunctionData(
      "initialize", 
      [TOKEN_NAME, TOKEN_SYMBOL, admin, denyLister, minter, user, MAX_SUPPLY]
    );

    // Deploy proxy
    proxy = await ethers.deployContract("contracts/Proxy.sol:Proxy", [
      await implementation.getAddress(),
      admin, // proxy admin
      initData
    ]);
    await proxy.waitForDeployment();

    // Connect to proxy through implementation ABI
    xBTC = implementation.attach(await proxy.getAddress());

    // Get the ProxyAdmin contract address from the proxy
    const ADMIN_SLOT = "0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103";
    const adminSlotValue = await ethers.provider.getStorage(await proxy.getAddress(), ADMIN_SLOT);
    const proxyAdminAddress = ethers.getAddress("0x" + adminSlotValue.slice(-40));
    
    // Connect to the ProxyAdmin contract using its ABI
    const proxyAdminABI = [
      "function owner() view returns (address)",
      "function transferOwnership(address newOwner)",
      "function upgradeAndCall(address proxy, address implementation, bytes data) payable",
      "function getProxyAdmin(address proxy) view returns (address)",
      "event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)"
    ];
    proxyAdmin = new ethers.Contract(proxyAdminAddress, proxyAdminABI, adminSigner);
  });

  it("Should get current proxy admin owner", async function () {
    // The ProxyAdmin contract owner should be the admin who deployed the proxy
    const currentOwner = await proxyAdmin.owner();
    expect(currentOwner.toLowerCase()).to.equal(admin.toLowerCase());
  });

  it("Should transfer proxy admin successfully", async function () {
    // Get current owner before transfer
    const initialOwner = await proxyAdmin.owner();
    console.log("Initial ProxyAdmin owner:", initialOwner);
    expect(initialOwner.toLowerCase()).to.equal(admin.toLowerCase());

    // Transfer ownership of the ProxyAdmin contract
    await expect(proxyAdmin.connect(adminSigner).transferOwnership(newAdmin))
      .to.emit(proxyAdmin, "OwnershipTransferred")
      .withArgs(admin, newAdmin);

    // Verify ownership has changed
    const finalOwner = await proxyAdmin.owner();
    console.log("Final ProxyAdmin owner:", finalOwner);
    expect(finalOwner.toLowerCase()).to.equal(newAdmin.toLowerCase());
  });

  it("Should allow new admin to perform admin functions", async function () {
    // First transfer ownership of ProxyAdmin
    await proxyAdmin.connect(adminSigner).transferOwnership(newAdmin);
    
    // Verify new admin can call admin functions
    // Deploy a new implementation for upgrade test
    const newImplementation = await ethers.deployContract("Token");
    await newImplementation.waitForDeployment();
    
    // The new admin should be able to upgrade the proxy through ProxyAdmin
    await expect(proxyAdmin.connect(newAdminSigner).upgradeAndCall(
      await proxy.getAddress(), 
      await newImplementation.getAddress(), 
      "0x" // empty data
    )).to.emit(proxy, "Upgraded")
      .withArgs(await newImplementation.getAddress());
  });

  it("Should prevent old admin from performing admin functions after transfer", async function () {
    // First transfer ownership
    await proxyAdmin.connect(adminSigner).transferOwnership(newAdmin);
    
    // Deploy a new implementation 
    const newImplementation = await ethers.deployContract("Token");
    await newImplementation.waitForDeployment();
    
    // Old admin should not be able to upgrade anymore
    await expect(proxyAdmin.connect(adminSigner).upgradeAndCall(
      await proxy.getAddress(), 
      await newImplementation.getAddress(), 
      "0x"
    )).to.be.reverted;
  });

  it("Should prevent non-admin from transferring admin", async function () {
    const nonAdminSigner = newAdminSigner; // Using newAdmin as non-admin initially
    
    // Non-admin should not be able to transfer ownership
    await expect(proxyAdmin.connect(nonAdminSigner).transferOwnership(newAdmin))
      .to.be.reverted;
  });

  it("Should maintain proxy functionality after admin transfer", async function () {
    const mintAmount = ethers.parseUnits("1000", 8);
    const signers = await ethers.getSigners();
    const minterSigner = signers[2];
    const user = await signers[3].getAddress();
    
    // Transfer ownership first
    await proxyAdmin.connect(adminSigner).transferOwnership(newAdmin);
    
    // Verify that the implementation functionality still works
    await expect(xBTC.connect(minterSigner).mint(user, mintAmount))
      .to.emit(xBTC, "Mint")
      .withArgs(user, mintAmount);
    
    expect(await xBTC.balanceOf(user)).to.equal(mintAmount);
    expect(await xBTC.name()).to.equal(TOKEN_NAME);
    expect(await xBTC.symbol()).to.equal(TOKEN_SYMBOL);
  });

  it("Should get proxy admin address", async function () {
    // Get the ProxyAdmin address from storage slot and verify it matches our connected contract
    const ADMIN_SLOT = "0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103";
    const adminSlotValue = await ethers.provider.getStorage(await proxy.getAddress(), ADMIN_SLOT);
    const proxyAdminAddress = ethers.getAddress("0x" + adminSlotValue.slice(-40));
    
    expect(proxyAdminAddress.toLowerCase()).to.equal((await proxyAdmin.getAddress()).toLowerCase());
  });

  it("Should verify proxy admin using ProxyAdmin contract", async function () {
    // Verify that our ProxyAdmin contract address matches the admin slot in the proxy
    const proxyAddress = await proxy.getAddress();
    
    // Get the admin from the ERC1967 admin slot
    const ADMIN_SLOT = "0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103";
    const adminSlotValue = await ethers.provider.getStorage(proxyAddress, ADMIN_SLOT);
    const adminFromSlot = ethers.getAddress("0x" + adminSlotValue.slice(-40));
    
    expect(adminFromSlot.toLowerCase()).to.equal((await proxyAdmin.getAddress()).toLowerCase());
    
    // Check that the current owner of the ProxyAdmin is our admin
    const ownerOfProxyAdmin = await proxyAdmin.owner();
    expect(ownerOfProxyAdmin.toLowerCase()).to.equal(admin.toLowerCase());
  });
});