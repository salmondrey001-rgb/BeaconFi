// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import "forge-std/Test.sol";
import "src/MockStableCoin.sol";
import "src/BeaconFiToken.sol";
import "src/BeaconFiBadges.sol";
import "src/BeaconFiVault.sol";

contract BeaconFiVaultTest is Test {
    MockStableCoin public usdc;
    BeaconFiToken public bcon;
    BeaconFiBadges public badges;
    BeaconFiVault public vault;

    address public alice = address(0xB12c3D3E89a8c93B63883FC0fc8eeb874292c6cE);
    address public bob = address(0xcD6E9325E0D9Bc3d13E7Ced97dEb467B71e873AE);
    address public treasury = address(0x1D43c3a1E969dcC7988dAB79660997021908e098);

    function setUp() public {
        usdc = new MockStableCoin("USD Coin", "USDC");
        bcon = new BeaconFiToken(address(this));
        badges = new BeaconFiBadges(address(this));
        
        vault = new BeaconFiVault(
            IERC20(address(usdc)),
            address(bcon),
            address(badges),
            treasury
        );

        bcon.transferOwnership(address(vault));
        badges.transferOwnership(address(vault));

        usdc.mint(alice, 10000 * 10**18);
        usdc.mint(bob, 500 * 10**18);
    }

    function test_DepositUpgradesSBTBadgesAndRewards() public {
        vm.startPrank(alice);
        usdc.approve(address(vault), 6000 * 10**18);
        
        // Triggers Gold Tier thresholds (>=$5000)
        vault.deposit(5500 * 10**18, alice);
        
        assertEq(badges.getUserTier(alice), 3); // Confirms Gold
        assertTrue(bcon.balanceOf(alice) > 0);
        vm.stopPrank();
    }

    function test_Phase1StrictLockReverts() public {
        vm.startPrank(bob);
        usdc.approve(address(vault), 200 * 10**18);
        vault.deposit(200 * 10**18, bob);

        skip(45 days); // Inside Phase 1 strict lock window

        vm.expectRevert("BeaconFi: Phase 1 strict lock active");
        vault.withdraw(50 * 10**18, bob, bob);
        vm.stopPrank();
    }

    function test_Phase2LinearDecayPenaltyChargesTreasury() public {
        vm.startPrank(alice);
        usdc.approve(address(vault), 2000 * 10**18);
        vault.deposit(2000 * 10**18, alice);

        // Advance past strict lock window right to the middle of decay limits
        skip(90 days + 137.5 days);

        uint256 treasuryBalanceBefore = usdc.balanceOf(treasury);
        vault.withdraw(1000 * 10**18, alice, alice);

        // Penalty must apply ~5% fee on structural withdrawal operations
        assertTrue(usdc.balanceOf(treasury) > treasuryBalanceBefore);
        vm.stopPrank();
    }

    function test_DeadMansSwitchExecution() public {
        vm.startPrank(bob);
        usdc.approve(address(vault), 100 * 10**18);
        vault.deposit(100 * 10**18, bob);
        vault.setBeneficiary(alice);
        vm.stopPrank();

        // Push past 365 days + 90 days grace parameter boundaries without check-ins
        skip(460 days);

        vm.startPrank(alice);
        uint256 aliceBalanceBefore = usdc.balanceOf(alice);
        vault.claimInheritance(bob);
        
        assertEq(usdc.balanceOf(alice), aliceBalanceBefore + 100 * 10**18);
        vm.stopPrank();
    }
}