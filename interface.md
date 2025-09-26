# xBTC EVM 智能合约接口文档

## 概述

xBTC EVM 是一个升级版的 ERC-20 代币合约，实现了跨链比特币的功能。合约支持铸造、销毁、暂停、拒绝列表管理等高级功能。

**合约信息：**
- 代币名称：xBTC
- 代币符号：xBTC
- 精度：8位小数
- 最大供应量：21,000,000 xBTC
- 合约版本：1.0.0

**核心特性：**
- ✅ ERC-20 标准代币功能
- ✅ ERC-2612 Permit (无gas授权)
- ✅ EIP-712 结构化数据签名验证
- ✅ 自定义错误处理 (gas高效)
- ✅ 批量拒绝列表操作
- ✅ 可升级代理模式
- ✅ 角色权限控制

## 角色权限

- **DEFAULT_ADMIN_ROLE**：默认管理员，可以分配其他角色
- **DENY_LISTER_ROLE**：拒绝列表管理员，可以暂停/取消暂停、管理拒绝列表
- **MINTER_ROLE**：铸造者，可以铸造和销毁代币、设置接收者

---

## 1. 初始化函数

### `initialize(string name, string symbol, address denyLister, address minter, address receiver)`

**功能：** 初始化合约，设置代币基本信息和角色

**参数：**
- `name`：代币名称
- `symbol`：代币符号  
- `denyLister`：拒绝列表管理员地址
- `minter`：铸造者地址
- `receiver`：初始接收者地址

**权限：** 只能调用一次（初始化器）

**示例：**
```solidity
// 初始化 xBTC 合约
xbtc.initialize(
    "Cross-Chain Bitcoin",
    "xBTC", 
    0x1234...5678,  // 拒绝列表管理员地址
    0xabcd...ef01,  // 铸造者地址
    0x9876...5432   // 国库地址作为初始接收者
);
```

---

## 2. 代币铸造函数

### `mint(uint256 amount)`

**功能：** 铸造新的 xBTC 代币到授权接收者地址

**参数：**
- `amount`：铸造数量（以 wei 为单位，8位精度）

**权限：** 仅 MINTER_ROLE

**限制：**
- 合约未暂停
- 不超过最大供应量
- 数量大于0

**示例：**
```solidity
// 铸造 1000 xBTC（1000 * 10^8 wei）
uint256 amount = 1000 * 10**8;
xbtc.mint(amount);
```

---

## 3. 代币销毁函数

### `burn(uint256 amount)`

**功能：** 销毁调用者的 xBTC 代币

**参数：**
- `amount`：销毁数量（以 wei 为单位）

**权限：** 仅 MINTER_ROLE

**限制：**
- 余额足够
- 数量大于0

**示例：**
```solidity
// 销毁 500 xBTC
uint256 amount = 500 * 10**8;
xbtc.burn(amount);
```

---

## 4. 接收者管理函数

### `setReceiver(address newReceiver)`

**功能：** 设置新的授权接收者地址

**参数：**
- `newReceiver`：新的接收者地址

**权限：** 仅 DENY_LISTER_ROLE

**限制：**
- 新接收者不能是零地址

**示例：**
```solidity
// 设置新的接收者地址
address newTreasury = 0xdef0...1234;
xbtc.setReceiver(newTreasury);
```

### `authorizedReceiver()`

**功能：** 获取当前授权接收者地址

**返回值：** `address` - 当前接收者地址

**权限：** 公开可读

**示例：**
```solidity
// 查询当前接收者
address currentReceiver = xbtc.authorizedReceiver();
```

---

## 5. 合约控制函数

### `pause()`

**功能：** 暂停合约，禁止所有转账操作

**权限：** 仅 DENY_LISTER_ROLE

**示例：**
```solidity
// 紧急暂停合约
xbtc.pause();
```

### `unpause()`

**功能：** 取消暂停，恢复正常操作

**权限：** 仅 DENY_LISTER_ROLE

