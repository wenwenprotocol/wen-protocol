address WenProtocol {
module StcPoolOracle {
    use StarcoinFramework::STCUSDOracle;
    use StarcoinFramework::PriceOracle;

    public fun get(): (u128, u128) {
        let price = STCUSDOracle::read(@0x07fa08a855753f0ff7292fdcbe871216);
        let scaling_factor = PriceOracle::get_scaling_factor<STCUSDOracle::STCUSD>();
        (price, scaling_factor)
    }
}
}
