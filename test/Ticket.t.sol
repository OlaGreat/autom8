// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {EventTicket} from "../src/contract/Ticket.sol";

contract EventTicketTest is Test {
    // Mirror events for expectEmit
    event EventSoldOut(uint indexed eventId);
    event EventEnded(uint indexed eventId);
    event TicketPurchased(address indexed buyer, uint256 indexed eventId, uint256 ticketId, uint256 price);

    EventTicket public ticket;
    address public token;
    address public buyer = address(0xB0B);
    address public receiver = address(0xC0FFEE);

    bytes4 constant SEL_TRANSFER_FROM = bytes4(keccak256("transferFrom(address,address,uint256)"));
    bytes4 constant SEL_TRANSFER = bytes4(keccak256("transfer(address,uint256)"));

    function setUp() public {
        token = address(0xA11CE); 
        ticket = new EventTicket(token);
    }

    function _createEvent(
        string memory name,
        uint256 price,
        uint256 maxTickets,
        uint256 startOffset,
        uint256 duration,
        string memory baseURI
    ) internal returns (uint256 eventId, uint256 startTime, uint256 endTime) {
        // Ensure start is in the future relative to current block.timestamp
        startTime = block.timestamp + startOffset;
        endTime = startTime + duration;

    ticket.createEvent(name, price, maxTickets, startTime, endTime, baseURI, EventTicket.EventType.Paid);
        eventId = ticket.nextEventId() - 1;
    }

    function test_buyTicket_success_mints_and_updates_state() public {
        uint256 price = 1 ether;
        (uint256 eventId, uint256 startTime, uint256 endTime) = _createEvent(
            "Concert", price, 5, 100, 1000, "ipfs://base/"
        );

        // Move time into the event window
        vm.warp(startTime + 1);

        // Mock successful transferFrom
        vm.mockCall(
            token,
            abi.encodeWithSelector(SEL_TRANSFER_FROM, buyer, address(ticket), price),
            abi.encode(true)
        );

        // Expect TicketPurchased event
        uint256 expectedTicketId = ticket.nextTicketId();
        vm.expectEmit(true, true, false, true);
        emit TicketPurchased(buyer, eventId, expectedTicketId, price);

        // Buy ticket
        vm.prank(buyer);
        ticket.buyTicket(eventId, "ticket1.json");

        // Ownership and tokenURI
        assertEq(ticket.ownerOf(expectedTicketId), buyer);
        assertEq(ticket.tokenURI(expectedTicketId), "ipfs://base/ticket1.json");

        // Mappings and counters
        assertEq(ticket.ticketToEvent(expectedTicketId), eventId);
        EventTicket.Event memory info = ticket.getEventInfo(eventId);
        assertEq(info.ticketsSold, 1);
        assertEq(info.totalRevenue, price);
        assertEq(uint256(info.status), uint256(EventTicket.Status.Active));
        assertEq(ticket.nextTicketId(), expectedTicketId + 1);
        assertEq(info.endTime, endTime);
    }

    function test_sold_out_on_last_ticket_emits_and_blocks_further_sales() public {
        uint256 price = 2 ether;
        (uint256 eventId, uint256 startTime, ) = _createEvent(
            "Exclusive", price, 1, 50, 500, "ipfs://base/"
        );

        vm.warp(startTime + 1);

        // Mock successful transferFrom for the first (and last) ticket
        vm.mockCall(
            token,
            abi.encodeWithSelector(SEL_TRANSFER_FROM, buyer, address(ticket), price),
            abi.encode(true)
        );

        // Expect TicketPurchased followed by EventSoldOut
        uint256 expectedTicketId = ticket.nextTicketId();
        vm.expectEmit(true, true, false, true);
        emit TicketPurchased(buyer, eventId, expectedTicketId, price);
        vm.expectEmit(true, false, false, true);
        emit EventSoldOut(eventId);

        vm.prank(buyer);
        ticket.buyTicket(eventId, "only.json");

        // Verify status is SoldOut
        EventTicket.Event memory info = ticket.getEventInfo(eventId);
        assertEq(uint256(info.status), uint256(EventTicket.Status.SoldOut));
        assertEq(info.ticketsSold, 1);

        // Further purchases are blocked
        vm.expectRevert(bytes("Event not active"));
        vm.prank(buyer);
        ticket.buyTicket(eventId, "another.json");
    }

    function test_withdrawRevenue_transfers_and_resets() public {
        uint256 price = 3 ether;
        (uint256 eventId, uint256 startTime, ) = _createEvent(
            "Festival", price, 10, 100, 1000, "ipfs://base/"
        );

        vm.warp(startTime + 1);

        // One purchase to accumulate revenue
        vm.mockCall(
            token,
            abi.encodeWithSelector(SEL_TRANSFER_FROM, buyer, address(ticket), price),
            abi.encode(true)
        );
        vm.prank(buyer);
        ticket.buyTicket(eventId, "t1.json");

        // Mock successful transfer during withdraw of totalRevenue (which equals price)
        vm.mockCall(
            token,
            abi.encodeWithSelector(SEL_TRANSFER, receiver, price),
            abi.encode(true)
        );

        // Withdraw revenue
        ticket.withdrawRevenue(eventId, receiver);

        // Verify revenue reset
        EventTicket.Event memory info = ticket.getEventInfo(eventId);
        assertEq(info.totalRevenue, 0);
    }

    function test_buyTicket_reverts_on_payment_failure() public {
        uint256 price = 4 ether;
        (uint256 eventId, uint256 startTime, ) = _createEvent(
            "PayFail", price, 2, 100, 1000, "ipfs://base/"
        );

        vm.warp(startTime + 1);

        // Mock failing transferFrom
        vm.mockCall(
            token,
            abi.encodeWithSelector(SEL_TRANSFER_FROM, buyer, address(ticket), price),
            abi.encode(false)
        );

        vm.expectRevert(bytes("Payment failed"));
        vm.prank(buyer);
        ticket.buyTicket(eventId, "bad.json");

        // Ensure no state changes
        assertEq(ticket.nextTicketId(), 0);
        EventTicket.Event memory info = ticket.getEventInfo(eventId);
        assertEq(info.ticketsSold, 0);
        assertEq(info.totalRevenue, 0);
    }

    function test_buyTicket_after_endTime_marks_ended_no_charge() public {
        uint256 price = 1 ether;
        (uint256 eventId, uint256 startTime, uint256 endTime) = _createEvent(
            "Late", price, 5, 100, 200, "ipfs://base/"
        );

        // Move past the end time
        vm.warp(endTime + 1);

        // Expect EventEnded and no revert
        vm.expectEmit(true, false, false, true);
        emit EventEnded(eventId);

        // Note: If transferFrom were called, it would revert due to decoding empty return data from an EOA.
        vm.prank(buyer);
        ticket.buyTicket(eventId, "late.json");

        // Verify no mint or charge occurred, and status updated to Ended
        assertEq(ticket.nextTicketId(), 0);
        EventTicket.Event memory info = ticket.getEventInfo(eventId);
        assertEq(uint256(info.status), uint256(EventTicket.Status.Ended));
        assertEq(info.ticketsSold, 0);
        assertEq(info.totalRevenue, 0);
    }

    function test_createEvent_reverts_on_invalid_time_range() public {
        uint256 nowTs = block.timestamp;

        // startTime >= endTime
    vm.expectRevert(bytes("Invalid time range"));
    ticket.createEvent("BadRange1", 1 ether, 10, nowTs + 1000, nowTs + 1000, "ipfs://base/", EventTicket.EventType.Paid);
    vm.expectRevert(bytes("Invalid time range"));
    ticket.createEvent("BadRange2", 1 ether, 10, nowTs + 2000, nowTs + 1000, "ipfs://base/", EventTicket.EventType.Paid);

        // startTime <= current time
    vm.expectRevert(bytes("Start must be in future"));
    ticket.createEvent("BadStart", 1 ether, 10, nowTs, nowTs + 1000, "ipfs://base/", EventTicket.EventType.Paid);
    vm.expectRevert(bytes("Start must be in future"));
    ticket.createEvent("BadStart2", 1 ether, 10, nowTs - 1, nowTs + 1000, "ipfs://base/", EventTicket.EventType.Paid);
    }
}