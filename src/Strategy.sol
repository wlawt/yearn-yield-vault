// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.12;
pragma experimental ABIEncoderV2;

// These are the core Yearn libraries
import {BaseStrategy} from "@yearnvaults/contracts/BaseStrategy.sol";

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "@openzeppelin/contracts/utils/math/Math.sol";

import "./interfaces/uniswap/IUni.sol";
import {ISwapRouter} from "./interfaces/uniswap/ISwapRouter.sol";

import "./interfaces/aave/ILendingPool.sol";
import "./interfaces/aave/IAToken.sol";
import "./interfaces/aave/IProtocolDataProvider.sol";

/*
    Strategy is supply DAI to AAVE pool to collect yield
*/
contract Strategy is BaseStrategy {
    using SafeERC20 for IERC20;
    using Address for address;

    // AAVE protocol address
    ILendingPool private constant lendingPool =
        ILendingPool(0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9);
    IProtocolDataProvider private constant protocolDataProvider =
        IProtocolDataProvider(0x057835Ad21a177dbdd3090bB1CAE03EaCF78Fc6d);

    // Token addresses
    address private constant aave = 0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9;
    address private constant weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address private constant dai = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

    // Supply token
    IAToken public aToken;

    // AMM routers
    ISwapRouter private constant UNI_V3_ROUTER =
        ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    IUni private constant UNI_V2_ROUTER =
        IUni(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

    enum SwapRouter {
        UniV3,
        UniV2
    }
    SwapRouter public swapRouter = SwapRouter.UniV3;

    uint256 private DECIMALS;
    uint16 private constant referralCode = 7; // Yearn's AAVE referral code

    // For deposit and selling minimums
    uint256 public constant minWantToDeposit = 100;
    uint256 public constant minRewardAmountToSell = 1e15;

    // Swap constants
    uint24 public constant aaveToWethSwapFee = 3000;
    uint24 public constant wethToWantSwapFee = 3000;

    constructor(address _vault) public BaseStrategy(_vault) {
        _initializeStrategy();
    }

    function initialize(
        address _vault,
        address _strategist,
        address _rewards,
        address _keeper
    ) external {
        _initialize(_vault, _strategist, _rewards, _keeper);
        _initializeStrategy();
    }

    function _initializeStrategy() internal {
        (address _aToken, , ) = protocolDataProvider.getReserveTokensAddresses(
            address(want)
        );

        aToken = IAToken(_aToken);

        // approve use of tokens for the AAVE lending pool
        approveMaxSpend(address(want), address(lendingPool));
        approveMaxSpend(address(aToken), address(lendingPool));

        // approve use of tokens for Uniswap
        approveMaxSpend(aave, address(UNI_V3_ROUTER));
    }

    function name() external view override returns (string memory) {
        return "StrategyDAIAAVE-Lending";
    }

    function estimatedTotalAssets() public view override returns (uint256) {
        uint256 balanceExcludingRewards = balanceOfWant() + getCurrentSupply();
        return balanceExcludingRewards;
    }

    function prepareReturn(uint256 _debtOutstanding)
        internal
        override
        returns (
            uint256 _profit,
            uint256 _loss,
            uint256 _debtPayment
        )
    {
        // Claim & sell the rewards;
        _claimAndSellRewards();

        uint256 totalDebt = vault.strategies(address(this)).totalDebt;

        uint256 supply = getCurrentSupply();
        uint256 totalAssets = balanceOfWant() + supply;

        // Calculate PnL
        if (totalDebt > totalAssets) {
            unchecked {
                _loss = totalDebt - totalAssets;
            }
        } else {
            unchecked {
                _profit = totalAssets - totalDebt;
            }
        }
    }

    function adjustPosition(uint256 _debtOutstanding) internal override {
        uint256 wantBalance = balanceOfWant();
        uint256 availableCollateral = wantBalance - _debtOutstanding;

        // Deposit any extra collateral
        if (
            wantBalance > _debtOutstanding &&
            availableCollateral > minWantToDeposit
        ) {
            _depositCollateral(availableCollateral);
        }
    }

    function liquidatePosition(uint256 _amountNeeded)
        internal
        override
        returns (uint256 _liquidatedAmount, uint256 _loss)
    {
        return (_amountNeeded, 0);
    }

    function liquidateAllPositions()
        internal
        override
        returns (uint256 _amountFreed)
    {
        (_amountFreed, ) = liquidatePosition(type(uint256).max);
    }

    function prepareMigration(address _newStrategy) internal override {
        require(
            getCurrentSupply() < minWantToDeposit,
            "Transfer needs to be above minimum threshold of 100 DAI"
        );
        uint256 totalAssets = balanceOfWant() + getCurrentSupply();
        // Might not work
        vault.transfer(_newStrategy, totalAssets);
    }

    function protectedTokens()
        internal
        view
        override
        returns (address[] memory)
    {
        address[] memory protected = new address[](1);
        protected[0] = aave;
    }

    function ethToWant(uint256 _amtInWei)
        public
        view
        virtual
        override
        returns (uint256)
    {
        // TODO create an accurate price oracle
        return _amtInWei;
        // weth, _amtInWei

        if (_amtInWei == 0) return _amtInWei;

        IUni routerV2 = UNI_V2_ROUTER;
        address[] memory _path = new address[](2);
        _path[0] = weth;
        _path[1] = address(want);
        uint256[] memory amounts = routerV2.getAmountsOut(_amtInWei, _path);

        return amounts[amounts.length - 1];
    }

    /*


            HELPERS


    */

    function _depositCollateral(uint256 amount) internal returns (uint256) {
        if (amount == 0) return 0;
        lendingPool.deposit(address(want), amount, address(this), referralCode);
        return amount;
    }

    function _withdrawCollteral(uint256 amount) internal returns (uint256) {
        if (amount == 0) return 0;
        lendingPool.withdraw(address(want), amount, address(this));
        return amount;
    }

    function approveMaxSpend(address token, address spender) internal {
        IERC20(token).safeApprove(spender, type(uint256).max);
    }

    function balanceOfWant() internal view returns (uint256) {
        return want.balanceOf(address(this));
    }

    function getCurrentSupply() public view returns (uint256 _deposits) {
        _deposits = aToken.balanceOf(address(this));
        return _deposits;
    }

    function _claimAndSellRewards() internal returns (uint256) {
        // sell AAVE for want
        // we earn "want" + AAVE (boosted rewards)
        uint256 aaveBalance = IERC20(aave).balanceOf(address(this));
        if (aaveBalance >= minRewardAmountToSell) {
            _sellAAVEForWant(aaveBalance, 0);
        }
    }

    function _sellAAVEForWant(uint256 amountIn, uint256 minOut) internal {
        if (amountIn == 0) return;

        bytes memory _path = abi.encodePacked(
            address(aave),
            aaveToWethSwapFee,
            address(weth),
            wethToWantSwapFee,
            address(want)
        );

        UNI_V3_ROUTER.exactInput(
            ISwapRouter.ExactInputParams(
                _path,
                address(this),
                block.timestamp,
                amountIn,
                minOut
            )
        );
    }
}
