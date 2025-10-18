// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ITicket} from "./interface/ITicket.sol";
import {LibStorage} from "./libraries/LibStorage.sol";

error EVENT_ENDED();
error TICKET_SOLD_OUT();
error INVALID_TOKEN_ID();
error NOT_OWNER_OR_APPROVED();

contract EventTicket is ITicket {

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);


    function buyTicket(uint256 eventId) external {
        LibStorage.AppStorage storage libStorage = LibStorage.appStorage();
        
        LibStorage.EventStruct storage evt = libStorage.events[eventId];
        require(eventId < libStorage.nextEventId, "Event does not exist");
        require(block.timestamp <= evt.endTime, "Event has ended");
        require(evt.ticketsSold < evt.maxTickets, "Tickets sold out");
        require(evt.status == LibStorage.Status.Active, "Event not active");

        if (evt.eventType == LibStorage.EventType.Paid){
            IERC20 token = IERC20(libStorage.paymentToken);
            require(token.transferFrom(msg.sender, address(this), evt.ticketPrice), "Payment failed");
        }

        uint256 ticketId = libStorage.nextTicketId;

        _mint(msg.sender, ticketId);
        _setTokenURI(ticketId, evt.ticketUri);
        
        emit TicketPurchased(msg.sender, eventId, ticketId, evt.ticketPrice);

        libStorage.ticketToEvent[ticketId] = eventId;
        evt.ticketsSold++;
        evt.totalRevenue += evt.ticketPrice;
        libStorage.nextTicketId++;
        libStorage.eventBalances[eventId] += evt.ticketPrice;

        if (evt.ticketsSold == evt.maxTickets){
            evt.status = LibStorage.Status.SoldOut;
            emit EventSoldOut(eventId);
        }
    }

    function _mint(address to, uint256 tokenId) internal {
        LibStorage.AppStorage storage s = LibStorage.appStorage();
        require(to != address(0), "ERC721: mint to the zero address");
        require(s.owners[tokenId] == address(0), "ERC721: token already minted");

        s.balances[to] += 1;
        s.owners[tokenId] = to;

        emit Transfer(address(0), to, tokenId);
    }

    function _setTokenURI(uint256 tokenId, string memory uri) internal {
        LibStorage.AppStorage storage s = LibStorage.appStorage();
        require(s.owners[tokenId] != address(0), "ERC721: URI set of nonexistent token");
        s.tokenURIs[tokenId] = uri;
    }

    function ownerOf(uint256 tokenId) external view returns (address) {
        LibStorage.AppStorage storage s = LibStorage.appStorage();
        address owner = s.owners[tokenId];
        require(owner != address(0), "ERC721: owner query for nonexistent token");
        return owner;
    }

    event moduleOwner(address indexed owner, string moduleName);

    function getTicketOwner() external  returns (address) {
        LibStorage.AppStorage storage libStorage = LibStorage.appStorage();
        emit moduleOwner (libStorage.owner, "ticket");

        return libStorage.owner;
    }

    function balanceOf(address owner) external view returns (uint256) {
        LibStorage.AppStorage storage s = LibStorage.appStorage();
        require(owner != address(0), "ERC721: balance query for the zero address");
        return s.balances[owner];
    }

    function tokenURI(uint256 tokenId) external view returns (string memory) {
        LibStorage.AppStorage storage s = LibStorage.appStorage();
        require(s.owners[tokenId] != address(0), "ERC721: URI query for nonexistent token");
        return s.tokenURIs[tokenId];
    }

    function getTicketEvent(uint256 ticketId) external view returns (uint256) {
        LibStorage.AppStorage storage s = LibStorage.appStorage();
        require(s.owners[ticketId] != address(0), "ERC721: query for nonexistent token");
        return s.ticketToEvent[ticketId];
    }
}
