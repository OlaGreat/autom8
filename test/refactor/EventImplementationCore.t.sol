// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "forge-std/Test.sol";
import "../../src/contract/refactor/Event.sol";
import {LibStorage} from "../../src/contract/libraries/ELibStorage.sol";
import {GlobalEventRegistry} from "../../src/contract/refactor/manager/GlobalEventRegistry.sol";

contract EventImplementationCoreTest is Test {
    EventImplementation public eventImpl;
    address public owner = address(1);
    address public admin = address(3);
    uint256 public constant ADMIN_FEE = 5;
    uint256 public constant EVENT_EXPENSES = 50 ether;
    GlobalEventRegistry public registry;
    
    function setUp() public {
        eventImpl = new EventImplementation();
        registry = new GlobalEventRegistry();
        eventImpl.initialize(owner, "TestOrg", address(0), ADMIN_FEE, admin, admin, address(registry));
    }
    function testCreateEvent_HappyPath() public {
        vm.startPrank(owner);
        uint256 startTime = block.timestamp + 1 days;
        uint256 endTime = block.timestamp + 7 days;
        string[] memory tags = new string[](2);
        tags[0] = "conference";
        tags[1] = "tech";
        eventImpl.createEvent("Test Event", 1 ether, 100, startTime, endTime, "uri", LibStorage.EventType.Paid, EVENT_EXPENSES, "Technology", "Virtual", tags);
        LibStorage.EventStruct memory eventInfo = eventImpl.getEventInfo(0);
        assertEq(eventInfo.name, "Test Event");
        assertEq(eventInfo.ticketPrice, 1 ether);
        assertEq(eventInfo.maxTickets, 100);
        assertEq(eventInfo.startTime, startTime);
        assertEq(eventInfo.endTime, endTime);
        assertEq(uint(eventInfo.status), uint(LibStorage.Status.Active));
        assertEq(uint(eventInfo.eventType), uint(LibStorage.EventType.Paid));
        assertEq(eventInfo.amountNeededForExpenses, EVENT_EXPENSES);
        assertEq(eventInfo.creator, owner);
        vm.stopPrank();
    }
}
