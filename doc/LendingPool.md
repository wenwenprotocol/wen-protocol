# Main

# Barnard

#### STC 借贷池 `0x88e2677b89841cd4ee7c15535798e1c8::STCLendingPoolV2`

---

# Functions

## Function `settings`
返回池子基础信息 (collaterization\_rate, liquidation\_threshold, liquidation\_multiplier, borrow\_opening\_fee, interest\_per\_second)

例如: (60000, 75000, 105000, 1000, 2500) 代表 (抵押率 60%, 清算线 75%, 清算费 5%, 借款费 1%, 借贷利息 2.5%)

```js
public fun settings(): (u128, u128, u128, u128, u128)
```

## Function `is_deprecated`
返回池子是否已弃用

```js
public fun is_deprecated(): bool
```

## Function `collateral_info`
返回抵押物总额

```js
public fun collateral_info(): u128
```

## Function `borrow_info`
返回借贷数据 (借款part， 借款amount, 剩余借款amount)

```js
public fun borrow_info(): (u128, u128, u128)
```

## Function `fee_info`
返回借贷数据 (利息接收地址， 当前累积利息, 更新时间)

```js
public fun fee_info(): (address, u128, u64)
```

## Function `position`
返回仓位信息 (抵押额， 借款part, 借款amount)

```js
public fun position(addr: address): (u128, u128, u128)
```

## Function `add_collateral`
添加抵押物

```js
public(script) fun add_collateral(account: signer, amount: u128)
```

## Function `remove_collateral`
移除抵押物

```js
public(script) fun remove_collateral(account: signer, receiver: address, amount: u128)
```

### Function `borrow`
借款

```js
public(script) fun borrow(account: signer, receiver: address, amount: u128)
```

## Function `repay`
还款

```js
public(script) fun repay(account: signer, receiver: address, part: u128)
```

## Function `is_solvent`
检查账户是否有偿还能力

```js
public fun is_solvent(addr: address, exchange_rate: u128): bool
```

## Function `cook`
组合方法

actions:

* ACTION\_ADD_COLLATERAL: u8 = 1
* ACTION\_REMOVE_COLLATERAL: u8 = 2
* ACTION\_BORROW: u8 = 3
* ACTION\_REPAY: u8 = 4

address 类型不需要时传值 0x00000000000000000000000000000000

```js
public(script) fun cook(
        account: signer,
        actions: vector<u8>,
        collateral_amount: u128,
        remove_collateral_amount: u128,
        remove_collateral_to: address,
        borrow_amount: u128,
        borrow_to: address,
        repay_part: u128,
        repay_to: address
   )
```

## Function `accrue`
累积利息

```js
public(script) fun accrue()
```

## Function `latest_exchange_rate`
获取 WEN-抵押物 价格信息返回 (价格, 精度)

```js
public fun latest_exchange_rate(): (u128, u128)
```
