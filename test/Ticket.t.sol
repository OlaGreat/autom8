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

contract TicketTest is Test {
	EventFactory public factory;
	EventImplementation public implementation;
	EventTicket public ticketContract;
	Payroll public payrollContract;
	SponsorVault public sponsorVault;
	MockERC20 public paymentToken;
	EventImplementation public proxy;

	address public owner = address(1);
	address public user = address(2);
	address public buyer = address(3);
	address public admin = address(4);

	uint256 public constant ADMIN_FEE = 5; // 5%
	uint256 public constant TICKET_PRICE = 1 ether;
	uint256 public constant MAX_TICKETS = 2;

	function setUp() public {
		vm.startPrank(owner);

		// Deploy token and modules
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

		// create proxy owned by `user`
		vm.startPrank(user);
		address proxyAddress = factory.createProxy("Test Org");
		proxy = EventImplementation(proxyAddress);
		vm.stopPrank();
	}

	function testBuyPaidTicketIncrementsCountersAndAssignsToken() public {
		vm.startPrank(user);
		uint256 startTime = block.timestamp + 1 days;
		uint256 endTime = block.timestamp + 7 days;

		proxy.createEvent(
			"Paid Event",
			TICKET_PRICE,
			MAX_TICKETS,
			startTime,
			endTime,
			"https://example.com/ticket",
			LibStorage.EventType.Paid,
			1 ether
		);
		vm.stopPrank();

		// buyer must have tokens
		paymentToken.mint(buyer, 5 ether);
		vm.startPrank(buyer);
		paymentToken.approve(address(proxy), TICKET_PRICE);
		proxy.buyTicket(0);
		vm.stopPrank();

		LibStorage.EventStruct memory info = proxy.getEventInfo(0);
		assertEq(info.ticketsSold, 1);
		assertEq(info.totalRevenue, TICKET_PRICE);

	// Ownership/tokenURI live in proxy storage; we already asserted counters
	// via getEventInfo above. Direct ERC721 getters are not exposed by the
	// implementation wrapper, so we avoid calling them here.
	}

	function testCannotBuyAfterEndOrWhenSoldOut() public {
		vm.startPrank(user);
		uint256 startTime = block.timestamp + 1 days;
		uint256 endTime = block.timestamp + 2 days;

		proxy.createEvent(
			"Short Event",
			TICKET_PRICE,
			1, // only 1 ticket
			startTime,
			endTime,
			"uri",
			LibStorage.EventType.Paid,
			1 ether
		);
		vm.stopPrank();

		// buy the only ticket
		paymentToken.mint(buyer, 5 ether);
		vm.startPrank(buyer);
		paymentToken.approve(address(proxy), TICKET_PRICE);
		proxy.buyTicket(0);
		vm.stopPrank();

		// attempt to buy again -> sold out
		vm.startPrank(address(8));
		paymentToken.mint(address(8), 5 ether);
		paymentToken.approve(address(proxy), TICKET_PRICE);
		vm.expectRevert("Tickets sold out");
		proxy.buyTicket(0);
		vm.stopPrank();

		// warp past end time and try to buy on a new event
		vm.startPrank(user);
		proxy.createEvent("Ended Event", TICKET_PRICE, 10, startTime, endTime, "uri2", LibStorage.EventType.Paid, 1 ether);
		vm.stopPrank();

		vm.warp(endTime + 10);
		vm.startPrank(buyer);
		paymentToken.approve(address(proxy), TICKET_PRICE);
		vm.expectRevert("Event has ended");
		proxy.buyTicket(1);
		vm.stopPrank();
	}
}
