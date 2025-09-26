# xBTC 函数快速参考表

## 核心函数一览

| 函数名 | 权限 | 功能 | 关键参数 |
|--------|------|------|----------|
| `initialize(...)` | 初始化器 | 合约初始化 | name, symbol, admin, minter, receiver |
| `mint(amount)` | MINTER_ROLE | 铸造代币 | amount (uint256) |
| `burn(amount)` | MINTER_ROLE | 销毁代币 | amount (uint256) |
| `setReceiver(newReceiver)` | DENY_LISTER_ROLE | 设置接收者 | newReceiver (address) |
| `authorizedReceiver()` | 公开 | 查询接收者 | 无 |
| `pause()` | DENY_LISTER_ROLE | 暂停合约 | 无 |
| `unpause()` | DENY_LISTER_ROLE | 取消暂停 | 无 |
| `addToDenyList(account)` | DENY_LISTER_ROLE | 添加到拒绝列表 | account (address) |
| `removeFromDenyList(account)` | DENY_LISTER_ROLE | 从拒绝列表移除 | account (address) |
| `batchAddToDenyList(accounts)` | DENY_LISTER_ROLE | 批量添加到拒绝列表 | accounts (address[]) |
| `batchRemoveFromDenyList(accounts)` | DENY_LISTER_ROLE | 批量从拒绝列表移除 | accounts (address[]) |
| `denyList(account)` | 公开 | 检查拒绝列表状态 | account (address) |
| `transferMinter(newMinter)` | MINTER_ROLE | 转移铸造者角色 | newMinter (address) |
| `transferDenyLister(newDenyLister)` | DENY_LISTER_ROLE | 转移拒绝列表管理员角色 | newDenyLister (address) |

## ERC-20 标准函数

| 函数名 | 权限 | 功能 | 参数 |
|--------|------|------|------|
| `transfer(to, amount)` | 代币持有者 | 转账 | to (address), amount (uint256) |
| `approve(spender, amount)` | 代币持有者 | 授权额度 | spender (address), amount (uint256) |
| `transferFrom(from, to, amount)` | 被授权者 | 代理转账 | from, to (address), amount (uint256) |
| `balanceOf(account)` | 公开 | 查询余额 | account (address) |
| `totalSupply()` | 公开 | 查询总供应量 | 无 |

## EIP-712 结构化签名函数

| 函数名 | 权限 | 功能 | 返回值 |
|--------|------|------|--------|
| `DOMAIN_SEPARATOR()` | 公开 | 获取域分隔符 | bytes32 |
| `eip712Domain()` | 公开 | 获取EIP-712域信息 | 完整域数据 |
| `nonces(address)` | 公开 | 查询地址nonce | uint256 |

## ERC-2612 Permit函数 (基于EIP-712)

| 函数名 | 权限 | 功能 | 关键特性 |
|--------|------|------|----------|
| `permit(...)` | 任何人 | 无gas授权 | 需要持有者签名 |

## 拒绝列表管理函数

| 函数名 | 权限 | 功能 | 关键特性 |
|--------|------|------|----------|
| `addToDenyList(account)` | DENY_LISTER_ROLE | 添加单个地址到拒绝列表 | 限制地址转账功能 |
| `removeFromDenyList(account)` | DENY_LISTER_ROLE | 从拒绝列表移除单个地址 | 恢复地址转账功能 |
| `batchAddToDenyList(accounts)` | DENY_LISTER_ROLE | 批量添加地址到拒绝列表 | 高效批量操作 |
| `batchRemoveFromDenyList(accounts)` | DENY_LISTER_ROLE | 批量从拒绝列表移除地址 | 高效批量操作 |

## 常用代码片段

### 1. 基本操作
```solidity
// 查询余额
uint256 balance = xbtc.balanceOf(userAddress);

// 转账 1000 xBTC
xbtc.transfer(recipient, 1000 * 10**8);

// 检查是否在拒绝列表中
bool inDenyList = xbtc.denyList(someAddress);

// 查询nonce (用于EIP-712签名)
uint256 nonce = xbtc.nonces(userAddress);

// 获取域分隔符
bytes32 domainSeparator = xbtc.DOMAIN_SEPARATOR();
```

### 2. 管理员操作
```solidity
// 紧急暂停
xbtc.pause();

// 添加可疑地址到拒绝列表
xbtc.addToDenyList(0xbadaddress);

// 批量添加地址到拒绝列表
address[] memory suspiciousAddresses = [0xbad1, 0xbad2, 0xbad3];
xbtc.batchAddToDenyList(suspiciousAddresses);

// 转移管理员角色到新地址
xbtc.transferDenyLister(0xnewdenylister);
```

