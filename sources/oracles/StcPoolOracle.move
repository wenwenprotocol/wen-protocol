module WenProtocol::StcPoolOracle {
    use StarcoinFramework::STCUSDOracle;
    use StarcoinFramework::PriceOracle;

    public fun get(): (u128, u128) {
        (
            STCUSDOracle::read(@0x82e35b34096f32c42061717c06e44a59),
            PriceOracle::get_scaling_factor<STCUSDOracle::STCUSD>(),
        )
    }
}
