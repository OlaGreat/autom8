// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {LibStorage} from "../libraries/LibStorage.sol";

interface IGlobalEventRegistry {
    // Event registration
    function registerEvent(
        address organizationProxy,
        uint256 eventId,
        LibStorage.EventStruct memory eventData
    ) external;

    // Event queries
    function getAllEvents() external view returns (LibStorage.EventStruct[] memory);
    function getEventsByCategory(string memory category) external view returns (LibStorage.EventStruct[] memory);
    function getEventsByOrganizer(address organizer) external view returns (LibStorage.EventStruct[] memory);
    function getEventById(uint256 globalEventId) external view returns (LibStorage.EventStruct memory);

    // Sponsor tracking
    function recordSponsorship(address sponsor, uint256 eventId, uint256 amount, address organizationProxy) external;
    function getSponsorHistory(address sponsor) external view returns (LibStorage.SponsorHistory[] memory);
    function getTotalSponsorContributions(address sponsor) external view returns (uint256);

    // Utility
    function getTotalEvents() external view returns (uint256);
    function getEventOrganization(uint256 globalEventId) external view returns (address);
}

library LibStorage {
    // Extended for global registry
    struct GlobalEventInfo {
        uint256 globalId;
        address organizationProxy;
        uint256 localEventId;
        EventStruct eventData;
    }

    struct SponsorHistory {
        uint256 eventId;
        address organizationProxy;
        uint256 amount;
        uint256 timestamp;
        string eventName;
    }

    // Keep existing EventStruct but add new fields
    struct EventStruct {
        uint256 id;
        string name;
        uint256 ticketPrice;
        uint256 maxTickets;
        uint256 ticketsSold;
        uint256 totalRevenue;
        uint256 startTime;
        uint256 endTime;
        Status status;
        string ticketUri;
        EventType eventType;
        address creator;
        uint256 amountNeededForExpenses;
        bool isPaid;
        // New MVP fields
        string category;
        string location;
        string[] tags;
    }

    enum Status { Inactive, Active, SoldOut, Ended }
    enum EventType { Free, Paid }
}
