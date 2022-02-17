address 0x100000 {
module SafeMath {
    use 0x1::Math;
    use 0x1::Errors;

    const EXP_SCALE_9: u128 = 1000000000;// e9
    const EXP_SCALE_10: u128 = 10000000000;// e10
    const EXP_SCALE_18: u128 = 1000000000000000000;// e18
    const U64_MAX:u64 = 18446744073709551615;  //length(U64_MAX)==20
    const U128_MAX:u128 = 340282366920938463463374607431768211455;  //length(U128_MAX)==39

    const EQUAL: u8 = 0;
    const LESS_THAN: u8 = 1;
    const GREATER_THAN: u8 = 2;

    const OVER_FLOW: u64 = 1001;
    const DIVIDE_BY_ZERO: u64 = 1002;

    /// support 18-bit precision token
    /// if token is limited release, the total capacity around e10 (almost ten billions)
    /// can avoid x*y/z overflow, and at the same time avoid loss presicion
    public fun safe_mul_div(x: u128, y: u128, z: u128): u128 {
        if ( z == 0) {
            abort Errors::invalid_argument(DIVIDE_BY_ZERO)
        };
        if (x <= EXP_SCALE_18 && y <= EXP_SCALE_18) {
            return x * y / z
        };
        if (x >= z || y >= z) {
            return Math::mul_div(x, y, z)
        };

        if (x >= y) {
            x = x * EXP_SCALE_10;
        } else {
            y = y * EXP_SCALE_10;
        };
        let r = Math::mul_div(x, y, z);
        r / EXP_SCALE_10
    }

    /// support 18-bit precision token
    /// if token is limited release, the total capacity around e10 (almost ten billions)
    /// can avoid x1*y1 compare x2*y2 overflow, and at the same time avoid loss presicion
    public fun safe_compare(x1: u128, y1: u128, x2: u128, y2: u128): u8 {
        let (r1, r2);
        if (x1 <= EXP_SCALE_18 && y1 <= EXP_SCALE_18 && x2 <= EXP_SCALE_18 && y2 <= EXP_SCALE_18) {
            r1 = x1 * y1;
            r2 = x2 * y2;
        } else {
            r1 = safe_mul_div(x1, y1, EXP_SCALE_18);
            r2 = safe_mul_div(x2, y2, EXP_SCALE_18);
            if (r1 == 0 && r2 == 0 ){
                r1 = x1 * y1;
                r2 = x2 * y2;
            };
        };

        if (r1 == r2) EQUAL
        else if (r1 < r2) LESS_THAN
        else GREATER_THAN
    }

    public fun safe_more_than_or_equal(x1: u128, y1: u128, x2: u128, y2: u128): bool {
        let r_order = safe_compare(x1, y1, x2, y2);
        if(EQUAL == r_order || GREATER_THAN == r_order){
            true
        } else {
            false
        }
    }

    /// support 18-bit precision token
    /// if token is limited release, the total capacity around e10 (almost ten billions)
    /// can avoid  sqrt(x*y) overflow, and at the same time avoid loss presicion
    public fun safe_mul_sqrt(x: u128, y: u128): u128 {
        if (x <= EXP_SCALE_18 && y <= EXP_SCALE_18) {
            (Math::sqrt(x * y) as u128)
        }else {
            // sqrt(x*y) == sqrt(x) * sqrt(y)
            let r = safe_mul_div(x, y ,EXP_SCALE_18);
            (Math::sqrt(r) as u128) * EXP_SCALE_9
        }
    }
}
}
