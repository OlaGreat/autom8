// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ITicket {

    event EventSoldOut(uint indexed eventId);
    event EventEnded(uint indexed eventId);
    event TicketPurchased(address indexed buyer, uint256 indexed eventId, uint256 ticketId, uint256 price);
    function buyTicket(uint256 eventId) external; 
}


