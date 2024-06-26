#[test_only]
module fox_swap::fox_swap_tests {
    use fox_swap::fox_swap;
    use fox_swap::fox_lottery;
    use sui::coin;
    use sui::test_scenario;
    use sui::math;
    use sui::sui::SUI;
    use sui::clock;
    use sui::random;
    use fox_coin::fox_coin::FOX_COIN;

    const ELpAmountInvalid: u64 = 1;

    const FoxCreateAmount: u64 = 5000000000000;
    const SuiCreateAmount: u64 = 1000000000000;
    const FoxAddAmount: u64 = 500000000000;
    const SuiAddAmount: u64 = 100000000000;

    const LotteryPoolCreateAmount: u64 = 5000000000000;
    const LotteryPoolAddAmount: u64 = 5000000000000;

    const PUBLIC_KEY: vector<u8> = x"1a90ed7e9e18a9f2db1f7fbabfe002745000b19b44fd68d87d97c6785460714e";
    const ECVRF_POOL_A_PROOF: vector<u8> = x"f82429bb25385cf60e14c5c160d4fb0614c64923308c83e3c2bd9da36efeb63ad594442fcf2f47e82fbc176f5993715999176bc16f699ea3955df3d2a439a7728c95fa324906306c44ff6f0df2833e00";
    const ECVRF_POOL_A_OUTPUT: vector<u8> = x"87cb7951dbb68b628a6fda43236de3544e4a8d70a77b6390e0d1743b1b57091563b5721a15de4befe0247fb06c853ebe13e217ea730e010a9eef4b7544e06a8e";
    const ECVRF_POOL_B_PROOF: vector<u8> = x"a43b26ec680e6ee9d89562ac2c0189e727917292c7df5bee67a82771de953602125aea95c47ff4c1e9ce17a15c2c261ea581645688446f9090b9647270e02b4ef0497dcd4316cc79e04a6c066c5aae08";
    const ECVRF_POOL_B_OUTPUT: vector<u8> = x"2088802416d14daa7419b928cf6d6a8df610bf7ce5ee6babe87ef3a2d9e210070d9341fe9eac45bccfd8be093d2f0ee250503850c60478f527fb1de1bbab836c";

    #[test]
    fun test_fox_swap() {
        let jason = @0x11;
        let alice = @0x22;

        let mut scenario_val = test_scenario::begin(jason);
        let scenario = &mut scenario_val;
        let mut clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, jason);
        {
            clock.increment_for_testing(42);
            let coin_a = coin::mint_for_testing<FOX_COIN>(FoxCreateAmount, test_scenario::ctx(scenario));
            let coin_b = coin::mint_for_testing<SUI>(SuiCreateAmount, test_scenario::ctx(scenario));
            fox_swap::create_swap_pool(coin_a, coin_b, &clock, test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, alice);
        {
            let mut pool = test_scenario::take_shared<fox_swap::Pool<FOX_COIN, SUI>>(scenario);
            let pool_ref = &mut pool;

            let coin_b2 = coin::mint_for_testing<SUI>(SuiAddAmount, test_scenario::ctx(scenario));
            fox_swap::swap_coin_b_to_coin_a(pool_ref, coin_b2, test_scenario::ctx(scenario));

            test_scenario::return_shared(pool);
        };

        test_scenario::next_tx(scenario, alice);
        {
            let mut pool = test_scenario::take_shared<fox_swap::Pool<FOX_COIN, SUI>>(scenario);
            let pool_ref = &mut pool;

            let coin_a2 = test_scenario::take_from_sender<coin::Coin<FOX_COIN>>(scenario);
            let coin_b2 = coin::mint_for_testing<SUI>(SuiAddAmount, test_scenario::ctx(scenario));
            fox_swap::add_liquidity(pool_ref, coin_a2, coin_b2, &clock, test_scenario::ctx(scenario));

            test_scenario::return_shared(pool);
        };

        clock.destroy_for_testing();
        test_scenario::end(scenario_val);
    }


