import { expect } from "chai";
import hre from "hardhat";
import { ContractTransactionResponse, ZeroAddress } from "ethers";
import type { Signer } from "ethers";

const { ethers } = hre;

describe("xBTC Contract", function () {
  let xBTC: any;
  let admin: Signer;
  let minter: Signer;
  let user1: Signer;
  let user2: Signer;
  let blocked: Signer;
  let adminAddress: string;
  let minterAddress: string;
  let user1Address: string;
  let user2Address: string;
  let blockedAddress: string;

  const TOKEN_NAME = "xBTC Token";
  const TOKEN_SYMBOL = "xBTC";
  const DENY_LISTER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("DENY_LISTER_ROLE"));
  const MINTER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("MINTER_ROLE"));
  const DEFAULT_ADMIN_ROLE = ethers.ZeroHash;
  const MAX_SUPPLY = 21_000_000n * 10n ** 8n;

  beforeEach(async function () {
    [admin, minter, user1, user2, blocked] = await ethers.getSigners();
    adminAddress = await admin.getAddress();
    minterAddress = await minter.getAddress();
    user1Address = await user1.getAddress();
    user2Address = await user2.getAddress();
    blockedAddress = await blocked.getAddress();

    // Deploy implementation
    const implementation = await ethers.deployContract("xbtc");
    await implementation.waitForDeployment();

    // Prepare initialization data
    const initData = implementation.interface.encodeFunctionData(
      "initialize", 
      [TOKEN_NAME, TOKEN_SYMBOL, adminAddress, minterAddress, user1Address]
    );

    // Deploy proxy
    const proxy = await ethers.deployContract("xbtcProxy", [
      await implementation.getAddress(),
      adminAddress,
      initData
    ]);
    await proxy.waitForDeployment();

    // Connect to proxy
    xBTC = implementation.attach(await proxy.getAddress());
  });

  describe("Deployment and Initialization", function () {
    it("Should initialize with correct values", async function () {
      expect(await xBTC.name()).to.equal(TOKEN_NAME);
      expect(await xBTC.symbol()).to.equal(TOKEN_SYMBOL);
      expect(await xBTC.decimals()).to.equal(8);
      expect(await xBTC.totalSupply()).to.equal(0);
      expect(await xBTC.version()).to.equal("1.0.0");
    });

    it("Should grant correct roles on initialization", async function () {
      expect(await xBTC.hasRole(DEFAULT_ADMIN_ROLE, adminAddress)).to.be.true;
      expect(await xBTC.hasRole(DENY_LISTER_ROLE, adminAddress)).to.be.true;
      expect(await xBTC.hasRole(MINTER_ROLE, minterAddress)).to.be.true;
      expect(await xBTC.hasRole(MINTER_ROLE, adminAddress)).to.be.false;
    });

    it("Should not allow re-initialization", async function () {
      await expect(
        xBTC.initialize(TOKEN_NAME, TOKEN_SYMBOL, adminAddress, minterAddress, user1Address)
      ).to.be.revertedWithCustomError(xBTC, "InvalidInitialization");
    });

    it("Should support expected interfaces", async function () {
      // ERC20
      expect(await xBTC.supportsInterface("0x36372b07")).to.be.false; // Not implemented in AccessControl
      // AccessControl
      expect(await xBTC.supportsInterface("0x7965db0b")).to.be.true;
    });
  });

  describe("Minting", function () {
    it("Should allow minter to mint tokens to authorized receiver", async function () {
      const mintAmount = 1000n * 10n ** 8n; // 1000 xBTC
      
      await expect(xBTC.connect(minter).mint(user1Address, mintAmount))
        .to.emit(xBTC, "Transfer")
        .withArgs(ZeroAddress, user1Address, mintAmount)
        .and.to.emit(xBTC, "Mint")
        .withArgs(user1Address, mintAmount);

      expect(await xBTC.balanceOf(user1Address)).to.equal(mintAmount);
      expect(await xBTC.totalSupply()).to.equal(mintAmount);
    });

    it("Should not allow non-minter to mint", async function () {
      const mintAmount = 1000n * 10n ** 8n;
      
      await expect(
        xBTC.connect(user1).mint(user1Address, mintAmount)
      ).to.be.revertedWithCustomError(xBTC, "AccessControlUnauthorizedAccount");
    });

    it("Should not allow setting zero address as receiver", async function () {
      await expect(
        xBTC.connect(admin).setReceiver(ZeroAddress)
      ).to.be.revertedWithCustomError(xBTC, "ZeroAddress");
    });

    it("Should not allow minting zero amount", async function () {
      await expect(
        xBTC.connect(minter).mint(user1Address, 0)
      ).to.be.revertedWithCustomError(xBTC, "ZeroAmount");
    });

    it("Should not allow minting beyond max supply", async function () {
      const exceedAmount = MAX_SUPPLY + 1n;
      
      await expect(
        xBTC.connect(minter).mint(user1Address, exceedAmount)
      ).to.be.revertedWithCustomError(xBTC, "ExceedsMaxSupply");
    });

    it("Should not allow minting to address in deny list", async function () {
      const mintAmount = 1000n * 10n ** 8n;
      
      // Add the address to deny list first
      await xBTC.connect(admin).addToDenyList(blockedAddress);
      
      await xBTC.connect(admin).setReceiver(blockedAddress);
      
      await expect(
        xBTC.connect(minter).mint(blockedAddress, mintAmount)
      ).to.be.revertedWithCustomError(xBTC, "RecipientInDenyList");
    });

    it("Should not allow minting to unauthorized receiver", async function () {
      const mintAmount = 1000n * 10n ** 8n;
      
      // The authorized receiver is set to user1Address during initialization
      // Try to mint to user2Address instead (unauthorized receiver)
      await expect(
        xBTC.connect(minter).mint(user2Address, mintAmount)
      ).to.be.revertedWithCustomError(xBTC, "NoAuthorizedReceiver");
    });
  });

  describe("Burning", function () {
    beforeEach(async function () {
      // Mint some tokens first
      const mintAmount = 1000n * 10n ** 8n;
      await xBTC.connect(minter).mint(user1Address, mintAmount);
    });

    it("Should allow minter to burn their own tokens", async function () {
      const burnAmount = 500n * 10n ** 8n;
      
      // First mint tokens to the minter
      await xBTC.connect(admin).setReceiver(minterAddress);
      await xBTC.connect(minter).mint(minterAddress, burnAmount);
      const initialBalance = await xBTC.balanceOf(minterAddress);
      
      await expect(xBTC.connect(minter).burn(burnAmount))
        .to.emit(xBTC, "Transfer")
        .withArgs(minterAddress, ZeroAddress, burnAmount)
        .and.to.emit(xBTC, "Burn")
        .withArgs(minterAddress, burnAmount);

      expect(await xBTC.balanceOf(minterAddress)).to.equal(initialBalance - burnAmount);
    });

    it("Should not allow non-minter to burn tokens", async function () {
      const burnAmount = 500n * 10n ** 8n;
      
      await expect(
        xBTC.connect(user1).burn(burnAmount)
      ).to.be.revertedWithCustomError(xBTC, "AccessControlUnauthorizedAccount");
    });

    // Note: Cannot test burning from zero address since msg.sender cannot be zero address

    it("Should not allow burning zero amount", async function () {
      await expect(
        xBTC.connect(minter).burn(0)
      ).to.be.revertedWithCustomError(xBTC, "ZeroAmount");
    });

    it("Should not allow burning more than balance", async function () {
      const balance = await xBTC.balanceOf(minterAddress);
      const excessAmount = balance + 1n;
      
      await expect(
        xBTC.connect(minter).burn(excessAmount)
      ).to.be.revertedWithCustomError(xBTC, "InsufficientBalance");
    });


  });

  describe("Deny List Management", function () {
    it("Should allow admin to add addresses to deny list", async function () {
      await expect(xBTC.connect(admin).addToDenyList(user1Address))
        .to.emit(xBTC, "AddedToDenyList")
        .withArgs(user1Address);

      expect(await xBTC.denyList(user1Address)).to.be.true;
    });

    it("Should allow admin to remove addresses from deny list", async function () {
      // Add to deny list first
      await xBTC.connect(admin).addToDenyList(user1Address);
      
      await expect(xBTC.connect(admin).removeFromDenyList(user1Address))
        .to.emit(xBTC, "RemovedFromDenyList")
        .withArgs(user1Address);

      expect(await xBTC.denyList(user1Address)).to.be.false;
    });

    it("Should not allow non-admin to add addresses to deny list", async function () {
      await expect(
        xBTC.connect(user1).addToDenyList(user2Address)
      ).to.be.revertedWithCustomError(xBTC, "AccessControlUnauthorizedAccount");
    });

    it("Should not allow adding zero address to deny list", async function () {
      await expect(
        xBTC.connect(admin).addToDenyList(ZeroAddress)
      ).to.be.revertedWithCustomError(xBTC, "ZeroAddress");
    });

    it("Should allow adding admin to deny list", async function () {
      await expect(
        xBTC.connect(admin).addToDenyList(adminAddress)
      ).to.emit(xBTC, "AddedToDenyList").withArgs(adminAddress);
      
      expect(await xBTC.denyList(adminAddress)).to.be.true;
    });

    it("Should allow adding minter to deny list", async function () {
      await expect(
        xBTC.connect(admin).addToDenyList(minterAddress)
      ).to.emit(xBTC, "AddedToDenyList").withArgs(minterAddress);
      
      expect(await xBTC.denyList(minterAddress)).to.be.true;
    });

    it("Should prevent transfers from addresses in deny list", async function () {
      // Mint tokens first
      const mintAmount = 1000n * 10n ** 8n;
      await xBTC.connect(minter).mint(user1Address, mintAmount);
      
      // Add user1 to deny list
      await xBTC.connect(admin).addToDenyList(user1Address);
      
      await expect(
        xBTC.connect(user1).transfer(user2Address, 100n * 10n ** 8n)
      ).to.be.revertedWithCustomError(xBTC, "SenderInDenyList");
    });

    it("Should prevent transfers to addresses in deny list", async function () {
      // Mint tokens first
      const mintAmount = 1000n * 10n ** 8n;
      await xBTC.connect(minter).mint(user1Address, mintAmount);
      
      // Add user2 to deny list
      await xBTC.connect(admin).addToDenyList(user2Address);
      
      await expect(
        xBTC.connect(user1).transfer(user2Address, 100n * 10n ** 8n)
      ).to.be.revertedWithCustomError(xBTC, "RecipientInDenyList");
    });
  });

  describe("Pausing", function () {
    it("Should allow admin to pause the contract", async function () {
      await xBTC.connect(admin).pause();
      expect(await xBTC.paused()).to.be.true;
    });

    it("Should allow admin to unpause the contract", async function () {
      await xBTC.connect(admin).pause();
      await xBTC.connect(admin).unpause();
      expect(await xBTC.paused()).to.be.false;
    });

    it("Should not allow non-admin to pause", async function () {
      await expect(
        xBTC.connect(user1).pause()
      ).to.be.revertedWithCustomError(xBTC, "AccessControlUnauthorizedAccount");
    });

    it("Should prevent transfers when paused", async function () {
      // Mint tokens first
      const mintAmount = 1000n * 10n ** 8n;
      await xBTC.connect(minter).mint(user1Address, mintAmount);
      
      // Pause the contract
      await xBTC.connect(admin).pause();
      
      await expect(
        xBTC.connect(user1).transfer(user2Address, 100n * 10n ** 8n)
      ).to.be.revertedWithCustomError(xBTC, "EnforcedPause");
    });
  });

  // EIP-3009 functions have been removed from the contract
  /*
  describe("EIP-3009 Transfer With Authorization", function () {
    let domain: any;
    let types: any;

    beforeEach(async function () {
      // Mint tokens to user1
      const mintAmount = 1000n * 10n ** 8n;
      await xBTC.connect(minter).mint(user1Address, mintAmount);

      // Set up domain and types for EIP-712 signatures
      const chainId = (await ethers.provider.getNetwork()).chainId;
      domain = {
        name: TOKEN_NAME,
        version: "1",
        chainId: Number(chainId),
        verifyingContract: await xBTC.getAddress(),
      };

      types = {
        TransferWithAuthorization: [
          { name: "from", type: "address" },
          { name: "to", type: "address" },
          { name: "value", type: "uint256" },
          { name: "validAfter", type: "uint256" },
          { name: "validBefore", type: "uint256" },
          { name: "nonce", type: "bytes32" },
        ],
        ReceiveWithAuthorization: [
          { name: "from", type: "address" },
          { name: "to", type: "address" },
          { name: "value", type: "uint256" },
          { name: "validAfter", type: "uint256" },
          { name: "validBefore", type: "uint256" },
          { name: "nonce", type: "bytes32" },
        ],
        CancelAuthorization: [
          { name: "authorizer", type: "address" },
          { name: "nonce", type: "bytes32" },
        ],
      };
    });

    it("Should execute transferWithAuthorization with valid signature", async function () {
      const transferAmount = 100n * 10n ** 8n;
      const nonce = ethers.randomBytes(32);
      const validAfter = 0;
      const validBefore = Math.floor(Date.now() / 1000) + 3600; // 1 hour from now

      const message = {
        from: user1Address,
        to: user2Address,
        value: transferAmount,
        validAfter,
        validBefore,
        nonce: ethers.hexlify(nonce),
      };

      const signature = await user1.signTypedData(domain, { TransferWithAuthorization: types.TransferWithAuthorization }, message);
      const { v, r, s } = ethers.Signature.from(signature);

      await expect(
        xBTC.transferWithAuthorization(
          user1Address,
          user2Address,
          transferAmount,
          validAfter,
          validBefore,
          ethers.hexlify(nonce),
          v,
          r,
          s
        )
      ).to.emit(xBTC, "Transfer")
        .withArgs(user1Address, user2Address, transferAmount)
        .and.to.emit(xBTC, "AuthorizationUsed")
        .withArgs(user1Address, ethers.hexlify(nonce));

      expect(await xBTC.balanceOf(user2Address)).to.equal(transferAmount);
      expect(await xBTC.authorizationState(user1Address, ethers.hexlify(nonce))).to.be.true;
    });

    it("Should execute receiveWithAuthorization with valid signature", async function () {
      const transferAmount = 100n * 10n ** 8n;
      const nonce = ethers.randomBytes(32);
      const validAfter = 0;
      const validBefore = Math.floor(Date.now() / 1000) + 3600;

      const message = {
        from: user1Address,
        to: user2Address,
        value: transferAmount,
        validAfter,
        validBefore,
        nonce: ethers.hexlify(nonce),
      };

      const signature = await user1.signTypedData(domain, { ReceiveWithAuthorization: types.ReceiveWithAuthorization }, message);
      const { v, r, s } = ethers.Signature.from(signature);

      await expect(
        xBTC.connect(user2).receiveWithAuthorization(
          user1Address,
          user2Address,
          transferAmount,
          validAfter,
          validBefore,
          ethers.hexlify(nonce),
          v,
          r,
          s
        )
      ).to.emit(xBTC, "Transfer")
        .withArgs(user1Address, user2Address, transferAmount)
        .and.to.emit(xBTC, "AuthorizationUsed")
        .withArgs(user1Address, ethers.hexlify(nonce));
    });

    it("Should not allow receiveWithAuthorization if caller is not payee", async function () {
      const transferAmount = 100n * 10n ** 8n;
      const nonce = ethers.randomBytes(32);
      const validAfter = 0;
      const validBefore = Math.floor(Date.now() / 1000) + 3600;

      const message = {
        from: user1Address,
        to: user2Address,
        value: transferAmount,
        validAfter,
        validBefore,
        nonce: ethers.hexlify(nonce),
      };

      const signature = await user1.signTypedData(domain, { ReceiveWithAuthorization: types.ReceiveWithAuthorization }, message);
      const { v, r, s } = ethers.Signature.from(signature);

      await expect(
        xBTC.connect(admin).receiveWithAuthorization(
          user1Address,
          user2Address,
          transferAmount,
          validAfter,
          validBefore,
          ethers.hexlify(nonce),
          v,
          r,
          s
        )
      ).to.be.revertedWith("xBTC: caller must be the payee");
    });

    it("Should cancel authorization", async function () {
      const nonce = ethers.randomBytes(32);
      
      const message = {
        authorizer: user1Address,
        nonce: ethers.hexlify(nonce),
      };

      const signature = await user1.signTypedData(domain, { CancelAuthorization: types.CancelAuthorization }, message);
      const { v, r, s } = ethers.Signature.from(signature);

      await expect(
        xBTC.cancelAuthorization(user1Address, ethers.hexlify(nonce), v, r, s)
      ).to.emit(xBTC, "AuthorizationCanceled")
        .withArgs(user1Address, ethers.hexlify(nonce));

      expect(await xBTC.authorizationState(user1Address, ethers.hexlify(nonce))).to.be.true;
    });

    it("Should reject expired authorization", async function () {
      const transferAmount = 100n * 10n ** 8n;
      const nonce = ethers.randomBytes(32);
      const validAfter = 0;
      const validBefore = Math.floor(Date.now() / 1000) - 3600; // 1 hour ago (expired)

      const message = {
        from: user1Address,
        to: user2Address,
        value: transferAmount,
        validAfter,
        validBefore,
        nonce: ethers.hexlify(nonce),
      };

      const signature = await user1.signTypedData(domain, { TransferWithAuthorization: types.TransferWithAuthorization }, message);
      const { v, r, s } = ethers.Signature.from(signature);

      await expect(
        xBTC.transferWithAuthorization(
          user1Address,
          user2Address,
          transferAmount,
          validAfter,
          validBefore,
          ethers.hexlify(nonce),
          v,
          r,
          s
        )
      ).to.be.revertedWith("xBTC: authorization expired");
    });

    it("Should reject authorization not yet valid", async function () {
      const transferAmount = 100n * 10n ** 8n;
      const nonce = ethers.randomBytes(32);
      const validAfter = Math.floor(Date.now() / 1000) + 3600; // 1 hour from now
      const validBefore = Math.floor(Date.now() / 1000) + 7200; // 2 hours from now

      const message = {
        from: user1Address,
        to: user2Address,
        value: transferAmount,
        validAfter,
        validBefore,
        nonce: ethers.hexlify(nonce),
      };

      const signature = await user1.signTypedData(domain, { TransferWithAuthorization: types.TransferWithAuthorization }, message);
      const { v, r, s } = ethers.Signature.from(signature);

      await expect(
        xBTC.transferWithAuthorization(
          user1Address,
          user2Address,
          transferAmount,
          validAfter,
          validBefore,
          ethers.hexlify(nonce),
          v,
          r,
          s
        )
      ).to.be.revertedWith("xBTC: authorization not yet valid");
    });

    it("Should reject already used authorization", async function () {
      const transferAmount = 100n * 10n ** 8n;
      const nonce = ethers.randomBytes(32);
      const validAfter = 0;
      const validBefore = Math.floor(Date.now() / 1000) + 3600;

      const message = {
        from: user1Address,
        to: user2Address,
        value: transferAmount,
        validAfter,
        validBefore,
        nonce: ethers.hexlify(nonce),
      };

      const signature = await user1.signTypedData(domain, { TransferWithAuthorization: types.TransferWithAuthorization }, message);
      const { v, r, s } = ethers.Signature.from(signature);

      // Use authorization once
      await xBTC.transferWithAuthorization(
        user1Address,
        user2Address,
        transferAmount,
        validAfter,
        validBefore,
        ethers.hexlify(nonce),
        v,
        r,
        s
      );

      // Try to use it again
      await expect(
        xBTC.transferWithAuthorization(
          user1Address,
          user2Address,
          transferAmount,
          validAfter,
          validBefore,
          ethers.hexlify(nonce),
          v,
          r,
          s
        )
      ).to.be.revertedWith("xBTC: authorization already used");
    });

    it("Should reject invalid signature", async function () {
      const transferAmount = 100n * 10n ** 8n;
      const nonce = ethers.randomBytes(32);
      const validAfter = 0;
      const validBefore = Math.floor(Date.now() / 1000) + 3600;

      // Create signature with user2 instead of user1
      const message = {
        from: user1Address,
        to: user2Address,
        value: transferAmount,
        validAfter,
        validBefore,
        nonce: ethers.hexlify(nonce),
      };

      const signature = await user2.signTypedData(domain, { TransferWithAuthorization: types.TransferWithAuthorization }, message);
      const { v, r, s } = ethers.Signature.from(signature);

      await expect(
        xBTC.transferWithAuthorization(
          user1Address,
          user2Address,
          transferAmount,
          validAfter,
          validBefore,
          ethers.hexlify(nonce),
          v,
          r,
          s
        )
      ).to.be.revertedWith("xBTC: invalid signature");
    });

    it("Should not allow authorization with blocked addresses", async function () {
      // Block user1
      await xBTC.connect(admin).blockAddress(user1Address);

      const transferAmount = 100n * 10n ** 8n;
      const nonce = ethers.randomBytes(32);
      const validAfter = 0;
      const validBefore = Math.floor(Date.now() / 1000) + 3600;

      const message = {
        from: user1Address,
        to: user2Address,
        value: transferAmount,
        validAfter,
        validBefore,
        nonce: ethers.hexlify(nonce),
      };

      const signature = await user1.signTypedData(domain, { TransferWithAuthorization: types.TransferWithAuthorization }, message);
      const { v, r, s } = ethers.Signature.from(signature);

      await expect(
        xBTC.transferWithAuthorization(
          user1Address,
          user2Address,
          transferAmount,
          validAfter,
          validBefore,
          ethers.hexlify(nonce),
          v,
          r,
          s
        )
      ).to.be.revertedWithCustomError(xBTC, "AddressInDenyList");
    });
  });
  */

  describe("Role Management", function () {
    it("Should allow admin to grant minter role", async function () {
      await xBTC.connect(admin).grantRole(MINTER_ROLE, user1Address);
      expect(await xBTC.hasRole(MINTER_ROLE, user1Address)).to.be.true;
    });

    it("Should allow admin to revoke minter role", async function () {
      await xBTC.connect(admin).revokeRole(MINTER_ROLE, minterAddress);
      expect(await xBTC.hasRole(MINTER_ROLE, minterAddress)).to.be.false;
    });

    it("Should not allow non-admin to grant roles", async function () {
      await expect(
        xBTC.connect(user1).grantRole(MINTER_ROLE, user2Address)
      ).to.be.revertedWithCustomError(xBTC, "AccessControlUnauthorizedAccount");
    });
  });

  describe("Standard ERC20 Functions", function () {
    beforeEach(async function () {
      // Mint tokens to user1
      const mintAmount = 1000n * 10n ** 8n;
      await xBTC.connect(minter).mint(user1Address, mintAmount);
    });

    it("Should transfer tokens between accounts", async function () {
      const transferAmount = 100n * 10n ** 8n;
      
      await expect(xBTC.connect(user1).transfer(user2Address, transferAmount))
        .to.emit(xBTC, "Transfer")
        .withArgs(user1Address, user2Address, transferAmount);

      expect(await xBTC.balanceOf(user2Address)).to.equal(transferAmount);
    });

    it("Should approve and transferFrom", async function () {
      const transferAmount = 100n * 10n ** 8n;
      
      await xBTC.connect(user1).approve(user2Address, transferAmount);
      expect(await xBTC.allowance(user1Address, user2Address)).to.equal(transferAmount);

      await expect(xBTC.connect(user2).transferFrom(user1Address, user2Address, transferAmount))
        .to.emit(xBTC, "Transfer")
        .withArgs(user1Address, user2Address, transferAmount);

      expect(await xBTC.balanceOf(user2Address)).to.equal(transferAmount);
    });

    it("Should support permit functionality", async function () {
      const spenderAddress = user2Address;
      const value = 100n * 10n ** 8n;
      const nonce = await xBTC.nonces(user1Address);
      const deadline = Math.floor(Date.now() / 1000) + 3600;

      const domain = {
        name: TOKEN_NAME,
        version: "1",
        chainId: Number((await ethers.provider.getNetwork()).chainId),
        verifyingContract: await xBTC.getAddress(),
      };

      const types = {
        Permit: [
          { name: "owner", type: "address" },
          { name: "spender", type: "address" },
          { name: "value", type: "uint256" },
          { name: "nonce", type: "uint256" },
          { name: "deadline", type: "uint256" },
        ],
      };

      const message = {
        owner: user1Address,
        spender: spenderAddress,
        value,
        nonce,
        deadline,
      };

      const signature = await user1.signTypedData(domain, types, message);
      const { v, r, s } = ethers.Signature.from(signature);

      await expect(
        xBTC.permit(user1Address, spenderAddress, value, deadline, v, r, s)
      ).to.emit(xBTC, "Approval")
        .withArgs(user1Address, spenderAddress, value);

      expect(await xBTC.allowance(user1Address, spenderAddress)).to.equal(value);
    });
  });

  describe("Edge Cases and Error Conditions", function () {
    it("Should handle maximum supply correctly", async function () {
      // Mint exactly MAX_SUPPLY
      await xBTC.connect(admin).setReceiver(user1Address);
      await expect(xBTC.connect(minter).mint(user1Address, MAX_SUPPLY))
        .to.emit(xBTC, "Mint")
        .withArgs(user1Address, MAX_SUPPLY);

      expect(await xBTC.totalSupply()).to.equal(MAX_SUPPLY);

      // Should not allow minting even 1 more
      await expect(
        xBTC.connect(minter).mint(user1Address, 1n)
      ).to.be.revertedWithCustomError(xBTC, "ExceedsMaxSupply");
    });

    // Authorization state and cancel authorization tests removed as EIP-3009 functions were removed
    /*
    it("Should return correct authorization state", async function () {
      const nonce = ethers.randomBytes(32);
      expect(await xBTC.authorizationState(user1Address, ethers.hexlify(nonce))).to.be.false;
    });

    it("Should prevent cancel of already used authorization", async function () {
      const nonce = ethers.randomBytes(32);
      
      // First cancel the authorization
      const domain = {
        name: TOKEN_NAME,
        version: "1",
        chainId: Number((await ethers.provider.getNetwork()).chainId),
        verifyingContract: await xBTC.getAddress(),
      };

      const types = {
        CancelAuthorization: [
          { name: "authorizer", type: "address" },
          { name: "nonce", type: "bytes32" },
        ],
      };

      const message = {
        authorizer: user1Address,
        nonce: ethers.hexlify(nonce),
      };

      const signature = await user1.signTypedData(domain, types, message);
      const { v, r, s } = ethers.Signature.from(signature);

      await xBTC.cancelAuthorization(user1Address, ethers.hexlify(nonce), v, r, s);

      // Try to cancel again
      await expect(
        xBTC.cancelAuthorization(user1Address, ethers.hexlify(nonce), v, r, s)
      ).to.be.revertedWith("xBTC: authorization already used");
    });
    */
  });

  describe("Receiver Management", function () {
    it("Should allow minter to set receiver", async function () {
      // Initial receiver is user1Address (set during initialization)
      // Change it to user2Address
      await expect(xBTC.connect(admin).setReceiver(user2Address))
        .to.emit(xBTC, "ReceiverSet")
        .withArgs(user1Address, user2Address);
        
      expect(await xBTC.authorizedReceiver()).to.equal(user2Address);
    });

    it("Should not allow non-deny lister to set receiver", async function () {
      await expect(
        xBTC.connect(user1).setReceiver(user2Address)
      ).to.be.revertedWithCustomError(xBTC, "AccessControlUnauthorizedAccount");
    });
  });

  describe("Coverage - Initialize Edge Cases", function () {
    it("Should revert when initializing with zero receiver address", async function () {
      // Deploy a new implementation for this test
      const implementation = await ethers.deployContract("xbtc");
      await implementation.waitForDeployment();

      // Try to initialize with zero receiver
      const initData = implementation.interface.encodeFunctionData(
        "initialize", 
        [TOKEN_NAME, TOKEN_SYMBOL, adminAddress, minterAddress, ZeroAddress]
      );

      // This should revert during proxy deployment
      await expect(
        ethers.deployContract("xbtcProxy", [
          await implementation.getAddress(),
          adminAddress,
          initData
        ])
      ).to.be.revertedWithCustomError(implementation, "ZeroAddress");
    });
  });

  describe("Coverage - Pause Functionality Edge Cases", function () {
    it("Should prevent minting when paused", async function () {
      // Pause the contract
      await xBTC.connect(admin).pause();
      
      // Try to mint - should be blocked by whenNotPaused modifier
      await expect(
        xBTC.connect(minter).mint(user1Address, 100n * 10n ** 8n)
      ).to.be.revertedWithCustomError(xBTC, "EnforcedPause");
    });

    it("Should prevent burning when paused", async function () {
      // First mint some tokens to minter
      await xBTC.connect(admin).setReceiver(minterAddress);
      await xBTC.connect(minter).mint(minterAddress, 1000n * 10n ** 8n);
      
      // Pause the contract
      await xBTC.connect(admin).pause();
      
      // Try to burn - should be blocked by whenNotPaused modifier
      await expect(
        xBTC.connect(minter).burn(100n * 10n ** 8n)
      ).to.be.revertedWithCustomError(xBTC, "EnforcedPause");
    });
  });

  describe("Coverage - Batch Deny List Operations", function () {
    describe("batchAddToDenyList", function () {
      it("Should successfully add multiple addresses to deny list", async function () {
        const addresses = [user1Address, user2Address];
        
        await expect(xBTC.connect(admin).batchAddToDenyList(addresses))
          .to.emit(xBTC, "AddedToDenyList")
          .withArgs(user1Address)
          .and.to.emit(xBTC, "AddedToDenyList")
          .withArgs(user2Address);

        expect(await xBTC.denyList(user1Address)).to.be.true;
        expect(await xBTC.denyList(user2Address)).to.be.true;
      });

      it("Should revert when non-admin calls batchAddToDenyList", async function () {
        await expect(
          xBTC.connect(user1).batchAddToDenyList([user2Address])
        ).to.be.revertedWithCustomError(xBTC, "AccessControlUnauthorizedAccount");
      });

      it("Should revert when empty array is passed to batchAddToDenyList", async function () {
        await expect(
          xBTC.connect(admin).batchAddToDenyList([])
        ).to.be.revertedWithCustomError(xBTC, "EmptyArray");
      });

      it("Should revert when zero address is in batchAddToDenyList array", async function () {
        await expect(
          xBTC.connect(admin).batchAddToDenyList([user1Address, ZeroAddress])
        ).to.be.revertedWithCustomError(xBTC, "ZeroAddress");
      });

      it("Should handle already denied addresses in batchAddToDenyList", async function () {
        // First add user1 to deny list
        await xBTC.connect(admin).addToDenyList(user1Address);
        
        // Now try to add user1 again along with user2
        // Should succeed but only emit event for user2
        await expect(
          xBTC.connect(admin).batchAddToDenyList([user1Address, user2Address])
        )
          .to.emit(xBTC, "AddedToDenyList")
          .withArgs(user2Address);
        
        // Verify both are in deny list
        expect(await xBTC.denyList(user1Address)).to.be.true;
        expect(await xBTC.denyList(user2Address)).to.be.true;
      });
    });

    describe("batchRemoveFromDenyList", function () {
      beforeEach(async function () {
        // Add some addresses to deny list first
        await xBTC.connect(admin).batchAddToDenyList([user1Address, user2Address]);
      });

      it("Should successfully remove multiple addresses from deny list", async function () {
        await expect(
          xBTC.connect(admin).batchRemoveFromDenyList([user1Address, user2Address])
        )
          .to.emit(xBTC, "RemovedFromDenyList")
          .withArgs(user1Address)
          .and.to.emit(xBTC, "RemovedFromDenyList")
          .withArgs(user2Address);
        
        // Verify addresses are removed from deny list
        expect(await xBTC.denyList(user1Address)).to.be.false;
        expect(await xBTC.denyList(user2Address)).to.be.false;
      });

      it("Should revert when non-admin calls batchRemoveFromDenyList", async function () {
        await expect(
          xBTC.connect(user1).batchRemoveFromDenyList([user1Address])
        ).to.be.revertedWithCustomError(xBTC, "AccessControlUnauthorizedAccount");
      });

      it("Should revert when empty array is passed to batchRemoveFromDenyList", async function () {
        await expect(
          xBTC.connect(admin).batchRemoveFromDenyList([])
        ).to.be.revertedWithCustomError(xBTC, "EmptyArray");
      });

      it("Should handle addresses not in deny list gracefully", async function () {
        // Remove user1 first
        await xBTC.connect(admin).removeFromDenyList(user1Address);
        
        // Now try to remove user1 again along with user2
        // Should only emit event for user2
        await expect(
          xBTC.connect(admin).batchRemoveFromDenyList([user1Address, user2Address])
        )
          .to.emit(xBTC, "RemovedFromDenyList")
          .withArgs(user2Address);
        
        // Verify final state
        expect(await xBTC.denyList(user1Address)).to.be.false;
        expect(await xBTC.denyList(user2Address)).to.be.false;
      });
    });
  });

  describe("Coverage - Additional Access Control Edge Cases", function () {
    it("Should revert when non-admin calls removeFromDenyList", async function () {
      // First add address to deny list
      await xBTC.connect(admin).addToDenyList(user1Address);
      
      // Try to remove with non-admin account
      await expect(
        xBTC.connect(user2).removeFromDenyList(user1Address)
      ).to.be.revertedWithCustomError(xBTC, "AccessControlUnauthorizedAccount");
    });

    it("Should revert when non-admin calls pause", async function () {
      await expect(
        xBTC.connect(user1).pause()
      ).to.be.revertedWithCustomError(xBTC, "AccessControlUnauthorizedAccount");
    });

    it("Should revert when non-admin calls unpause", async function () {
      // First pause with admin
      await xBTC.connect(admin).pause();
      
      // Try to unpause with non-admin
      await expect(
        xBTC.connect(user1).unpause()
      ).to.be.revertedWithCustomError(xBTC, "AccessControlUnauthorizedAccount");
    });
  });

  describe("Role Transfer Tests", function () {
    describe("Minter Role Transfer", function () {
      it("Should allow current minter to transfer minter role", async function () {
        // Verify initial state
        expect(await xBTC.hasRole(MINTER_ROLE, minterAddress)).to.be.true;
        expect(await xBTC.hasRole(MINTER_ROLE, user1Address)).to.be.false;

        // Transfer minter role
        await expect(xBTC.connect(minter).transferMinter(user1Address))
          .to.emit(xBTC, "MinterTransferred")
          .withArgs(minterAddress, user1Address);

        // Verify role transfer
        expect(await xBTC.hasRole(MINTER_ROLE, minterAddress)).to.be.false;
        expect(await xBTC.hasRole(MINTER_ROLE, user1Address)).to.be.true;

        // Verify new minter can mint (admin sets receiver since setReceiver requires DENY_LISTER_ROLE)
        await xBTC.connect(admin).setReceiver(user2Address);
        await expect(xBTC.connect(user1).mint(user2Address, ethers.parseUnits("1000", 8)))
          .to.not.be.reverted;

        // Verify old minter cannot mint
        await expect(xBTC.connect(minter).mint(user1Address, ethers.parseUnits("1000", 8)))
          .to.be.revertedWithCustomError(xBTC, "AccessControlUnauthorizedAccount");
      });

      it("Should not allow non-minter to transfer minter role", async function () {
        await expect(xBTC.connect(user1).transferMinter(user2Address))
          .to.be.revertedWithCustomError(xBTC, "AccessControlUnauthorizedAccount");
      });

      it("Should not allow transfer to zero address", async function () {
        await expect(xBTC.connect(minter).transferMinter(ZeroAddress))
          .to.be.revertedWithCustomError(xBTC, "ZeroAddress");
      });

      it("Should not allow transfer to same address", async function () {
        await expect(xBTC.connect(minter).transferMinter(minterAddress))
          .to.be.revertedWithCustomError(xBTC, "SameValue");
      });
    });

    describe("Deny Lister Role Transfer", function () {
      it("Should allow current deny lister to transfer deny lister role", async function () {
        // Verify initial state
        expect(await xBTC.hasRole(DENY_LISTER_ROLE, adminAddress)).to.be.true;
        expect(await xBTC.hasRole(DENY_LISTER_ROLE, user1Address)).to.be.false;

        // Transfer deny lister role
        await expect(xBTC.connect(admin).transferDenyLister(user1Address))
          .to.emit(xBTC, "DenyListerTransferred")
          .withArgs(adminAddress, user1Address);

        // Verify role transfer
        expect(await xBTC.hasRole(DENY_LISTER_ROLE, adminAddress)).to.be.false;
        expect(await xBTC.hasRole(DENY_LISTER_ROLE, user1Address)).to.be.true;

        // Verify new deny lister can pause
        await expect(xBTC.connect(user1).pause())
          .to.not.be.reverted;

        // Verify old deny lister cannot pause
        await expect(xBTC.connect(admin).unpause())
          .to.be.revertedWithCustomError(xBTC, "AccessControlUnauthorizedAccount");
      });

      it("Should not allow non-deny-lister to transfer deny lister role", async function () {
        await expect(xBTC.connect(user1).transferDenyLister(user2Address))
          .to.be.revertedWithCustomError(xBTC, "AccessControlUnauthorizedAccount");
      });

      it("Should not allow transfer to zero address", async function () {
        await expect(xBTC.connect(admin).transferDenyLister(ZeroAddress))
          .to.be.revertedWithCustomError(xBTC, "ZeroAddress");
      });

      it("Should not allow transfer to same address", async function () {
        await expect(xBTC.connect(admin).transferDenyLister(adminAddress))
          .to.be.revertedWithCustomError(xBTC, "SameValue");
      });
    });

    describe("Role Addition to Deny List", function () {
      beforeEach(async function () {
        // Mint some tokens for testing
        await xBTC.connect(minter).mint(user1Address, 1000n * 10n ** 8n);
      });

      it("Should allow adding deny lister to deny list", async function () {
        await expect(xBTC.connect(admin).addToDenyList(adminAddress))
          .to.emit(xBTC, "AddedToDenyList")
          .withArgs(adminAddress);

        expect(await xBTC.denyList(adminAddress)).to.be.true;
      });

      it("Should allow adding minter to deny list", async function () {
        await expect(xBTC.connect(admin).addToDenyList(minterAddress))
          .to.emit(xBTC, "AddedToDenyList")
          .withArgs(minterAddress);

        expect(await xBTC.denyList(minterAddress)).to.be.true;
      });

      it("Should allow batch adding roles to deny list", async function () {
        const rolesToBlock = [adminAddress, minterAddress];
        
        await expect(xBTC.connect(admin).batchAddToDenyList(rolesToBlock))
          .to.emit(xBTC, "AddedToDenyList")
          .withArgs(adminAddress)
          .and.to.emit(xBTC, "AddedToDenyList")
          .withArgs(minterAddress);

        expect(await xBTC.denyList(adminAddress)).to.be.true;
        expect(await xBTC.denyList(minterAddress)).to.be.true;
      });

      it("Should prevent transfers from deny lister in deny list", async function () {
        // Add admin to deny list
        await xBTC.connect(admin).addToDenyList(adminAddress);
        
        // Admin should not be able to transfer tokens
        await expect(xBTC.connect(admin).transfer(user2Address, ethers.parseUnits("1", 8)))
          .to.be.revertedWithCustomError(xBTC, "SenderInDenyList");
      });

      it("Should prevent minting when receiver is in deny list", async function () {
        // Add the authorized receiver to deny list
        await xBTC.connect(admin).addToDenyList(user1Address);
        
        // Minter should not be able to mint because recipient is in deny list
        await expect(xBTC.connect(minter).mint(user1Address, ethers.parseUnits("1000", 8)))
          .to.be.revertedWithCustomError(xBTC, "RecipientInDenyList");
      });

      it("Should allow minting when minter is in deny list but receiver is not", async function () {
        // Add minter to deny list (but not the receiver)
        await xBTC.connect(admin).addToDenyList(minterAddress);
        
        // Minter should still be able to mint (they have the role and recipient is not blocked)
        await expect(xBTC.connect(minter).mint(user1Address, ethers.parseUnits("1000", 8)))
          .to.not.be.reverted;
      });
    });

    describe("Edge Cases", function () {
      it("Should allow role transfer even when role holder is in deny list", async function () {
        // Add minter to deny list
        await xBTC.connect(admin).addToDenyList(minterAddress);
        
        // Minter should still be able to transfer their role
        await expect(xBTC.connect(minter).transferMinter(user1Address))
          .to.emit(xBTC, "MinterTransferred")
          .withArgs(minterAddress, user1Address);

        // New minter should be able to mint (not in deny list) - admin sets receiver
        await xBTC.connect(admin).setReceiver(user2Address);
        await expect(xBTC.connect(user1).mint(user2Address, ethers.parseUnits("1000", 8)))
          .to.not.be.reverted;
      });

      it("Should work with multiple role transfers", async function () {
        // Transfer minter: minter -> user1
        await xBTC.connect(minter).transferMinter(user1Address);
        
        // Transfer deny lister: admin -> user2  
        await xBTC.connect(admin).transferDenyLister(user2Address);
        
        // Verify final state
        expect(await xBTC.hasRole(MINTER_ROLE, user1Address)).to.be.true;
        expect(await xBTC.hasRole(DENY_LISTER_ROLE, user2Address)).to.be.true;
        expect(await xBTC.hasRole(MINTER_ROLE, minterAddress)).to.be.false;
        expect(await xBTC.hasRole(DENY_LISTER_ROLE, adminAddress)).to.be.false;

        // New deny lister can set receiver and new minter can mint
        await xBTC.connect(user2).setReceiver(blockedAddress);
        await expect(xBTC.connect(user1).mint(blockedAddress, ethers.parseUnits("1000", 8)))
          .to.not.be.reverted;

        // New deny lister can add to deny list
        await expect(xBTC.connect(user2).addToDenyList(user1Address))
          .to.not.be.reverted;
      });
    });
  });
});