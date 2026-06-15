// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./BeaconFiToken.sol";
import "./BeaconFiBadges.sol";

contract BeaconFiVault is ERC4626 {
    using SafeERC20 for IERC20;

    struct DepositRecord {
        uint256 amount;
        uint256 depositTimestamp;
        uint256 lastCheckIn;
        address beneficiary;
    }

    // Configurable System Constraints
    uint256 public constant STRICT_LOCK_DURATION = 90 days;
    uint256 public constant DECAY_DURATION = 275 days; 
    uint256 public constant GRACE_PERIOD = 90 days;
    uint256 public constant MAX_PENALTY_BPS = 1000; // 10%
    uint256 public constant BPS_DENOMINATOR = 10000;

    mapping(address => DepositRecord) public userRecords;

    BeaconFiToken public immutable bconToken;
    BeaconFiBadges public immutable badgeNFT;
    address public treasury;

    event CheckedIn(address indexed user, uint256 timestamp);
    event BeneficiaryAssigned(address indexed user, 
    address indexed beneficiary);
    event EarlyExitLevied(address indexed user, uint256 penaltyAmount, 
    uint256 netReturned);
    event InheritanceClaimed(address indexed owner, 
    address indexed beneficiary, uint256 amount);

    constructor(
        IERC20 _asset,
        address _bconToken,
        address _badgeNFT,
        address _treasury
    ) ERC4626(_asset) ERC20("BeaconFi Vault Token", "bfUSDC") {
        bconToken = BeaconFiToken(_bconToken);
        badgeNFT = BeaconFiBadges(_badgeNFT);
        treasury = _treasury;
    }

    function deposit(uint256 assets, address receiver) public 
    override returns (uint256) {
        uint256 shares = super.deposit(assets, receiver);
        
        DepositRecord storage record = userRecords[receiver];
        record.amount += assets;
        record.depositTimestamp = block.timestamp;
        record.lastCheckIn = block.timestamp;

        _updateUserBadge(receiver, record.amount);
        _mintLoyaltyRewards(receiver, assets);

        return shares;
    }

    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public override returns (uint256) {
        require(msg.sender == owner, "BeaconFi: Authorization error");
        DepositRecord storage record = userRecords[owner];
        
        uint256 timeElapsed = block.timestamp - record.depositTimestamp;
        require(timeElapsed >= STRICT_LOCK_DURATION, "BeaconFi: Phase 1 strict lock active");

        uint256 penaltyBps = getPenaltyBps(timeElapsed);
        uint256 sharesToBurn = previewWithdraw(assets);

        if (penaltyBps > 0) {
            uint256 penaltyAmount = (assets * penaltyBps) / BPS_DENOMINATOR;
            uint256 netAssets = assets - penaltyAmount;

            record.amount -= assets;
            record.lastCheckIn = block.timestamp;

            // Execution of the Value Capture System (Yield/Penalty collection loop)
            IERC20(asset()).safeTransfer(treasury, penaltyAmount);
            _burn(owner, sharesToBurn);
            IERC20(asset()).safeTransfer(receiver, netAssets);

            _updateUserBadge(owner, record.amount);
            emit EarlyExitLevied(owner, penaltyAmount, netAssets);
            return sharesToBurn;
        }

        record.amount -= assets;
        record.lastCheckIn = block.timestamp;
        _updateUserBadge(owner, record.amount);
        
        return super.withdraw(assets, receiver, owner);
    }

    // Dead-Man's Switch Controls
    function setBeneficiary(address _beneficiary) external {
        require(_beneficiary != address(0), "BeaconFi: Invalid beneficiary");
        userRecords[msg.sender].beneficiary = _beneficiary;
        userRecords[msg.sender].lastCheckIn = block.timestamp;
        emit BeneficiaryAssigned(msg.sender, _beneficiary);
    }

    function proofOfLife() external {
        userRecords[msg.sender].lastCheckIn = block.timestamp;
        emit CheckedIn(msg.sender, block.timestamp);
    }

    function claimInheritance(address owner) external {
        DepositRecord storage record = userRecords[owner];
        require(record.beneficiary == msg.sender, "BeaconFi: Unauthorized beneficiary execution");
        require(
            block.timestamp > record.lastCheckIn + STRICT_LOCK_DURATION + DECAY_DURATION + GRACE_PERIOD,
            "BeaconFi: Dead-man's switch timeline not reached"
        );

        uint256 totalAssets = maxWithdraw(owner);
        uint256 shares = previewWithdraw(totalAssets);

        record.amount = 0;
        _burn(owner, shares);
        IERC20(asset()).safeTransfer(msg.sender, totalAssets);

        emit InheritanceClaimed(owner, msg.sender, totalAssets);
    }

    // Helper Math Functions
    function getPenaltyBps(uint256 timeElapsed) public pure 
    returns (uint256) {
        if (timeElapsed >= STRICT_LOCK_DURATION + DECAY_DURATION) 
        return 0;
        uint256 decayTime = timeElapsed - STRICT_LOCK_DURATION;
        uint256 progress = (decayTime * BPS_DENOMINATOR) / DECAY_DURATION;
        return (MAX_PENALTY_BPS * (BPS_DENOMINATOR - progress)) / BPS_DENOMINATOR;
    }

    function _updateUserBadge(address user, uint256 currentBalance) internal {
        uint256 targetTier = 0;
        if (currentBalance >= 5000 * 10**18) targetTier = 3;      // Gold
        else if (currentBalance >= 1000 * 10**18) targetTier = 2; // Silver
        else if (currentBalance >= 100 * 10**18) targetTier = 1;  // Bronze

        if (targetTier > 0 && badgeNFT.getUserTier(user) != targetTier) {
            badgeNFT.mintBadge(user, targetTier);
        }
    }

    function _mintLoyaltyRewards(address user, uint256 amount) 
    internal {
        uint256 tier = badgeNFT.getUserTier(user);
        uint256 multiplier = 100; // 1x baseline
        if (tier == 2) multiplier = 120; // 1.2x Boost
        if (tier == 3) multiplier = 150; // 1.5x Boost

        uint256 rewardAmount = (amount * multiplier) / 1000;
        bconToken.mintReward(user, rewardAmount);
    }
}
