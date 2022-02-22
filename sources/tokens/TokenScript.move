address WenProtocol {
module TokenScript {
    use WenProtocol::WEN;
    use WenProtocol::SHARE;

    public(script) fun init_WEN(account: signer) { WEN::initialize(&account); }
    public(script) fun init_WEN_v2(account: signer) { WEN::initialize_minting(&account); }
    public(script) fun mint_WEN(account: signer, to: address, amount: u128) { WEN::mint_to(&account, to, amount); }
    public(script) fun init_SHARE(account: signer) { SHARE::initialize(&account); }
    public(script) fun mint_SHARE(account: signer, to: address, amount: u128) { SHARE::mint(&account, to, amount); }
}
}
