# Modified ERC-721 Contracts

This contains modified versions from Openzeppelin's ERC721.

The modification is made such that at a given point in time a wallet can only holy upto one of these ERC721. To be able to transfer an NFT a the wallet or for the wallet to mint a new NFT, it should be holding another of this NFT.

There is also an addition of a view only function `belongsTo` which allows the contract to return the token ID for the token when a wallet address is passed. If the wallet does not own a token it returns address(0). This is internally stored with a new mapping `_tokenIDs`.

