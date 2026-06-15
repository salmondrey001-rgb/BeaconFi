// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import "forge-std/Test.sol";
import "../src/BeaconFiBadges.sol";

contract BeaconFiBadgesTest is Test {
    BeaconFiBadges public badges;
    
    address public owner = address(0x1D43c3a1E969dcC7988dAB79660997021908e098);
    address public alice = address(0xB12c3D3E89a8c93B63883FC0fc8eeb874292c6cE);
    address public bob = address(0xcD6E9325E0D9Bc3d13E7Ced97dEb467B71e873AE);

    function setUp() public {
        badges = new BeaconFiBadges(owner);
    }

    function test_MintBadgeTracksTiers() public {
        vm.startPrank(owner);
        uint256 tokenId = badges.mintBadge(alice, 3); // Mint Gold Tier
        vm.stopPrank();

        assertEq(badges.getUserTier(alice), 3);
        assertEq(badges.badgeTiers(tokenId), 3);
        assertEq(badges.ownerOf(tokenId), alice);
    }

    function test_UpgradingBadgeBurnsOldToken() public {
        vm.startPrank(owner);
        uint256 firstTokenId = badges.mintBadge(alice, 1); // Bronze
        assertEq(badges.balanceOf(alice), 1);

        // Upgrade Alice to Silver (Tier 2)
        uint256 secondTokenId = badges.mintBadge(alice, 2);
        vm.stopPrank();

        // Balance remains 1 because the Bronze badge was structurally burned on-chain
        assertEq(badges.balanceOf(alice), 1);
        assertEq(badges.getUserTier(alice), 2);
        
        // Verifying the old token ID throws an ERC721 non-existent error
        bytes4 selector = bytes4(keccak256("ERC721NonexistentToken(uint256)"));
        vm.expectRevert(abi.encodeWithSelector(selector, firstTokenId));
        badges.ownerOf(firstTokenId);
    }

    function test_SoulboundRestrictionPreventsTransfers() public {
        vm.startPrank(owner);
        uint256 tokenId = badges.mintBadge(alice, 1);
        vm.stopPrank();

        // Alice attempts to bypass the protocol and send her badge to Bob
        vm.startPrank(alice);
        vm.expectRevert("BeaconFi: Token is Soulbound and non-transferable");
        badges.transferFrom(alice, bob, tokenId);
        vm.stopPrank();
    }
}