# xSOL 测试交易记录

**测试网络**: Chain 1952  
**测试时间**: 2025年12月5日  
**部署者地址**: 0xEf2Dd344AE3d5032b779C5B8914c10689707883F  
**测试账户地址**: 0xd19600392a0cEBB023e5a04DE12D7491aDb45E6b  

---

## 📋 测试概览

✅ **11个测试组全部通过**  
🔗 **共21笔交易上链**

---

## 🧪 测试交易详情

### 1. 📦 合约部署

#### 1.1 部署实现合约 (Implementation)

**交易哈希**: `0x2d10c4ac89af8a296b9f6b53d7dc378a10c4385f8d27dffc5322fc23f439959f`  
**合约地址**: `0x48b0b61365Fe5b9B71CAb1f0Fe6865B7f9F52C7d`

**接口函数**: `constructor()`

**结果**: ✅ 成功部署 xSOL 实现合约

---

#### 1.2 部署代理合约 (Proxy)

**交易哈希**: `0xa0c47ea363ebfcd32990cce89a1441e19b077cacb63eeb4a88152e952cbcfe7a`  
**合约地址**: `0x61652b779c9D74F7ee21e1910048183449A4bEbf`

**接口函数**: `constructor(address implementation, address admin, bytes memory data)`

**参数**:
- `implementation`: 0x48b0b61365Fe5b9B71CAb1f0Fe6865B7f9F52C7d
- `admin`: 0xEf2Dd344AE3d5032b779C5B8914c10689707883F
- `data`: 初始化数据（包含代币名称、符号、角色分配等）

**初始化参数**:
- 代币名称: "xSOL"
- 代币符号: "xSOL"
- 小数位数: 9
- 最大供应量: 1,000,000,000 xSOL
- Admin角色: 0xEf2Dd344AE3d5032b779C5B8914c10689707883F
- DenyLister角色: 0xEf2Dd344AE3d5032b779C5B8914c10689707883F
- Minter角色: 0xEf2Dd344AE3d5032b779C5B8914c10689707883F
- 授权接收者: 0xEf2Dd344AE3d5032b779C5B8914c10689707883F

**结果**: ✅ 成功部署代理合约并完成初始化

---

### 2. 🪙 铸造功能测试

#### 2.1 设置接收地址为测试账户

**交易哈希**: `0x8726cf3969c5552a5a61e0d81e11c5eed0c6cd1749ff51a1676cf560d392ec87`

**接口函数**: `setReceiver(address newReceiver)`

**参数**:
- `newReceiver`: 0xd19600392a0cEBB023e5a04DE12D7491aDb45E6b (测试账户)

**结果**: ✅ 成功设置接收地址

---

#### 2.2 铸造代币

**交易哈希**: `0xd292d94753806acd3c0ea97b01cd5d30641a780904fdaa94e7caab2bc3cfd7aa`

**接口函数**: `mint(address receiver, uint256 amount)`

**参数**:
- `receiver`: 0xd19600392a0cEBB023e5a04DE12D7491aDb45E6b (测试账户)
- `amount`: 1000000000000 (1,000 xSOL, 9位小数)

**结果**: ✅ 成功铸造 1,000 xSOL 到测试账户

---

#### 2.3 恢复接收地址为Admin

**交易哈希**: `0xb748a5fbfc7d72ec5d74bf1d5dab005f51e78b121f01693dc3e793ab516ec652`

**接口函数**: `setReceiver(address newReceiver)`

**参数**:
- `newReceiver`: 0xEf2Dd344AE3d5032b779C5B8914c10689707883F (Admin)

**结果**: ✅ 成功恢复接收地址

---

### 3. 💸 转账功能测试

**交易哈希**: `0xe847cc59e6180538a906704d7ffbcf3f4babf2ba437f6af64fd51724a78a7bc9`

**接口函数**: `transfer(address to, uint256 amount)`

**参数**:
- `from`: 0xd19600392a0cEBB023e5a04DE12D7491aDb45E6b (测试账户)
- `to`: 0xEf2Dd344AE3d5032b779C5B8914c10689707883F (Admin)
- `amount`: 100000000000 (100 xSOL, 9位小数)

**结果**: ✅ 成功转账 100 xSOL  
- 测试账户余额: 900 xSOL  
- Admin余额: 100 xSOL

---

### 4. ✅ 授权功能测试

#### 4.1 授权操作

**交易哈希**: `0xf510fb7186347f3d8914dd608596fc3a08349175b4c6598fb270694a5394e5df`

**接口函数**: `approve(address spender, uint256 amount)`

**参数**:
- `owner`: 0xd19600392a0cEBB023e5a04DE12D7491aDb45E6b (测试账户)
- `spender`: 0xEf2Dd344AE3d5032b779C5B8914c10689707883F (Admin)
- `amount`: 50000000000 (50 xSOL, 9位小数)

**结果**: ✅ 成功授权 Admin 使用 50 xSOL

