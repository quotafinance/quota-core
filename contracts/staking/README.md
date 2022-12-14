# Staking Contracts

This folder contains the contracts that are used for both initial and perpetual staking pools.

LPTokenWrapper - This contract is used by the Token Rewards contract to keep track of the staked balances, lock duration, unlock time and balance amount of LP tokens staked on the contract. These values are tracked and used for calculating the amount of staking rewards that need to be distributed per user and when they are allowed to remove their staked amounts.

StakingWhitelist - This is standard Role contract using open zeppelin, it is used to add the whitelisting feature to the Staking pool contracts.