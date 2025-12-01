import { expect } from "chai";
import hre from "hardhat";
const { ethers } = hre;

describe("xBTC Comprehensive Tests", function () {
  let implementation: any;
  let proxy: any;
  let xBTC: any;
  let signers: any[];
  let admin: string;
  let minter: string;
  let user1: string;
  let user2: string;

  const TOKEN_NAME = "xBTC";
  const TOKEN_SYMBOL = "xBTC";
  const MAX_SUPPLY = 21_000_000n * 10n ** 8n; // 21 million xBTC

  beforeEach(async function () {
    signers = await ethers.getSigners();
    admin = await signers[0].getAddress();
    minter = await signers[1].getAddress();
    user1 = await signers[2].getAddress();
    user2 = await signers[3].getAddress();

    // Deploy implementation
    implementation = await ethers.deployContract("Token");
    await implementation.waitForDeployment();

    // Prepare initialization data
    const initData = implementation.interface.encodeFunctionData(
      "initialize", 
      [TOKEN_NAME, TOKEN_SYMBOL, admin, minter, user1, MAX_SUPPLY]
    );

    // Deploy proxy
    proxy = await ethers.deployContract("contracts/Proxy.sol:Proxy", [
      await implementation.getAddress(),
      admin,
      initData
    ]);
    await proxy.waitForDeployment();

    // Connect to proxy
    xBTC = implementation.attach(await proxy.getAddress());
  });

  describe("Initialization Edge Cases", function () {
    it("Should not allow re-initialization", async function () {
      await expect(
        xBTC.initialize(TOKEN_NAME, TOKEN_SYMBOL, admin, minter, user1, MAX_SUPPLY)
      ).to.be.revertedWithCustomError(xBTC, "InvalidInitialization");
    });

    it("Should have correct max supply", async function () {
      expect(await xBTC.MAX_SUPPLY()).to.equal(MAX_SUPPLY);
    });
  });

  describe("Minting Edge Cases", function () {
    it("Should not allow setting receiver to zero address", async function () {
      await expect(
        xBTC.connect(signers[0]).setReceiver(ethers.ZeroAddress)
      ).to.be.revertedWithCustomError(xBTC, "ZeroAddress");
    });

    it("Should not allow minting zero amount", async function () {
      await expect(
        xBTC.connect(signers[1]).mint(user1, 0)
      ).to.be.revertedWithCustomError(xBTC, "ZeroAmount");
    });

    it("Should not allow exceeding max supply", async function () {
      const exceedAmount = MAX_SUPPLY + 1n;
      await expect(
        xBTC.connect(signers[1]).mint(user1, exceedAmount)
      ).to.be.revertedWithCustomError(xBTC, "ExceedsMaxSupply");
    });

    it("Should allow minting exactly max supply", async function () {
      await expect(xBTC.connect(signers[1]).mint(user1, MAX_SUPPLY))
        .to.emit(xBTC, "Mint")
        .withArgs(user1, MAX_SUPPLY);

      expect(await xBTC.totalSupply()).to.equal(MAX_SUPPLY);
    });

    it("Should not allow non-minter to mint", async function () {
      await expect(
        xBTC.connect(signers[2]).mint(user1, ethers.parseUnits("100", 8))
      ).to.be.revertedWithCustomError(xBTC, "AccessControlUnauthorizedAccount");
    });
  });

  describe("Burning Edge Cases", function () {
    beforeEach(async function () {
      // Mint some tokens first
      await xBTC.connect(signers[1]).mint(user1, ethers.parseUnits("1000", 8));
    });

    // Note: Cannot test burning from zero address since msg.sender cannot be zero address

    it("Should not allow burning zero amount", async function () {
      await expect(
        xBTC.connect(signers[1]).burn(0)
      ).to.be.revertedWithCustomError(xBTC, "ZeroAmount");
    });

    it("Should not allow burning more than balance", async function () {
      const balance = await xBTC.balanceOf(minter);
      await expect(
        xBTC.connect(signers[1]).burn(balance + 1n)
      ).to.be.revertedWithCustomError(xBTC, "InsufficientBalance");
    });

    it("Should allow minter to burn their own tokens", async function () {
      const burnAmount = ethers.parseUnits("100", 8);
      
      // First mint tokens to the minter
      await xBTC.connect(signers[0]).setReceiver(minter);
      await xBTC.connect(signers[1]).mint(minter, burnAmount);
      const initialBalance = await xBTC.balanceOf(minter);
      
      await expect(xBTC.connect(signers[1]).burn(burnAmount))
        .to.emit(xBTC, "Transfer")
        .withArgs(minter, ethers.ZeroAddress, burnAmount)
        .and.to.emit(xBTC, "Burn")
        .withArgs(minter, burnAmount);
        
      expect(await xBTC.balanceOf(minter)).to.equal(initialBalance - burnAmount);
    });
  });

  describe("Address Blocking Edge Cases", function () {
    it("Should not allow adding zero address to deny list", async function () {
      await expect(
        xBTC.connect(signers[0]).addToDenyList(ethers.ZeroAddress)
      ).to.be.revertedWithCustomError(xBTC, "ZeroAddress");
    });

    it("Should allow adding admin to deny list", async function () {
      await expect(
        xBTC.connect(signers[0]).addToDenyList(admin)
      ).to.emit(xBTC, "AddedToDenyList").withArgs(admin);
      
      expect(await xBTC.denyList(admin)).to.be.true;
    });

    it("Should allow adding minter to deny list", async function () {
      await expect(
        xBTC.connect(signers[0]).addToDenyList(minter)
      ).to.emit(xBTC, "AddedToDenyList").withArgs(minter);
      
      expect(await xBTC.denyList(minter)).to.be.true;
    });

    it("Should not allow non-admin to add to deny list", async function () {
      await expect(
        xBTC.connect(signers[1]).addToDenyList(user1)
      ).to.be.revertedWithCustomError(xBTC, "AccessControlUnauthorizedAccount");
    });

    it("Should not allow minting to address in deny list", async function () {
      await xBTC.connect(signers[0]).addToDenyList(user1);
      await expect(
        xBTC.connect(signers[1]).mint(user1, ethers.parseUnits("100", 8))
      ).to.be.revertedWithCustomError(xBTC, "RecipientInDenyList");
    });


  });

  describe("Role Management", function () {
    const DENY_LISTER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("DENY_LISTER_ROLE"));
    const MINTER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("MINTER_ROLE"));
    const DEFAULT_ADMIN_ROLE = ethers.ZeroHash;

    it("Should allow admin to grant roles", async function () {
      await expect(xBTC.connect(signers[0]).grantRole(MINTER_ROLE, user1))
        .to.emit(xBTC, "RoleGranted")
        .withArgs(MINTER_ROLE, user1, admin);
      
      expect(await xBTC.hasRole(MINTER_ROLE, user1)).to.be.true;
    });

    it("Should allow admin to revoke roles", async function () {
      await expect(xBTC.connect(signers[0]).revokeRole(MINTER_ROLE, minter))
        .to.emit(xBTC, "RoleRevoked")
        .withArgs(MINTER_ROLE, minter, admin);
      
      expect(await xBTC.hasRole(MINTER_ROLE, minter)).to.be.false;
    });

    it("Should not allow non-admin to grant roles", async function () {
      await expect(
        xBTC.connect(signers[1]).grantRole(MINTER_ROLE, user1)
      ).to.be.revertedWithCustomError(xBTC, "AccessControlUnauthorizedAccount");
    });
  });

  // EIP-3009 functions have been removed from the contract
  /*
  describe("EIP-3009 Transfer Authorization", function () {
    let domain: any;

    beforeEach(async function () {
      // Mint tokens
      await xBTC.connect(signers[1]).mint(user1, ethers.parseUnits("1000", 8));

      // Set up EIP-712 domain
      const chainId = (await ethers.provider.getNetwork()).chainId;
      domain = {
        name: TOKEN_NAME,
        version: "1",
        chainId: Number(chainId),
        verifyingContract: await xBTC.getAddress(),
      };
    });

    it("Should reject expired authorization", async function () {
      const transferAmount = ethers.parseUnits("100", 8);
      const nonce = ethers.randomBytes(32);
      const validAfter = 0;
      const validBefore = Math.floor(Date.now() / 1000) - 3600; // Expired

      const types = {
        TransferWithAuthorization: [
          { name: "from", type: "address" },
          { name: "to", type: "address" },
          { name: "value", type: "uint256" },
          { name: "validAfter", type: "uint256" },
          { name: "validBefore", type: "uint256" },
          { name: "nonce", type: "bytes32" },
        ],
      };

      const message = {
        from: user1,
        to: user2,
        value: transferAmount,
        validAfter,
        validBefore,
        nonce: ethers.hexlify(nonce),
      };

      const signature = await signers[2].signTypedData(domain, { TransferWithAuthorization: types.TransferWithAuthorization }, message);
      const { v, r, s } = ethers.Signature.from(signature);

      await expect(
        xBTC.transferWithAuthorization(user1, user2, transferAmount, validAfter, validBefore, ethers.hexlify(nonce), v, r, s)
      ).to.be.revertedWith("xBTC: authorization expired");
    });

    it("Should reject not yet valid authorization", async function () {
      const transferAmount = ethers.parseUnits("100", 8);
      const nonce = ethers.randomBytes(32);
      const validAfter = Math.floor(Date.now() / 1000) + 3600; // Future
      const validBefore = Math.floor(Date.now() / 1000) + 7200;

      const types = {
        TransferWithAuthorization: [
          { name: "from", type: "address" },
          { name: "to", type: "address" },
          { name: "value", type: "uint256" },
          { name: "validAfter", type: "uint256" },
          { name: "validBefore", type: "uint256" },
          { name: "nonce", type: "bytes32" },
        ],
      };

      const message = {
        from: user1,
        to: user2,
        value: transferAmount,
        validAfter,
        validBefore,
        nonce: ethers.hexlify(nonce),
      };

      const signature = await signers[2].signTypedData(domain, { TransferWithAuthorization: types.TransferWithAuthorization }, message);
      const { v, r, s } = ethers.Signature.from(signature);

      await expect(
        xBTC.transferWithAuthorization(user1, user2, transferAmount, validAfter, validBefore, ethers.hexlify(nonce), v, r, s)
      ).to.be.revertedWith("xBTC: authorization not yet valid");
    });

    it("Should reject invalid signature", async function () {
      const transferAmount = ethers.parseUnits("100", 8);
      const nonce = ethers.randomBytes(32);
      const validAfter = 0;
      const validBefore = Math.floor(Date.now() / 1000) + 3600;

      const types = {
        TransferWithAuthorization: [
          { name: "from", type: "address" },
          { name: "to", type: "address" },
          { name: "value", type: "uint256" },
          { name: "validAfter", type: "uint256" },
          { name: "validBefore", type: "uint256" },
          { name: "nonce", type: "bytes32" },
        ],
      };

      const message = {
        from: user1,
        to: user2,
        value: transferAmount,
        validAfter,
        validBefore,
        nonce: ethers.hexlify(nonce),
      };

      // Sign with wrong signer (signers[3] instead of signers[2])
      const signature = await signers[3].signTypedData(domain, { TransferWithAuthorization: types.TransferWithAuthorization }, message);
      const { v, r, s } = ethers.Signature.from(signature);

      await expect(
        xBTC.transferWithAuthorization(user1, user2, transferAmount, validAfter, validBefore, ethers.hexlify(nonce), v, r, s)
      ).to.be.revertedWith("xBTC: invalid signature");
    });

    it("Should reject already used authorization", async function () {
      const transferAmount = ethers.parseUnits("100", 8);
      const nonce = ethers.randomBytes(32);
      const validAfter = 0;
      const validBefore = Math.floor(Date.now() / 1000) + 3600;

      const types = {
        TransferWithAuthorization: [
          { name: "from", type: "address" },
          { name: "to", type: "address" },
          { name: "value", type: "uint256" },
          { name: "validAfter", type: "uint256" },
          { name: "validBefore", type: "uint256" },
          { name: "nonce", type: "bytes32" },
        ],
      };

      const message = {
        from: user1,
        to: user2,
        value: transferAmount,
        validAfter,
        validBefore,
        nonce: ethers.hexlify(nonce),
      };

      const signature = await signers[2].signTypedData(domain, { TransferWithAuthorization: types.TransferWithAuthorization }, message);
      const { v, r, s } = ethers.Signature.from(signature);

      // Use authorization first time
      await xBTC.transferWithAuthorization(user1, user2, transferAmount, validAfter, validBefore, ethers.hexlify(nonce), v, r, s);

      // Try to use again
      await expect(
        xBTC.transferWithAuthorization(user1, user2, transferAmount, validAfter, validBefore, ethers.hexlify(nonce), v, r, s)
      ).to.be.revertedWith("xBTC: authorization already used");
    });

    it("Should check authorization state", async function () {
      const nonce = ethers.randomBytes(32);
      expect(await xBTC.authorizationState(user1, ethers.hexlify(nonce))).to.be.false;
    });

    it("Should not allow receiveWithAuthorization if caller is not payee", async function () {
      const transferAmount = ethers.parseUnits("100", 8);
      const nonce = ethers.randomBytes(32);
      const validAfter = 0;
      const validBefore = Math.floor(Date.now() / 1000) + 3600;

      const types = {
        ReceiveWithAuthorization: [
          { name: "from", type: "address" },
          { name: "to", type: "address" },
          { name: "value", type: "uint256" },
          { name: "validAfter", type: "uint256" },
          { name: "validBefore", type: "uint256" },
          { name: "nonce", type: "bytes32" },
        ],
      };

      const message = {
        from: user1,
        to: user2,
        value: transferAmount,
        validAfter,
        validBefore,
        nonce: ethers.hexlify(nonce),
      };

      const signature = await signers[2].signTypedData(domain, { ReceiveWithAuthorization: types.ReceiveWithAuthorization }, message);
      const { v, r, s } = ethers.Signature.from(signature);

      // Try with wrong caller (admin instead of user2)
      await expect(
        xBTC.connect(signers[0]).receiveWithAuthorization(user1, user2, transferAmount, validAfter, validBefore, ethers.hexlify(nonce), v, r, s)
      ).to.be.revertedWith("xBTC: caller must be the payee");
    });

    it("Should cancel authorization", async function () {
      const nonce = ethers.randomBytes(32);

      const types = {
        CancelAuthorization: [
          { name: "authorizer", type: "address" },
          { name: "nonce", type: "bytes32" },
        ],
      };

      const message = {
        authorizer: user1,
        nonce: ethers.hexlify(nonce),
      };

      const signature = await signers[2].signTypedData(domain, types, message);
      const { v, r, s } = ethers.Signature.from(signature);

      await expect(
        xBTC.cancelAuthorization(user1, ethers.hexlify(nonce), v, r, s)
      ).to.emit(xBTC, "AuthorizationCanceled")
        .withArgs(user1, ethers.hexlify(nonce));

      expect(await xBTC.authorizationState(user1, ethers.hexlify(nonce))).to.be.true;
    });

    it("Should not allow canceling already used authorization", async function () {
      const nonce = ethers.randomBytes(32);

      const types = {
        CancelAuthorization: [
          { name: "authorizer", type: "address" },
          { name: "nonce", type: "bytes32" },
        ],
      };

      const message = {
        authorizer: user1,
        nonce: ethers.hexlify(nonce),
      };

      const signature = await signers[2].signTypedData(domain, types, message);
      const { v, r, s } = ethers.Signature.from(signature);

      // Cancel first time
      await xBTC.cancelAuthorization(user1, ethers.hexlify(nonce), v, r, s);

      // Try to cancel again
      await expect(
        xBTC.cancelAuthorization(user1, ethers.hexlify(nonce), v, r, s)
      ).to.be.revertedWith("xBTC: authorization already used");
    });
  });
  */

  describe("ERC20 Standard Functions", function () {
    beforeEach(async function () {
      await xBTC.connect(signers[1]).mint(user1, ethers.parseUnits("1000", 8));
    });

    it("Should handle approve and transferFrom", async function () {
      const amount = ethers.parseUnits("100", 8);
      
      // Approve
      await expect(xBTC.connect(signers[2]).approve(user2, amount))
        .to.emit(xBTC, "Approval")
        .withArgs(user1, user2, amount);

      expect(await xBTC.allowance(user1, user2)).to.equal(amount);

      // TransferFrom
      await expect(xBTC.connect(signers[3]).transferFrom(user1, user2, amount))
        .to.emit(xBTC, "Transfer")
        .withArgs(user1, user2, amount);
    });

    it("Should support permit functionality", async function () {
      const spender = user2;
      const value = ethers.parseUnits("100", 8);
      const nonce = await xBTC.nonces(user1);
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
        owner: user1,
        spender,
        value,
        nonce,
        deadline,
      };

      const signature = await signers[2].signTypedData(domain, types, message);
      const { v, r, s } = ethers.Signature.from(signature);

      await expect(
        xBTC.permit(user1, spender, value, deadline, v, r, s)
      ).to.emit(xBTC, "Approval")
        .withArgs(user1, spender, value);

      expect(await xBTC.allowance(user1, spender)).to.equal(value);
    });
  });

  describe("Interface Support", function () {
    it("Should support Access Control interface", async function () {
      expect(await xBTC.supportsInterface("0x7965db0b")).to.be.true; // AccessControl
    });
  });

  describe("Version Information", function () {
    it("Should return correct version", async function () {
      expect(await xBTC.version()).to.equal("1.0.0");
    });
  });
});