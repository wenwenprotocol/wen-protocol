// Copyright (c) The Elements Studio Core Contributors
// SPDX-License-Identifier: Apache-2.0

address 0x100000 {
module TokenSwapFee {
    use 0x1::Account;
    use 0x1::Token;
    use 0x1::Event;
    use 0x100000::TokenSwapLibrary;
    use 0x100000::TokenSwapConfig;
    use 0x100000::TokenSwap::{Self};
    use 0x100000::MockToken::USD as XUSDT;

    const ERROR_ROUTER_SWAP_FEE_MUST_NOT_NEGATIVE: u64 = 1031;
    const ERROR_SWAP_INVALID_TOKEN_PAIR: u64 = 2000;

    /// Event emitted when token swap .
    struct SwapFeeEvent has drop, store {
        /// token code of X type
        x_token_code: Token::TokenCode,
        /// token code of X type
        y_token_code: Token::TokenCode,
        signer: address,
        fee_addree: address,
        swap_fee: u128,
        fee_out: u128,
    }

    struct TokenSwapFeeEvent has key, store {
        swap_fee_event: Event::EventHandle<SwapFeeEvent>,
    }

    /// Initialize token swap fee
    public fun initialize_token_swap_fee(signer: &signer) {
        init_swap_oper_fee_config(signer);

        move_to(signer, TokenSwapFeeEvent{
            swap_fee_event: Event::new_event_handle<SwapFeeEvent>(signer),
        });
    }

    /// init default operation fee config
    public fun init_swap_oper_fee_config(signer: &signer) {
        TokenSwapConfig::set_swap_fee_operation_rate(signer, 10, 60);
    }

    public fun handle_token_swap_fee<X: copy + drop + store, Y: copy + drop + store>(signer_address: address, token_x: Token::Token<X>
    ) acquires TokenSwapFeeEvent {
        intra_handle_token_swap_fee<X, Y, XUSDT>(signer_address, token_x)
    }


    /// X is token to pay for fee
    fun intra_handle_token_swap_fee<X: copy + drop + store,
                                    Y: copy + drop + store,
                                    FeeToken: copy + drop + store>(signer_address: address, token_x: Token::Token<X>
    ) acquires TokenSwapFeeEvent {
        let fee_address = TokenSwapConfig::fee_address();
        let (fee_handle, swap_fee, fee_out);
        // the token to pay for fee, is fee token
        if (Token::is_same_token<X, FeeToken>()) {
            (fee_handle, swap_fee, fee_out) = swap_fee_direct_deposit<X, Y>(token_x);
        } else {
            // check [X, FeeToken] token pair exist
            let fee_token_pair_exist = TokenSwap::swap_pair_exists<X, FeeToken>();
            let fee_address_accept_fee_token = Account::is_accepts_token<FeeToken>(fee_address);
            if (fee_token_pair_exist && fee_address_accept_fee_token) {
                (fee_handle, swap_fee, fee_out) = swap_fee_swap<X, FeeToken>(token_x);
            }else {
                // if fee address has not accept the token pay for fee, the swap fee will retention in LP pool
                (fee_handle, swap_fee, fee_out) = swap_fee_direct_deposit<X, Y>(token_x);
            };
        };
        if (fee_handle) {
            // fee token and the token to pay for fee compare
            let order = TokenSwap::compare_token<X, Y>();
            assert(order != 0, ERROR_SWAP_INVALID_TOKEN_PAIR);
            if (order == 1) {
                emit_swap_fee_event<X, Y>(signer_address, swap_fee, fee_out);
            }else {
                emit_swap_fee_event<Y, X>(signer_address, swap_fee, fee_out);
            };
        }
    }


    /// Emit swap fee event
    fun emit_swap_fee_event<X: copy + drop + store, Y: copy + drop + store>(
        signer_address: address,
        swap_fee: u128,
        fee_out: u128,
    ) acquires TokenSwapFeeEvent {
        let token_swap_fee_event = borrow_global_mut<TokenSwapFeeEvent>(TokenSwapConfig::admin_address());
        Event::emit_event(&mut token_swap_fee_event.swap_fee_event, SwapFeeEvent{
            x_token_code: Token::token_code<X>(),
            y_token_code: Token::token_code<Y>(),
            signer: signer_address,
            fee_addree: TokenSwapConfig::fee_address(),
            swap_fee,
            fee_out,
        });
    }

    fun swap_fee_direct_deposit<X: copy + drop + store, Y: copy + drop + store>(token_x: Token::Token<X>): (bool, u128, u128) {
        let fee_address = TokenSwapConfig::fee_address();
        if (Account::is_accepts_token<X>(fee_address)) {
            let x_value = Token::value(&token_x);
            Account::deposit(fee_address, token_x);
            (true, x_value, x_value)
            //if swap fee deposit to fee address fail, return back to lp pool
        } else {
            let order = TokenSwap::compare_token<X, Y>();
            assert(order != 0, ERROR_SWAP_INVALID_TOKEN_PAIR);
            if (order == 1) {
                TokenSwap::return_back_to_lp_pool<X, Y>(token_x, Token::zero());
            } else {
                TokenSwap::return_back_to_lp_pool<Y, X>(Token::zero(), token_x);
            };
            (false, 0, 0)
        }
    }

    fun swap_fee_swap<X: copy + drop + store, FeeToken: copy + drop + store>(token_x: Token::Token<X>): (bool, u128, u128) {
        let x_value = Token::value(&token_x);
        // just return, not assert error
        if (x_value == 0) {
            Token::destroy_zero(token_x);
            return (false, 0, 0)
        };

        let fee_address = TokenSwapConfig::fee_address();
        let order = TokenSwap::compare_token<X, FeeToken>();
        assert(order != 0, ERROR_SWAP_INVALID_TOKEN_PAIR);
        let (fee_numberator, fee_denumerator) = TokenSwapConfig::get_poundage_rate<X, FeeToken>();
        let (reserve_x, reserve_fee) = TokenSwap::get_reserves<X, FeeToken>();
        let fee_out = TokenSwapLibrary::get_amount_out(x_value, reserve_x, reserve_fee, fee_numberator, fee_denumerator);
        let (token_x_out, token_fee_out);
        let (token_x_fee, token_fee_fee);
        if (order == 1) {
            (token_x_out, token_fee_out, token_x_fee, token_fee_fee) = TokenSwap::swap<X, FeeToken>(token_x, fee_out, Token::zero(), 0);
        } else {
            (token_fee_out, token_x_out, token_fee_fee, token_x_fee) = TokenSwap::swap<FeeToken, X>(Token::zero(), 0, token_x, fee_out);
        };
        Token::destroy_zero(token_x_out);
        Account::deposit(fee_address, token_fee_out);
        Token::destroy_zero(token_fee_fee);
        swap_fee_direct_deposit<X, FeeToken>(token_x_fee);
        (true, x_value, fee_out)
    }
}
}
