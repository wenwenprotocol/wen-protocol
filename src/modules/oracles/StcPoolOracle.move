address 0x100000 {
module StcPoolOracle {
    use 0x1::STCUSDOracle;
    use 0x1::PriceOracle;

    public fun get(): (u128, u128) {
        let price = STCUSDOracle::read(@0x07fa08a855753f0ff7292fdcbe871216);
        let scaling_factor = PriceOracle::get_scaling_factor<STCUSDOracle::STCUSD>();
        (price, scaling_factor)
    }
}
}
