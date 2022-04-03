// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;
import "forge-std/console.sol";

import {IProtocolDataProvider} from "../interfaces/aave/IProtocolDataProvider.sol";
import {StrategyFixture} from "./utils/StrategyFixture.sol";
import {Strategy} from "../Strategy.sol";

contract StrategyOperationsTest is StrategyFixture {
    // setup is run on before each test
    function setUp() public override {
        // setup vault
        super.setUp();
    }

    function testSetupVaultOK() public {
        console.log("address of vault", address(vault));
        assertTrue(address(0) != address(vault));
        assertEq(vault.token(), address(want));
        assertEq(vault.depositLimit(), type(uint256).max);
    }

    function testSetupStrategyOK() public {
        console.log("address of strategy", address(strategy));
        assertTrue(address(0) != address(strategy));
        assertEq(address(strategy.vault()), address(vault));
    }

    /// Test Operations
    function testOperation(uint256 _amount) public {
        vm_std_cheats.assume(_amount > minFuzzAmt && _amount < maxFuzzAmt);
        console.log("amount", _amount);
        tip(address(want), address(user), _amount);

        // Deposit to the vault
        uint256 balanceBefore = want.balanceOf(address(user));
        actions.userDeposit(user, vault, want, _amount);
        // Check if deposit went to the vault
        assertRelApproxEq(want.balanceOf(address(vault)), _amount, DELTA);

        // harvest
        vm_std_cheats.prank(user);
        vault.withdraw();
        assertRelApproxEq(want.balanceOf(user), balanceBefore, DELTA);
    }

    function testSweep(uint256 _amount) public {
        vm_std_cheats.assume(_amount > minFuzzAmt && _amount < maxFuzzAmt);
        tip(address(want), address(user), _amount);

        // Strategy want token doesn't work
        vm_std_cheats.prank(user);
        want.transfer(address(strategy), _amount);
        assertEq(address(want), address(strategy.want()));
        assertGt(want.balanceOf(address(strategy)), 0);
        vm_std_cheats.prank(gov);
        vm_std_cheats.expectRevert("!want");
        strategy.sweep(address(want));

        // Vault share token doesn't work
        vm_std_cheats.prank(gov);
        vm_std_cheats.expectRevert("!shares");
        strategy.sweep(address(vault));
    }
}
