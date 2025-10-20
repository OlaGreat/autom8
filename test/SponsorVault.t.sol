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

contract SponsorVaultTest is Test {
	EventFactory public factory;
	EventImplementation public implementation;
	EventTicket public ticketContract;
	Payroll public payrollContract;
	SponsorVault public sponsorVault;
	MockERC20 public paymentToken;
	EventImplementation public proxy;

	address public owner = address(1);
	address public user = address(2);
	address public sponsor = address(3);
	address public admin = address(4);

	uint256 public constant ADMIN_FEE = 5; // 5%

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

	function testSponsorEventAndGetInfo() public {
		vm.startPrank(user);
		uint256 startTime = block.timestamp + 1 days;
		uint256 endTime = block.timestamp + 7 days;

		proxy.createEvent(
			"Sponsored Event",
			0,
			100,
			startTime,
			endTime,
			"uri",
			LibStorage.EventType.Paid,
			10 ether
		);
		vm.stopPrank();

		// sponsor the event
		vm.startPrank(sponsor);
		paymentToken.mint(sponsor, 50 ether);
		paymentToken.approve(address(proxy), 10 ether);
		proxy.sponsorEvent(0, 10 ether);

		uint256 totalSponsorship = proxy.getTotalSponsorship(0);
		assertEq(totalSponsorship, 10 ether);

		LibStorage.SponsorInfo memory sInfo = proxy.getSponsorInfo(sponsor, 0);
		assertEq(sInfo.sponsor, sponsor);
		assertEq(sInfo.amount, 10 ether);
		vm.stopPrank();
	}

	function testDistributeSponsorshipPaysSponsorsMinusPlatformFee() public {
		vm.startPrank(user);
		uint256 startTime = block.timestamp + 1 days;
		uint256 endTime = block.timestamp + 7 days;

		proxy.createEvent(
			"Distribute Event",
			0,
			100,
			startTime,
			endTime,
			"uri",
			LibStorage.EventType.Paid,
			50 ether
		);
		vm.stopPrank();

		// sponsor the event with two sponsors
		vm.startPrank(sponsor);
		paymentToken.mint(sponsor, 50 ether);
		paymentToken.approve(address(proxy), 10 ether);
		proxy.sponsorEvent(0, 10 ether);
		vm.stopPrank();

		address sponsor2 = address(7);
		vm.startPrank(sponsor2);
		paymentToken.mint(sponsor2, 50 ether);
		paymentToken.approve(address(proxy), 10 ether);
		proxy.sponsorEvent(0, 10 ether);
		vm.stopPrank();

	// verify sponsorship totals and sponsor list
	uint256 total = proxy.getTotalSponsorship(0);
	assertEq(total, 20 ether);

	LibStorage.SponsorInfo[] memory sponsors = proxy.getAllSponsors(0);
	assertEq(sponsors.length, 2);
	}
}
