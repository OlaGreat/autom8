// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

error EVENT_ENDED();
error TICKET_SOLD_OUT();
contract EventTicket is ERC721URIStorage, ReentrancyGuard {
    IERC20 public paymentToken;

    event EventSoldOut(uint indexed eventId);
    event EventEnded(uint indexed eventId);
    event TicketPurchased(address indexed buyer, uint256 indexed eventId, uint256 ticketId, uint256 price);




    enum Status {Inactive, Active, SoldOut, Ended}

    enum EventType {Free, Paid}

    struct Event {
        uint256 id;
        string name;
        uint256 ticketPrice;
        uint256 maxTickets;
        uint256 ticketsSold;
        uint256 totalRevenue;
        uint256 startTime;
        uint256 endTime;
        Status status;
        string baseURI; 
        EventType eventType;
    }

    mapping(uint256 => Event) public events;
    mapping(uint256 => uint256) public ticketToEvent;
    uint256 public nextEventId;
    uint256 public nextTicketId;

    constructor(address _paymentToken) ERC721("Event Ticket", "ETK") {
        paymentToken = IERC20(_paymentToken);
    }

        function createEvent(string memory name,uint256 ticketPrice,uint256 maxTickets,uint256 startTime,uint256 endTime,string memory baseURI, EventType _eventType) external {
        require(startTime < endTime, "Invalid time range");
        require(startTime > block.timestamp, "Start must be in future");

        events[nextEventId] = Event({
            id: nextEventId,
            name: name,
            ticketPrice: ticketPrice,
            maxTickets: maxTickets,
            ticketsSold: 0,
            totalRevenue: 0,
            startTime: startTime,
            endTime: endTime,
            status: Status.Active,
            baseURI: baseURI,
            eventType: _eventType
        });

        nextEventId++;
    }

    function buyTicket(uint256 eventId, string memory ticketURI) external nonReentrant {
        Event storage evt = events[eventId];
        require(eventId < nextEventId, "Event does not exist");
        require(evt.status == Status.Active, "Event not active");

        if (block.timestamp > evt.endTime ){
            evt.status = Status.Ended;
            emit EventEnded(eventId);
            return;
        }

        if (evt.eventType == EventType.Paid){
            bool success = paymentToken.transferFrom(msg.sender, address(this), evt.ticketPrice);
            require(success, "Payment failed");
        }


        uint256 ticketId = nextTicketId;

        _safeMint(msg.sender, ticketId);

        _setTokenURI(ticketId, string(abi.encodePacked(evt.baseURI, ticketURI)));
        emit TicketPurchased(msg.sender, eventId, ticketId, evt.ticketPrice);

        ticketToEvent[ticketId] = eventId;
        evt.ticketsSold++;
        evt.totalRevenue += evt.ticketPrice;

        nextTicketId++;

        if (evt.ticketsSold == evt.maxTickets){
            evt.status = Status.SoldOut;
            emit EventSoldOut(eventId);
        }
    }

    function getEventInfo(uint256 eventId) external view returns (Event memory) {
        return events[eventId];
    }

    function withdrawRevenue(uint256 eventId, address to) external  nonReentrant {
        Event storage evt = events[eventId];
        require(evt.totalRevenue > 0, "No revenue");
        bool success = paymentToken.transfer(to, evt.totalRevenue);
        require(success, "Withdraw failed");
        evt.totalRevenue = 0;
    }
}
