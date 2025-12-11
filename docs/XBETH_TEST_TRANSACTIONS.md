# xBETH 测试交易记录

**测试网络**: Chain 1952  
**测试时间**: 2025年12月11日  
**部署者地址**: 0xEf2Dd344AE3d5032b779C5B8914c10689707883F  
**测试账户地址**: 0xd19600392a0cEBB023e5a04DE12D7491aDb45E6b  

---

## 📋 测试概览

✅ **11个测试组全部通过**  
🔗 **共30笔交易上链**

---

## 🧪 测试交易详情

### 1. 📦 合约部署

#### 1.1 部署实现合约 (Implementation)

**交易哈希**: `0xf3f5762284795c603362cd2602b7809864036b671e6a4fd0252e137f0034a178`  
**合约地址**: `0x1317418402a924B3484ed3016735b77719E8fC1B`

**接口函数**: `constructor()`

**结果**: ✅ 成功部署 xBETH 实现合约

---

#### 1.2 部署代理合约 (Proxy)

**交易哈希**: `0xd79e83451ff229d6e34df027002596c86c09304800b471aef63979dad1257845`  
**合约地址**: `0x15c05f62958C0De1A594B90abCB1d996fCBBbaA4`

**接口函数**: `constructor(address implementation, address admin, bytes memory data)`

**参数**:
- `implementation`: 0x1317418402a924B3484ed3016735b77719E8fC1B
- `admin`: 0xEf2Dd344AE3d5032b779C5B8914c10689707883F
- `data`: 初始化数据（包含代币名称、符号、角色分配等）

**初始化参数**:
- 代币名称: "OKX Staked ETH"
- 代币符号: "xBETH"
- 小数位数: 18
- 最大供应量: 1,000,000,000 xBETH
- Admin角色: 0xEf2Dd344AE3d5032b779C5B8914c10689707883F
- DenyLister角色: 0xEf2Dd344AE3d5032b779C5B8914c10689707883F
- Minter角色: 0xEf2Dd344AE3d5032b779C5B8914c10689707883F
- 授权接收者: 0xEf2Dd344AE3d5032b779C5B8914c10689707883F

**结果**: ✅ 成功部署代理合约并完成初始化

---

#### 1.3 设置临时 Oracle (Admin)

**交易哈希**: `0xed2dfd6f2bf0c8221de2d7507da1e3a7d10af90335886c6d75ccedf2402d79b8`

**接口函数**: `setOracle(address newOracle)`

**参数**:
- `newOracle`: 0xEf2Dd344AE3d5032b779C5B8914c10689707883F (Admin)

**结果**: ✅ 临时设置 Admin 为 Oracle

---

#### 1.4 设置初始汇率

**交易哈希**: `0xa9c1f4dd3cf1f7209ae4aa6c64fbc70c9b003c73a290e80309987080e0767e9f`

**接口函数**: `updateExchangeRate(uint256 newRate)`

**参数**:
- `newRate`: 1000000000000000000 (1e18, 即 1:1)

**结果**: ✅ 成功设置初始汇率为 1:1

---

#### 1.5 部署 ExchangeRateUpdater 合约

**交易哈希**: `0xdbbfb33f47f5665316e4b993f3d82cef67d63ee8989e7f7f047475a7ec97ee5a`  
**合约地址**: `0xb18366B902ad10720648281A11F7eFA1AdE92E9e`

**接口函数**: `constructor(address owner)`

**参数**:
- `owner`: 0xEf2Dd344AE3d5032b779C5B8914c10689707883F

**结果**: ✅ 成功部署 ExchangeRateUpdater 合约

---

#### 1.6 初始化 ExchangeRateUpdater

**交易哈希**: `0xb68664584e134810dc0581fc478b35928d8517f53ebcea386e9ae1c2e6760782`

**接口函数**: `initialize(address owner, address tokenContract)`

**参数**:
- `owner`: 0xEf2Dd344AE3d5032b779C5B8914c10689707883F
- `tokenContract`: 0x15c05f62958C0De1A594B90abCB1d996fCBBbaA4

**结果**: ✅ 成功初始化 ExchangeRateUpdater

---

#### 1.7 配置汇率更新调用者

**交易哈希**: `0xa1680de01a02005348ddfd067a8742ee0f34413b48902b5682f3ff3477f0ce06`

