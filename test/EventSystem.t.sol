// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "../src/contract/EventFactory.sol";
import "../src/contract/EventImplementation.sol";
import "../src/contract/Ticket.sol";
import "../src/contract/Payroll.sol";
import "../src/contract/SponsorVault.sol";

import "../src/contract/EventProxy.sol"; 

import {LibStorage} from "../src/contract/libraries/LibStorage.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Test Token", "TEST") {
        _mint(msg.sender, 1000000 * 10**18);
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract EventSystemTest is Test {
    EventFactory public factory;
    EventImplementation public implementation;
    EventTicket public ticketContract;
    Payroll public payrollContract;
    SponsorVault public sponsorVault;
    MockERC20 public paymentToken;
    VerifiableProxy public eventProxy;

    address public owner = address(1);
    address public user = address(2);
    address public sponsor = address(3);
    address public worker = address(4);
    address public admin = address(5);
    address public dev = address(8);

    uint256 public constant ADMIN_FEE = 5; // 5%
    uint256 public constant TICKET_PRICE = 1 ether;
    uint256 public constant MAX_TICKETS = 100;
    uint256 public constant EVENT_EXPENSES = 50 ether;

    function setUp() public {
        vm.startPrank(owner);

        // Deploy token
        paymentToken = new MockERC20();

        // Deploy implementation contracts
        implementation = new EventImplementation();
        ticketContract = new EventTicket();
        payrollContract = new Payroll();
        sponsorVault = new SponsorVault();
         bytes memory initData = abi.encodeWithSelector(
            implementation.initialize.selector,
            user, "wwwww", ticketContract, payrollContract, sponsorVault, paymentToken, 10, address(0), dev
        );

        eventProxy = new VerifiableProxy(address(implementation), user, initData);

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

        // Mint tokens to test accounts
        paymentToken.mint(user, 10 ether);
        paymentToken.mint(sponsor, 100 ether);
        paymentToken.mint(worker, 5 ether);

        vm.stopPrank();
    }

    function testCreateProxy() public {
        vm.startPrank(user);
        
        address proxyAddress = factory.createProxy("Test Organization");
        
        assertNotEq(proxyAddress, address(0));
        assertEq(factory.getOwnerProxy(user), proxyAddress);
        
        vm.stopPrank();
    }

    function testCannotCreateMultipleProxies() public {
        vm.startPrank(user);
        
        factory.createProxy("Test Organization");
        
        vm.expectRevert(USER_ALREADY_REGISTERED.selector);
        factory.createProxy("Another Organization");
        
        vm.stopPrank();
    }

    function testCreateEvent() public {
        vm.startPrank(user);
        
        address proxyAddress = factory.createProxy("Test Organization");
        EventImplementation proxy = EventImplementation(proxyAddress);

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
        assertEq(uint(eventInfo.status), uint(LibStorage.Status.Active));
        
        vm.stopPrank();
    }

    function testSponsorEvent() public {
        // Create proxy and event first
        vm.startPrank(user);
        address proxyAddress = factory.createProxy("Test Organization");
        EventImplementation proxy = EventImplementation(proxyAddress);

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

        // Sponsor the event
        vm.startPrank(sponsor);
        uint256 sponsorAmount = 10 ether;
        
        paymentToken.approve(proxyAddress, sponsorAmount);
        proxy.sponsorEvent(0, sponsorAmount);

        uint256 totalSponsorship = proxy.getTotalSponsorship(0);
        assertEq(totalSponsorship, sponsorAmount);

        LibStorage.SponsorInfo memory sponsorInfo = proxy.getSponsorInfo(sponsor, 0);
        assertEq(sponsorInfo.sponsor, sponsor);
        assertEq(sponsorInfo.amount, sponsorAmount);
        
        vm.stopPrank();
    }

    function testBuyTicket() public {
        // Create proxy and event
        vm.startPrank(user);
        address proxyAddress = factory.createProxy("Test Organization");
        EventImplementation proxy = EventImplementation(proxyAddress);

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

        // Buy ticket
        vm.startPrank(user);
        paymentToken.approve(proxyAddress, TICKET_PRICE);
        proxy.buyTicket(0);

        LibStorage.EventStruct memory eventInfo = proxy.getEventInfo(0);
        assertEq(eventInfo.ticketsSold, 1);
        assertEq(eventInfo.totalRevenue, TICKET_PRICE);

        vm.stopPrank();
    }

    function testAddWorkerToPayroll() public {
        // Create proxy and event
        vm.startPrank(user);
        address proxyAddress = factory.createProxy("Test Organization");
        EventImplementation proxy = EventImplementation(proxyAddress);

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

        // Add worker to payroll
        uint256 salary = 5 ether;
        proxy.addWorkerToPayroll(salary, "Security Guard", worker, 0);

        LibStorage.WorkerInfo memory workerInfo = proxy.getWorkerInfo(worker, 0);
        assertEq(workerInfo.salary, salary);
        assertEq(workerInfo.employee, worker);
        assertEq(workerInfo.description, "Security Guard");
        assertFalse(workerInfo.paid);

        uint256 totalCost = proxy.getTotalCost(0);
        assertEq(totalCost, salary);

        vm.stopPrank();
    }

    function testAddMultipleWorkersToPayroll() public {
        // Create proxy and event
        vm.startPrank(user);
        address proxyAddress = factory.createProxy("Test Organization");
        EventImplementation proxy = EventImplementation(proxyAddress);

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

        // Create worker array
        LibStorage.WorkerInfo[] memory workers = new LibStorage.WorkerInfo[](2);
        workers[0] = LibStorage.WorkerInfo({
            salary: 3 ether,
            paid: false,
            description: "Security",
            employee: address(10),
            position: 0
        });
        workers[1] = LibStorage.WorkerInfo({
            salary: 2 ether,
            paid: false,
            description: "Cleaner",
            employee: address(11),
            position: 0
        });

        proxy.addWorkersToPayroll(workers, 0);

        LibStorage.WorkerInfo memory worker1 = proxy.getWorkerInfo(address(10), 0);
        LibStorage.WorkerInfo memory worker2 = proxy.getWorkerInfo(address(11), 0);

        assertEq(worker1.salary, 3 ether);
        assertEq(worker2.salary, 2 ether);

        uint256 totalCost = proxy.getTotalCost(0);
        assertEq(totalCost, 5 ether);

        vm.stopPrank();
    }

    function testUpdateWorkerSalary() public {
        // Setup
        vm.startPrank(user);
        address proxyAddress = factory.createProxy("Test Organization");
        EventImplementation proxy = EventImplementation(proxyAddress);

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

        proxy.addWorkerToPayroll(5 ether, "Security Guard", worker, 0);

        // Update salary
        uint256 newSalary = 7 ether;
        proxy.updateWorkerSalary(worker, newSalary, 0);

        LibStorage.WorkerInfo memory workerInfo = proxy.getWorkerInfo(worker, 0);
        assertEq(workerInfo.salary, newSalary);

        uint256 totalCost = proxy.getTotalCost(0);
        assertEq(totalCost, newSalary);

        vm.stopPrank();
    }

    function testCannotBuyTicketAfterEventEnds() public {
        // Create proxy and event
        vm.startPrank(user);
        address proxyAddress = factory.createProxy("Test Organization");
        EventImplementation proxy = EventImplementation(proxyAddress);

        uint256 startTime = block.timestamp + 1 days;
        uint256 endTime = block.timestamp + 2 days;

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

        // Fast forward past end time
        vm.warp(endTime + 1);

        // Try to buy ticket
        vm.startPrank(user);
        paymentToken.approve(proxyAddress, TICKET_PRICE);
        
        vm.expectRevert("Event has ended");
        proxy.buyTicket(0);
        
        vm.stopPrank();
    }

    function testCannotBuyTicketWhenSoldOut() public {
        // Create proxy and event with 1 ticket max
        vm.startPrank(user);
        address proxyAddress = factory.createProxy("Test Organization");
        EventImplementation proxy = EventImplementation(proxyAddress);

        uint256 startTime = block.timestamp + 1 days;
        uint256 endTime = block.timestamp + 7 days;

        proxy.createEvent(
            "Test Event",
            TICKET_PRICE,
            1, // Only 1 ticket
            startTime,
            endTime,
            "https://example.com/ticket",
            LibStorage.EventType.Paid,
            EVENT_EXPENSES
        );

        // Buy the only ticket
        paymentToken.approve(proxyAddress, TICKET_PRICE);
        proxy.buyTicket(0);

        // Try to buy another ticket
        paymentToken.approve(proxyAddress, TICKET_PRICE);
        vm.expectRevert("Tickets sold out");
        proxy.buyTicket(0);

        vm.stopPrank();
    }

    function testFreeEventTicketPurchase() public {
        // Create proxy and free event
        vm.startPrank(user);
        address proxyAddress = factory.createProxy("Test Organization");
        EventImplementation proxy = EventImplementation(proxyAddress);

        uint256 startTime = block.timestamp + 1 days;
        uint256 endTime = block.timestamp + 7 days;

        proxy.createEvent(
            "Free Event",
            0, // Free ticket
            MAX_TICKETS,
            startTime,
            endTime,
            "https://example.com/ticket",
            LibStorage.EventType.Free,
            EVENT_EXPENSES
        );

        // Buy free ticket (no payment needed)
        proxy.buyTicket(0);

        LibStorage.EventStruct memory eventInfo = proxy.getEventInfo(0);
        assertEq(eventInfo.ticketsSold, 1);
        assertEq(eventInfo.totalRevenue, 0);

        vm.stopPrank();
    }

    function testGetAllEvents() public {
        vm.startPrank(user);
        address proxyAddress = factory.createProxy("Test Organization");
        EventImplementation proxy = EventImplementation(proxyAddress);

        uint256 startTime = block.timestamp + 1 days;
        uint256 endTime = block.timestamp + 7 days;

        // Create two events
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
            startTime,
            endTime,
            "https://example.com/ticket2",
            LibStorage.EventType.Free,
            EVENT_EXPENSES
        );

        LibStorage.EventStruct[] memory allEvents = proxy.getAllEvents();
        assertEq(allEvents.length, 2);
        assertEq(allEvents[0].name, "Event 1");
        assertEq(allEvents[1].name, "Event 2");

        vm.stopPrank();
    }

    function testGetEventRevenue() public {
        // Create proxy and event
        vm.startPrank(user);
        address proxyAddress = factory.createProxy("Test Organization");
        EventImplementation proxy = EventImplementation(proxyAddress);

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

        // Buy multiple tickets
        paymentToken.approve(proxyAddress, TICKET_PRICE * 3);
        proxy.buyTicket(0);
        proxy.buyTicket(0);
        proxy.buyTicket(0);

        uint256 revenue = proxy.getEventRevenue(0);
        assertEq(revenue, TICKET_PRICE * 3);

        uint256 ticketsSold = proxy.getTicketTotalSale(0);
        assertEq(ticketsSold, 3);

        vm.stopPrank();
    }

    function testOnlyOwnerCanCreateEvent() public {
        vm.startPrank(user);
        address proxyAddress = factory.createProxy("Test Organization");
        vm.stopPrank();

        // Try to create event as non-owner
        vm.startPrank(address(999));
        EventImplementation proxy = EventImplementation(proxyAddress);

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


    function testGetImplementationAddress() public {
        vm.startPrank(user);
        address proxyAddress = factory.createProxy("Test Organization");
        // Try to create event as non-owner
        EventImplementation proxy = EventImplementation(proxyAddress);

        
        vm.stopPrank();
        // assert(owner).equals(user);
    }



    function testInvalidEventCreation() public {
        vm.startPrank(user);
        address proxyAddress = factory.createProxy("Test Organization");
        EventImplementation proxy = EventImplementation(proxyAddress);

        uint256 startTime = block.timestamp + 1 days;
        uint256 endTime = block.timestamp + 7 days;

        // Test invalid time range
        vm.expectRevert(INVALID_TIME_RANGE.selector);
        proxy.createEvent(
            "Invalid Event",
            TICKET_PRICE,
            MAX_TICKETS,
            endTime, // Start after end
            startTime,
            "https://example.com/ticket",
            LibStorage.EventType.Paid,
            EVENT_EXPENSES
        );

        // Test start time in past
        vm.expectRevert(START_MUST_BE_IN_FUTURE.selector);
        proxy.createEvent(
            "Past Event",
            TICKET_PRICE,
            MAX_TICKETS,
            block.timestamp - 1, // Past time
            endTime,
            "https://example.com/ticket",
            LibStorage.EventType.Paid,
            EVENT_EXPENSES
        );

        vm.stopPrank();
    }
}