---

#### 4.2 授权转账

**交易哈希**: `0xf71a891a0eb9da5959cc81585ed61cb1208e9bc89c3e26895ca1614310ca2807`

**接口函数**: `transferFrom(address from, address to, uint256 amount)`

**参数**:
- `from`: 0xd19600392a0cEBB023e5a04DE12D7491aDb45E6b (测试账户)
- `to`: 0xEf2Dd344AE3d5032b779C5B8914c10689707883F (Admin)
- `amount`: 30000000000 (30 xSOL, 9位小数)

**结果**: ✅ 成功通过授权转账 30 xSOL  
- Admin余额: 130 xSOL  
- 剩余授权额度: 20 xSOL

---

### 5. ⏸️ 暂停/恢复功能测试

#### 5.1 暂停合约

**交易哈希**: `0xcc21b7102505a11a2207c69ebb6d9f636984191b68c61d7c64a8e38a55348bf9`

**接口函数**: `pause()`

**参数**: 无

**结果**: ✅ 成功暂停合约，所有转账功能被禁用

---

#### 5.2 恢复合约

**交易哈希**: `0x001aa9348517e6a49ebafad77f1c44c47e9b052a9bde637999300e388cedb6e4`

**接口函数**: `unpause()`

**参数**: 无

**结果**: ✅ 成功恢复合约，转账功能重新启用

---

### 6. 🚫 拒绝名单功能测试

#### 6.1 添加单个地址到拒绝名单

**交易哈希**: `0x022c9adbd6b433de21507361b0d82ff9925c01e8f898e07edf0878d21ac93e8a`

**接口函数**: `addToDenyList(address account)`

**参数**:
- `account`: 0x0000000000000000000000000000000000001234

**结果**: ✅ 成功添加地址到拒绝名单

---

#### 6.2 从拒绝名单移除地址

**交易哈希**: `0x28453a891044a7badbde8f2b0c58fa6c3a976b3a9ba54027a404672d48ae47c8`

**接口函数**: `removeFromDenyList(address account)`

**参数**:
- `account`: 0x0000000000000000000000000000000000001234

**结果**: ✅ 成功从拒绝名单移除地址

---

### 7. 📋 批量拒绝名单功能测试

#### 7.1 批量添加到拒绝名单

**交易哈希**: `0x2fe333d5b9a9a70eec9f979c7fb27f54926336ba6641d17204a1397d768530dc`

**接口函数**: `batchAddToDenyList(address[] memory accounts)`

**参数**:
- `accounts`: 
  - 0x0000000000000000000000000000000000001111
  - 0x0000000000000000000000000000000000002222
  - 0x0000000000000000000000000000000000003333

**结果**: ✅ 成功批量添加 3 个地址到拒绝名单

---

#### 7.2 批量从拒绝名单移除

**交易哈希**: `0x5a640cffecdbb6eaf91f4d7883db21dd8672462aec815e740456825f1acc4a88`

**接口函数**: `batchRemoveFromDenyList(address[] memory accounts)`

**参数**:
- `accounts`: 
  - 0x0000000000000000000000000000000000001111
  - 0x0000000000000000000000000000000000002222
  - 0x0000000000000000000000000000000000003333

**结果**: ✅ 成功批量移除 3 个地址

---

### 8. 🎯 接收地址管理测试

#### 8.1 设置接收地址为测试账户

**交易哈希**: `0x07108dd083e533e7c81282401f3c5d2b8318423d601b719d20c04cae53e5c059`

**接口函数**: `setReceiver(address newReceiver)`

**参数**:
- `newReceiver`: 0xd19600392a0cEBB023e5a04DE12D7491aDb45E6b (测试账户)

**结果**: ✅ 成功设置新的授权接收地址

---

#### 8.2 恢复接收地址为Admin

**交易哈希**: `0x22f43afa490e5c04c00624086d2c6e8f70aa26da8f7534873b9b826706bddf99`

**接口函数**: `setReceiver(address newReceiver)`

**参数**:
- `newReceiver`: 0xEf2Dd344AE3d5032b779C5B8914c10689707883F (Admin)

**结果**: ✅ 成功恢复接收地址

---

### 9. 👥 角色转移功能测试

#### 9.1 转移铸造者角色

**交易哈希**: `0xe3e621c10d6e0f38bcbc61ff0f84ca1047008d18345b3d2cd9b5799e8fdf50aa`

**接口函数**: `transferMinter(address newMinter)`

**参数**:
- `previousMinter`: 0xEf2Dd344AE3d5032b779C5B8914c10689707883F (Admin)
- `newMinter`: 0xd19600392a0cEBB023e5a04DE12D7491aDb45E6b (测试账户)

**结果**: ✅ 成功转移 MINTER_ROLE  
- Admin 失去铸造权限  
- 测试账户获得铸造权限

---

#### 9.2 转移铸造者角色回Admin

