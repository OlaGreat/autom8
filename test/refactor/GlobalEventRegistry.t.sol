// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/contract/refactor/manager/GlobalEventRegistry.sol";
import {LibStorage} from "../../src/contract/libraries/ELibStorage.sol";

contract GlobalEventRegistryTest is Test {
    GlobalEventRegistry public registry;
    address public sponsor = address(1);
    address public owner = address(2);

    function setUp() public {
        registry = new GlobalEventRegistry();
    }

    function createSampleEvent(uint256 id) internal view returns (LibStorage.EventStruct memory) {
        string [] memory _tags = new string [](2);
        _tags[0] = "web3";
        _tags[1] = "evm";
        return LibStorage.EventStruct({
            id: id,
            name: "Test Event",
            ticketPrice: 1 ether,
            maxTickets: 100,
            ticketsSold: 0,
            totalRevenue: 0,
            startTime: block.timestamp + 1 days,
            endTime: block.timestamp + 7 days,
            status: LibStorage.Status.Active,
            ticketUri: "ipfs://test",
            eventType: LibStorage.EventType.Paid,
            creator: address(2),
            amountNeededForExpenses: 50 ether,
            isPaid: false,
            category: "workshop",
            location: "Lagos",
            tags: _tags
        });
    }

    function testAddEvent() public {
        LibStorage.EventStruct memory event1 = createSampleEvent(0);
        registry.addEvent(event1);

        LibStorage.EventStruct[] memory events = registry.getAllEvent();
        assertEq(events.length, 1);
        assertEq(events[0].id, 0);
        assertEq(events[0].name, "Test Event");
        assertEq(events[0].ticketPrice, 1 ether);
    }

    function testSponsorEvent() public {
        LibStorage.EventStruct memory event1 = createSampleEvent(0);
        vm.startPrank(owner);
        registry.sponsorEvent(sponsor, event1);
        vm.stopPrank();

        LibStorage.EventStruct[] memory sponsoredEvents = registry.getSponserdEvents(sponsor);
        assertEq(sponsoredEvents.length, 1);
        assertEq(sponsoredEvents[0].id, 0);
        assertEq(sponsoredEvents[0].name, "Test Event");
    }

    function testSponsorEvent_RevertOnZeroAddress() public {
        LibStorage.EventStruct memory event1 = createSampleEvent(0);
        vm.expectRevert(INVALID_ADDRESS_ZERO.selector);
        registry.sponsorEvent(address(0), event1);
    }

    function testAddSponsoredAmount() public {
        registry.addSponsoredAmount(sponsor, 5 ether);
        assertEq(registry.getAmountPaidInSponsorShip(sponsor), 5 ether);

        // Test cumulative addition
        registry.addSponsoredAmount(sponsor, 3 ether);
        assertEq(registry.getAmountPaidInSponsorShip(sponsor), 8 ether);
    }

    function testAddSponsoredAmount_RevertOnZeroAddress() public {
        vm.expectRevert(INVALID_ADDRESS_ZERO.selector);
        registry.addSponsoredAmount(address(0), 5 ether);
    }

    function testGetSponserdEvents_RevertOnZeroAddress() public {
        vm.expectRevert(INVALID_ADDRESS_ZERO.selector);
        registry.getSponserdEvents(address(0));
    }

    function testGetAmountPaidInSponsorShip_RevertOnZeroAddress() public {
        vm.expectRevert(INVALID_ADDRESS_ZERO.selector);
        registry.getAmountPaidInSponsorShip(address(0));
    }

    function testMultipleEvents() public {
        // Add multiple events
        for(uint i = 0; i < 3; i++) {
            LibStorage.EventStruct memory event_ = createSampleEvent(i);
            registry.addEvent(event_);
        }

        LibStorage.EventStruct[] memory events = registry.getAllEvent();
        assertEq(events.length, 3);
        
        // Verify each event
        for(uint i = 0; i < 3; i++) {
            assertEq(events[i].id, i);
            assertEq(events[i].name, "Test Event");
        }
    }

    function testMultipleSponsoredEvents() public {
        // Sponsor multiple events
        for(uint i = 0; i < 3; i++) {
            LibStorage.EventStruct memory event_ = createSampleEvent(i);
            registry.sponsorEvent(sponsor, event_);
            registry.addSponsoredAmount(sponsor, 1 ether);
        }

        LibStorage.EventStruct[] memory sponsoredEvents = registry.getSponserdEvents(sponsor);
        assertEq(sponsoredEvents.length, 3);
        
        // Verify total sponsored amount
        assertEq(registry.getAmountPaidInSponsorShip(sponsor), 3 ether);
    }

    function testDifferentSponsors() public {
        address sponsor1 = address(10);
        address sponsor2 = address(11);

        // Add events for different sponsors
        LibStorage.EventStruct memory event1 = createSampleEvent(0);
        LibStorage.EventStruct memory event2 = createSampleEvent(1);

        registry.sponsorEvent(sponsor1, event1);
        registry.sponsorEvent(sponsor2, event2);

        registry.addSponsoredAmount(sponsor1, 5 ether);
        registry.addSponsoredAmount(sponsor2, 3 ether);

        // Verify sponsor1's data
        LibStorage.EventStruct[] memory sponsor1Events = registry.getSponserdEvents(sponsor1);
        assertEq(sponsor1Events.length, 1);
        assertEq(sponsor1Events[0].id, 0);
        assertEq(registry.getAmountPaidInSponsorShip(sponsor1), 5 ether);

        // Verify sponsor2's data
        LibStorage.EventStruct[] memory sponsor2Events = registry.getSponserdEvents(sponsor2);
        assertEq(sponsor2Events.length, 1);
        assertEq(sponsor2Events[0].id, 1);
        assertEq(registry.getAmountPaidInSponsorShip(sponsor2), 3 ether);
    }
}