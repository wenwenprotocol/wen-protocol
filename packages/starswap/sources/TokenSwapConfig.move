// Copyright (c) The Elements Studio Core Contributors
// SPDX-License-Identifier: Apache-2.0

// TODO: replace the address with admin address
address StarSwap {

module TokenSwapConfig {
    use StarcoinFramework::Config;
    use StarcoinFramework::Signer;
    use StarcoinFramework::Errors;

    // Numerator and denumerator default fixed value
    const DEFAULT_OPERATION_NUMERATOR: u64 = 10;
    const DEFAULT_OPERATION_DENUMERATOR: u64 = 60;
    const DEFAULT_POUNDAGE_NUMERATOR: u64 = 3;
    const DEFAULT_POUNDAGE_DENUMERATOR: u64 = 1000;

    const SWAP_FEE_SWITCH_ON: bool = true;
    const SWAP_FEE_SWITCH_OFF: bool = false;

    const ERROR_NOT_HAS_PRIVILEGE: u64 = 101;

    struct SwapFeePoundageConfig<phantom X, phantom Y> has copy, drop, store {
        numerator: u64,
        denumerator: u64,
    }

    struct SwapFeeOperationConfig has copy, drop, store {
        numerator: u64,
        denumerator: u64,
    }

    public fun get_swap_fee_operation_rate(): (u64, u64) {
        if (Config::config_exist_by_address<SwapFeeOperationConfig>(admin_address())) {
            let conf = Config::get_by_address<SwapFeeOperationConfig>(admin_address());
            let numerator: u64 = conf.numerator;
            let denumerator: u64 = conf.denumerator;
            (numerator, denumerator)
        } else {
            (DEFAULT_OPERATION_NUMERATOR, DEFAULT_OPERATION_DENUMERATOR)
        }
    }

    /// Swap fee allocation mode: LP Providor 5/6, Operation management 1/6
    /// Poundage number of liquidity token pair
    public fun get_poundage_rate<X: copy + drop + store,
                                 Y: copy + drop + store>(): (u64, u64) {

        if (Config::config_exist_by_address<SwapFeePoundageConfig<X, Y>>(admin_address())) {
            let conf = Config::get_by_address<SwapFeePoundageConfig<X, Y>>(admin_address());
            let numerator: u64 = conf.numerator;
            let denumerator: u64 = conf.denumerator;
            (numerator, denumerator)
        } else {
            (DEFAULT_POUNDAGE_NUMERATOR, DEFAULT_POUNDAGE_DENUMERATOR)
        }
    }

    /// Set fee rate for operation rate, only admin can call
    public fun set_swap_fee_operation_rate(signer: &signer, num: u64, denum: u64) {
        assert!(Signer::address_of(signer) == admin_address(), Errors::invalid_state(ERROR_NOT_HAS_PRIVILEGE));
        let config = SwapFeeOperationConfig{
            numerator: num,
            denumerator: denum,
        };
        if (Config::config_exist_by_address<SwapFeeOperationConfig>(admin_address())) {
            Config::set<SwapFeeOperationConfig>(signer, config);
        } else {
            Config::publish_new_config<SwapFeeOperationConfig>(signer, config);
        }
    }

    /// Set fee rate for poundage rate, only admin can call
    public fun set_poundage_rate<X: copy + drop + store,
                                 Y: copy + drop + store>(signer: &signer,
                                                         num: u64,
                                                         denum: u64) {
        assert!(Signer::address_of(signer) == admin_address(), Errors::invalid_state(ERROR_NOT_HAS_PRIVILEGE));
        let config = SwapFeePoundageConfig<X, Y>{
            numerator: num,
            denumerator: denum,
        };
        if (Config::config_exist_by_address<SwapFeePoundageConfig<X, Y>>(admin_address())) {
            Config::set<SwapFeePoundageConfig<X, Y>>(signer, config);
        } else {
            Config::publish_new_config<SwapFeePoundageConfig<X, Y>>(signer, config);
        }
    }

    public fun admin_address(): address {
        @StarSwap
    }

    public fun fee_address(): address {
        @0x0a4183ac9335a9f5804014eab01c0abc
    }

    public fun get_swap_fee_switch(): bool {
        SWAP_FEE_SWITCH_ON
    }
}
}