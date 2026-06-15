// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import "forge-std/Script.sol";
import "../src/MockStableCoin.sol";
import "../src/BeaconFiToken.sol";
import "../src/BeaconFiBadges.sol";
import "../src/BeaconFiVault.sol";

contract DeployBeaconFi is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envOr("PRIVATE_KEY", uint256(0x4c15fdee9fa447becc0a04a7458d569198b4d158f6c88e8df83dca));
        address treasury = vm.envOr("TREASURY_ADDRESS", address(0x1D43c3a1E969dcC7988dAB79660997021908e098));

        address deployer_address = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy Mock USDC
        MockStableCoin mockUSDC = new MockStableCoin("Mock USDC", "USDC");
        console.log("Mock USDC deployed to:", address(mockUSDC));

        // 2. Deploy BCON Token
        BeaconFiToken bconToken = new BeaconFiToken(deployer_address);
        console.log("BCON Token deployed to:", address(bconToken));

        // 3. Deploy BeaconFi Badges
        BeaconFiBadges badgesNFT = new BeaconFiBadges(deployer_address);
        console.log("Badges NFT deployed to:", address(badgesNFT));

        // 4. Deploy Core BeaconFi Vault
        BeaconFiVault vault = new BeaconFiVault(
            IERC20(address(mockUSDC)),
            address(bconToken),
            address(badgesNFT),
            treasury
        );
        console.log("BeaconFi Vault deployed to:", address(vault));

        // 5. Transfer Ownership of Token and Badges to the Vault
        bconToken.transferOwnership(address(vault));
        badgesNFT.transferOwnership(address(vault));
        console.log("Ownership transferred to Vault successfully.");

        // Optionally mint test tokens
        mockUSDC.mint(vm.addr(deployerPrivateKey), 10000 * 10**18);

        vm.stopBroadcast();
    }
}
