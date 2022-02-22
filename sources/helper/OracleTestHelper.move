module WenProtocol::OracleTestHelper {
    use StarcoinFramework::STCUSDOracle;
    use StarcoinFramework::PriceOracle;

    public(script) fun init_data_source(account: signer, value: u128) {
        PriceOracle::init_data_source<STCUSDOracle::STCUSD>(&account, 0);
        PriceOracle::update<STCUSDOracle::STCUSD>(&account, value);
    }

    public(script) fun update(account: signer, value: u128) {
        PriceOracle::update<STCUSDOracle::STCUSD>(&account, value);
    }
}