**接口函数**: `configureCaller(address caller, uint256 allowance, uint256 interval)`

**参数**:
- `caller`: 0xd19600392a0cEBB023e5a04DE12D7491aDb45E6b (测试账户)
- `allowance`: 10000000000000000 (1%, 1e16)
- `interval`: 86400 (1天)

**结果**: ✅ 成功配置测试账户为汇率更新调用者

---

#### 1.8 设置 ExchangeRateUpdater 为 Oracle

**交易哈希**: `0x6456012df2d842afcb33e32f5a4c243fa446175853a15ffd24f377739083ee98`

**接口函数**: `setOracle(address newOracle)`

**参数**:
- `newOracle`: 0xb18366B902ad10720648281A11F7eFA1AdE92E9e (ExchangeRateUpdater)

**结果**: ✅ 成功设置 ExchangeRateUpdater 为 Oracle

---

### 2. 📈 汇率更新功能测试

**交易哈希**: `0xe906c8aeb555706d1868accdd62dfbddb8c3a8c1f1b60e8970fcd60e62cdd62b`

**接口函数**: `updateExchangeRate(uint256 newRate)`

**参数**:
- `newRate`: 1005000000000000000 (1.005 * 1e18, 即 0.5% 增长)

**结果**: ✅ 成功更新汇率从 1.0 到 1.005

---

### 3. 🔧 调用者管理测试

#### 3.1 添加新调用者

**交易哈希**: `0x0b3b2d367a41d3d70620522ca00c7d30df2cc3541bc2a64fb15a10f8e92e318e`

**接口函数**: `configureCaller(address caller, uint256 allowance, uint256 interval)`

**参数**:
- `caller`: 0x0000000000000000000000000000000000009999
- `allowance`: 10000000000000000 (1%, 1e16)
- `interval`: 86400 (1天)

**结果**: ✅ 成功添加测试调用者

---

#### 3.2 移除调用者

**交易哈希**: `0xdc623f84765ae97f234c6301285cda6e6411c2c970141e45c61a6aa9f96d7ab3`

**接口函数**: `removeCaller(address caller)`

**参数**:
- `caller`: 0x0000000000000000000000000000000000009999

**结果**: ✅ 成功移除测试调用者

---

### 4. 🪙 铸造功能测试

#### 4.1 设置接收地址为测试账户

**交易哈希**: `0x8941d0af063cbaf4f74ed26aadc9f34ccfd0a9df3a59081371a1e3ae825b32b7`

**接口函数**: `setReceiver(address newReceiver)`

**参数**:
- `newReceiver`: 0xd19600392a0cEBB023e5a04DE12D7491aDb45E6b (测试账户)

**结果**: ✅ 成功设置接收地址

---

#### 4.2 铸造代币

**交易哈希**: `0x62c8f2c323341bf62f1ff767dc1b9ffaac1290d5ada788af50087459abb8415a`

**接口函数**: `mint(address receiver, uint256 amount)`

**参数**:
- `receiver`: 0xd19600392a0cEBB023e5a04DE12D7491aDb45E6b (测试账户)
- `amount`: 1000000000000000000000 (1,000 xBETH, 18位小数)

**结果**: ✅ 成功铸造 1,000 xBETH 到测试账户

---

#### 4.3 恢复接收地址为Admin

**交易哈希**: `0x3d8398e5cb3c4a2f61d81737b8a2cf68f528df10903d76fbe67c0efaddac02a8`

**接口函数**: `setReceiver(address newReceiver)`

**参数**:
- `newReceiver`: 0xEf2Dd344AE3d5032b779C5B8914c10689707883F (Admin)

**结果**: ✅ 成功恢复接收地址

---

### 5. 💸 转账功能测试

**交易哈希**: `0x4c7ef83e4e6bf5c4231e4ea550ae8e58bafc1c11807e2e59ad16ead853fadade`

**接口函数**: `transfer(address to, uint256 amount)`

**参数**:
- `from`: 0xd19600392a0cEBB023e5a04DE12D7491aDb45E6b (测试账户)
- `to`: 0xEf2Dd344AE3d5032b779C5B8914c10689707883F (Admin)
- `amount`: 100000000000000000000 (100 xBETH, 18位小数)

**结果**: ✅ 成功转账 100 xBETH  
- 测试账户余额: 900 xBETH  
- Admin余额: 100 xBETH

---

### 6. ✅ 授权功能测试

