// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/utils/ReentrancyGuardUpgradeable.sol";
import  "./interface/ITicket.sol";
import  "./interface/IPayroll.sol";
import  "./interface/ISponsor.sol";

import {LibStorage} from "./libraries/LibStorage.sol";

error INVALID_TIME_RANGE();
error START_MUST_BE_IN_FUTURE();
error UNAUTHORIZED_UPGRADE();

contract EventImplementation is Initializable, UUPSUpgradeable, ReentrancyGuardUpgradeable {
    using LibStorage for LibStorage.AppStorage;

    event EventPaid(uint256 eventId, uint256 timestamp);



    function initialize(
        address _owner, 
        string memory orgName, 
        address _ticketContract,
        address _payrollContract,
        address _sponsorVault,
        address _paymentToken,
        uint adminFee,
        address _adminFeeAddress,
        address dev
        ) external initializer {
        LibStorage.AppStorage storage libStorage = LibStorage.appStorage();
        libStorage.owner = _owner;
        libStorage.organizationName = orgName;
        libStorage.admins[_owner] = true;
        libStorage.paymentToken = _paymentToken;
        libStorage.adminFee = adminFee;
        libStorage.adminFeeAddress = _adminFeeAddress;
        libStorage.devAddress = dev;

        libStorage.ticketContract = ITicket(_ticketContract);
        libStorage.payrollContract = IPayroll(_payrollContract);
        libStorage.sponsorVault = ISponsor(_sponsorVault);
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
    }
    

    modifier onlyOwner() {
        LibStorage.AppStorage storage libStorage = LibStorage.appStorage();
        require(msg.sender == libStorage.owner, "Not owner");
        _;
    }

    modifier onlyImplementationOwner() {
        LibStorage.AppStorage storage libStorage = LibStorage.appStorage();
        require(msg.sender == libStorage.devAddress, "Not implementation owner");
        _;
    }

    // modifier modulesSet() {
    //     LibStorage.AppStorage storage s = LibStorage.appStorage();
    //     require(
    //         s.ticketModule != address(0) &&
    //         s.sponsorVault != address(0) &&
    //         s.payrollModule != address(0),
    //         "Modules not set"
    //     );
    //     _;
    // }


    function _delegateModuleCall(address module, bytes memory data) internal returns (bytes memory) {
        (bool success, bytes memory result) = module.delegatecall(data);
        if (!success) {
            if (result.length > 0) {
                assembly {
                    let size := mload(result)
                    revert(add(result, 32), size)
                }
            } else {
                revert("Delegatecall failed");
            }
        }
        return result;
    }

    function createEvent(
        string memory name,
        uint256 ticketPrice,
        uint256 maxTickets,
        uint256 startTime,
        uint256 endTime,
        string memory _ticketUri,
        LibStorage.EventType _eventType,
        uint _amountNeededForExpenses
    ) external onlyOwner nonReentrant {
        LibStorage.AppStorage storage libStorage = LibStorage.appStorage();

        if (startTime >= endTime) revert INVALID_TIME_RANGE();
        if (startTime <= block.timestamp) revert START_MUST_BE_IN_FUTURE();

        uint256 id = libStorage.nextEventId;
        libStorage.events[id] = LibStorage.EventStruct({
            id: id,
            name: name,
            ticketPrice: ticketPrice,
            maxTickets: maxTickets,
            ticketsSold: 0,
            totalRevenue: 0,
            startTime: startTime,
            endTime: endTime,
            status: LibStorage.Status.Active,
            ticketUri: _ticketUri,
            eventType: _eventType,
            creator: msg.sender,
            amountNeededForExpenses: _amountNeededForExpenses,
            isPaid: false
        });

        libStorage.allEvent.push(libStorage.events[id]);
        libStorage.unpaidEvents.push(libStorage.events[id]);

        libStorage.nextEventId++;
    }


    function buyTicket(uint256 eventId) external nonReentrant {
        LibStorage.AppStorage storage s = LibStorage.appStorage();
        _delegateModuleCall(
            address(s.ticketContract),
            abi.encodeWithSignature("buyTicket(uint256)", eventId)
        );
    }


    function sponsorEvent(uint256 eventId, uint256 amount) external nonReentrant  {
        LibStorage.AppStorage storage s = LibStorage.appStorage();
        _delegateModuleCall(
            address(s.sponsorVault),
            abi.encodeWithSignature("sponsorEvent(uint256,uint256)", amount, eventId)
        );
    }

    function getSponsorInfo(address sponsor, uint256 event_id) external returns (LibStorage.SponsorInfo memory){
        LibStorage.AppStorage storage s = LibStorage.appStorage();
        bytes memory result = _delegateModuleCall(
            address(s.sponsorVault),
            abi.encodeWithSignature("getSponsorInfo(address,uint256)", sponsor, event_id)
        );
        return abi.decode(result, (LibStorage.SponsorInfo));
    }
    
    function getTotalSponsorship(uint256 event_id) external returns (uint256){
        LibStorage.AppStorage storage s = LibStorage.appStorage();
        bytes memory result = _delegateModuleCall(
            address(s.sponsorVault),
            abi.encodeWithSignature("getTotalSponsorship(uint256)", event_id)
        );
        return abi.decode(result, (uint256));
    }

    function getAllSponsors(uint256 event_id) external returns (LibStorage.SponsorInfo[] memory) {
        LibStorage.AppStorage storage s = LibStorage.appStorage();
        bytes memory result = _delegateModuleCall(
            address(s.sponsorVault),
            abi.encodeWithSignature("getAllSponsors(uint256)", event_id)
        );
        return abi.decode(result, (LibStorage.SponsorInfo[]));
    }

    function addWorkersToPayroll(LibStorage.WorkerInfo[] memory workersInfo, uint256 eventId) external onlyOwner{
    LibStorage.AppStorage storage s = LibStorage.appStorage();
    _delegateModuleCall(
        address(s.payrollContract),
        abi.encodeWithSelector(
            IPayroll.addWorkersToPayroll.selector,
            workersInfo,
            eventId
        )
    );
}

    function addWorkerToPayroll(uint256 salary, string memory description, address employeeAddress, uint256 eventId) external onlyOwner{
        LibStorage.AppStorage storage s = LibStorage.appStorage();
        _delegateModuleCall(
            address(s.payrollContract),
            abi.encodeWithSignature("addWorkerToPayroll(uint256,string,address,uint256)", salary, description, employeeAddress, eventId)
        );

    }
    
    function updateWorkerAddress(address newAddress, address oldAddress, uint256 eventId) external onlyOwner(){
        LibStorage.AppStorage storage s = LibStorage.appStorage();
        _delegateModuleCall(
            address(s.payrollContract),
            abi.encodeWithSignature("updateWorkerAddress(address,address,uint256)", newAddress, oldAddress, eventId)        
        );
    }

    function updateWorkerSalary(address employeeAddress, uint256 newSalary, uint256 eventId) external onlyOwner(){
        LibStorage.AppStorage storage s = LibStorage.appStorage();
        _delegateModuleCall(
            address(s.payrollContract),
            abi.encodeWithSignature("updateWorkerSalary(address,uint256,uint256)", employeeAddress, newSalary, eventId)        
        );
    }

    function getWorkerInfo(address employee, uint256 eventId) external returns (LibStorage.WorkerInfo memory) {
        LibStorage.AppStorage storage s = LibStorage.appStorage();
        bytes memory result = _delegateModuleCall(
            address(s.payrollContract),
            abi.encodeWithSignature("getWorkerInfo(address,uint256)", employee, eventId)
        );
        return abi.decode(result, (LibStorage.WorkerInfo));
    }

    function getTotalCost(uint256 event_id) external returns (uint256) {
        LibStorage.AppStorage storage s = LibStorage.appStorage();
        require(event_id < s.nextEventId, "Event does not exist");
        bytes memory result = _delegateModuleCall(
            address(s.payrollContract),
            abi.encodeWithSignature("getTotalCost(uint256)", event_id)
        );
        return abi.decode(result, (uint256));

    }

    function getTicketTotalSale(uint256 eventId) external view returns (uint256) {
        LibStorage.AppStorage storage libStorage = LibStorage.appStorage();
        require(eventId < libStorage.nextEventId, "Event does not exist");
        return libStorage.events[eventId].ticketsSold;
    }

    function getEventRevenue(uint256 eventId) external view returns (uint256) {
        LibStorage.AppStorage storage libStorage = LibStorage.appStorage();
        require(eventId < libStorage.nextEventId, "Event does not exist");
        return libStorage.events[eventId].totalRevenue;
    }

    function getEventInfo(uint256 eventId) external view returns (LibStorage.EventStruct memory) {
        LibStorage.AppStorage storage libStorage = LibStorage.appStorage();
        require(eventId < libStorage.nextEventId, "Event does not exist");
        return libStorage.events[eventId];
    }

    function getAllEvents() external view returns (LibStorage.EventStruct[] memory) {
        LibStorage.AppStorage storage libStorage = LibStorage.appStorage();
        LibStorage.EventStruct[] memory allEvents = libStorage.allEvent;
        return allEvents;
    }   

    function getEventWorkers(uint256 event_id) external returns (LibStorage.WorkerInfo [] memory) {
        LibStorage.AppStorage storage s = LibStorage.appStorage();
        bytes memory result = _delegateModuleCall(
            address(s.payrollContract),
            abi.encodeWithSignature("getAllWorker(uint256)",event_id)
        );
        return abi.decode(result, (LibStorage.WorkerInfo []));
    }

    function getOwner() external view returns (address) {
        LibStorage.AppStorage storage libStorage = LibStorage.appStorage();
        return libStorage.owner;
    }


    function pay () external {
        LibStorage.AppStorage storage libStorage = LibStorage.appStorage();
        LibStorage.EventStruct [] storage unPaidEvents = libStorage.unpaidEvents;
        LibStorage.EventStruct [] storage events = libStorage.allEvent;
        if (unPaidEvents.length == 0) {
            return;
        }

        for (uint i = 0; i < unPaidEvents.length; i++) {
            if (!unPaidEvents[i].isPaid && block.timestamp > unPaidEvents[i].endTime) {
                uint256 eventId = unPaidEvents[i].id;
                events[eventId].isPaid = true;
                libStorage.events[eventId].isPaid = true;
                _delegateModuleCall(
                    address(libStorage.payrollContract),
                    abi.encodeWithSignature("payWorkers(uint256)", eventId)
                );

                _delegateModuleCall(
                    address(libStorage.sponsorVault),
                    abi.encodeWithSignature("distributeSponsorshipFunds(uint256)", eventId)
                );

                unPaidEvents[i] = unPaidEvents[unPaidEvents.length - 1];
                unPaidEvents.pop();
                emit EventPaid(eventId, block.timestamp);
            }
        }
    
    }


    function _authorizeUpgrade(address) internal override onlyImplementationOwner {}


}


