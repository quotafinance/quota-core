// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../interfaces/IMembershipNFT.sol";
import "./ReferralHandlerTest.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract NFTFactory {

    address public admin;
    mapping(uint256 => address) NFTToHandler;
    mapping(address => uint256) HandlerToNFT;
    mapping(address => bool) handlerStorage;
    IMembershipNFT public NFT;
    string public defaultTokenURI;
    string[] public tokenURI;

    event LevelChange(address handler, uint256 oldTier, uint256 newTier);

    modifier onlyAdmin() { // Change this to a list with ROLE library
        require(msg.sender == admin, "only admin");
        _;
    }

    constructor() {
        admin = msg.sender;
    }

// Test version of the TokenURI functions from Tiermanager for Test Deployment

    function setTokenURI(uint256 tier, string memory _tokenURI) onlyAdmin public {
        tokenURI[tier] = _tokenURI;
    }

    function getTokenURI(uint256 tier) public view returns (string memory) {
        return tokenURI[tier];
    }

    function getHandler(uint256 tokenID) external view returns (address) {
        return NFTToHandler[tokenID];
    }

    function isHandler(address _handler) public view returns (bool) {
        return handlerStorage[_handler];
    }

    function alertLevel(uint256 oldTier, uint256 newTier) external { // All the handlers notify the Factory incase there is a change in levels
        require(isHandler(msg.sender) == true);
        emit LevelChange(msg.sender, oldTier, newTier);
    }

    function setNFTAddress(address _NFT) onlyAdmin external {
        NFT = IMembershipNFT(_NFT); // Set address of the NFT contract
    }

    function setDefaultURI(string memory _tokenURI) onlyAdmin public {
        defaultTokenURI = _tokenURI;
    }

    function mint(address referrer) onlyAdmin external returns (address) { //Referrer is address of NFT handler of the guy above
        uint256 NFTID = NFT.issueNFT(msg.sender, defaultTokenURI);
        ReferralHandler handler = new ReferralHandler(admin, referrer, address(NFT), NFTID);
        NFTToHandler[NFTID] = address(handler);
        HandlerToNFT[address(handler)] = NFTID;
        handlerStorage[address(handler)] = true;
        addToReferrersAbove(1, address(handler));
        return address(handler);
    }

    function addToReferrersAbove(uint256 _tier, address _handler) internal {
        if(_handler != address(0)) {
            address first_ref = IReferralHandler(_handler).referredBy();
            if(first_ref != address(0)) {
                IReferralHandler(first_ref).addToReferralTree(1, _handler, _tier);
                address second_ref = IReferralHandler(first_ref).referredBy();
                if(second_ref != address(0)) {
                    IReferralHandler(second_ref).addToReferralTree(2, _handler, _tier);
                    address third_ref = IReferralHandler(second_ref).referredBy();
                    if(third_ref != address(0)) {
                        IReferralHandler(third_ref).addToReferralTree(3, _handler, _tier);
                        address fourth_ref = IReferralHandler(third_ref).referredBy();
                        if(fourth_ref != address(0))
                            IReferralHandler(fourth_ref).addToReferralTree(4, _handler, _tier);
                    }
                }
            }
        }
    }

}