#### 6.1 授权操作

**交易哈希**: `0x7033023fd73799c9223102ac959de21153999643def126b98d7dbcd0dba1b627`

**接口函数**: `approve(address spender, uint256 amount)`

**参数**:
- `owner`: 0xd19600392a0cEBB023e5a04DE12D7491aDb45E6b (测试账户)
- `spender`: 0xEf2Dd344AE3d5032b779C5B8914c10689707883F (Admin)
- `amount`: 50000000000000000000 (50 xBETH, 18位小数)

**结果**: ✅ 成功授权 Admin 使用 50 xBETH

---

#### 6.2 授权转账

**交易哈希**: `0xeaf3e574e9cdde166bf8530822ec9294bedb4ce911ee31c03578cb9df33c6a67`

**接口函数**: `transferFrom(address from, address to, uint256 amount)`

**参数**:
- `from`: 0xd19600392a0cEBB023e5a04DE12D7491aDb45E6b (测试账户)
- `to`: 0xEf2Dd344AE3d5032b779C5B8914c10689707883F (Admin)
- `amount`: 30000000000000000000 (30 xBETH, 18位小数)

**结果**: ✅ 成功通过授权转账 30 xBETH  
- Admin余额: 130 xBETH  
- 剩余授权额度: 20 xBETH

---

### 7. ⏸️ 暂停/恢复功能测试

#### 7.1 暂停合约

**交易哈希**: `0xf666f77c522d8f6f286ee8fa0e757c9f1f64bd40819ef1de1653deda22bb7ca4`

**接口函数**: `pause()`

**参数**: 无

**结果**: ✅ 成功暂停合约，所有转账功能被禁用

---

#### 7.2 恢复合约

**交易哈希**: `0x43aca5eeee7405954b664d9f2e84b4866bb70f9124706a8445af5040c242d555`

**接口函数**: `unpause()`

**参数**: 无

**结果**: ✅ 成功恢复合约，转账功能重新启用

---

### 8. 🚫 拒绝名单功能测试

#### 8.1 添加单个地址到拒绝名单

**交易哈希**: `0xa4f5d4e19fd1dc63505050d488027f8ac7706557602b9e4289c1a2f62981e5ad`

**接口函数**: `addToDenyList(address account)`

**参数**:
- `account`: 0x0000000000000000000000000000000000001234

**结果**: ✅ 成功添加地址到拒绝名单

---

#### 8.2 从拒绝名单移除地址

**交易哈希**: `0xb883e731aa1457e6022e363f6e6b9e710a8a6a0061076b1669f5dabab9333afa`

**接口函数**: `removeFromDenyList(address account)`

**参数**:
- `account`: 0x0000000000000000000000000000000000001234

**结果**: ✅ 成功从拒绝名单移除地址

---

### 9. 📋 批量拒绝名单功能测试

#### 9.1 批量添加到拒绝名单

**交易哈希**: `0x1ccdd7186b5365c2aa6460551f44da9f145ca9a6d88b1369c3a38921eebd1db5`

**接口函数**: `batchAddToDenyList(address[] memory accounts)`

**参数**:
- `accounts`: 
  - 0x0000000000000000000000000000000000001111
  - 0x0000000000000000000000000000000000002222
  - 0x0000000000000000000000000000000000003333

**结果**: ✅ 成功批量添加 3 个地址到拒绝名单

---

#### 9.2 批量从拒绝名单移除

**交易哈希**: `0xbe60e15e4e5eb492bb9530050a119cc1a595898c96b0852d616e82dea7e641b7`

**接口函数**: `batchRemoveFromDenyList(address[] memory accounts)`

**参数**:
- `accounts`: 
  - 0x0000000000000000000000000000000000001111
  - 0x0000000000000000000000000000000000002222
  - 0x0000000000000000000000000000000000003333

**结果**: ✅ 成功批量移除 3 个地址

---

### 10. 🎯 接收地址管理测试

#### 10.1 设置接收地址为测试账户

**交易哈希**: `0x1177f4e41ebb0f750c8b73338796141357935cb510da937f1e1e34d498dd843d`

**接口函数**: `setReceiver(address newReceiver)`

**参数**:
- `newReceiver`: 0xd19600392a0cEBB023e5a04DE12D7491aDb45E6b (测试账户)

**结果**: ✅ 成功设置新的授权接收地址

