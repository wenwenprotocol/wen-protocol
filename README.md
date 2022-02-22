# WEN Stable Coin for starcoin

## Move Package Manager
## Compile

```
mpm sandbox clean
mpm package build
mpm sandbox publish --ignore-breaking-changes
```

## Test

```
mpm spectest
```

---
## Move CLI (Old version)
### Compile

```
move clean
move check
move publish --ignore-breaking-changes
```

### Test

```
move functional-test
```

---
## Document

[Token](doc/Token.md)

[LendingPool](doc/LendingPool.md)

[Farm](doc/Farm.md)
