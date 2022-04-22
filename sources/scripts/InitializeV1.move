module WenProtocol::InitializeV1 {

    use WenProtocol::WEN;
    use WenProtocol::STCLendingPoolV2;

    public(script) fun init(account: signer) {
        WEN::initialize(&account);
        STCLendingPoolV2::initialize(account);
    }
}
