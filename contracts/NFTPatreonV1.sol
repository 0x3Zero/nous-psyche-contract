// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./ReferralRegistry.sol";

contract NFTPatreonV1 is ReentrancyGuard {
    address public protocolWallet;
    IERC721 public nftContract;
    ReferralRegistry public referralRegistry;
    
    mapping(uint256 => uint256) public keySupply;
    mapping(address => bool) public isAllowlisted;
    
    uint256 public referralFeePool;
    mapping(address => uint256) public referralCounters;
    mapping(address => address) public userToReferralAddress;
    mapping(uint256 => mapping(address => uint256)) public balanceKeys;
    
    // Total referral counts
    uint256 public currentReferralCount;
    
    uint256 public protocolFeePercentage;
    uint256 public nftFeePercentage;
    uint256 public referralFeePercentage;

    bool public paused;

    event ClaimReferral(address user, uint256 userCommission, uint256 userReferralCount, uint256 referralFeePool, uint256 referralCount);
    event ReferralAllowance(address user, bytes referralCode, address referralAddress);
    event BuyKey(BuyEvent buy);
    event SellKey(SellEvent sell);

    struct BuyEvent {
        address user; 
        uint256 tokenId;
        uint256 amount; 
        uint256 price; 
        uint256 protocolFee; 
        uint256 nftFee; 
        uint256 referralFee; 
        uint256 totalSupply; 
        uint256 supplyPerUser;
    }
    struct SellEvent {
        address user; 
        uint256 tokenId; 
        uint256 amount; 
        uint256 price; 
        uint256 protocolFee; 
        uint256 nftFee; 
        uint256 totalSupply; 
        uint256 supplyPerUser;
    }
    constructor(
        address _protocolWallet, 
        address _nftContractAddress, 
        uint256 _protocolFeePercentage, 
        uint256 _nftFeePercentage, 
        uint256 _referralFeePercentage,
        address _referralRegistryAddress
    ) {
        protocolWallet = _protocolWallet;
        nftContract = IERC721(_nftContractAddress);
        protocolFeePercentage = _protocolFeePercentage;
        nftFeePercentage = _nftFeePercentage;
        referralFeePercentage = _referralFeePercentage;
        referralRegistry = ReferralRegistry(_referralRegistryAddress);
    }

    modifier onlyProtocolOwner() {
        require(msg.sender == protocolWallet, "Not authorized");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    function setProtocolWallet(address _newProtocolWallet) external onlyProtocolOwner {
        protocolWallet = _newProtocolWallet;
    }

    // Set protocol fee percentage
    function setProtocolFeePercentage(uint256 _protocolFee) external onlyProtocolOwner {
        protocolFeePercentage = _protocolFee;
    }

    // Set NFT fee percentage
    function setNftFeePercentage(uint256 _nftFee) external onlyProtocolOwner {
        nftFeePercentage = _nftFee;
    }

    // Set referral fee percentage
    function setReferralFeePercentage(uint256 _referralFee) external onlyProtocolOwner {
        referralFeePercentage = _referralFee;
    }

    // Set referral registry
    function setReferralRegistryAddress(address _referralRegistryAddress) external onlyProtocolOwner {
        referralRegistry = ReferralRegistry(_referralRegistryAddress);
    }

    // Set nft contract address
    function setNftContractAddress(address _nftContractAddress) external onlyProtocolOwner {
        nftContract = IERC721(_nftContractAddress);
    }
    
    function enterAllowlistWithReferral(bytes memory referralCode) external nonReentrant whenNotPaused {
        require(referralRegistry.checkCodeValidity(referralCode), "Invalid referral code");
        address referralAddress = referralRegistry.getAddressForCode(referralCode);
        isAllowlisted[msg.sender] = true;
        userToReferralAddress[msg.sender] = referralAddress;
        referralRegistry.markCodeAsUsed(referralCode);

        emit ReferralAllowance(msg.sender, referralCode, referralAddress);
    }

    function getPrice(uint256 supply, uint256 amount) public pure returns (uint256) {
        require(amount > 0, "Amount cannot be zero");
        uint256 sum1 = supply == 0 ? 0 : (supply - 1) * supply * (2 * (supply - 1) + 1) / 6;
        uint256 sum2 = supply == 0 && amount == 1 ? 0 : (amount - 1 + supply) * (supply + amount) * (2 * (amount - 1 + supply) + 1) / 6;
        uint256 summation = sum2 - sum1;
        return summation * 1 ether / 16000;
    }

    function getBuyPrice(uint256 tokenId, uint256 amount) public view returns (uint256) {
        return getPrice(keySupply[tokenId], amount);
    }

    function getSellPrice(uint256 tokenId, uint256 amount) public view returns (uint256) {
        return getPrice(keySupply[tokenId] - amount, amount);
    }

    function getBuyPriceAfterFee(uint256 tokenId, uint256 amount) public view returns (uint256) {
        uint256 price = getBuyPrice(tokenId, amount);
        uint256 protocolFee = price * protocolFeePercentage / 1 ether;
        uint256 nftFee = price * nftFeePercentage / 1 ether;
        uint256 referralFee = price * referralFeePercentage / 1 ether;

        return price + protocolFee + nftFee + referralFee;
    }

    function getSellPriceAfterFee(uint256 tokenId, uint256 amount) public view returns (uint256) {
        uint256 price = getSellPrice(tokenId, amount);
        uint256 protocolFee = price * protocolFeePercentage / 1 ether;
        uint256 nftFee = price * nftFeePercentage / 1 ether;
        return price - protocolFee - nftFee;
    }

    function buyKey(uint256 tokenId, uint256 amount) external payable nonReentrant whenNotPaused {
        require(amount > 0, "Amount cannot be zero");
        require(isAllowlisted[msg.sender], "Address not allowlisted");
        address tokenOwner = nftContract.ownerOf(tokenId);
        require(tokenOwner != address(0), "Invalid tokenId");
        
        uint256 price = getBuyPrice(tokenId, amount);
        uint256 protocolFee = price * protocolFeePercentage / 1 ether;
        uint256 nftFee = price * nftFeePercentage / 1 ether;
        uint256 referralFee = price * referralFeePercentage / 1 ether;

        require(msg.value >= price + protocolFee + nftFee + referralFee, "Insufficient payment");

        referralFeePool += referralFee;

        keySupply[tokenId] += amount;
        balanceKeys[tokenId][msg.sender] += amount;
        
        address referralAddress = userToReferralAddress[msg.sender];
        
        referralCounters[referralAddress] += amount;
        currentReferralCount += amount;

        (bool success1, ) = protocolWallet.call{value: protocolFee}("");
        (bool success2, ) = tokenOwner.call{value: nftFee}("");

        require(success1 && success2, "Unable to send funds");

        emit BuyKey(BuyEvent(msg.sender, tokenId, amount, price, protocolFee, nftFee, referralFee, keySupply[tokenId], balanceKeys[tokenId][msg.sender]));
    }

    function sellKey(uint256 tokenId, uint256 amount) external nonReentrant whenNotPaused {
        require(amount > 0, "Amount cannot be zero");
        require(balanceKeys[tokenId][msg.sender] >= amount, "Insufficient shares");
        
        uint256 supply = keySupply[tokenId];
        require(supply > amount, "Cannot sell the last share");
        uint256 price = getPrice(supply - amount, amount);
        uint256 protocolFee = price * protocolFeePercentage / 1 ether;
        uint256 nftFee = price * nftFeePercentage / 1 ether;

        keySupply[tokenId] -= amount;
        balanceKeys[tokenId][msg.sender] -= amount;

        address tokenOwner = nftContract.ownerOf(tokenId);

        (bool success1, ) = msg.sender.call{value: price - protocolFee - nftFee}("");
        (bool success2, ) = protocolWallet.call{value: protocolFee}("");
        (bool success3, ) = tokenOwner.call{value: nftFee}("");

        require(success1 && success2 && success3, "Unable to send funds");

        emit SellKey(SellEvent(msg.sender, tokenId, amount, price, protocolFee, nftFee, keySupply[tokenId], balanceKeys[tokenId][msg.sender]));

    }

    function getUserBalanceKeys (uint256 tokenId) public view returns (uint256) {
        return balanceKeys[tokenId][msg.sender];
    }

    function checkReferralFeeBalance() public view returns (uint256) {
        return calculateReferralFee(msg.sender);
    }

    function calculateReferralFee(address user) private view returns (uint256) {
      uint256 userReferralCount = referralCounters[user];
      require(userReferralCount > 0, "No referral fees to claim");

      uint256 userCommissionRatio = (userReferralCount * 1e18) / currentReferralCount;
      uint256 commissionPool = referralFeePool; 
      uint256 userCommission = (commissionPool * userCommissionRatio) / 1e18;

      return userCommission;
    }

    function claimReferralFee() external nonReentrant whenNotPaused {
        uint256 userCommission = calculateReferralFee(msg.sender);
        uint256 userReferralCount = referralCounters[msg.sender];

        referralFeePool -= userCommission;
        currentReferralCount -= userReferralCount;
        referralCounters[msg.sender] = 0;

        (bool success1, ) = msg.sender.call{value: userCommission}("");
        require(success1, "Unable to send funds");

        emit ClaimReferral(msg.sender, userCommission, userReferralCount, referralFeePool, currentReferralCount);
    }

    function pause() public onlyProtocolOwner() {
        require(!paused, "Contract is already paused");
        paused = true;
    }

    function unpause() public onlyProtocolOwner {
        require(paused, "Contract is not paused");
        paused = false;
    }
}