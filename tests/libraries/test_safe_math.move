//! account: alice, 10000000000000 0x1::STC::STC

//! new-transaction
// check: EXECUTED
//! sender: alice
script {
    use 0x1::Math;
    use 0x100000::SafeMath;

    // case : x*y/z overflow
    fun main(_: signer) {
        let scaling_factor = Math::pow(10, 18);
        let amount_x: u128 = 1000000000;
        let reserve_y: u128 = 50000;
        let reserve_x: u128 = 20000000 * scaling_factor;

        // overflow: 1000000000 * 50000 / (20000000 * 10 ** 18) = 5 * 10 ** 13 / 2 * 10 ** 25 = 0
        assert(SafeMath::safe_mul_div(amount_x, reserve_y, reserve_x) == 0, 3003);
        // 1000000000 * 20000000 * 10 ** 18 / 50000 = 2 * 10 ** 34 / 5 * 10 ** 4
        assert(SafeMath::safe_mul_div(amount_x, reserve_x, reserve_y) == 4 * Math::pow(10, 29), 3004);
    }
}

//! new-transaction
// check: EXECUTED
//! sender: alice
script {
    use 0x1::Math;
    use 0x100000::SafeMath;

    // case : x*y/z overflow
    fun main(_: signer) {
        let scaling_factor = Math::pow(10, 18);
        let amount_x: u128 = 110000 * scaling_factor;
        let reserve_y: u128 = 8000000 * scaling_factor;
        let reserve_x: u128 = 2000000 * scaling_factor;

        assert(SafeMath::safe_mul_div(amount_x, reserve_y, reserve_x) == 440000 * scaling_factor, 3003);
        assert(SafeMath::safe_mul_div(amount_x, reserve_x, reserve_y) == 27500 * scaling_factor, 3004);
    }
}

//! new-transaction
// check: EXECUTED
//! sender: alice
script {
    use 0x1::Math;
    use 0x100000::SafeMath;

    // case : x*y/z overflow
    fun main(_: signer) {
        let scaling_factor_9 = Math::pow(10, 9);
        let scaling_factor_18 = Math::pow(10, 18);
        let amount_x: u128 = 1100;
        let reserve_y: u128 = 8 * scaling_factor_9;
        let reserve_x: u128 = 2000000 * scaling_factor_18;

        assert(SafeMath::safe_mul_div(amount_x, reserve_y, reserve_x) == 0 * scaling_factor_9, 3006);
        assert(SafeMath::safe_mul_div(amount_x, reserve_x, reserve_y) == 275000000 * scaling_factor_9, 3007);
    }
}

//! new-transaction
// check: EXECUTED
//! sender: alice
script {
    use 0x1::Math;
    use 0x100000::SafeMath;

    // case : x*y/z overflow
    fun main(_: signer) {
        let scaling_factor_18 = Math::pow(10, 18);
        let amount_x: u128 = 1999;
        let reserve_y: u128 = 37;
        let reserve_x: u128 = 1000;

        // 1999 * 10 ** 18 / 1000 * 10 ** 18 * 37 = 1999 / 1000 * 37  = 1 * 37 = 37
        let amount_y_2_loss_precesion = (amount_x * scaling_factor_18) / (reserve_x * scaling_factor_18) * reserve_y;
        assert(amount_y_2_loss_precesion == 37, 3010);
        // 1999 * 37 / 1000 = 73963 / 1000 = 73
        assert(SafeMath::safe_mul_div(amount_x, reserve_y, reserve_x) == 73, 3008);
        assert(SafeMath::safe_mul_div(amount_x * scaling_factor_18, reserve_y, reserve_x * scaling_factor_18) == 73, 3009);
    }
}

//! new-transaction
// check: EXECUTED
//! sender: alice
script {
    use 0x1::Math;
    use 0x100000::SafeMath;

    // case : x*y/z overflow
    fun main(_: signer) {
        let scaling_factor_9 = Math::pow(10, 9);
        let scaling_factor_18 = Math::pow(10, 18);
        let x1: u128 = 1100;
        let y1: u128 = 8 * scaling_factor_9;
        let x2: u128 = 2000000 * scaling_factor_18;
        let y2: u128 = 4000000 * scaling_factor_18;

        // equal = 0 | lessthan =1 | greatthan = 2
        // x1 * y1 = 8800 * 10 ** 9 | x2 * y2 = 8 * 10 ** 12 * 10 ** 18
        assert(SafeMath::safe_compare(x1, y1, x2, y2) == 1, 10001);
        // x1 * y1 = 8800 * 10 ** 9 * 10 ** 36 | x2 * y2 = 8 * 10 ** 12 * 10 ** 18
        assert(SafeMath::safe_compare(x1 * scaling_factor_18, y1 * scaling_factor_18, x2, y2) == 2, 10002);
        // x1 * y1 = 8800 * 10 ** 9 | x2 * y2 = (2 * 10 ** 24 / 10 ** 9) * (4 * 10 ** 24 / 10 ** 9) = 8 * 10 ** 30
        assert(SafeMath::safe_compare(x1, y1, x2 / scaling_factor_9, y2 / scaling_factor_9) == 1, 10003);
    }
}


//! new-transaction
// check: EXECUTED
//! sender: alice
script {
    use 0x1::Math;
    use 0x100000::SafeMath;

    // case : x*y/z overflow
    fun main(_: signer) {
        let scaling_factor_9 = Math::pow(10, 9);
        let scaling_factor_18 = Math::pow(10, 18);

        let x: u128 = 2000000 * scaling_factor_18; // 2 * e24
        let y: u128 = 2000000 * scaling_factor_18;
        let x1: u128 = 1000;
        let y1: u128 = 9 * scaling_factor_9;

        assert(SafeMath::safe_mul_sqrt(x, y) == 2 * Math::pow(10, 24), 20001);
        assert(SafeMath::safe_mul_sqrt(x1, y1) == 3 * Math::pow(10, 6), 20002);
        // sqrt(9000)
        assert(SafeMath::safe_mul_sqrt(x1, y1 / scaling_factor_9) == (Math::sqrt(9000) as u128), 20003);
    }
}
