## Yearn vault strategy

A basic concept of using Yearn strategies to generate yield on DAI. As one of my first Solidity projects,
I wanted to get an understanding of the DeFi ecosystem, and the Yearn docs and GitHub was a good place
for me to start. The code was forked from [storming0x](https://github.com/storming0x/foundry-yearnV2-gen-lev-lending) and uses the [brownie strategy mix](https://github.com/yearn/brownie-strategy-mix) that the Yearn team put together to use as a template. Additional resources that I used can be found in the resource section below.

## The strategy

The strategy itself is pretty straightforward. A user has some DAI that they want to deposit into the yvDAI vault. The vault has many strategies, one of the strategy is to take the DAI and lend it to Aave through the Aave Lending Pools. The user is able to earn yield from this over time.

## Next steps

There's a lot that can be added. Some quick thoughts. The DAI can be used as collateral to purchase FXS. The FXS can be locked with Convex in exchange for cvxFXS, which can be deposited into the cvxFXS pool on Curve (~0.98% base + 4.14% boost). The same can be done for rETH (0.96% base + 1.57% boost). However, price action volatility should be considered for lower market-cap assets like Frax when determining the appropriate borrowing ratio. Other options could include the [bean.money](bean.money) protocol where DAI can be swapped for $BEAN, a decentralized credit-based algostable coin (~60% vAPY).

## Installation and Setup

1. To install with [Foundry](https://github.com/gakonst/foundry).

2. Fork this repository and create a new repository using it as template. [Create from template](https://docs.github.com/en/repositories/creating-and-managing-repositories/creating-a-repository-from-a-template)

3. Clone your newly created repository recursively to include modules.

```sh
git clone --recursive https://github.com/myuser/foundry-yearn-strategy

cd foundry-yearn-strategy
```

4. Build the project.

```sh
make build
```

5. Sign up for [Infura](https://infura.io/) and generate an API key and copy your RPC url. Store it in the `ETH_RPC_URL` environment variable.
NOTE: you can use other services.

6. Use .env file
  1. Make a copy of `.env.example`
  2. Add the values for `ETH_RPC_URL` and other example vars
     NOTE: If you set up a global environment variable, that will take precedence

## Testing

To run the tests:

```
make test
```

to run tests with traces (using console.sol):

```
make trace
```

## Resources

- [StrategyDAICurve Yearn v1 Vault](https://github.com/yearn/yearn-protocol/blob/develop/contracts/strategies/StrategyDAICurve.sol)
- [Yearn Vaults](https://vaults.yearn.finance/ethereum/stables)
- [Article](https://medium.com/yearn-state-of-the-vaults/the-vaults-at-yearn-9237905ffed3) of all the Yearn Vaults
- [Deploying a new Strategy](https://docs.yearn.finance/developers/v2/DEPLOYMENT)
- [Foundry Toolkit](https://github.com/gakonst/foundry)
