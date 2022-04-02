// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;

import {Strategy} from "../Strategy.sol";
import {StrategyFixture} from "./utils/StrategyFixture.sol";

import {DAIAaveFactory} from "../DAIAaveFactory.sol";

contract StrategyFreeFunds is StrategyFixture {
    function setUp() public override {
        super.setUp();
    }

    // Test if freeing funds from old strategy works
    function testFreeFunds(uint256 _amount) public {
        vm_std_cheats.assume(_amount > minFuzzAmt && _amount < maxFuzzAmt);
        tip(address(want), user, _amount);

        // uint256 balanceBefore = want.balanceOf(user);
        actions.userDeposit(user, vault, want, _amount);

        // free funds from old strategy
        vm_std_cheats.prank(gov);
        vault.revokeStrategy(address(strategy));
        skip(1);
        vm_std_cheats.prank(gov);
        strategy.harvest();
        assertLt(strategy.estimatedTotalAssets(), strategy.minWantToDeposit());
    }
}
