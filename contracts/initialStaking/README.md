# Initial Staking Pool Contracts

These are the contracts used for QUOTA's intial fair distribution pools.


Escrow Token - This token is used as a placeholder for the staking pool and used for calculating the amount of rewards the user has accrued.

Notifier - This contract notifiers the staking pools to start distributing rewards, loads up the escrow with 4.0 tokens and tracks all the staked and unstaked events from all the Staking pools. (Both intial and perpetual).

Token Rewards - This is the main staking contract where the users are able to stake their LP token and start getting rewards. This is loaded with Escrow tokens to help keep track of the users rewards. When the user claims their rewards, it notifiers the Pool Escrow to release the real 4.0 tokens to the user based on the ratio of escrow tokens to 4.0 tokens.

Pool Escrow - This contract is loaded up with the 4.0 tokens which are to be distributed as rewards for staking. This contract is notified by the Token Rewards contract with the amount and the recipient to whom the reward needs to be released to.

Staking Factory - This contract is used to streamline the deployment and setting up for the Token Reward, Pool escrow and Escrow token pairs.