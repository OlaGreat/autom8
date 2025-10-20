// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interface/IGlobalEventRegistry.sol";

contract GlobalEventRegistry is IGlobalEventRegistry, Ownable {
    using LibStorage for LibStorage.GlobalEventInfo;
    using LibStorage for LibStorage.SponsorHistory;

    // Storage
    LibStorage.GlobalEventInfo[] public allEvents;
    mapping(uint256 => LibStorage.GlobalEventInfo) public eventsById;
    mapping(string => LibStorage.GlobalEventInfo[]) public eventsByCategory;
    mapping(address => LibStorage.GlobalEventInfo[]) public eventsByOrganizer;
    mapping(address => LibStorage.SponsorHistory[]) public sponsorHistories;
    mapping(address => uint256) public totalSponsorContributions;

    uint256 public nextGlobalEventId = 1;

    event EventRegistered(uint256 indexed globalEventId, address indexed organizationProxy, uint256 localEventId);
    event SponsorshipRecorded(address indexed sponsor, uint256 indexed eventId, uint256 amount);

    constructor() Ownable(msg.sender) {}

    function registerEvent(
        address organizationProxy,
        uint256 localEventId,
        LibStorage.EventStruct memory eventData
    ) external {
        require(organizationProxy != address(0), "Invalid organization proxy");

        uint256 globalId = nextGlobalEventId++;

        LibStorage.GlobalEventInfo memory globalEvent = LibStorage.GlobalEventInfo({
            globalId: globalId,
            organizationProxy: organizationProxy,
            localEventId: localEventId,
            eventData: eventData
        });

        allEvents.push(globalEvent);
        eventsById[globalId] = globalEvent;
        eventsByCategory[eventData.category].push(globalEvent);
        eventsByOrganizer[eventData.creator].push(globalEvent);

        emit EventRegistered(globalId, organizationProxy, localEventId);
    }

    function getAllEvents() external view returns (LibStorage.EventStruct[] memory) {
        LibStorage.EventStruct[] memory events = new LibStorage.EventStruct[](allEvents.length);
        for (uint256 i = 0; i < allEvents.length; i++) {
            events[i] = allEvents[i].eventData;
        }
        return events;
    }

    function getEventsByCategory(string memory category) external view returns (LibStorage.EventStruct[] memory) {
        LibStorage.GlobalEventInfo[] memory categoryEvents = eventsByCategory[category];
        LibStorage.EventStruct[] memory events = new LibStorage.EventStruct[](categoryEvents.length);
        for (uint256 i = 0; i < categoryEvents.length; i++) {
            events[i] = categoryEvents[i].eventData;
        }
        return events;
    }

    function getEventsByOrganizer(address organizer) external view returns (LibStorage.EventStruct[] memory) {
        LibStorage.GlobalEventInfo[] memory organizerEvents = eventsByOrganizer[organizer];
        LibStorage.EventStruct[] memory events = new LibStorage.EventStruct[](organizerEvents.length);
        for (uint256 i = 0; i < organizerEvents.length; i++) {
            events[i] = organizerEvents[i].eventData;
        }
        return events;
    }

    function getEventById(uint256 globalEventId) external view returns (LibStorage.EventStruct memory) {
        require(globalEventId < nextGlobalEventId && globalEventId > 0, "Event not found");
        return eventsById[globalEventId].eventData;
    }

    function recordSponsorship(
        address sponsor,
        uint256 globalEventId,
        uint256 amount,
        address organizationProxy
    ) external {
        require(sponsor != address(0), "Invalid sponsor");
        require(globalEventId < nextGlobalEventId && globalEventId > 0, "Event not found");

        LibStorage.GlobalEventInfo memory eventInfo = eventsById[globalEventId];
        require(eventInfo.organizationProxy == organizationProxy, "Organization proxy mismatch");

        LibStorage.SponsorHistory memory history = LibStorage.SponsorHistory({
            eventId: globalEventId,
            organizationProxy: organizationProxy,
            amount: amount,
            timestamp: block.timestamp,
            eventName: eventInfo.eventData.name
        });

        sponsorHistories[sponsor].push(history);
        totalSponsorContributions[sponsor] += amount;

        emit SponsorshipRecorded(sponsor, globalEventId, amount);
    }

    function getSponsorHistory(address sponsor) external view returns (LibStorage.SponsorHistory[] memory) {
        return sponsorHistories[sponsor];
    }

    function getTotalSponsorContributions(address sponsor) external view returns (uint256) {
        return totalSponsorContributions[sponsor];
    }

    function getTotalEvents() external view returns (uint256) {
        return allEvents.length;
    }

    function getEventOrganization(uint256 globalEventId) external view returns (address) {
        require(globalEventId < nextGlobalEventId && globalEventId > 0, "Event not found");
        return eventsById[globalEventId].organizationProxy;
    }
}