---

#### 10.2 恢复接收地址为Admin

**交易哈希**: `0xce24c53ef5126d545873211abb3fe99497172efa7e4f05b4f6988d9354117e4e`

**接口函数**: `setReceiver(address newReceiver)`

**参数**:
- `newReceiver`: 0xEf2Dd344AE3d5032b779C5B8914c10689707883F (Admin)

**结果**: ✅ 成功恢复接收地址

---

### 11. 👥 角色转移功能测试

#### 11.1 转移铸造者角色

**交易哈希**: `0x6d91277ee61a02592cc4f562caf5632077250edf755c5212e37ecee89c9e4488`

**接口函数**: `transferMinter(address newMinter)`

**参数**:
- `previousMinter`: 0xEf2Dd344AE3d5032b779C5B8914c10689707883F (Admin)
- `newMinter`: 0xd19600392a0cEBB023e5a04DE12D7491aDb45E6b (测试账户)

**结果**: ✅ 成功转移 MINTER_ROLE  
- Admin 失去铸造权限  
- 测试账户获得铸造权限

---

#### 11.2 转移铸造者角色回Admin

**交易哈希**: `0x037998ef417c553c3d236133cf62ce15a8069644707beb42321d1fe79a52d811`

**接口函数**: `transferMinter(address newMinter)`

**参数**:
- `previousMinter`: 0xd19600392a0cEBB023e5a04DE12D7491aDb45E6b (测试账户)
- `newMinter`: 0xEf2Dd344AE3d5032b779C5B8914c10689707883F (Admin)

**结果**: ✅ 成功转移回 MINTER_ROLE

---

#### 11.3 转移拒绝名单管理者角色

**交易哈希**: `0xd3ef5d974948c1c97768ed01b804311d4ee48579fcf1966ea7d551dbe1568134`

**接口函数**: `transferDenyLister(address newDenyLister)`

**参数**:
- `previousDenyLister`: 0xEf2Dd344AE3d5032b779C5B8914c10689707883F (Admin)
- `newDenyLister`: 0xd19600392a0cEBB023e5a04DE12D7491aDb45E6b (测试账户)

**结果**: ✅ 成功转移 DENY_LISTER_ROLE  
- Admin 失去拒绝名单管理权限  
- 测试账户获得拒绝名单管理权限

---

#### 11.4 转移拒绝名单管理者角色回Admin

**交易哈希**: `0xf07b3e4c8d44b7a4cac3a943aebe27bf14ccace8951cd95c0090773b12667c61`

**接口函数**: `transferDenyLister(address newDenyLister)`

**参数**:
- `previousDenyLister`: 0xd19600392a0cEBB023e5a04DE12D7491aDb45E6b (测试账户)
- `newDenyLister`: 0xEf2Dd344AE3d5032b779C5B8914c10689707883F (Admin)

**结果**: ✅ 成功转移回 DENY_LISTER_ROLE

---

### 12. 🔥 销毁功能测试

**交易哈希**: `0x34ee2999c37ce94dc51db23006d495f263ff701ecc53848973dfc8d1954e6a32`

**接口函数**: `burn(uint256 amount)`

**参数**:
- `burner`: 0xEf2Dd344AE3d5032b779C5B8914c10689707883F (Admin)
- `amount`: 50000000000000000000 (50 xBETH, 18位小数)

**结果**: ✅ 成功销毁 50 xBETH  
- Admin余额: 80 xBETH (从 130 xBETH 减少)  
- 总供应量: 950 xBETH (从 1000 xBETH 减少)

---

## 📊 测试统计

### 测试的函数 (共24个)

| # | 函数名 | 调用次数 | 状态 |
|---|--------|---------|------|
| 1 | constructor() | 3 | ✅ |
| 2 | initialize() | 2 | ✅ |
| 3 | setOracle() | 2 | ✅ |
| 4 | updateExchangeRate() | 2 | ✅ |
| 5 | configureCaller() | 2 | ✅ |
| 6 | removeCaller() | 1 | ✅ |
| 7 | mint() | 1 | ✅ |
| 8 | transfer() | 1 | ✅ |
| 9 | approve() | 1 | ✅ |
| 10 | transferFrom() | 1 | ✅ |
| 11 | pause() | 1 | ✅ |
| 12 | unpause() | 1 | ✅ |
| 13 | addToDenyList() | 1 | ✅ |
| 14 | removeFromDenyList() | 1 | ✅ |
| 15 | batchAddToDenyList() | 1 | ✅ |
| 16 | batchRemoveFromDenyList() | 1 | ✅ |
| 17 | setReceiver() | 5 | ✅ |
| 18 | transferMinter() | 2 | ✅ |
| 19 | transferDenyLister() | 2 | ✅ |
| 20 | burn() | 1 | ✅ |
| 21 | balanceOf() | 多次 | ✅ |
| 22 | allowance() | 多次 | ✅ |
| 23 | exchangeRate() | 多次 | ✅ |
| 24 | oracle() | 多次 | ✅ |

