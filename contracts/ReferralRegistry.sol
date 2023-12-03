// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract ReferralRegistry is AccessControl {
    mapping(address => bytes) private referralCodes;
    mapping(bytes => address) private codeToUser;
    mapping(bytes => uint256) public totalCodeUsed;
    mapping(address => bool) public allowedAddresses;

    uint256 public maxCodeUsed;

    constructor(uint256 _maxUsed) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        maxCodeUsed = _maxUsed;
    }

    modifier onlyAllowed() {
        require(allowedAddresses[msg.sender], "Not allowed");
        _;
    }

    function removeDisallowAddress(address addr) public onlyRole(DEFAULT_ADMIN_ROLE) {
        allowedAddresses[addr] = false;
    }

    function addAllowAddress(address addr) public onlyRole(DEFAULT_ADMIN_ROLE) {
        allowedAddresses[addr] = true;
    }

    function generateReferralCode(address user) private view returns (bytes memory) {
        return abi.encodePacked(keccak256(abi.encodePacked(user, block.timestamp)));
    }

    function assignReferralCode() public {
        bytes memory code = referralCodes[msg.sender];

        bool canGenRefCode = false;

        if (code.length > 0 && totalCodeUsed[code] >= maxCodeUsed - 1) {
          canGenRefCode = true;
        }

        if (code.length == 0) {
          canGenRefCode = true;
        }
        require(canGenRefCode, "Referral code not exceed max used yet.");
        bytes memory newCode = generateReferralCode(msg.sender);
        referralCodes[msg.sender] = newCode;
        codeToUser[newCode] = msg.sender;
    }

    function checkCodeValidity(bytes memory code) public view returns (bool) {
        if(codeToUser[code] == address(0)) {
            return false;
        }

        return totalCodeUsed[code] < maxCodeUsed;
    }

    function markCodeAsUsed(bytes memory code) public onlyAllowed {
        require(checkCodeValidity(code), "Invalid or already used referral code");
        ++totalCodeUsed[code];
    }

    function getAddressForCode(bytes memory code) public view returns (address) {
        address userAddress = codeToUser[code];
        require(userAddress != address(0), "Invalid or unused referral code");
        require(totalCodeUsed[code] < maxCodeUsed, "Referral code already used");
        return userAddress;
    }

    function getCode(address user) public view returns (bytes memory) {
        require(referralCodes[user].length > 0, "User has no referral code");
        return referralCodes[user];
    }
}