// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {EventTicketLib} from "./library/TicketManger.sol";
import {SponsorLib} from "./library/Sponsor.sol";
import {PayrollLib} from "./library/Pay-roll.sol";
import {LibStorage} from "../libraries/ELibStorage.sol";
import {IGlobalEventRegistry} from "../interface/IGlobalEventRegistry.sol";

error INVALID_TIME_RANGE();
error START_MUST_BE_IN_FUTURE();

contract EventImplementation is Initializable, UUPSUpgradeable, ReentrancyGuard {

    event EventPaid(uint256 indexed eventId, uint256 timestamp);
    event EventCreated(address indexed creator, string name, uint256 startTime, uint256 endTime);

    modifier onlyOwner() {
        require(msg.sender == LibStorage.appStorage().owner, "Not owner");
        _;
    }
    modifier onlyImplementationOwner() {
        LibStorage.AppStorage storage libStorage = LibStorage.appStorage();
        require(msg.sender == libStorage.devAddress, "impl Authorize: Not implementation owner");
        _;
    }


        function initialize(
        address _owner, 
        string memory orgName, 
        address _paymentToken,
        uint adminFee,
        address _adminFeeAddress,
        address dev,
        address _globalRegistry
        ) external initializer {
        LibStorage.AppStorage storage libStorage = LibStorage.appStorage();
        libStorage.owner = _owner;
        libStorage.organizationName = orgName;
        libStorage.admins[_owner] = true;
        libStorage.paymentToken = _paymentToken;
        libStorage.adminFee = adminFee;
        libStorage.adminFeeAddress = _adminFeeAddress;
        libStorage.devAddress = dev;
        libStorage.globalRegistry = IGlobalEventRegistry(_globalRegistry);
    }
    

    function createEvent(
        string memory name,
        uint256 ticketPrice,
        uint256 maxTickets,
        uint256 startTime,
        uint256 endTime,
        string memory ticketUri,
        LibStorage.EventType eventType,
        uint amountNeeded,
        string memory _category,
        string memory _location,
        string[] memory _tags
    ) external onlyOwner {
        require(startTime < endTime, "Invalid time range");
        require(startTime > block.timestamp, "Start must be future");

        LibStorage.AppStorage storage s = LibStorage.appStorage();
        uint256 id = s.nextEventId;

        s.events[id] = LibStorage.EventStruct({
            id: id,
            name: name,
            ticketPrice: ticketPrice,
            maxTickets: maxTickets,
            ticketsSold: 0,
            totalRevenue: 0,
            startTime: startTime,
            endTime: endTime,
            status: LibStorage.Status.Active,
            ticketUri: ticketUri,
            eventType: eventType,
            creator: msg.sender,
            amountNeededForExpenses: amountNeeded,
            isPaid: false,
            category : _category,
            location: _location,
            tags: _tags
        });

        s.allEvent.push(s.events[id]);
        s.unpaidEvents.push(s.events[id]);
        s.nextEventId++;
        LibStorage.EventStruct memory newEvent = s.events[id];

        s.globalRegistry.addEvent(newEvent);

        emit EventCreated(msg.sender, name, startTime, endTime);
    }

    function buyTicket(uint256 eventId) external nonReentrant {
        EventTicketLib.buyTicket(eventId);
    }

    function sponsorEvent(uint256 eventId, uint256 amount) external nonReentrant {
        LibStorage.EventStruct memory sposoredEvent = SponsorLib.sponsorEvent(amount, eventId);
        LibStorage.AppStorage storage libStorage = LibStorage.appStorage();

        libStorage.globalRegistry.sponsorEvent(msg.sender, sposoredEvent);
        libStorage.globalRegistry.addSponsoredAmount(msg.sender, amount);
    }

    function addWorkersToPayroll(LibStorage.WorkerInfo[] memory workers, uint256 eventId) external onlyOwner {
        PayrollLib.addWorkersToPayroll(workers, eventId);
    }

    function addWorkerToPayroll(uint256 salary, string memory desc, address emp, uint256 eventId) external onlyOwner {
        PayrollLib.addWorkerToPayroll(salary, desc, emp, eventId);
    }

    function updateWorkerAddress(address newAddr, address oldAddr, uint256 eventId) external onlyOwner {
        PayrollLib.updateWorkerAddress(newAddr, oldAddr, eventId);
    }

    function updateWorkerSalary(address emp, uint256 newSalary, uint256 eventId) external onlyOwner {
        PayrollLib.updateWorkerSalary(emp, newSalary, eventId);
    }

    function removeworkerfromPayroll (uint event_id, address employee) external onlyOwner {
        PayrollLib.removeWorker(event_id, employee);
    }

    function getEventInfo(uint256 eventId) external view returns (LibStorage.EventStruct memory) {
        LibStorage.AppStorage storage s = LibStorage.appStorage();
        require(eventId < s.nextEventId, "Event not found");
        return s.events[eventId];
    }

    function getAllEvents() external view returns (LibStorage.EventStruct[] memory) {
        return LibStorage.appStorage().allEvent;
    }

    function getWorkerInfo(address emp, uint256 eventId) external view returns (LibStorage.WorkerInfo memory) {
        return PayrollLib.getWorkerInfo(emp, eventId);
    }

    function getEventWorkers(uint256 eventId) external view returns (LibStorage.WorkerInfo[] memory) {
        return PayrollLib.getAllWorker(eventId);
    }

    function getTotalCost(uint256 eventId) external view returns (uint256) {
        return PayrollLib.getTotalCost(eventId);
    }

    function getSponsorInfo(address sponsor, uint256 eventId) external view returns (LibStorage.SponsorInfo memory) {
        return SponsorLib.getSponsorInfo(sponsor, eventId);
    }

    function getTotalSponsorship(uint256 eventId) external view returns (uint256) {
        return SponsorLib.getTotalSponsorship(eventId);
    }

    function getAllSponsors(uint256 eventId) external view returns (LibStorage.SponsorInfo[] memory) {
        return SponsorLib.getAllSponsors(eventId);
    }

    function getTicketOwner(uint256 tokenId) external view returns (address) {
        return EventTicketLib.ownerOf(tokenId);
    }

    function getTicketEvent(uint256 tokenId) external view returns (uint256) {
        return EventTicketLib.getTicketEvent(tokenId);
    }

    function pay() external {
        LibStorage.AppStorage storage s = LibStorage.appStorage();
        LibStorage.EventStruct[] storage unpaid = s.unpaidEvents;

        for (uint i = 0; i < unpaid.length; i++) {
            if (!unpaid[i].isPaid && block.timestamp > unpaid[i].endTime) {
                uint256 eventId = unpaid[i].id;
                s.events[eventId].isPaid = true;

                PayrollLib.payWorkers(eventId);
                SponsorLib.distributeSponsorship(eventId);

                unpaid[i] = unpaid[unpaid.length - 1];
                unpaid.pop();

                emit EventPaid(eventId, block.timestamp);
            }
        }
    }

    function getOwner() external view returns (address) {
        return LibStorage.appStorage().owner;
    }

    function _authorizeUpgrade(address) internal override onlyImplementationOwner {}

}