    #[test]
    fun test_fox_lp() {
        let jason = @0x11;
        let alice = @0x22;

        let mut scenario_val = test_scenario::begin(jason);
        let scenario = &mut scenario_val;
        let mut clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, jason);
        {
            clock.increment_for_testing(42);
            let coin_a = coin::mint_for_testing<FOX_COIN>(FoxCreateAmount, test_scenario::ctx(scenario));
            let coin_b = coin::mint_for_testing<SUI>(SuiCreateAmount, test_scenario::ctx(scenario));
            fox_swap::create_swap_pool(coin_a, coin_b, &clock, test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, alice);
        {
            let mut pool = test_scenario::take_shared<fox_swap::Pool<FOX_COIN, SUI>>(scenario);
            let pool_ref = &mut pool;

            let coin_a2 = coin::mint_for_testing<FOX_COIN>(FoxAddAmount, test_scenario::ctx(scenario));
            let coin_b2 = coin::mint_for_testing<SUI>(SuiAddAmount, test_scenario::ctx(scenario));
            fox_swap::add_liquidity(pool_ref, coin_a2, coin_b2, &clock, test_scenario::ctx(scenario));

            // next epoch
            test_scenario::ctx(scenario).increment_epoch_number();

            let lottery_type = 1; // instant lottery
            fox_swap::get_daily_coupon(pool_ref, lottery_type, test_scenario::ctx(scenario));

            test_scenario::return_shared(pool);
        };

        test_scenario::next_tx(scenario, alice);
        {
            let coupon = test_scenario::take_from_sender<fox_swap::Coupon>(scenario);
            let lp_amount = fox_swap::get_coupon_lp_amount(&coupon);
            let pool_new_lp_amount = math::sqrt(FoxCreateAmount + FoxAddAmount) * math::sqrt(SuiCreateAmount + SuiAddAmount);
            let pool_old_lp_amount = math::sqrt(FoxCreateAmount) * math::sqrt(SuiCreateAmount);
            let expected_lp_amount = pool_new_lp_amount - pool_old_lp_amount;
            assert!(lp_amount == expected_lp_amount, ELpAmountInvalid);
            test_scenario::return_to_sender(scenario, coupon);
        };

        clock.destroy_for_testing();
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_fox_lottery_pool_a() {
        let jason = @0x0;
        let alice = @0x22;

        let mut scenario_val = test_scenario::begin(jason);
        let scenario = &mut scenario_val;
        let mut clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, jason);
        {
            random::create_for_testing(test_scenario::ctx(scenario));
            let coin = coin::mint_for_testing<FOX_COIN>(LotteryPoolCreateAmount, test_scenario::ctx(scenario));
            let public_key = PUBLIC_KEY;
            fox_lottery::create_lottery_pool_a(coin, public_key, test_scenario::ctx(scenario));

            clock.increment_for_testing(42);
            let coin_a = coin::mint_for_testing<FOX_COIN>(FoxCreateAmount, test_scenario::ctx(scenario));
            let coin_b = coin::mint_for_testing<SUI>(SuiCreateAmount, test_scenario::ctx(scenario));
            fox_swap::create_swap_pool(coin_a, coin_b, &clock, test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, alice);
        {
            let r = test_scenario::take_shared<random::Random>(scenario);
            let mut lottery_pool_a = test_scenario::take_shared<fox_lottery::LotteryPoolA<FOX_COIN>>(scenario);
            let lottery_pool_ref = &mut lottery_pool_a;

            let swap_pool = test_scenario::take_shared<fox_swap::Pool<FOX_COIN, SUI>>(scenario);

            let coin2 = coin::mint_for_testing<FOX_COIN>(LotteryPoolAddAmount, test_scenario::ctx(scenario));
            fox_lottery::add_pool_a_bonous(lottery_pool_ref, coin2, test_scenario::ctx(scenario));

            let ecvrf_proof = ECVRF_POOL_A_PROOF;
            let ecvrf_output = ECVRF_POOL_A_OUTPUT;
            let coupon = fox_swap::get_coupon_for_testing(328474789, 1, 99999999999, 100, test_scenario::ctx(scenario));
            fox_lottery::draw_pool_a_instant_lottery(coupon, &swap_pool, lottery_pool_ref,
                     ecvrf_output, ecvrf_proof, &r, test_scenario::ctx(scenario));

            test_scenario::return_shared(r);
            test_scenario::return_shared(lottery_pool_a);
            test_scenario::return_shared(swap_pool);
        };

        clock.destroy_for_testing();
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_fox_lottery_pool_b() {
        let jason = @0x0;
        let alice = @0x22;
        let jack = @0x33;

        let mut scenario_val = test_scenario::begin(jason);
        let scenario = &mut scenario_val;
        let mut clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, jason);
        {
            random::create_for_testing(test_scenario::ctx(scenario));
            let coin = coin::mint_for_testing<FOX_COIN>(LotteryPoolCreateAmount, test_scenario::ctx(scenario));
            let public_key = PUBLIC_KEY;
            fox_lottery::create_lottery_pool_b(coin, public_key, test_scenario::ctx(scenario));

            // next epoch
            test_scenario::ctx(scenario).increment_epoch_number();

            clock.increment_for_testing(42);
            let coin_a = coin::mint_for_testing<FOX_COIN>(FoxCreateAmount, test_scenario::ctx(scenario));
            let coin_b = coin::mint_for_testing<SUI>(SuiCreateAmount, test_scenario::ctx(scenario));
            fox_swap::create_swap_pool(coin_a, coin_b, &clock, test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, alice);
        {
            let mut lottery_pool_b = test_scenario::take_shared<fox_lottery::LotteryPoolB<FOX_COIN>>(scenario);
            let lottery_pool_ref = &mut lottery_pool_b;

            let coupon = fox_swap::get_coupon_for_testing(328474789, 2, 99999999999, 100, test_scenario::ctx(scenario));
            fox_lottery::place_bet_to_pool_b(coupon, lottery_pool_ref, test_scenario::ctx(scenario));

            test_scenario::return_shared(lottery_pool_b);
        };

        test_scenario::next_tx(scenario, jack);
        {
            let mut lottery_pool_b = test_scenario::take_shared<fox_lottery::LotteryPoolB<FOX_COIN>>(scenario);
            let lottery_pool_ref = &mut lottery_pool_b;

            let coupon = fox_swap::get_coupon_for_testing(328474790, 2, 10000000000, 100, test_scenario::ctx(scenario));
            fox_lottery::place_bet_to_pool_b(coupon, lottery_pool_ref, test_scenario::ctx(scenario));

            test_scenario::return_shared(lottery_pool_b);
        };

        test_scenario::next_tx(scenario, jason);
        {
            let admin_cap = test_scenario::take_from_sender<fox_lottery::PoolBAdminCap>(scenario);
            let r = test_scenario::take_shared<random::Random>(scenario);
            let mut lottery_pool_b = test_scenario::take_shared<fox_lottery::LotteryPoolB<FOX_COIN>>(scenario);
            let swap_pool = test_scenario::take_shared<fox_swap::Pool<FOX_COIN, SUI>>(scenario);

            let ecvrf_proof = ECVRF_POOL_B_PROOF;
            let ecvrf_output = ECVRF_POOL_B_OUTPUT;
            fox_lottery::pool_b_close_betting(&admin_cap, &mut lottery_pool_b, test_scenario::ctx(scenario));
            fox_lottery::pool_b_draw_and_distrubute(&admin_cap, &swap_pool, &mut lottery_pool_b, ecvrf_output, ecvrf_proof, &r, test_scenario::ctx(scenario));

            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(r);
            test_scenario::return_shared(lottery_pool_b);
            test_scenario::return_shared(swap_pool);
        };

        clock.destroy_for_testing();
        test_scenario::end(scenario_val);
    }
}
