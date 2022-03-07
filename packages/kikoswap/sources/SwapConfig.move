address KikoSwap {
module SwapConfig {
    use StarcoinFramework::Signer;

    const CONFIG_ADDRESS: address = @KikoSwap;
    const PERMISSION_DENIED: u64 = 400001;
    const EXCESSIVE_FEE_RATE: u64 = 400002;
    const EXCESSIVE_TREASURY_FEE_RATE: u64 = 400003;

    struct Config has key, store {
        // total fee, 30 for 0.3%, cannot excess 10000
        fee_rate: u128,
        // fee ratio to treasury, 5 for 0.05%, cannot excess fee_rate
        treasury_fee_rate: u128,
        // extra config
        extra0: u128,
        extra1: u128,
        extra2: u128,
        extra3: u128,
        extra4: u128
    }

    // init
    public fun initialize(
        signer: &signer,
        fee_rate: u128,
        treasury_fee_rate: u128,
        extra0: u128,
        extra1: u128,
        extra2: u128,
        extra3: u128,
        extra4: u128
    ) {
        assert!(Signer::address_of(signer) == CONFIG_ADDRESS, PERMISSION_DENIED);
        assert!(fee_rate < 10000, EXCESSIVE_FEE_RATE);
        assert!(treasury_fee_rate <= fee_rate, EXCESSIVE_TREASURY_FEE_RATE);

        move_to<Config>(signer, Config{
            fee_rate: fee_rate,
            treasury_fee_rate: treasury_fee_rate,
            extra0: extra0,
            extra1: extra1,
            extra2: extra2,
            extra3: extra3,
            extra4: extra4
        });
    }

    // update
    public fun update(
        signer: &signer,
        fee_rate: u128,
        treasury_fee_rate: u128,
        extra0: u128,
        extra1: u128,
        extra2: u128,
        extra3: u128,
        extra4: u128
    ) acquires Config {
        assert!(Signer::address_of(signer) == CONFIG_ADDRESS, PERMISSION_DENIED);
        assert!(fee_rate < 10000, EXCESSIVE_FEE_RATE);
        assert!(treasury_fee_rate <= fee_rate, EXCESSIVE_TREASURY_FEE_RATE);

        let config = borrow_global_mut<Config>(CONFIG_ADDRESS);
        config.fee_rate = fee_rate;
        config.treasury_fee_rate = treasury_fee_rate;
        config.extra0 = extra0;
        config.extra1 = extra1;
        config.extra2 = extra2;
        config.extra3 = extra3;
        config.extra4 = extra4;
    }

    public fun get_fee_config(): (u128, u128) acquires Config {
        let config = borrow_global<Config>(CONFIG_ADDRESS);
        (config.fee_rate, config.treasury_fee_rate)
    }

    public fun get_extra_config(): (u128, u128, u128, u128, u128) acquires Config {
        let config = borrow_global<Config>(CONFIG_ADDRESS);
        (config.extra0, config.extra1, config.extra2, config.extra3, config.extra4)
    }

}

}