**示例：**
```solidity
// 恢复合约正常运行
xbtc.unpause();
```

---

## 6. 拒绝列表管理函数

### `addToDenyList(address account)`

**功能：** 将指定地址添加到拒绝列表，禁止其进行转账

**参数：**
- `account`：要添加到拒绝列表的地址

**权限：** 仅 DENY_LISTER_ROLE

**限制：**
- 不能添加零地址
- 不能添加管理员
- 不能添加铸造者

**示例：**
```solidity
// 添加可疑地址到拒绝列表
address suspiciousAddr = 0xbad1...2345;
xbtc.addToDenyList(suspiciousAddr);
```

### `removeFromDenyList(address account)`

**功能：** 从拒绝列表中移除地址

**参数：**
- `account`：要从拒绝列表中移除的地址

**权限：** 仅 DENY_LISTER_ROLE

**示例：**
```solidity
// 从拒绝列表中移除地址
xbtc.removeFromDenyList(suspiciousAddr);
```

### `batchAddToDenyList(address[] accounts)`

**功能：** 批量添加地址到拒绝列表

**参数：**
- `accounts`：要添加到拒绝列表的地址数组

**权限：** 仅 DENY_LISTER_ROLE

**示例：**
```solidity
// 批量添加地址到拒绝列表
address[] memory suspiciousAddrs = [0xbad1..., 0xbad2..., 0xbad3...];
xbtc.batchAddToDenyList(suspiciousAddrs);
```

### `batchRemoveFromDenyList(address[] accounts)`

**功能：** 批量从拒绝列表中移除地址

**参数：**
- `accounts`：要从拒绝列表中移除的地址数组

**权限：** 仅 DENY_LISTER_ROLE

**示例：**
```solidity
// 批量从拒绝列表中移除地址
address[] memory addrsToRemove = [0xaddr1..., 0xaddr2...];
xbtc.batchRemoveFromDenyList(addrsToRemove);
```

### `denyList(address account)`

**功能：** 检查地址是否在拒绝列表中

**参数：**
- `account`：要检查的地址

**返回值：** `bool` - true表示在拒绝列表中

**权限：** 公开可读

**示例：**
```solidity
// 检查地址状态
bool inDenyList = xbtc.denyList(someAddress);
if (inDenyList) {
    // 地址在拒绝列表中，无法转账
}
```

---

## 7. 角色转移函数

### `transferMinter(address newMinter)`

**功能：** 将铸造者角色转移给新地址

**参数：**
- `newMinter`：新的铸造者地址

**权限：** 仅 MINTER_ROLE

**限制：**
- 新铸造者不能是零地址
- 新铸造者不能与当前铸造者相同

**示例：**
```solidity
// 转移铸造者角色
address newMinterAddr = 0xdef0...1234;
xbtc.transferMinter(newMinterAddr);
```

### `transferDenyLister(address newDenyLister)`

**功能：** 将拒绝列表管理员角色转移给新地址

**参数：**
- `newDenyLister`：新的拒绝列表管理员地址

**权限：** 仅 DENY_LISTER_ROLE

**限制：**
- 新拒绝列表管理员不能是零地址
- 新拒绝列表管理员不能与当前管理员相同

**示例：**
```solidity
// 转移拒绝列表管理员角色
address newDenyListerAddr = 0xabc0...5678;
xbtc.transferDenyLister(newDenyListerAddr);
```

---

## 8. EIP-712 结构化数据签名函数

### `DOMAIN_SEPARATOR()`

**功能：** 获取EIP-712域分隔符

**返回值：** `bytes32` - 当前合约的域分隔符

**权限：** 公开可读

**示例：**
```solidity
// 获取域分隔符
bytes32 domainSeparator = xbtc.DOMAIN_SEPARATOR();
```

### `eip712Domain()`

**功能：** 获取EIP-712域信息