### 3. 铸造者操作
```solidity
// 设置新接收者 (只有DENY_LISTER_ROLE可以设置)
xbtc.setReceiver(0xnewtreasury);

// 铸造 1 万 xBTC (铸造到当前设置的接收者)
xbtc.mint(10000 * 10**8);

// 销毁 5000 xBTC (只能销毁自己的代币)
xbtc.burn(5000 * 10**8);

// 转移铸造者角色到新地址
xbtc.transferMinter(0xnewminter);
```

### 4. EIP-712 签名操作
```javascript
// ERC-2612 Permit 签名
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

// 创建签名
const signature = await signer.signTypedData(domain, types, message);
const { v, r, s } = ethers.Signature.from(signature);

// 调用permit
await xbtc.permit(owner, spender, value, deadline, v, r, s);
```

### 5. 自定义错误处理
```javascript
// 现代错误处理示例
try {
  await xbtc.transfer(recipient, amount);
} catch (error) {
  if (error.reason?.includes('AddressInDenyList')) {
    console.error('收款地址在拒绝列表中');
  } else if (error.reason?.includes('InsufficientBalance')) {
    console.error('余额不足');
  } else if (error.reason?.includes('ContractPaused')) {
    console.error('合约已暂停');
  }
}

// 批量操作示例
const addresses = [0xaddr1, 0xaddr2, 0xaddr3];
try {
  await xbtc.batchAddToDenyList(addresses);
  console.log('批量添加到拒绝列表成功');
} catch (error) {
  console.error('批量操作失败:', error.reason);
}
```

## 重要常量

| 常量 | 值 | 说明 |
|------|----|----- |
| `MAX_SUPPLY` | 21,000,000 * 10^8 | 最大供应量 |
| `decimals()` | 8 | 代币精度 |
| `MINTER_ROLE` | keccak256("MINTER_ROLE") | 铸造者角色 |
| `DENY_LISTER_ROLE` | keccak256("DENY_LISTER_ROLE") | 拒绝列表管理员角色 |

### 合约常量

| 常量 | 说明 |
|------|------|
| `DEFAULT_ADMIN_ROLE` | 默认管理员角色，可以分配其他角色 |
| `version()` | 合约版本标识符，返回 "1.0.0" |

## 主要事件

```solidity
// 代币操作
event Mint(address indexed to, uint256 amount);
event Burn(address indexed from, uint256 amount);

// 管理操作
event ReceiverSet(address indexed previousReceiver, address indexed newReceiver);
event AddedToDenyList(address indexed account);
event RemovedFromDenyList(address indexed account);
event MinterTransferred(address indexed previousMinter, address indexed newMinter);
event DenyListerTransferred(address indexed previousDenyLister, address indexed newDenyLister);

// ERC-20 标准
event Transfer(address indexed from, address indexed to, uint256 value);
event Approval(address indexed owner, address indexed spender, uint256 value);
```

## 自定义错误类型

```solidity
// 主要自定义错误
error ZeroAddress();
error ZeroAmount();
error InsufficientBalance(uint256 requested, uint256 available);
error ExceedsMaxSupply(uint256 requested, uint256 maxSupply);
error AddressInDenyList(address account);
error SenderInDenyList(address sender);
error RecipientInDenyList(address recipient);
error ContractPaused();
error NoAuthorizedReceiver();
error InvalidArrayLength();
error SameValue();

// 错误检查示例
try {
    xbtc.transfer(recipient, amount);
} catch (error) {
    // 现代错误处理，gas效率更高
}
```

## 权限检查

```solidity
// 检查是否有铸造权限
bool canMint = xbtc.hasRole(xbtc.MINTER_ROLE(), msg.sender);

// 检查是否有管理权限
bool canAdmin = xbtc.hasRole(xbtc.DENY_LISTER_ROLE(), msg.sender);
```

## EIP-712 功能特性

### 🔑 **支持的签名类型**
- ✅ **ERC-2612 Permit**: 无gas授权 (继承自OpenZeppelin)
- ✅ **EIP-712 结构化签名**: 标准化签名验证 (继承自OpenZeppelin)
- ✅ **自定义错误**: 高效错误处理
- ✅ **批量操作**: 高效拒绝列表管理

### ⚡ **核心优势**
- 🚀 **无gas授权**: 用户签名，第三方支付gas费用
- 🔒 **安全可靠**: EIP-712标准化签名验证
- ⚡ **高效错误处理**: 自定义错误减少gas消耗
- 🛡️ **防重放**: nonce机制保护安全

### 📱 **应用场景**
- 💳 **钱包集成**: 一键授权，无需预先approve
- 🏦 **合规管理**: 灵活的拒绝列表控制
- ⚡ **批量操作**: 高效的地址管理
- 🎮 **DApp应用**: 现代化的错误处理
