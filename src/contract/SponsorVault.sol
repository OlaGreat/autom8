// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SponsorVault is ReentrancyGuard {
    IERC20 public paymentToken;

    struct SponsorInfo {
        uint256 depositAmount;
        uint256 sharePercentage; // Basis points (e.g., 1000 = 10%)
    }

    mapping(uint256 => mapping(address => SponsorInfo)) public eventSponsors;
    mapping(uint256 => address[]) public eventSponsorList;
    mapping(uint256 => uint256) public eventTotalDeposits;
    mapping(uint256 => address) public eventContracts;

    event SponsorDeposited(uint256 indexed eventId, address indexed sponsor, uint256 amount);
    event RevenueDistributed(uint256 indexed eventId, address indexed sponsor, uint256 amount);
    event DepositWithdrawn(uint256 indexed eventId, address indexed sponsor, uint256 amount);
    event SponsorsRefunded(uint256 indexed eventId, uint256 totalRefunded);

    constructor(address _paymentToken) {
        paymentToken = IERC20(_paymentToken);
    }

    modifier onlyEventContract(uint256 eventId) {
        require(msg.sender == eventContracts[eventId], "Unauthorized: not event contract");
        _;
    }

    function setEventContract(uint256 eventId, address eventContract) external {
        // This should be called by the factory during event creation
        require(eventContracts[eventId] == address(0), "Event contract already set");
        eventContracts[eventId] = eventContract;
    }

    function deposit(uint256 eventId, address sponsor, uint256 amount) external onlyEventContract(eventId) nonReentrant {
        require(amount > 0, "Deposit must be positive");

        // Note: Transfer is handled by EventImplementation, so we don't transfer here

        if (eventSponsors[eventId][sponsor].depositAmount == 0) {
            eventSponsorList[eventId].push(sponsor);
        }

        eventSponsors[eventId][sponsor].depositAmount += amount;
        eventTotalDeposits[eventId] += amount;

        // Update share percentages for all sponsors
        _updateSharePercentages(eventId);

        emit SponsorDeposited(eventId, sponsor, amount);
    }

    function distributeRevenue(uint256 eventId, uint256 totalRevenue) external onlyEventContract(eventId) nonReentrant {
        uint256 totalDeposits = eventTotalDeposits[eventId];
        require(totalDeposits > 0, "No deposits to distribute");

        address[] memory sponsors = eventSponsorList[eventId];
        for (uint256 i = 0; i < sponsors.length; i++) {
            address sponsor = sponsors[i];
            uint256 share = (eventSponsors[eventId][sponsor].depositAmount * totalRevenue) / totalDeposits;
            if (share > 0) {
                paymentToken.transfer(sponsor, share);
                emit RevenueDistributed(eventId, sponsor, share);
            }
        }
    }

    function withdrawDeposit(uint256 eventId, address sponsor, uint256 amount) external onlyEventContract(eventId) nonReentrant {
        require(amount > 0, "Withdrawal amount must be positive");
        require(eventSponsors[eventId][sponsor].depositAmount >= amount, "Insufficient deposit balance");

        eventSponsors[eventId][sponsor].depositAmount -= amount;
        eventTotalDeposits[eventId] -= amount;

        // Update share percentages for remaining sponsors
        _updateSharePercentages(eventId);

        emit DepositWithdrawn(eventId, sponsor, amount);
    }

    function refundAllSponsors(uint256 eventId) external onlyEventContract(eventId) nonReentrant {
        uint256 totalToRefund = eventTotalDeposits[eventId];
        require(totalToRefund > 0, "No deposits to refund");

        address[] memory sponsors = eventSponsorList[eventId];
        for (uint256 i = 0; i < sponsors.length; i++) {
            address sponsor = sponsors[i];
            uint256 depositAmount = eventSponsors[eventId][sponsor].depositAmount;
            if (depositAmount > 0) {
                paymentToken.transfer(sponsor, depositAmount);
                eventSponsors[eventId][sponsor].depositAmount = 0;
            }
        }

        eventTotalDeposits[eventId] = 0;
        emit SponsorsRefunded(eventId, totalToRefund);
    }

    function getSponsorInfo(uint256 eventId, address sponsor) external view returns (SponsorInfo memory) {
        return eventSponsors[eventId][sponsor];
    }

    function getEventSponsors(uint256 eventId) external view returns (address[] memory) {
        return eventSponsorList[eventId];
    }

    function getTotalDeposits(uint256 eventId) external view returns (uint256) {
        return eventTotalDeposits[eventId];
    }

    function _updateSharePercentages(uint256 eventId) internal {
        uint256 totalDeposits = eventTotalDeposits[eventId];
        address[] memory sponsors = eventSponsorList[eventId];

        for (uint256 i = 0; i < sponsors.length; i++) {
            address sponsor = sponsors[i];
            uint256 sponsorDeposit = eventSponsors[eventId][sponsor].depositAmount;
            eventSponsors[eventId][sponsor].sharePercentage = (sponsorDeposit * 10000) / totalDeposits; // Basis points
        }
    }
}
