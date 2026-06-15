//SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BeaconFiBadges is ERC721, Ownable{
    uint256 private _nextTokenId;

    event locked(uint256 tokenId);

    mapping(uint256 => uint256) public badgeTiers;
    mapping(address => uint256) public userBadges;

    constructor(address owner) 
    ERC721("BeaconFI Badge", "bBadge") Ownable(owner){}

    function mintBadge(address to, uint256 tier)
    external onlyOwner returns(uint256){
        if(userBadges[to] != 0){
            _burn(userBadges[to]);
        }
        uint256 tokenId = ++_nextTokenId;
        _mint(to, tokenId);
        badgeTiers[tokenId] = tier;
        userBadges[to] = tokenId;

        emit locked(tokenId);
        return tokenId;
    }
    function getUserTier(address user) external view returns(uint256){
        uint256 tokenId = userBadges[user];
        if(tokenId == 0) return 0;
        return badgeTiers[tokenId];
    }
    function _update(address to, uint256 tokenId, address auth) 
    internal override returns(address){
        address from = _ownerOf(tokenId);
        if(from != address(0) && to != address(0)){
            revert("BeaconFi: Token is Soulbound and non-transferable");
        }
        return super._update(to, tokenId, auth);
    } 
}