**返回值：** 
- `fields` (bytes1) - 域字段标识
- `name` (string) - 合约名称
- `version` (string) - 合约版本
- `chainId` (uint256) - 链ID
- `verifyingContract` (address) - 验证合约地址
- `salt` (bytes32) - 盐值
- `extensions` (uint256[]) - 扩展信息

**权限：** 公开可读

**示例：**
```javascript
// 获取完整域信息 (JavaScript)
const domain = await xbtc.eip712Domain();
console.log('合约名称:', domain.name);
console.log('版本:', domain.version);
console.log('链ID:', domain.chainId);
```

### `nonces(address owner)`

**功能：** 查询地址的当前nonce值

**参数：**
- `owner`：要查询的地址

**返回值：** `uint256` - 当前nonce值

**权限：** 公开可读

**示例：**
```solidity
// 查询nonce
uint256 currentNonce = xbtc.nonces(userAddress);
```

---

## 9. ERC-2612 Permit 函数（基于EIP-712）

### `permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)`

**功能：** 使用签名批准授权，无需发送交易

**参数：**
- `owner`：代币持有者地址
- `spender`：被授权者地址
- `value`：授权数量
- `deadline`：授权截止时间戳
- `v, r, s`：EIP-712签名参数

**权限：** 任何人可调用（需要有效签名）

**EIP-712 签名结构：**
```typescript
const domain = {
  name: "xBTC",
  version: "1", 
  chainId: chainId,
  verifyingContract: contractAddress
};

const types = {
  Permit: [
    { name: "owner", type: "address" },
    { name: "spender", type: "address" },
    { name: "value", type: "uint256" },
    { name: "nonce", type: "uint256" },
    { name: "deadline", type: "uint256" }
  ]
};

const message = {
  owner: ownerAddress,
  spender: spenderAddress,
  value: amount,
  nonce: currentNonce,
  deadline: deadline
};
```

**示例：**
```javascript
// JavaScript/TypeScript 示例
const nonce = await xbtc.nonces(owner);
const deadline = Math.floor(Date.now() / 1000) + 3600; // 1小时后过期

// 创建签名
const signature = await signer.signTypedData(domain, types, message);
const { v, r, s } = ethers.Signature.from(signature);

// 调用permit
await xbtc.permit(owner, spender, value, deadline, v, r, s);
```

---

## 10. 自定义错误处理

### 自定义错误类型

xBTC 合约使用现代的自定义错误机制，提供更高效的 gas 使用和更清晰的错误信息：

**主要错误类型：**
- `ZeroAddress()` - 零地址错误
- `ZeroAmount()` - 零金额错误  
- `InsufficientBalance(uint256 requested, uint256 available)` - 余额不足
- `ExceedsMaxSupply(uint256 requested, uint256 maxSupply)` - 超过最大供应量
- `AddressInDenyList(address account)` - 地址在拒绝列表中
- `SenderInDenyList(address sender)` - 发送者在拒绝列表中
- `RecipientInDenyList(address recipient)` - 接收者在拒绝列表中
- `ContractPaused()` - 合约已暂停
- `NoAuthorizedReceiver()` - 未设置授权接收者
- `InvalidArrayLength()` - 数组长度无效
- `SameValue()` - 相同值错误

### 错误处理最佳实践

**前端错误处理示例：**
```javascript
// 现代错误处理示例
try {
  await xbtc.transfer(recipient, amount);
  console.log('转账成功');
} catch (error) {
  // 检查自定义错误
  if (error.reason?.includes('RecipientInDenyList')) {
    console.error('收款地址在拒绝列表中，无法转账');
  } else if (error.reason?.includes('InsufficientBalance')) {
    const match = error.reason.match(/InsufficientBalance\((\d+), (\d+)\)/);
    if (match) {
      const requested = match[1];
      const available = match[2];
      console.error(`余额不足：请求 ${requested}，可用 ${available}`);
    }
  } else if (error.reason?.includes('ContractPaused')) {
    console.error('合约已暂停，请稍后重试');
  } else if (error.reason?.includes('ExceedsMaxSupply')) {
    console.error('铸造数量超过最大供应量限制');
  } else {
    console.error('转账失败:', error.reason);
  }
}
```

