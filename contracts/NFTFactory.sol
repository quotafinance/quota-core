// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./interfaces/IMembershipNFT.sol";
import "./ReferralHandler.sol";
import "./interfaces/ITierManager.sol";
import "./interfaces/IRebaserNew.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract NFTFactory {

    address public admin;
    address public tierManager;
    address public taxManager;
    address public rebaser;
    address public token;
    mapping(uint256 => address) NFTToHandler;
    mapping(address => uint256) HandlerToNFT;
    mapping(address => bool) handlerStorage;
    IMembershipNFT public NFT;
    string public tokenURI;

    event LevelChange(address handler, uint256 oldTier, uint256 newTier);

    modifier onlyAdmin() { // Change this to a list with ROLE library
        require(msg.sender == admin, "only admin");
        _;
    }

    constructor(address _tierManager, string memory _tokenURI) {
        admin = msg.sender;
        tierManager = _tierManager;
        tokenURI = _tokenURI;
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
        tokenURI = _tokenURI;
    }

    function setRebaser(address _rebaser) onlyAdmin external {
        rebaser = _rebaser; // Set address of the Rebaser contract
    }

    function setToken(address _token) onlyAdmin external {
        token = _token; // Set address of the Rebaser contract
    }

    function setTaxManager(address _taxManager) onlyAdmin external {
        taxManager = _taxManager;
    }

    function mint(address referrer) onlyAdmin external returns (address) { //Referrer is address of NFT handler of the guy above
        uint256 NFTID = NFT.issueNFT(msg.sender, tokenURI);
        uint256 epoch = IRebaser(rebaser).getPositiveEpochCount();
        ReferralHandler handler = new ReferralHandler(admin, epoch, rebaser, token, tierManager, taxManager, referrer, address(NFT), NFTID);
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