**交易哈希**: `0xabf29a155451055aebe7f59c2ae98e7249f68c531beecdee17921854ef4081a6`

**接口函数**: `transferMinter(address newMinter)`

**参数**:
- `previousMinter`: 0xd19600392a0cEBB023e5a04DE12D7491aDb45E6b (测试账户)
- `newMinter`: 0xEf2Dd344AE3d5032b779C5B8914c10689707883F (Admin)

**结果**: ✅ 成功转移回 MINTER_ROLE

---

#### 9.3 转移拒绝名单管理者角色

**交易哈希**: `0x216d032a8eb7aa795f1fffded1f3ac805de7cb6c1f5ded3ccfe4d322e2c4dd84`

**接口函数**: `transferDenyLister(address newDenyLister)`

**参数**:
- `previousDenyLister`: 0xEf2Dd344AE3d5032b779C5B8914c10689707883F (Admin)
- `newDenyLister`: 0xd19600392a0cEBB023e5a04DE12D7491aDb45E6b (测试账户)

**结果**: ✅ 成功转移 DENY_LISTER_ROLE  
- Admin 失去拒绝名单管理权限  
- 测试账户获得拒绝名单管理权限

---

#### 9.4 转移拒绝名单管理者角色回Admin

**交易哈希**: `0xcdfe15f4c1fd0835a9d058934b7b9420dd03163280f732c927160cedb5baf5a0`

**接口函数**: `transferDenyLister(address newDenyLister)`

**参数**:
- `previousDenyLister`: 0xd19600392a0cEBB023e5a04DE12D7491aDb45E6b (测试账户)
- `newDenyLister`: 0xEf2Dd344AE3d5032b779C5B8914c10689707883F (Admin)

**结果**: ✅ 成功转移回 DENY_LISTER_ROLE

---

### 10. 🔥 销毁功能测试

**交易哈希**: `0x9d06b8bb5c8ef373d888b09ed923aaabbc01334284e11662bfee23e7c71d63e7`

**接口函数**: `burn(uint256 amount)`

**参数**:
- `burner`: 0xEf2Dd344AE3d5032b779C5B8914c10689707883F (Admin)
- `amount`: 50000000000 (50 xSOL, 9位小数)

**结果**: ✅ 成功销毁 50 xSOL  
- Admin余额: 80 xSOL (从 130 xSOL 减少)  
- 总供应量: 950 xSOL (从 1000 xSOL 减少)

---

## 📊 测试统计

### 测试的函数 (共18个)

| # | 函数名 | 调用次数 | 状态 |
|---|--------|---------|------|
| 1 | constructor() | 2 | ✅ |
| 2 | initialize() | 1 | ✅ |
| 3 | mint() | 1 | ✅ |
| 4 | transfer() | 1 | ✅ |
| 5 | approve() | 1 | ✅ |
| 6 | transferFrom() | 1 | ✅ |
| 7 | pause() | 1 | ✅ |
| 8 | unpause() | 1 | ✅ |
| 9 | addToDenyList() | 1 | ✅ |
| 10 | removeFromDenyList() | 1 | ✅ |
| 11 | batchAddToDenyList() | 1 | ✅ |
| 12 | batchRemoveFromDenyList() | 1 | ✅ |
| 13 | setReceiver() | 5 | ✅ |
| 14 | transferMinter() | 2 | ✅ |
| 15 | transferDenyLister() | 2 | ✅ |
| 16 | burn() | 1 | ✅ |
| 17 | balanceOf() | 多次 | ✅ |
| 18 | allowance() | 多次 | ✅ |

### 最终状态

**合约地址**: 0x61652b779c9D74F7ee21e1910048183449A4bEbf

**代币信息**:
- 名称: xSOL
- 符号: xSOL
- 小数位: 9
- 总供应量: 950 xSOL (950,000,000,000)
- 最大供应量: 1,000,000,000 xSOL

**账户余额**:
- Admin (0xEf2Dd344AE3d5032b779C5B8914c10689707883F): 80 xSOL (80,000,000,000)
- 测试账户 (0xd19600392a0cEBB023e5a04DE12D7491aDb45E6b): 870 xSOL (870,000,000,000)

**角色分配**:
- DEFAULT_ADMIN_ROLE: Admin
- MINTER_ROLE: Admin
- DENY_LISTER_ROLE: Admin

---

## ✅ 测试结论

所有 11 个测试组，18 个函数全部测试通过！

✅ 部署功能正常  
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

## 🔍 xSOL 特点

**与 xETH 的主要差异**:
- **小数位数**: 9位 (vs xETH的18位)
- **最大供应量**: 1,000,000,000 (vs xETH的100,000,000)
- **金额表示**: 1 xSOL = 1,000,000,000 (10^9)

**功能完全相同**: 所有核心功能与 xETH 保持一致

---

*测试完成时间: 2025年12月5日*  
*生成工具: Foundry Script*  
*测试脚本: Test.xSOL.testnet.s.sol*