**批量操作错误处理：**
```javascript
// 批量添加到拒绝列表
try {
  const addresses = [
    '0xbad1234567890123456789012345678901234567',
    '0xbad2345678901234567890123456789012345678',
    '0xbad3456789012345678901234567890123456789'
  ];
  
  await xbtc.batchAddToDenyList(addresses);
  console.log('批量添加成功');
} catch (error) {
  if (error.reason?.includes('InvalidArrayLength')) {
    console.error('地址数组长度无效');
  } else if (error.reason?.includes('ZeroAddress')) {
    console.error('数组中包含零地址');
  } else {
    console.error('批量操作失败:', error.reason);
  }
}
```

### 自定义错误的优势

**Gas 效率：**
- 自定义错误比传统的 `require` 字符串消耗更少的 gas
- 减少合约大小，降低部署成本
- 提供更精确的错误信息

**开发体验：**
- 类型安全的错误处理
- 更好的错误分类和处理
- 支持参数化错误信息

**示例对比：**
```solidity
// 传统方式 (gas 更高)
require(amount > 0, "Amount must be greater than zero");

// 现代方式 (gas 更低)
if (amount == 0) revert ZeroAmount();

// 带参数的错误
if (balance < amount) revert InsufficientBalance(amount, balance);
```

---

## 11. 标准 ERC-20 函数

### `name()` → `string`
**功能：** 返回代币名称
**示例：** `"Cross-Chain Bitcoin"`

### `symbol()` → `string`
**功能：** 返回代币符号
**示例：** `"xBTC"`

### `decimals()` → `uint8`
**功能：** 返回代币精度
**示例：** `8`

### `totalSupply()` → `uint256`
**功能：** 返回总供应量

### `balanceOf(address account)` → `uint256`
**功能：** 查询账户余额
**示例：**
```solidity
uint256 balance = xbtc.balanceOf(userAddress);
```

### `transfer(address to, uint256 amount)` → `bool`
**功能：** 转账代币
**示例：**
```solidity
// 转账 100 xBTC
bool success = xbtc.transfer(recipient, 100 * 10**8);
```

### `approve(address spender, uint256 amount)` → `bool`
**功能：** 授权额度
**示例：**
```solidity
// 授权合约可花费 500 xBTC
xbtc.approve(contractAddress, 500 * 10**8);
```

### `transferFrom(address from, address to, uint256 amount)` → `bool`
**功能：** 代理转账
**示例：**
```solidity
// 代理转账
xbtc.transferFrom(owner, recipient, 200 * 10**8);
```

---

## 12. 工具函数

### `version()` → `string`
**功能：** 返回合约版本
**示例：** `"1.0.0"`

### `supportsInterface(bytes4 interfaceId)` → `bool`
**功能：** 检查是否支持特定接口

**示例：**
```solidity
// 检查是否支持ERC-165
bool supportsERC165 = xbtc.supportsInterface(0x01ffc9a7);

// 检查是否支持ERC-20
bool supportsERC20 = xbtc.supportsInterface(0x36372b07);

// 检查是否支持AccessControl
bool supportsAccessControl = xbtc.supportsInterface(0x7965db0b);
```

---

## 13. 事件

### 代币操作事件
```solidity
event Mint(address indexed to, uint256 amount);
event Burn(address indexed from, uint256 amount);
```

### 接收者管理事件
```solidity
event ReceiverSet(address indexed previousReceiver, address indexed newReceiver);
```

### 拒绝列表管理事件
```solidity
event AddedToDenyList(address indexed account);
event RemovedFromDenyList(address indexed account);
```

### 角色转移事件
```solidity
event MinterTransferred(address indexed previousMinter, address indexed newMinter);
event DenyListerTransferred(address indexed previousDenyLister, address indexed newDenyLister);
```

