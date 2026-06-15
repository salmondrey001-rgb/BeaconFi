// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import "forge-std/Test.sol";
import "../src/BeaconFiToken.sol";

contract BeaconFiTokenTest is Test {
    BeaconFiToken public bcon;
    
    address public owner = address(0x1D43c3a1E969dcC7988dAB79660997021908e098);
    address public alice = address(0xB12c3D3E89a8c93B63883FC0fc8eeb874292c6cE);
    address public bob = address(0xcD6E9325E0D9Bc3d13E7Ced97dEb467B71e873AE);

    function setUp() public {
        // Deploy token with the test contract acting as temporary owner
        bcon = new BeaconFiToken(owner);
    }

    function test_MetadataAndInitialization() public {
        assertEq(bcon.name(), "BeaconFi");
        assertEq(bcon.symbol(), "BCON");
        assertEq(bcon.owner(), owner);
    }

    function test_OwnerCanMintRewards() public {
        uint256 mintAmount = 1000 * 10**18;
        
        vm.prank(owner);
        bcon.mintReward(alice, mintAmount);
        
        assertEq(bcon.balanceOf(alice), mintAmount);
    }

    function test_NonOwnerCannotMintRewards() public {
        uint256 mintAmount = 1000 * 10**18;
        
        // OpenZeppelin v5 uses standard Custom Errors for Ownable
        // error OwnableUnauthorizedAccount(address account);
        bytes4 selector = bytes4(keccak256("OwnableUnauthorizedAccount(address)"));
        
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(selector, alice));
        bcon.mintReward(bob, mintAmount);
    }

    function test_PublicCanBurnTokens() public {
        uint256 initialSupply = 500 * 10**18;
        uint256 burnAmount = 200 * 10**18;

        // Mint tokens to Alice first
        vm.prank(owner);
        bcon.mintReward(alice, initialSupply);

        // Alice burns a portion of her tokens
        vm.startPrank(alice);
        bcon.burn(burnAmount);
        vm.stopPrank();

        assertEq(bcon.balanceOf(alice), initialSupply - burnAmount);
    }
}