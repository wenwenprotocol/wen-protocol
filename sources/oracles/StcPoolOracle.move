module WenProtocol::StcPoolOracle {
    use StarcoinFramework::STCUSDOracle;
    use StarcoinFramework::PriceOracle;

    public fun get(): (u128, u128) {
        (
            STCUSDOracle::read(@0x07fa08a855753f0ff7292fdcbe871216),
            PriceOracle::get_scaling_factor<STCUSDOracle::STCUSD>(),
        )
    }
}
