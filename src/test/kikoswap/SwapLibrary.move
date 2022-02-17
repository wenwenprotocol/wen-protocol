address 0x400000 {
module SwapLibrary {
    use 0x1::Token;
    use 0x1::Account;
    use 0x1::Signer;
    use 0x1::BCS;
    use 0x1::Compare;
    use 0x1::Math;
    use 0x400000::SwapConfig;

    const IDENTICAL_TOKEN: u64 = 300001;
    const INSUFFICIENT_AMOUNT: u64 = 300002;
    const INSUFFICIENT_LIQUIDITY: u64 = 300003;
    const INSUFFICIENT_INPUT_AMOUNT: u64 = 300004;
    const INSUFFICIENT_OUT_AMOUNT: u64 = 300005;
    
    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    public fun get_token_order<X: store, Y: store>(): u8 {
        let x_bytes = BCS::to_bytes<Token::TokenCode>(&Token::token_code<X>());
        let y_bytes = BCS::to_bytes<Token::TokenCode>(&Token::token_code<Y>());
        let order : u8 = Compare::cmp_bcs_bytes(&x_bytes, &y_bytes);
        assert(order != 0, IDENTICAL_TOKEN);
        order
    }

    // given some amount of an asset and pair reserves, returns an equivalent amount of the other asset
    public fun quote(amount_x: u128, reserve_x: u128, reserve_y: u128): u128 {
        assert(amount_x > 0, INSUFFICIENT_AMOUNT);
        assert(reserve_x > 0 && reserve_y > 0, INSUFFICIENT_LIQUIDITY);
        Math::mul_div(amount_x, reserve_y, reserve_x)
    }

    // accept token for swap
    public fun accept_token<TokenType: store>(signer: &signer) {
        let is_accept_token = Account::is_accepts_token<TokenType>(Signer::address_of(signer));
        if (!is_accept_token) {
            Account::do_accept_token<TokenType>(signer);
        };
    }

    // caculate amount out with exact in
    public fun get_amount_out(amount_in: u128, reserve_in: u128, reserve_out: u128): u128 {
        assert(amount_in > 0, INSUFFICIENT_INPUT_AMOUNT);
        assert(reserve_in > 0 && reserve_out > 0, INSUFFICIENT_LIQUIDITY);
        let (fee_rate, _) = SwapConfig::get_fee_config();
        let amount_in_with_fee = amount_in * (10000 - fee_rate);
        let denominator = reserve_in * 10000 + amount_in_with_fee;
        Math::mul_div(amount_in_with_fee, reserve_out, denominator)
    }

    // caculate amount in with exact out
    public fun get_amount_in(amount_out: u128, reserve_in: u128, reserve_out: u128): u128 {
        assert(amount_out > 0, INSUFFICIENT_OUT_AMOUNT);
        assert(reserve_in > 0 && reserve_out > 0, INSUFFICIENT_LIQUIDITY);
        let (fee_rate,_) = SwapConfig::get_fee_config();
        let denominator = (reserve_out - amount_out) * (10000 - fee_rate);
        Math::mul_div(reserve_in, amount_out * 10000, denominator) + 1
    }

}
}