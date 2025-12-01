import { expect } from "chai";
import hre from "hardhat";

const { ethers } = hre;

describe("xBTC Proxy Tests", function () {
  let implementation: any;
  let proxy: any;
  let xBTC: any;
  let admin: string;
  let minter: string;
  let user: string;

  const TOKEN_NAME = "Cross-Chain Bitcoin";
  const TOKEN_SYMBOL = "xBTC";
  const MAX_SUPPLY = 21_000_000n * 10n ** 8n;

  beforeEach(async function () {
    const signers = await ethers.getSigners();
    admin = await signers[0].getAddress();
    minter = await signers[1].getAddress();
    user = await signers[2].getAddress();
    
    // Store signer references
    const adminSigner = signers[0];
    const minterSigner = signers[1];
    const userSigner = signers[2];

    // Deploy implementation
    implementation = await ethers.deployContract("Token");
    await implementation.waitForDeployment();

    // Prepare initialization data
    const initData = implementation.interface.encodeFunctionData(
      "initialize", 
      [TOKEN_NAME, TOKEN_SYMBOL, admin, minter, user, MAX_SUPPLY]
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
  });

  it("Should initialize correctly through proxy", async function () {
    expect(await xBTC.name()).to.equal(TOKEN_NAME);
    expect(await xBTC.symbol()).to.equal(TOKEN_SYMBOL);
    expect(await xBTC.decimals()).to.equal(8);
    expect(await xBTC.totalSupply()).to.equal(0);
    expect(await xBTC.version()).to.equal("1.0.0");
  });

  it("Should have correct roles", async function () {
    const DENY_LISTER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("DENY_LISTER_ROLE"));
    const MINTER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("MINTER_ROLE"));
    const DEFAULT_DENY_LISTER_ROLE = ethers.ZeroHash;

    expect(await xBTC.hasRole(DEFAULT_DENY_LISTER_ROLE, admin)).to.be.true;
    expect(await xBTC.hasRole(DENY_LISTER_ROLE, admin)).to.be.true;
    expect(await xBTC.hasRole(MINTER_ROLE, minter)).to.be.true;
  });

  it("Should mint tokens", async function () {
    const mintAmount = ethers.parseUnits("1000", 8); // 1000 xBTC
    const signers = await ethers.getSigners();
    const minterSigner = signers[1];
    
    await expect(xBTC.connect(minterSigner).mint(user, mintAmount))
      .to.emit(xBTC, "Mint")
      .withArgs(user, mintAmount)
      .and.to.emit(xBTC, "Transfer")
      .withArgs(ethers.ZeroAddress, user, mintAmount);

    expect(await xBTC.balanceOf(user)).to.equal(mintAmount);
    expect(await xBTC.totalSupply()).to.equal(mintAmount);
  });

  it("Should burn tokens", async function () {
    const mintAmount = ethers.parseUnits("1000", 8);
    const burnAmount = ethers.parseUnits("500", 8);
    const signers = await ethers.getSigners();
    const minterSigner = signers[1];
    
    // First mint
    await xBTC.connect(minterSigner).mint(user, mintAmount);
    
    // First set receiver to minter so they can burn their own tokens
    await xBTC.connect(signers[0]).setReceiver(minter);
    await xBTC.connect(signers[1]).mint(minter, burnAmount);
    
    // Then burn
    await expect(xBTC.connect(minterSigner).burn(burnAmount))
      .to.emit(xBTC, "Burn")
      .withArgs(minter, burnAmount)
      .and.to.emit(xBTC, "Transfer")
      .withArgs(minter, ethers.ZeroAddress, burnAmount);

    expect(await xBTC.balanceOf(minter)).to.equal(0);
  });

  it("Should transfer tokens", async function () {
    const mintAmount = ethers.parseUnits("1000", 8);
    const transferAmount = ethers.parseUnits("250", 8);
    const signers = await ethers.getSigners();
    const minterSigner = signers[1];
    const userSigner = signers[2];
    const user2 = await signers[3].getAddress();
    
    // Mint to user
    await xBTC.connect(minterSigner).mint(user, mintAmount);
    
    // Transfer from user to user2
    await expect(xBTC.connect(userSigner).transfer(user2, transferAmount))
      .to.emit(xBTC, "Transfer")
      .withArgs(user, user2, transferAmount);

    expect(await xBTC.balanceOf(user)).to.equal(mintAmount - transferAmount);
    expect(await xBTC.balanceOf(user2)).to.equal(transferAmount);
  });

  it("Should add and remove addresses from deny list", async function () {
    const signers = await ethers.getSigners();
    const adminSigner = signers[0];
    
    await expect(xBTC.connect(adminSigner).addToDenyList(user))
      .to.emit(xBTC, "AddedToDenyList")
      .withArgs(user);

    expect(await xBTC.denyList(user)).to.be.true;

    await expect(xBTC.connect(adminSigner).removeFromDenyList(user))
      .to.emit(xBTC, "RemovedFromDenyList")
      .withArgs(user);

    expect(await xBTC.denyList(user)).to.be.false;
  });

  it("Should prevent transfers when paused", async function () {
    const mintAmount = ethers.parseUnits("1000", 8);
    const transferAmount = ethers.parseUnits("100", 8);
    const signers = await ethers.getSigners();
    const adminSigner = signers[0];
    const minterSigner = signers[1];
    const userSigner = signers[2];
    const user2 = await signers[3].getAddress();
    
    // Mint tokens
    await xBTC.connect(minterSigner).mint(user, mintAmount);
    
    // Pause the contract
    await xBTC.connect(adminSigner).pause();
    expect(await xBTC.paused()).to.be.true;

    // Try to transfer (should fail)
    await expect(
      xBTC.connect(userSigner).transfer(user2, transferAmount)
    ).to.be.revertedWithCustomError(xBTC, "EnforcedPause");

    // Unpause and transfer should work
    await xBTC.connect(adminSigner).unpause();
    expect(await xBTC.paused()).to.be.false;

    await expect(xBTC.connect(userSigner).transfer(user2, transferAmount))
      .to.emit(xBTC, "Transfer")
      .withArgs(user, user2, transferAmount);
  });

  it("Should prevent transfers from/to blocked addresses", async function () {
    const mintAmount = ethers.parseUnits("1000", 8);
    const transferAmount = ethers.parseUnits("100", 8);
    const signers = await ethers.getSigners();
    const adminSigner = signers[0];
    const minterSigner = signers[1];
    const userSigner = signers[2];
    const user2 = await signers[3].getAddress();
    const user2Signer = signers[3];
    
    // Mint tokens to both users
    await xBTC.connect(minterSigner).mint(user, mintAmount);
    await xBTC.connect(adminSigner).setReceiver(user2);
    await xBTC.connect(minterSigner).mint(user2, mintAmount);
    
    // Add user to deny list
    await xBTC.connect(adminSigner).addToDenyList(user);
    
    // Try transfer from blocked address (should fail)
    await expect(
      xBTC.connect(userSigner).transfer(user2, transferAmount)
          ).to.be.revertedWithCustomError(xBTC, "SenderInDenyList");

    // Try transfer to blocked address (should fail)
    await expect(
      xBTC.connect(user2Signer).transfer(user, transferAmount)
          ).to.be.revertedWithCustomError(xBTC, "RecipientInDenyList");

    // Remove from deny list and transfers should work
    await xBTC.connect(adminSigner).removeFromDenyList(user);

    await expect(xBTC.connect(userSigner).transfer(user2, transferAmount))
      .to.emit(xBTC, "Transfer")
      .withArgs(user, user2, transferAmount);
  });
});