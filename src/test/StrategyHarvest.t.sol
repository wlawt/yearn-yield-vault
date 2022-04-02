// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;

import {Strategy} from "../Strategy.sol";
import {StrategyFixture} from "./utils/StrategyFixture.sol";

import {DAIAaveFactory} from "../DAIAaveFactory.sol";

contract StrategyHarvest is StrategyFixture {
    function setUp() public override {
        super.setUp();
    }

    // Test if Estimate Total Assets is correct
    function testHarvest(uint256 _amount) public {
        vm_std_cheats.assume(_amount > minFuzzAmt && _amount < maxFuzzAmt);
        tip(address(want), user, _amount);

        // uint256 balanceBefore = want.balanceOf(user);
        actions.userDeposit(user, vault, want, _amount);

        // harvest
        skip(1);
        vm_std_cheats.prank(strategist);
        strategy.harvest();
        assertRelApproxEq(strategy.estimatedTotalAssets(), _amount, DELTA);
    }
}
