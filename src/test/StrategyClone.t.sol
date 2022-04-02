// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;

import {Strategy} from "../Strategy.sol";
import {StrategyFixture} from "./utils/StrategyFixture.sol";

import {DAIAaveFactory} from "../DAIAaveFactory.sol";

contract StrategyClone is StrategyFixture {
    function setUp() public override {
        super.setUp();
    }

    function testClone(uint256 _amount) public {
        vm_std_cheats.assume(_amount > minFuzzAmt && _amount < maxFuzzAmt);
        tip(address(want), user, _amount);

        actions.userDeposit(user, vault, want, _amount);

        vm_std_cheats.prank(strategist);
        Strategy clonedStrategy = Strategy(
            daiAaveFactory.cloneDAIAave(address(vault))
        );

        // free funds from old strategy
        vm_std_cheats.prank(gov);
        vault.revokeStrategy(address(strategy));
        skip(1);
        vm_std_cheats.prank(gov);
        strategy.harvest();
        assertLt(strategy.estimatedTotalAssets(), strategy.minWantToDeposit());

        // take funds to new strategy
        vm_std_cheats.prank(gov);
        vault.addStrategy(
            address(clonedStrategy),
            10_000,
            0,
            type(uint256).max,
            1_000
        );
        tip(address(weth), whale, 1e6);
        vm_std_cheats.prank(whale);
        weth.transfer(address(clonedStrategy), 1e6);
        skip(1);
        vm_std_cheats.prank(gov);
        clonedStrategy.harvest();
        assertRelApproxEq(
            clonedStrategy.estimatedTotalAssets(),
            _amount,
            DELTA
        );
    }
}