### 标准 ERC-20 事件
```solidity
event Transfer(address indexed from, address indexed to, uint256 value);
event Approval(address indexed owner, address indexed spender, uint256 value);
```

---

## 14. 自定义错误详解

常见的自定义错误及其含义：

- `ZeroAddress()` - 提供了零地址参数
- `ZeroAmount()` - 提供了零金额参数
- `InsufficientBalance(uint256 requested, uint256 available)` - 余额不足，显示请求金额和可用金额
- `ExceedsMaxSupply(uint256 requested, uint256 maxSupply)` - 超过最大供应量，显示请求金额和最大供应量
- `AddressInDenyList(address account)` - 地址在拒绝列表中
- `SenderInDenyList(address sender)` - 发送者在拒绝列表中
- `RecipientInDenyList(address recipient)` - 接收者在拒绝列表中
- `ContractPaused()` - 合约已暂停
- `NoAuthorizedReceiver()` - 未设置授权接收者
- `InvalidArrayLength()` - 数组长度无效（空数组或过长）
- `SameValue()` - 设置的值与当前值相同

**优势：**
- Gas 效率更高
- 提供参数化错误信息
- 更好的前端错误处理体验

---

## 15. 使用示例

### 完整的部署和使用流程

```solidity
// 1. 部署并初始化
xbtc.initialize(
    "xBTC",
    "xBTC",
    adminAddress,
    minterAddress,
    treasuryAddress
);

// 2. 铸造初始供应量
xbtc.mint(1000000 * 10**8); // 铸造 100万 xBTC

// 3. 设置新的接收者
xbtc.setReceiver(newTreasuryAddress);

// 4. 正常转账
xbtc.transfer(userAddress, 1000 * 10**8);

// 5. 紧急情况下暂停合约
xbtc.pause();

// 6. 添加可疑地址到拒绝列表
xbtc.addToDenyList(suspiciousAddress);

// 7. 恢复正常运行
xbtc.unpause();

// 8. 转移角色（安全起见）
xbtc.transferMinter(newMinterAddress);  // 转移铸造者角色
xbtc.transferDenyLister(newDenyListerAddress);    // 转移拒绝列表管理员角色
```

### EIP-712 完整示例

```javascript
// 完整的EIP-712签名和调用示例
async function createPermitSignature(signer, spender, value, deadline, contractAddress, chainId) {
  // 1. 获取当前nonce
  const nonce = await xbtc.nonces(await signer.getAddress());
  
  // 2. 构建域信息
  const domain = {
    name: "xBTC",
    version: "1",
    chainId: chainId,
    verifyingContract: contractAddress
  };
  
  // 3. 定义类型
  const types = {
    Permit: [
      { name: "owner", type: "address" },
      { name: "spender", type: "address" },
      { name: "value", type: "uint256" },
      { name: "nonce", type: "uint256" },
      { name: "deadline", type: "uint256" }
    ]
  };
  
  // 4. 构建消息
  const message = {
    owner: await signer.getAddress(),
    spender: spender,
    value: value,
    nonce: nonce,
    deadline: deadline
  };
  
  // 5. 创建签名
  const signature = await signer.signTypedData(domain, types, message);
  return ethers.Signature.from(signature);
}

// 使用permit进行无gas授权
async function usePermit() {
  const spender = "0x1234...";
  const value = ethers.parseUnits("1000", 8);
  const deadline = Math.floor(Date.now() / 1000) + 3600;
  
  const { v, r, s } = await createPermitSignature(
    userSigner, spender, value, deadline, 
    contractAddress, chainId
  );
  
  // 第三方可以代为调用permit（支付gas）
  await xbtc.permit(
    await userSigner.getAddress(),
    spender,
    value,
    deadline,
    v, r, s
  );
  
  console.log("授权成功，无需用户支付gas！");
}
```

### 前端集成示例

