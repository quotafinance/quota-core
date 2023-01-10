// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./interfaces/IMembershipNFT.sol";
import "./interfaces/IReferralHandler.sol";
import "./interfaces/IDepositBox.sol";
import "./interfaces/ITierManager.sol";
import "./interfaces/IRebaserNew.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";

contract NFTFactory {

    address public admin;
    address public tierManager;
    address public taxManager;
    address public rebaser;
    address public token;
    address public handlerImplementation;
    address public depositBoxImplementation;
    address public rewarder;
    mapping(uint256 => address) NFTToHandler;
    mapping(address => uint256) HandlerToNFT;
    mapping(uint256 => address) NFTToDepositBox;
    mapping(address => bool) handlerStorage;
    IMembershipNFT public NFT;
    string public tokenURI;

    event NewIssuance(uint256 id, address handler, address depositBox);
    event LevelChange(address handler, uint256 oldTier, uint256 newTier);
    event SelfTaxClaimed(address indexed handler, uint256 amount, uint256 timestamp);
    event RewardClaimed(address indexed handler, uint256 amount, uint256 timestamp);
    event DepositClaimed(address  indexed handler, uint256 amount, uint256 timestamp);

    modifier onlyAdmin() { // Change this to a list with ROLE library
        require(msg.sender == admin, "only admin");
        _;
    }

    constructor(address _handlerImplementation, address _depositBoxImplementation, string memory _tokenURI) {
        admin = msg.sender;
        handlerImplementation = _handlerImplementation;
        depositBoxImplementation = _depositBoxImplementation;
        tokenURI = _tokenURI;
    }

    function getHandlerForUser(address user) external view returns (address) {
        uint256 tokenID = NFT.belongsTo(user);
        if(tokenID != 0) // Incase user holds no NFT
            return NFTToHandler[tokenID];
        return address(0);
    }

    function getHandler(uint256 tokenID) external view returns (address) {
        return NFTToHandler[tokenID];
    }

    function getDepositBox(uint256 tokenID) external view returns (address) {
        return NFTToDepositBox[tokenID];
    }

    function isHandler(address _handler) public view returns (bool) {
        return handlerStorage[_handler];
    }

    function addHandler(address _handler) public onlyAdmin { // For adding handlers for Staking pools and Protocol owned Pools
        handlerStorage[_handler] = true;
    }

    function alertLevel(uint256 oldTier, uint256 newTier) external { // All the handlers notify the Factory incase there is a change in levels
        require(isHandler(msg.sender) == true);
        emit LevelChange(msg.sender, oldTier, newTier);
    }

    function alertSelfTaxClaimed(uint256 amount, uint256 timestamp) external { // All the handlers notify the Factory when the claim self tax
        require(isHandler(msg.sender) == true);
        emit SelfTaxClaimed(msg.sender, amount, timestamp);
    }

    function alertReferralClaimed(uint256 amount, uint256 timestamp) external { // All the handlers notify the Factory when the claim referral Reward
        require(isHandler(msg.sender) == true);
        emit RewardClaimed(msg.sender, amount, timestamp);
    }

    function getRebaser() external view returns(address) {
        return rebaser;  // Get address of the Rebaser contract
    }

    function getToken()  external view returns(address){
        return token ; // Set address of the Token contract
    }

    function getTaxManager() external view returns(address) {
        return taxManager;
    }

    function getRewarder() external view returns(address) {
        return rewarder;
    }

    function getTierManager() external view returns(address) {
        return tierManager;
    }

    function setDefaultURI(string memory _tokenURI) onlyAdmin public {
        tokenURI = _tokenURI;
    }

    function setRewarder(address _rewarder) onlyAdmin public {
        rewarder = _rewarder;
    }

    function setNFTAddress(address _NFT) onlyAdmin external {
        NFT = IMembershipNFT(_NFT); // Set address of the NFT contract
    }

    function setRebaser(address _rebaser) onlyAdmin external {
        rebaser = _rebaser; // Set address of the Rebaser contract
    }

    function setToken(address _token) onlyAdmin external {
        token = _token; // Set address of the Token contract
    }

    function setTaxManager(address _taxManager) onlyAdmin external {
        taxManager = _taxManager;
    }

    function setTierManager(address _tierManager) onlyAdmin external {
        tierManager = _tierManager;
    }

    function mint(address referrer) external returns (address) { //Referrer is address of NFT handler of the guy above
        uint256 nftID = NFT.issueNFT(msg.sender, tokenURI);
        uint256 epoch = IRebaser(rebaser).getPositiveEpochCount(); // The handlers need to only track positive rebases
        IReferralHandler handler = IReferralHandler(Clones.clone(handlerImplementation));
        // TODO: change the admin to not be static, instead change when NFT factory's admin is changed
        handler.initialize(admin, epoch, token, referrer, address(NFT), nftID);
        IDepositBox depositBox =  IDepositBox(Clones.clone(depositBoxImplementation));
        depositBox.initialize(address(handler), nftID, token);
        handler.setDepositBox(address(depositBox));
        NFTToHandler[nftID] = address(handler);
        NFTToDepositBox[nftID] = address(depositBox);
        HandlerToNFT[address(handler)] = nftID;
        handlerStorage[address(handler)] = true;
        handlerStorage[address(depositBox)] = true; // Required to allow it fully transfer the collected rewards without limit
        addToReferrersAbove(1, address(handler));
        emit NewIssuance(nftID, address(handler), address(depositBox));
        return address(handler);
    }

    //TODO: Refactor reuable code
    function mintToAddress(address referrer, address recipient, uint256 tier) external onlyAdmin returns (address) { //Referrer is address of NFT handler of the guy above
        uint256 nftID = NFT.issueNFT(recipient, tokenURI);
        uint256 epoch = IRebaser(rebaser).getPositiveEpochCount(); // The handlers need to only track positive rebases
        IReferralHandler handler = IReferralHandler(Clones.clone(handlerImplementation));
        handler.initialize(admin, epoch, token, referrer, address(NFT), nftID);
        IDepositBox depositBox =  IDepositBox(Clones.clone(depositBoxImplementation));
        depositBox.initialize(address(handler), nftID, token);
        handler.setDepositBox(address(depositBox));
        NFTToHandler[nftID] = address(handler);
        NFTToDepositBox[nftID] = address(depositBox);
        HandlerToNFT[address(handler)] = nftID;
        handlerStorage[address(handler)] = true;
        handlerStorage[address(depositBox)] = true; // Required to allow it fully transfer the collected rewards without limit
        addToReferrersAbove(1, address(handler));
        handler.setTier(tier);
        emit NewIssuance(nftID, address(handler), address(depositBox));
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