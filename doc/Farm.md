# Main

# Barnard

#### StarSwap STC-SHARE `0x88e2677b89841cd4ee7c15535798e1c8::STCSHAREFarmV2`

* stake: STC-SHARE LP Token on StarSwap
* reward: Share
* release per second: 0.1 share/s
* total reward: 10M share 

#### StarSwap STC-WEN `0x88e2677b89841cd4ee7c15535798e1c8::STCWENFarmV2`

* stake: STC-WEN LP Token on StarSwap
* reward: Share
* release per second: 0.1 share/s
* total reward: 10M share 

#### KikoSwap STC-WEN
#### KikoSwap STC-SHARE

---

# Functions

## Function `query_remaining_reward`
返回奖励 share token 余额

```js
public fun query_remaining_reward(): u128
```

## Function `query_farming_asset`
返回矿池锁仓量

```js
public fun query_farming_asset(): u128
```

## Function `query_stake`
返回指定账号锁仓量

```js
public fun query_stake(addr: address): u128
```

## Function `query_farming_asset_setting`
返回池子设置(每秒奖励数, 累积每份得到的奖励, 开始时间, 是否alive)

```js
public fun query_farming_asset_setting(): (u128, u128, u64, bool)
```

## Function `pending`
查看指定地址收益

```js
public fun pending(addr: address): u128
```

## Function `deposit`
质押一定量 LP Token

```js
public(script) fun deposit(account: signer, amount: u128)
```

## Function `withdraw`
赎回一定量 LP Token

```js
public(script) fun withdraw(account: signer, amount: u128)
```

## Function `harvest`
提取收益

```js
public(script) fun harvest(account: signer)
```
