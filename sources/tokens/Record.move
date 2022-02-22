address WenProtocol {
module Record {
    use StarcoinFramework::PriceOracle;

    const PRECISION: u8 = 9;
    struct SSHARE has copy, drop, store {}

    public(script) fun register(account: signer) {
        PriceOracle::register_oracle<SSHARE>(&account, PRECISION);
    }

    public fun get(ds_addr: address): u128 {
        PriceOracle::read<SSHARE>(ds_addr)
    }

    public fun latest_30_days_data(): u128 {
        PriceOracle::read<SSHARE>(@0xf67396ad8b0890c26137ec79e8e4d5c1)
    }
}
}
