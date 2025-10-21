// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interface/IGlobalEventRegistry.sol";


library LibStorage {
    bytes32 constant STORAGE_SLOT = keccak256("autom8.contract.storage");
    enum Status {Inactive,SoldOut,Active,Ended }
    enum EventType { Free, Paid }

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
        string category; // e.g., "conference", "concert", "workshop"
        string location; // city/country for geo-filtering
        string[] tags;   // optional tags for searchability
    }

    struct WorkerInfo {
        uint256 salary;
        bool paid;
        string description;
        address employee;
        uint256 position;
    }

    struct SponsorInfo {
        address sponsor;
        uint256 amount;
        uint256 position;
        uint eventId;
        uint percentageContribution;
    }

    struct AppStorage {
        // configuration
        address paymentToken; // ERC20 token used for payments

        // ERC721 bookkeeping
        mapping(uint256 => address) owners;
        mapping(address => uint256) balances;
        mapping(uint256 => string) tokenURIs;

        // tickets/events
        uint256 nextEventId;
        uint256 nextTicketId;
        mapping(uint256 => EventStruct) events;
        mapping(uint256 => uint256) ticketToEvent;
        // mapping(uint => uint256) eventBalance;
        EventStruct [] allEvent;


        // track unpaid event
        EventStruct [] unpaidEvents;

        // payroll
        mapping(uint256 => mapping(address => WorkerInfo)) eventWorkers;
        mapping(uint256 => WorkerInfo[]) eventWorkerList;
        mapping(uint256 => uint256) totalCost;
        // tracks balance to be spend on workers for each event. 
        mapping(uint256 => uint256) expensesBalance;

        // sponsors
        mapping(uint256 => mapping(address => SponsorInfo)) eventSponsors;
        mapping(uint256 => SponsorInfo[]) eventSponsorList;
        mapping(uint256 => uint256) totalSponsorship;

        // balances per event (token amounts)
        mapping(uint256 => uint256) eventBalances;

        // per-proxy owner / admin
        address owner;
        mapping(address => bool) admins;
        string organizationName;

        //developer
        uint256 adminFee;
        address adminFeeAddress;
        address devAddress;

        IGlobalEventRegistry globalRegistry;


    }

    function appStorage() internal pure returns (AppStorage storage s) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            s.slot := slot
        }
    }

}