```javascript
// React + ethers.js 集成示例
import { ethers } from "ethers";

class XBTCContract {
  constructor(contractAddress, provider) {
    this.contract = new ethers.Contract(contractAddress, xbtcABI, provider);
    this.contractAddress = contractAddress;
  }
  
  // 检查余额
  async getBalance(address) {
    const balance = await this.contract.balanceOf(address);
    return ethers.formatUnits(balance, 8);
  }
  
  // 普通转账
  async transfer(signer, to, amount) {
    const contract = this.contract.connect(signer);
    const amountWei = ethers.parseUnits(amount.toString(), 8);
    return await contract.transfer(to, amountWei);
  }
  
  // 无gas授权 (Permit)
  async permitApprove(signer, spender, amount) {
    const amountWei = ethers.parseUnits(amount.toString(), 8);
    const deadline = Math.floor(Date.now() / 1000) + 3600;
    const nonce = await this.contract.nonces(await signer.getAddress());
    const chainId = (await signer.provider.getNetwork()).chainId;
    
    const domain = {
      name: "xBTC",
      version: "1", 
      chainId: Number(chainId),
      verifyingContract: this.contractAddress
    };
    
    const types = {
      Permit: [
        { name: "owner", type: "address" },
        { name: "spender", type: "address" },
        { name: "value", type: "uint256" },
        { name: "nonce", type: "uint256" },
        { name: "deadline", type: "uint256" }
      ]
    };
    
    const message = {
      owner: await signer.getAddress(),
      spender: spender,
      value: amountWei,
      nonce: nonce,
      deadline: deadline
    };
    
    const signature = await signer.signTypedData(domain, types, message);
    const { v, r, s } = ethers.Signature.from(signature);
    
    return {
      owner: await signer.getAddress(),
      spender, 
      value: amountWei,
      deadline,
      v, r, s
    };
  }
  
  // 检查拒绝列表状态
  async checkDenyListStatus(address) {
    return await this.contract.denyList(address);
  }

  // 查询当前授权接收者
  async getAuthorizedReceiver() {
    return await this.contract.authorizedReceiver();
  }
}

// 使用示例
const xbtc = new XBTCContract(contractAddress, provider);

// 查询余额
const balance = await xbtc.getBalance(userAddress);
console.log(`余额: ${balance} xBTC`);

// 无gas授权
const permitData = await xbtc.permitApprove(userSigner, spenderAddress, 1000);
console.log("授权数据:", permitData);

// 检查拒绝列表状态
const isDenied = await xbtc.checkDenyListStatus(userAddress);
console.log(`地址是否在拒绝列表: ${isDenied}`);

// 查询授权接收者
const receiver = await xbtc.getAuthorizedReceiver();
console.log(`当前授权接收者: ${receiver}`);
```

## 16. 总结

这份文档涵盖了 xBTC EVM 合约的所有主要功能，包括：

### 🔧 核心功能
- ✅ ERC-20 标准代币功能
- ✅ 升级代理模式
- ✅ 角色权限控制
- ✅ 铸造和销毁管理

### 🛡️ 安全特性  
- ✅ 合约暂停/恢复
- ✅ 拒绝列表管理机制（包括管理员和铸造者）
- ✅ 批量拒绝列表操作
- ✅ 多重权限验证
- ✅ 安全的角色转移机制

### 🚀 高级功能
- ✅ **EIP-712 结构化签名**
- ✅ **ERC-2612 Permit** (无gas授权)
- ✅ **自定义错误处理** (gas高效)
- ✅ **现代化错误管理**
- ✅ **批量拒绝列表操作**
- ✅ **角色转移机制**

### 🌐 跨链特性
- ✅ 统一的合约接口
- ✅ 一致的代币精度 (8位)
- ✅ 相同的最大供应量限制
- ✅ 兼容多链部署
- ✅ 透明代理升级模式

合约具有完整的权限控制、安全机制和现代化的错误处理功能，特别适用于跨链比特币应用场景。通过EIP-712支持和自定义错误机制，用户可以享受无gas授权和高效错误处理的便利。拒绝列表管理和角色转移功能确保了合约的安全性和可管理性。
