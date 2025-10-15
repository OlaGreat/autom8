// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {EventImplementation} from "../src/contract/EventImplementation.sol";
import {SponsorVault} from "../src/contract/SponsorVault.sol";
import {Ticket} from "../src/contract/Ticket.sol";
import {Payroll} from "../src/contract/Payroll.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract EventImplementationTest is Test {
    EventImplementation eventImpl;
    EventImplementation proxy;
    SponsorVault sponsorVault;
    Ticket ticket;
    Payroll payroll;
    ERC20Mock paymentToken;

    address owner;
    address alice;
    address bob;

    uint256 eventId = 1;
    uint256 fundingGoal = 100 ether;
    uint256 startTime;
    uint256 endTime;

    function setUp() public {
        owner = makeAddr("owner");
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        paymentToken = new ERC20Mock();
        ticket = new Ticket();
        payroll = new Payroll(address(paymentToken));
        sponsorVault = new SponsorVault(address(paymentToken));

        startTime = block.timestamp + 1 days;
        endTime = startTime + 7 days;

        eventImpl = new EventImplementation();

        // Define ticket tiers
        EventImplementation.TicketTier[] memory tiers = new EventImplementation.TicketTier[](3);
        tiers[0] = EventImplementation.TicketTier("VIP", 1 ether, 10, 0);
        tiers[1] = EventImplementation.TicketTier("General", 0.5 ether, 100, 0);
        tiers[2] = EventImplementation.TicketTier("Early Bird", 0.3 ether, 50, 0);

        bytes memory initData = abi.encodeWithSelector(
            EventImplementation.initialize.selector,
            owner,
            eventId,
            fundingGoal,
            startTime,
            endTime,
            "Test Event",
            "A test event",
            address(ticket),
            address(payroll),
            address(paymentToken),
            address(sponsorVault),
            7000, // sponsorPercentage
            500,  // platformFee
            owner, // platformWallet
            tiers
        );

        ERC1967Proxy proxyContract = new ERC1967Proxy(address(eventImpl), initData);
        proxy = EventImplementation(address(proxyContract));

        // Set the event contract in SponsorVault for access control
        sponsorVault.setEventContract(eventId, address(proxy));

        // Transfer ownership of ticket contract to the proxy
        ticket.transferOwnership(address(proxy));
    }

    function testInitialization() public {
        assertEq(proxy.owner(), owner);
        assertEq(proxy.eventId(), eventId);
        assertEq(proxy.fundingGoal(), fundingGoal);
        assertEq(proxy.startTime(), startTime);
        assertEq(proxy.endTime(), endTime);
        assertEq(proxy.isActive(), true);
        assertEq(proxy.isFreeEvent(), false);
        assertEq(proxy.sponsorPercentage(), 7000);
        assertEq(proxy.platformFee(), 500);
        assertEq(proxy.platformWallet(), owner);

        // Check ticket tiers
        (string memory name0, uint256 price0, uint256 maxSupply0, uint256 sold0) = proxy.ticketTiers(0);
        assertEq(name0, "VIP");
        assertEq(price0, 1 ether);
        assertEq(maxSupply0, 10);
        assertEq(sold0, 0);

        (string memory name1, uint256 price1, uint256 maxSupply1, uint256 sold1) = proxy.ticketTiers(1);
        assertEq(name1, "General");
        assertEq(price1, 0.5 ether);
        assertEq(maxSupply1, 100);
        assertEq(sold1, 0);
    }

    function testDepositBeforeStart() public {
        vm.prank(alice);
        vm.expectRevert("Event not in progress");
        proxy.deposit(10 ether);
    }

    function testDepositAfterEnd() public {
        vm.warp(endTime + 1);
        vm.prank(alice);
        vm.expectRevert("Event not in progress");
        proxy.deposit(10 ether);
    }

    function testDepositAfterFundingGoal() public {
        vm.warp(startTime + 1);
        vm.startPrank(alice);
        paymentToken.mint(alice, 100 ether);
        paymentToken.approve(address(proxy), 100 ether);

        proxy.deposit(50 ether);
        proxy.deposit(50 ether); // Should fail as goal met

        vm.expectRevert("Funding goal already met");
        proxy.deposit(1 ether);
        vm.stopPrank();
    }

    function testDepositSuccess() public {
        vm.warp(startTime + 1);
        vm.startPrank(alice);
        paymentToken.mint(alice, 50 ether);
        paymentToken.approve(address(proxy), 50 ether);

        proxy.deposit(50 ether);

        assertEq(proxy.currentBalance(), 50 ether);
        vm.stopPrank();
    }

    function testEndEventBeforeEndTime() public {
        vm.prank(owner);
        vm.expectRevert("Event not yet ended");
        proxy.endEvent();
    }

    function testEndEventAfterEndTime() public {
        vm.warp(endTime + 1);
        vm.prank(owner);
        proxy.endEvent();

        assertEq(proxy.isActive(), false);
    }

    function testEndEventNotOwner() public {
        vm.warp(endTime + 1);
        vm.prank(alice);
        vm.expectRevert();
        proxy.endEvent();
    }

    function testGetBalance() public {
        assertEq(proxy.getBalance(), 0);
        vm.warp(startTime + 1);
        vm.startPrank(alice);
        paymentToken.mint(alice, 25 ether);
        paymentToken.approve(address(proxy), 25 ether);
        proxy.deposit(25 ether);
        vm.stopPrank();

        assertEq(proxy.getBalance(), 25 ether);
    }

    function testGetSponsors() public {
        vm.warp(startTime + 1);
        vm.startPrank(alice);
        paymentToken.mint(alice, 25 ether);
        paymentToken.approve(address(proxy), 25 ether);
        proxy.deposit(25 ether);
        vm.stopPrank();

        vm.startPrank(bob);
        paymentToken.mint(bob, 25 ether);
        paymentToken.approve(address(proxy), 25 ether);
        proxy.deposit(25 ether);
        vm.stopPrank();

        (address[] memory sponsors, uint256[] memory deposits) = proxy.getSponsors();
        assertEq(sponsors.length, 2, "Should have 2 sponsors");
        assertEq(deposits.length, 2, "Should have 2 deposits");
        // Check that both deposits are present (order might vary)
        bool foundAlice = false;
        bool foundBob = false;
        for (uint256 i = 0; i < deposits.length; i++) {
            if (deposits[i] == 25 ether) {
                if (sponsors[i] == alice) foundAlice = true;
                if (sponsors[i] == bob) foundBob = true;
            }
        }
        assertTrue(foundAlice, "Alice's deposit should be found");
        assertTrue(foundBob, "Bob's deposit should be found");
    }

    function testFreeEvent() public {
        EventImplementation freeImpl = new EventImplementation();
        EventImplementation.TicketTier[] memory freeTiers = new EventImplementation.TicketTier[](1);
        freeTiers[0] = EventImplementation.TicketTier("Free", 0, 1000, 0);

        bytes memory freeInitData = abi.encodeWithSelector(
            EventImplementation.initialize.selector,
            owner,
            2,
            0, // fundingGoal = 0
            startTime,
            endTime,
            "Free Event",
            "A free event",
            address(ticket),
            address(payroll),
            address(paymentToken),
            address(sponsorVault),
            7000, // sponsorPercentage
            500,  // platformFee
            owner, // platformWallet
            freeTiers
        );

        ERC1967Proxy freeProxyContract = new ERC1967Proxy(address(freeImpl), freeInitData);
        EventImplementation freeProxy = EventImplementation(address(freeProxyContract));

        assertEq(freeProxy.isFreeEvent(), true);
    }

    function testPurchaseTicket() public {
        vm.warp(startTime + 1);
        vm.startPrank(alice);
        paymentToken.mint(alice, 1 ether);
        paymentToken.approve(address(proxy), 1 ether);

        // Purchase VIP ticket (tier 0)
        proxy.purchaseTicket(0);

        // Check ticket was minted and tier sold count increased
        (string memory name, uint256 price, uint256 maxSupply, uint256 sold) = proxy.ticketTiers(0);
        assertEq(sold, 1);
        assertEq(proxy.currentBalance(), 1 ether);
        vm.stopPrank();
    }

    function testPurchaseTicketSoldOut() public {
        vm.warp(startTime + 1);

        // Fill VIP tier (max 10)
        for (uint256 i = 0; i < 10; i++) {
            address buyer = makeAddr(string(abi.encodePacked("buyer", i)));
            vm.startPrank(buyer);
            paymentToken.mint(buyer, 1 ether);
            paymentToken.approve(address(proxy), 1 ether);
            proxy.purchaseTicket(0);
            vm.stopPrank();
        }

        // Try to buy 11th VIP ticket
        address buyer11 = makeAddr("buyer11");
        vm.startPrank(buyer11);
        paymentToken.mint(buyer11, 1 ether);
        paymentToken.approve(address(proxy), 1 ether);
        vm.expectRevert("Ticket tier sold out");
        proxy.purchaseTicket(0);
        vm.stopPrank();
    }

    function testPurchaseTicketInvalidTier() public {
        vm.warp(startTime + 1);
        vm.startPrank(alice);
        paymentToken.mint(alice, 1 ether);
        paymentToken.approve(address(proxy), 1 ether);

        vm.expectRevert("Invalid ticket tier");
        proxy.purchaseTicket(99); // Invalid tier
        vm.stopPrank();
    }
}
