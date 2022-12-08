// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./NFT/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./interfaces/INFTFactory.sol";
import "./interfaces/IReferralHandler.sol";

contract MembershipNFT is ERC721URIStorage {

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    mapping (uint256 => address) public tokenMinter;
    address public admin;
    address public factory;

    modifier onlyFactory() { // Change this to a list with ROLE library
        require(msg.sender == factory, "only admin");
        _;
    }

    constructor(address _factory) ERC721("ETF Membership NFT", "ETFNFT") {
        admin = msg.sender;
        factory = _factory;
        _tokenIds.increment(); // Start Token IDs from 1 instead of 0
    }

    function issueNFT(address user, string memory tokenURI)
        public
        onlyFactory
        returns (uint256)
    {
        uint256 newNFTId = _tokenIds.current();
        _mint(user, newNFTId);
        _setTokenURI(newNFTId, tokenURI);
        tokenMinter[newNFTId] = user;
        _tokenIds.increment();
        return newNFTId;
    }

    function changeURI(uint256 tokenID, string memory tokenURI)
        public
    {
        address handler = INFTFactory(factory).getHandler(tokenID);
        require(msg.sender == handler, "Only Handler can update Token's URI");
        _setTokenURI(tokenID, tokenURI);
    }

    function tier(uint256 tokenID)
        public
        view
        returns(uint256)
    {
        address handler = INFTFactory(factory).getHandler(tokenID);
        return IReferralHandler(handler).getTier();
    }

    function getTransferLimit(uint256 tokenID)
        public
        view
        returns(uint256)
    {
        address handler = INFTFactory(factory).getHandler(tokenID);
        return IReferralHandler(handler).getTransferLimit();
    }

}