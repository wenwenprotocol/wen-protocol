# Main

# Barnard

#### WEN `0x88e2677b89841cd4ee7c15535798e1c8::WEN::WEN`

#### SHARE `0x88e2677b89841cd4ee7c15535798e1c8::SHARE::SHARE`

#### SSHARE `0x88e2677b89841cd4ee7c15535798e1c8::SSHARE::SSHARE`

---

# SSHARE Functions

### Function `total_supply`
返回 sshare 总发行量, 同: Token::market_cap<SSHARE>() 获取

```js
public fun total_supply(): u128
```

### Function `balance_of`
返回指定用户的锁定 sshare 余额 和 到期时间

```js
public fun balance_of(addr: address): (u128, u64)
```

### Function `balance`
返回合约持有的 share 量

```js
public fun balance(): u128
```

### Function `locked_balance`
返回总体锁定未claim 的 sshare

```js
public fun locked_balance(): u128
```

### Function `deposit`
存入一定量 share , 主要是将借贷池利息转入其中

```js
public(script) fun deposit(asigner: signer, amount: u128)
```

### Function `mint`
质押一定量 share 得到 sshare 锁定时间 24 小时

```js
public(script) fun mint(asigner: signer, amount: u128)
```

### Function `claim`
将锁定的 sshare 提取到钱包

```js
public(script) fun claim(asigner: signer)
```

### Function `burn`
将一定量 sshare 燃烧，换取 share

```js
public(script) fun burn(asigner: signer, samount: u128)
```
