// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../src/contract/EventFactory.sol";
import "../src/contract/EventImplementation.sol";
import "../src/contract/Ticket.sol";
import "../src/contract/Payroll.sol";
import "../src/contract/SponsorVault.sol";
import {LibStorage} from "../src/contract/libraries/LibStorage.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Test Token", "TEST") {
        _mint(msg.sender, 1000000 * 10**18);
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract EventImplementationTest is Test {
    EventFactory public factory;
    EventImplementation public implementation;
    EventTicket public ticketContract;
    Payroll public payrollContract;
    SponsorVault public sponsorVault;
    MockERC20 public paymentToken;
    EventImplementation public proxy;

    address public owner = address(1);
    address public user = address(2);
    address public admin = address(3);

    uint256 public constant ADMIN_FEE = 5; // 5%
    uint256 public constant TICKET_PRICE = 1 ether;
    uint256 public constant MAX_TICKETS = 100;
    uint256 public constant EVENT_EXPENSES = 50 ether;

    function setUp() public {
        vm.startPrank(owner);

        // Deploy token and contracts
        paymentToken = new MockERC20();
        implementation = new EventImplementation();
        ticketContract = new EventTicket();
        payrollContract = new Payroll();
        sponsorVault = new SponsorVault();

        // Deploy factory
        factory = new EventFactory(
            address(implementation),
            address(ticketContract),
            address(payrollContract),
            address(sponsorVault),
            address(paymentToken),
            ADMIN_FEE,
            admin
        );

        vm.stopPrank();

        // Create proxy for testing
        vm.startPrank(user);
        address proxyAddress = factory.createProxy("Test Organization");
        proxy = EventImplementation(proxyAddress);
        vm.stopPrank();

        // Mint tokens
        paymentToken.mint(user, 100 ether);
    }

    function testCreateEventImpl() public {
        vm.startPrank(user);
        
        uint256 startTime = block.timestamp + 1 days;
        uint256 endTime = block.timestamp + 7 days;

        proxy.createEvent(
            "Test Event",
            TICKET_PRICE,
            MAX_TICKETS,
            startTime,
            endTime,
            "https://example.com/ticket",
            LibStorage.EventType.Paid,
            EVENT_EXPENSES
        );

        LibStorage.EventStruct memory eventInfo = proxy.getEventInfo(0);
        assertEq(eventInfo.name, "Test Event");
        assertEq(eventInfo.ticketPrice, TICKET_PRICE);
        assertEq(eventInfo.maxTickets, MAX_TICKETS);
        assertEq(eventInfo.startTime, startTime);
        assertEq(eventInfo.endTime, endTime);
        assertEq(uint(eventInfo.status), uint(LibStorage.Status.Active));
        assertEq(uint(eventInfo.eventType), uint(LibStorage.EventType.Paid));
        assertEq(eventInfo.amountNeededForExpenses, EVENT_EXPENSES);
        assertEq(eventInfo.creator, user);
        
        vm.stopPrank();
    }

    function testOnlyOwnerCanCreateEvent() public {
        vm.startPrank(address(999)); 
        
        uint256 startTime = block.timestamp + 1 days;
        uint256 endTime = block.timestamp + 7 days;

        vm.expectRevert("impl Onlyowner: Not owner");
        proxy.createEvent(
            "Unauthorized Event",
            TICKET_PRICE,
            MAX_TICKETS,
            startTime,
            endTime,
            "https://example.com/ticket",
            LibStorage.EventType.Paid,
            EVENT_EXPENSES
        );
        
        vm.stopPrank();
    }

    function testCannotCreateEventWithInvalidTimeRange() public {
        vm.startPrank(user);
        
        uint256 startTime = block.timestamp + 7 days;
        uint256 endTime = block.timestamp + 1 days; // End before start

        vm.expectRevert(INVALID_TIME_RANGE.selector);
        proxy.createEvent(
            "Invalid Event",
            TICKET_PRICE,
            MAX_TICKETS,
            startTime,
            endTime,
            "https://example.com/ticket",
            LibStorage.EventType.Paid,
            EVENT_EXPENSES
        );
        
        vm.stopPrank();
    }

    function testCannotCreateEventInPast() public {
        vm.startPrank(user);
        
        uint256 startTime = block.timestamp - 1; // Past time
        uint256 endTime = block.timestamp + 7 days;

        vm.expectRevert(START_MUST_BE_IN_FUTURE.selector);
        proxy.createEvent(
            "Past Event",
            TICKET_PRICE,
            MAX_TICKETS,
            startTime,
            endTime,
            "https://example.com/ticket",
            LibStorage.EventType.Paid,
            EVENT_EXPENSES
        );
        
        vm.stopPrank();
    }

    function testGetAllEvents() public {
        vm.startPrank(user);
        
        uint256 startTime = block.timestamp + 1 days;
        uint256 endTime = block.timestamp + 7 days;

        // Create multiple events
        proxy.createEvent(
            "Event 1",
            TICKET_PRICE,
            MAX_TICKETS,
            startTime,
            endTime,
            "https://example.com/ticket1",
            LibStorage.EventType.Paid,
            EVENT_EXPENSES
        );

        proxy.createEvent(
            "Event 2",
            TICKET_PRICE * 2,
            MAX_TICKETS / 2,
            startTime + 1 days,
            endTime + 1 days,
            "https://example.com/ticket2",
            LibStorage.EventType.Free,
            EVENT_EXPENSES * 2
        );

        LibStorage.EventStruct[] memory allEvents = proxy.getAllEvents();
        assertEq(allEvents.length, 2);
        assertEq(allEvents[0].name, "Event 1");
        assertEq(allEvents[1].name, "Event 2");
        assertEq(allEvents[1].ticketPrice, TICKET_PRICE * 2);
        
        vm.stopPrank();
    }

    function testGetEventRevenue() public {
        vm.startPrank(user);
        
        uint256 startTime = block.timestamp + 1 days;
        uint256 endTime = block.timestamp + 7 days;

        proxy.createEvent(
            "Revenue Test Event",
            TICKET_PRICE,
            MAX_TICKETS,
            startTime,
            endTime,
            "https://example.com/ticket",
            LibStorage.EventType.Paid,
            EVENT_EXPENSES
        );

        // Initially no revenue
        uint256 initialRevenue = proxy.getEventRevenue(0);
        assertEq(initialRevenue, 0);

        uint256 initialTicketsSold = proxy.getTicketTotalSale(0);
        assertEq(initialTicketsSold, 0);
        
        vm.stopPrank();
    }

    function testEventIdIncrementation() public {
        vm.startPrank(user);
        
        uint256 startTime = block.timestamp + 1 days;
        uint256 endTime = block.timestamp + 7 days;

        proxy.createEvent(
            "Event 0",
            TICKET_PRICE,
            MAX_TICKETS,
            startTime,
            endTime,
            "https://example.com/ticket0",
            LibStorage.EventType.Paid,
            EVENT_EXPENSES
        );

        proxy.createEvent(
            "Event 1",
            TICKET_PRICE,
            MAX_TICKETS,
            startTime,
            endTime,
            "https://example.com/ticket1",
            LibStorage.EventType.Free,
            EVENT_EXPENSES
        );

        LibStorage.EventStruct memory event0 = proxy.getEventInfo(0);
        LibStorage.EventStruct memory event1 = proxy.getEventInfo(1);

        assertEq(event0.id, 0);
        assertEq(event1.id, 1);
        assertEq(event0.name, "Event 0");
        assertEq(event1.name, "Event 1");
        
        vm.stopPrank();
    }

    function testFreeEvent() public {
        vm.startPrank(user);
        
        uint256 startTime = block.timestamp + 1 days;
        uint256 endTime = block.timestamp + 7 days;

    

        proxy.createEvent(
            "Free Event",
            0, // Free ticket
            MAX_TICKETS,
            startTime,
            endTime,
            "https://example.com/free-ticket",
            LibStorage.EventType.Free,
            EVENT_EXPENSES
        );

        LibStorage.EventStruct memory eventInfo = proxy.getEventInfo(0);
        assertEq(eventInfo.ticketPrice, 0);
        assertEq(uint(eventInfo.eventType), uint(LibStorage.EventType.Free));
        
        vm.stopPrank();

    }


    function testAddWorkersToPayroll() public {
    // First create an event
    vm.startPrank(user);
    uint256 startTime = block.timestamp + 1 days;
    uint256 endTime = block.timestamp + 7 days;
    
    proxy.createEvent(
        "Test Event",
        TICKET_PRICE,
        MAX_TICKETS,
        startTime,
        endTime,
        "https://example.com/ticket",
        LibStorage.EventType.Paid,
        EVENT_EXPENSES
    );
    vm.stopPrank();

    // Create array of workers
    LibStorage.WorkerInfo[] memory workers = new LibStorage.WorkerInfo[](2);
    
    // First worker
    workers[0] = LibStorage.WorkerInfo({
        salary: 5 ether,
        paid: false,
        description: "Security",
        employee: address(4),
        position: 0
    });

    // Second worker
    workers[1] = LibStorage.WorkerInfo({
        salary: 3 ether,
        paid: false,
        description: "Cleaner",
        employee: address(5),
        position: 1
    });

    // Add workers to payroll
    vm.startPrank(user);
    proxy.addWorkersToPayroll(workers, 0);

    // Verify workers were added correctly
    LibStorage.WorkerInfo memory worker1 = proxy.getWorkerInfo(address(4), 0);
    LibStorage.WorkerInfo memory worker2 = proxy.getWorkerInfo(address(5), 0);

    // Assert first worker
    assertEq(worker1.salary, 5 ether, "Worker 1 salary mismatch");
    assertEq(worker1.paid, false, "Worker 1 paid status mismatch");
    assertEq(worker1.description, "Security", "Worker 1 description mismatch");
    assertEq(worker1.employee, address(4), "Worker 1 address mismatch");
    assertEq(worker1.position, 0, "Worker 1 position mismatch");

    // Assert second worker
    assertEq(worker2.salary, 3 ether, "Worker 2 salary mismatch");
    assertEq(worker2.paid, false, "Worker 2 paid status mismatch");
    assertEq(worker2.description, "Cleaner", "Worker 2 description mismatch");
    assertEq(worker2.employee, address(5), "Worker 2 address mismatch");
    assertEq(worker2.position, 1, "Worker 2 position mismatch");

    // Verify total cost was updated correctly
    uint256 totalCost = proxy.getTotalCost(0);
    assertEq(totalCost, 8 ether, "Total cost mismatch");
    vm.stopPrank();
}
}