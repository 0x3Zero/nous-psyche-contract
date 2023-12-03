// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract NousPsycheNFTV2 is ERC721, ERC721Enumerable, ERC721Royalty, Pausable, AccessControl, ReentrancyGuard {

    struct Perk {
        string title; // Short title of 1-10 words
        string description; // Brief description of 10-30 words
        string cid; // CID to IPFS
        uint256 price;
        bool forSale;
        uint256 prerequisitePerkId;
        bool isPrivate;
        bool isLocked;
        bool isActivable;
        bool isRepurchaseable;
    }

    mapping(uint256 => Perk) public perks;
    mapping(uint256 => uint256[]) public ownedPerks;
    mapping(uint256 => bytes32) public perkMerkleRoot;
    uint256 public nextPerkId = 10001;

    uint256 public immutable maxTokens;
    uint256 public immutable mintPrice;

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant MERKLEPROOF_ROLE = keccak256("MERKLEPROOF_ROLE");
    bytes32 public constant PERK_CREATOR_ROLE = keccak256("PERK_CREATOR_ROLE");
    
    uint256 public nextTokenId = 0;
    // metadata URI
    string public baseTokenURI;

    address public royaltyAddress;
    uint96 public royaltyBps = 1000;

    event Purchased(address from, uint indexed tokenId, uint indexed perkId, string cid);
    event Equipped(uint256 indexed tokenId, uint256 indexed perkId, string cid);
    event PerkAdded(uint256 indexed perkId);
    event PerkUpdated(uint256 indexed perkId);
    event PerkSaleToggled(uint256 indexed perkId, bool isForSale, bool isLocked);

    constructor(uint256 _mintPrice, uint256 _maxTokens)
        ERC721("NousPsyche", "NPSY")
    {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);

        mintPrice = _mintPrice;
        maxTokens = _maxTokens;
    }

    function addPerk(string memory title, string memory description, string memory cid, uint256 price, uint256 prerequisitePerkId, bool isPrivate, bool isActivable, bool isRepurchaseable) external onlyRole(PERK_CREATOR_ROLE) {
        uint256 newPerkId = nextPerkId;
        perks[nextPerkId] = Perk(title, description, cid, price, false, prerequisitePerkId, isPrivate, false, isActivable, isRepurchaseable);
        nextPerkId++;

        emit PerkAdded(newPerkId);
    }

    function updatePerk(uint256 perkId, string memory title, string memory description, string memory cid, uint256 price, uint256 prerequisitePerkId, bool isPrivate, bool isActivable, bool isRepurchaseable) external onlyRole(PERK_CREATOR_ROLE) {
        require(perkId < nextPerkId, "Perk does not exist");
        require(!perks[perkId].isLocked, "Perk is locked and cannot be updated");
        
        bool currentLockedStatus = perks[perkId].isLocked;
        perks[perkId] = Perk(title, description, cid, price, perks[perkId].forSale, prerequisitePerkId, isPrivate, currentLockedStatus, isActivable, isRepurchaseable);

        emit PerkUpdated(perkId);
    }

    function togglePerkSale(uint256 perkId) external onlyRole(PERK_CREATOR_ROLE) {
        require(perkId < nextPerkId, "Perk does not exist");
        perks[perkId].forSale = !perks[perkId].forSale;

        if (perks[perkId].forSale) {
            perks[perkId].isLocked = true;
        }

        emit PerkSaleToggled(perkId, perks[perkId].forSale, perks[perkId].isLocked);
    }

    function getPerkInfo(uint256 perkId) external view returns (Perk memory) {
        require(perkId < nextPerkId, "Perk does not exist");
        Perk memory perk = perks[perkId];
        return perk;
    }

    function hasPerk(uint256 tokenId, uint256 perkId) public view returns (bool) {
        require(perkId < nextPerkId, "Perk does not exist");
        for (uint256 i = 0; i < ownedPerks[tokenId].length; i++) {
            if (ownedPerks[tokenId][i] == perkId) {
                return true;
            }
        }
        return false;
    }

    function purchasePerk(uint256 tokenId, uint256 perkId, bytes32[] calldata merkleProof) external payable {
        require(ownerOf(tokenId) == msg.sender, "Not the NFT owner");
        require(perkId < nextPerkId, "Perk does not exist");
        require(perks[perkId].forSale, "Perk not for sale");

        if (perks[perkId].isPrivate) {
          require(isWhitelistedForPerk(tokenId, perkId, msg.sender, merkleProof), "Not whitelisted for this perk");
        }
        
        require(msg.value >= perks[perkId].price, "Insufficient payment");
        
        if (perks[perkId].prerequisitePerkId != 0) {
            require(hasPerk(tokenId, perks[perkId].prerequisitePerkId), "Prerequisite perk not owned");
        }

        if (!perks[perkId].isRepurchaseable) {
          require(!hasPerk(tokenId, perkId), "Perk already owned");
        } 

        if (!hasPerk(tokenId, perkId)) {
          ownedPerks[tokenId].push(perkId);
        }

        emit Purchased(msg.sender, tokenId, perkId, perks[perkId].cid);
    }

    function equip(uint256 tokenId, uint256 perkId) external {
        require(ownerOf(tokenId) == msg.sender, "You do not own this bot");
        require(hasPerk(tokenId, perkId), "This perk is not owned by the bot");

        emit Equipped(tokenId, perkId, perks[perkId].cid);
    }

    function addWhitelistMerkle(uint256 perkId, bytes32 _merkleRoot) external onlyRole(MERKLEPROOF_ROLE) {
        require(perkId < nextPerkId, "Perk does not exist");
        perkMerkleRoot[perkId] = _merkleRoot;
    }

    function isWhitelistedForPerk(uint256 tokenId, uint256 perkId, address userAddress, bytes32[] calldata merkleProof) public view returns (bool) {
        require(ownerOf(tokenId) == userAddress, "Not the NFT owner");
        require(perkId < nextPerkId, "Perk does not exist");
        require(perks[perkId].isPrivate, "Private perk");

        bytes32 leaf = keccak256(abi.encodePacked(userAddress));
        return MerkleProof.verify(merkleProof, perkMerkleRoot[perkId], leaf);
    }
    
    function withdrawFunds() external onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");

        (bool success, ) = payable(msg.sender).call{value: balance}(
            ""
        );
        require(success, "Transfer failed");
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function setBaseURI(string calldata baseURI) external onlyRole(DEFAULT_ADMIN_ROLE) {
        baseTokenURI = baseURI;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }

    function setDefaultRoyalty(address _receiver, uint96 _feeNumerator) public onlyRole(DEFAULT_ADMIN_ROLE) {
        royaltyAddress = _receiver;
        royaltyBps = _feeNumerator;
        
        _setDefaultRoyalty(royaltyAddress, royaltyBps);
    }

    function mint() external payable {
        require(!hasMinted(msg.sender), "Each address may only mint one NFT");
        require(msg.value >= mintPrice, "Insufficient fee");
        require(totalSupply() < maxTokens, "Max NFT limit reached");

        // Token id will start from 0
        if (totalSupply() > 0) {
            nextTokenId++;
        }
        uint256 tokenId = nextTokenId;

        _safeMint(msg.sender, tokenId);
    }

    function hasMinted(address _address) public view returns (bool) {
      return balanceOf(_address) > 0;
    }

    // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize)
        internal
        whenNotPaused
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, ERC721Royalty, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721Royalty) {
        super._burn(tokenId);
    }
}
