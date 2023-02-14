# Token Feature contracts

This folder contracts which are used the 4.0 token contract.

BalanceManagement and BalanceStorage contracts are used to track the underlying balance of the users and they are updated each time there is a mint, transfer or burn occurs.

Token Interface and TokenStorage contracts are used to define the properties, functions and events that are used by the 4.0 token contract.

TradePair and Whitelistable contracts are derived from the Openzeppelin Roles contract, these are used to set an address to allow them to have more relaxed trading rules compared the rest of the addresses. These are mainly used for addresses that interact with external DEFI systems (for example: DEX routers and pairs) or protocol's contracts which need to be able to transfer their balance without a limit(For example, Liquidity Extension contract, escrows, etc).

Frozen Contract is  derived from the Openzeppelin Roles contract, it is used to freeze the assets of a target address incase of an unforeable event.