### 最终状态

**合约地址**:
- xBETH Proxy: 0x15c05f62958C0De1A594B90abCB1d996fCBBbaA4
- xBETH Implementation: 0x1317418402a924B3484ed3016735b77719E8fC1B
- ExchangeRateUpdater: 0xb18366B902ad10720648281A11F7eFA1AdE92E9e
- ProxyAdmin: 0xb6adb19cbecd813cc442f4423301a0d5c704710c

**代币信息**:
- 名称: OKX Staked ETH
- 符号: xBETH
- 小数位: 18
- 总供应量: 950 xBETH (950,000,000,000,000,000,000)
- 最大供应量: 1,000,000,000 xBETH
- 当前汇率: 1.005 (1005000000000000000)

**账户余额**:
- Admin (0xEf2Dd344AE3d5032b779C5B8914c10689707883F): 80 xBETH
- 测试账户 (0xd19600392a0cEBB023e5a04DE12D7491aDb45E6b): 870 xBETH

**角色分配**:
- DEFAULT_ADMIN_ROLE: Admin
- MINTER_ROLE: Admin
- DENY_LISTER_ROLE: Admin

**Oracle 配置**:
- Oracle 地址: ExchangeRateUpdater (0xb18366B902ad10720648281A11F7eFA1AdE92E9e)
- 测试账户汇率更新额度: 1% (每天)

---

## ✅ 测试结论

所有 11 个测试组，24 个函数全部测试通过！

✅ 部署功能正常  
✅ Oracle 和汇率管理功能正常  
✅ 汇率更新调用者管理功能正常  
✅ 铸造功能正常  
✅ 转账功能正常  
✅ 授权功能正常  
✅ 暂停/恢复功能正常  
✅ 拒绝名单功能正常  
✅ 批量操作功能正常  
✅ 接收地址管理功能正常  
✅ 角色转移功能正常  
✅ 销毁功能正常  
✅ 读取函数正常

**测试环境**: Chain 1952 (测试网)  
**区块链浏览器**: 所有交易均可在区块链浏览器中查看验证

---

## 🔍 xBETH 特点

**作为 Staked Token 的特性**:
- **汇率机制**: 支持可变汇率，反映质押收益
- **Oracle 系统**: 通过 ExchangeRateUpdater 合约管理汇率更新
- **Rate Limit**: 每个调用者有独立的汇率更新额度限制

**与 xSOL 的主要差异**:
- **小数位数**: 18位 (vs xSOL的9位)
- **最大供应量**: 1,000,000,000 (与 xSOL 相同)
- **金额表示**: 1 xBETH = 1,000,000,000,000,000,000 (10^18)

**功能完全相同**: 所有核心功能与其他 xToken 保持一致

---

## 📈 Gas 消耗统计

| 交易类型 | Gas 消耗 |
|---------|---------|
| 部署实现合约 | 3,193,501 |
| 部署代理合约 | 1,042,447 |
| 部署 ExchangeRateUpdater | 1,188,885 |
| 设置 Oracle | ~35,000 |
| 更新汇率 | ~54,000 |
| 铸造代币 | ~88,000 |
| 转账 | ~63,000 |
| 授权 | ~51,000 |
| 暂停/恢复 | ~30,000-52,000 |
| 拒绝名单操作 | ~30,000-52,000 |
| 批量拒绝名单 | ~40,000-101,000 |
| 角色转移 | ~55,000 |
| 销毁 | ~49,000 |

**总 Gas 消耗**: 6,956,801 gas  
**总花费**: 0.0006956801 ETH

---

*测试完成时间: 2025年12月11日*  
*生成工具: Foundry Script*  
*测试脚本: Test.xBETH.testnet.s.sol*
