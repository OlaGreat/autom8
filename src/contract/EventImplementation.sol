// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Ticket.sol";
import "./Payroll.sol";
import "./SponsorVault.sol";

contract EventImplementation is Initializable, OwnableUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable {
    struct TicketTier {
        string name;
        uint256 price;
        uint256 maxSupply;
        uint256 currentSold;
    }

    uint256 public eventId;
    uint256 public fundingGoal;
    uint256 public currentBalance;
    uint256 public startTime;
    uint256 public endTime;
    string public eventName;
    string public description;
    bool public isFreeEvent;
    bool public isActive;
    bool public emergencyPaused;
    uint256 public sponsorPercentage; // Basis points (e.g., 7000 = 70%)
    uint256 public platformFee; // Basis points (e.g., 500 = 5%)
    address public platformWallet;

    uint256 public constant MIN_DEPOSIT = 0.01 ether;

    TicketTier[] public ticketTiers;

    Ticket public ticketContract;
    Payroll public payrollContract;
    SponsorVault public sponsorVault;
    IERC20 public paymentToken;

    event Deposit(address indexed sponsor, uint256 amount);
    event EventEnded(uint256 totalRevenue, uint256 sponsorShare, uint256 workerShare, uint256 platformFee);
    event TicketPurchased(address indexed buyer, uint256 ticketId, uint256 price);
    event DepositWithdrawn(address indexed sponsor, uint256 amount);
    event EventCancelled(uint256 totalRefunded);
    event EmergencyPaused(address indexed pauser);
    event EmergencyUnpaused(address indexed unpauser);
    event EventDetailsUpdated(string newName, string newDescription);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _owner,
        uint256 _eventId,
        uint256 _fundingGoal,
        uint256 _startTime,
        uint256 _endTime,
        string memory _eventName,
        string memory _description,
        address _ticketContract,
        address _payrollContract,
        address _paymentToken,
        address _sponsorVault,
        uint256 _sponsorPercentage,
        uint256 _platformFee,
        address _platformWallet,
        TicketTier[] memory _ticketTiers
    ) public initializer {
        __Ownable_init(_owner);
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        eventId = _eventId;
        fundingGoal = _fundingGoal;
        startTime = _startTime;
        endTime = _endTime;
        eventName = _eventName;
        description = _description;
        isFreeEvent = _fundingGoal == 0;
        isActive = true;
        emergencyPaused = false;
        sponsorPercentage = _sponsorPercentage;
        platformFee = _platformFee;
        platformWallet = _platformWallet;

        ticketContract = Ticket(_ticketContract);
        payrollContract = Payroll(_payrollContract);
        sponsorVault = SponsorVault(_sponsorVault);
        paymentToken = IERC20(_paymentToken);

        // Initialize ticket tiers
        for (uint256 i = 0; i < _ticketTiers.length; i++) {
            ticketTiers.push(_ticketTiers[i]);
        }
    }

    modifier whenNotPaused() {
        require(!emergencyPaused, "Event is emergency paused");
        _;
    }

    function deposit(uint256 amount) external nonReentrant whenNotPaused {
        require(isActive, "Event is not active");
        require(block.timestamp >= startTime && block.timestamp <= endTime, "Event not in progress");
        require(currentBalance < fundingGoal, "Funding goal already met");
        require(amount >= MIN_DEPOSIT, "Deposit amount too small");

        require(paymentToken.transferFrom(msg.sender, address(sponsorVault), amount), "Transfer failed");
        sponsorVault.deposit(eventId, msg.sender, amount);
        currentBalance += amount;

        emit Deposit(msg.sender, amount);
    }

    function purchaseTicket(uint256 tierId) external nonReentrant whenNotPaused {
        require(isActive, "Event is not active");
        require(block.timestamp >= startTime && block.timestamp <= endTime, "Event not in progress");
        require(tierId < ticketTiers.length, "Invalid ticket tier");

        TicketTier storage tier = ticketTiers[tierId];
        require(tier.currentSold < tier.maxSupply, "Ticket tier sold out");

        require(paymentToken.transferFrom(msg.sender, address(this), tier.price), "Transfer failed");

        // Mint ticket with correct eventId and tierId
        uint256 ticketId = ticketContract.mintWithDetails(msg.sender, eventId, tier.price, tierId);

        tier.currentSold++;
        currentBalance += tier.price;

        emit TicketPurchased(msg.sender, ticketId, tier.price);
    }

    function endEvent() external onlyOwner nonReentrant {
        require(isActive, "Event already ended");
        require(block.timestamp > endTime, "Event not yet ended");

        isActive = false;

        uint256 totalRevenue = currentBalance;
        uint256 platformFeeAmount = (totalRevenue * platformFee) / 10000;
        uint256 remainingRevenue = totalRevenue - platformFeeAmount;
        uint256 sponsorShare = (remainingRevenue * sponsorPercentage) / 10000;
        uint256 workerShare = remainingRevenue - sponsorShare;

        // Transfer platform fee
        if (platformFeeAmount > 0) {
            paymentToken.transfer(platformWallet, platformFeeAmount);
        }

        // Distribute to sponsors via SponsorVault
        if (sponsorShare > 0) {
            paymentToken.transfer(address(sponsorVault), sponsorShare);
            sponsorVault.distributeRevenue(eventId, sponsorShare);
        }

        // Pay workers via Payroll
        if (workerShare > 0) {
            paymentToken.approve(address(payrollContract), workerShare);
            payrollContract.payWorkers(eventId);
        }

        emit EventEnded(totalRevenue, sponsorShare, workerShare, platformFeeAmount);
    }

    function getBalance() external view returns (uint256) {
        return currentBalance;
    }

    function getSponsors() external view returns (address[] memory, uint256[] memory) {
        address[] memory sponsors = sponsorVault.getEventSponsors(eventId);
        uint256[] memory deposits = new uint256[](sponsors.length);
        for (uint256 i = 0; i < sponsors.length; i++) {
            deposits[i] = sponsorVault.getSponsorInfo(eventId, sponsors[i]).depositAmount;
        }
        return (sponsors, deposits);
    }

    function withdrawDeposit(uint256 amount) external nonReentrant {
        require(isActive, "Event ended");
        require(block.timestamp < startTime, "Event already started");
        require(amount > 0, "Withdrawal amount must be positive");

        uint256 sponsorDeposit = sponsorVault.getSponsorInfo(eventId, msg.sender).depositAmount;
        require(sponsorDeposit >= amount, "Insufficient deposit balance");

        // Update sponsor vault
        sponsorVault.withdrawDeposit(eventId, msg.sender, amount);
        currentBalance -= amount;

        // Transfer back to sponsor
        require(paymentToken.transferFrom(address(sponsorVault), msg.sender, amount), "Transfer failed");

        emit DepositWithdrawn(msg.sender, amount);
    }

    function cancelEvent() external onlyOwner nonReentrant {
        require(isActive, "Event already ended");
        require(block.timestamp < startTime, "Event already started");

        isActive = false;

        uint256 totalToRefund = currentBalance;
        if (totalToRefund > 0) {
            paymentToken.transfer(address(sponsorVault), totalToRefund);
            sponsorVault.refundAllSponsors(eventId);
        }

        emit EventCancelled(totalToRefund);
    }

    function emergencyPause() external onlyOwner {
        emergencyPaused = true;
        emit EmergencyPaused(msg.sender);
    }

    function emergencyUnpause() external onlyOwner {
        emergencyPaused = false;
        emit EmergencyUnpaused(msg.sender);
    }

    function updateEventDetails(string memory _eventName, string memory _description) external onlyOwner {
        require(block.timestamp < startTime, "Cannot update after event started");
        eventName = _eventName;
        description = _description;
        emit EventDetailsUpdated(_eventName, _description);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
