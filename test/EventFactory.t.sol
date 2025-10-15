// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {EventFactory} from "../src/contract/EventFactory.sol";
import {EventImplementation} from "../src/contract/EventImplementation.sol";
import {SponsorVault} from "../src/contract/SponsorVault.sol";
import {Ticket} from "../src/contract/Ticket.sol";
import {Payroll} from "../src/contract/Payroll.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract EventFactoryTest is Test {
    EventFactory factory;
    EventImplementation implementation;
    SponsorVault sponsorVault;
    Ticket ticket;
    Payroll payroll;
    ERC20Mock paymentToken;

    address owner;
    address deployer;
    address alice;

    function setUp() public {
        owner = makeAddr("owner");
        deployer = makeAddr("deployer");
        alice = makeAddr("alice");

        paymentToken = new ERC20Mock();
        ticket = new Ticket();
        payroll = new Payroll(address(paymentToken));
        sponsorVault = new SponsorVault(address(paymentToken));
        implementation = new EventImplementation();

        vm.prank(owner);
        factory = new EventFactory(address(implementation), address(sponsorVault));

        vm.prank(owner);
        factory.authorizeDeployer(deployer);
    }

    function testFactoryDeployment() public {
        assertEq(factory.implementation(), address(implementation));
        assertEq(factory.sponsorVault(), address(sponsorVault));
        assertEq(factory.owner(), owner);
    }

    function testCreateEvent() public {
        vm.prank(deployer);

        uint256 fundingGoal = 100 ether;
        uint256 startTime = block.timestamp + 1 days;
        uint256 endTime = startTime + 7 days;
        string memory eventName = "Test Event";
        string memory description = "A test event";

        // Define ticket tiers
        EventImplementation.TicketTier[] memory tiers = new EventImplementation.TicketTier[](2);
        tiers[0] = EventImplementation.TicketTier("VIP", 2 ether, 20, 0);
        tiers[1] = EventImplementation.TicketTier("Standard", 1 ether, 100, 0);

        address eventAddress = factory.createEvent(
            fundingGoal,
            startTime,
            endTime,
            eventName,
            description,
            address(ticket),
            address(payroll),
            address(paymentToken),
            tiers
        );

        assertTrue(eventAddress != address(0));
        assertEq(factory.getOwnerEventCount(deployer), 1);
        assertEq(factory.getOwnerEvents(deployer)[0], eventAddress);

        // Verify ticket tiers were set correctly
        EventImplementation eventContract = EventImplementation(eventAddress);
        (string memory name0, uint256 price0, uint256 maxSupply0, uint256 sold0) = eventContract.ticketTiers(0);
        assertEq(name0, "VIP");
        assertEq(price0, 2 ether);
        assertEq(maxSupply0, 20);
    }

    function testCreateFreeEvent() public {
        vm.prank(deployer);

        uint256 fundingGoal = 0;
        uint256 startTime = block.timestamp + 1 days;
        uint256 endTime = startTime + 7 days;
        string memory eventName = "Free Event";
        string memory description = "A free event";

        // Define free ticket tiers
        EventImplementation.TicketTier[] memory tiers = new EventImplementation.TicketTier[](1);
        tiers[0] = EventImplementation.TicketTier("Free", 0, 1000, 0);

        address eventAddress = factory.createEvent(
            fundingGoal,
            startTime,
            endTime,
            eventName,
            description,
            address(ticket),
            address(payroll),
            address(paymentToken),
            tiers
        );

        assertTrue(eventAddress != address(0));
        assertEq(factory.getOwnerEventCount(deployer), 1);
    }

    function testUnauthorizedDeployerCannotCreateEvent() public {
        vm.prank(alice);

        uint256 fundingGoal = 100 ether;
        uint256 startTime = block.timestamp + 1 days;
        uint256 endTime = startTime + 7 days;
        string memory eventName = "Test Event";
        string memory description = "A test event";

        // Define ticket tiers for unauthorized test
        EventImplementation.TicketTier[] memory tiers = new EventImplementation.TicketTier[](1);
        tiers[0] = EventImplementation.TicketTier("Standard", 1 ether, 100, 0);

        vm.expectRevert("Not authorized to deploy");
        factory.createEvent(
            fundingGoal,
            startTime,
            endTime,
            eventName,
            description,
            address(ticket),
            address(payroll),
            address(paymentToken),
            tiers
        );
    }

    function testInvalidTimeRange() public {
        vm.prank(deployer);

        uint256 fundingGoal = 100 ether;
        uint256 startTime = block.timestamp + 7 days;
        uint256 endTime = startTime - 1 days; // Invalid: end before start
        string memory eventName = "Test Event";
        string memory description = "A test event";

        // Define ticket tiers for invalid time test
        EventImplementation.TicketTier[] memory tiers = new EventImplementation.TicketTier[](1);
        tiers[0] = EventImplementation.TicketTier("Standard", 1 ether, 100, 0);

        vm.expectRevert("Invalid time range");
        factory.createEvent(
            fundingGoal,
            startTime,
            endTime,
            eventName,
            description,
            address(ticket),
            address(payroll),
            address(paymentToken),
            tiers
        );
    }

    function testEventIdIncrement() public {
        vm.startPrank(deployer);

        // Define ticket tiers for first event
        EventImplementation.TicketTier[] memory tiers1 = new EventImplementation.TicketTier[](1);
        tiers1[0] = EventImplementation.TicketTier("VIP", 2 ether, 50, 0);

        // First event
        address event1 = factory.createEvent(
            100 ether,
            block.timestamp + 1 days,
            block.timestamp + 8 days,
            "Event 1",
            "Description 1",
            address(ticket),
            address(payroll),
            address(paymentToken),
            tiers1
        );

        // Define ticket tiers for second event
        EventImplementation.TicketTier[] memory tiers2 = new EventImplementation.TicketTier[](1);
        tiers2[0] = EventImplementation.TicketTier("Standard", 1 ether, 100, 0);

        // Second event
        address event2 = factory.createEvent(
            200 ether,
            block.timestamp + 2 days,
            block.timestamp + 9 days,
            "Event 2",
            "Description 2",
            address(ticket),
            address(payroll),
            address(paymentToken),
            tiers2
        );

        vm.stopPrank();

        assertTrue(event1 != event2);
        assertEq(factory.getOwnerEventCount(deployer), 2);
    }
}
