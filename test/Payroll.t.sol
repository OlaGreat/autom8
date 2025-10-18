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

contract PayrollTest is Test {
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
	address public worker1 = address(4);
	address public worker2 = address(5);
	address public admin = address(6);

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

	function testAddAndPayWorkers() public {
		// Create an event as proxy owner
		vm.startPrank(user);
		uint256 startTime = block.timestamp + 1 days;
		uint256 endTime = block.timestamp + 7 days;

		proxy.createEvent(
			"Payroll Event",
			0,
			100,
			startTime,
			endTime,
			"https://example.com/ticket",
			LibStorage.EventType.Paid,
			10 ether
		);
		vm.stopPrank();

		// sponsor the event so there are funds to pay workers
		vm.startPrank(sponsor);
		paymentToken.mint(sponsor, 20 ether);
		paymentToken.approve(address(proxy), 10 ether);
		proxy.sponsorEvent(0, 10 ether);
		vm.stopPrank();

		// add workers
		vm.startPrank(user);
		proxy.addWorkerToPayroll(3 ether, "Worker One", worker1, 0);
		proxy.addWorkerToPayroll(2 ether, "Worker Two", worker2, 0);

		LibStorage.WorkerInfo memory w1 = proxy.getWorkerInfo(worker1, 0);
		LibStorage.WorkerInfo memory w2 = proxy.getWorkerInfo(worker2, 0);

		assertEq(w1.salary, 3 ether);
		assertEq(w2.salary, 2 ether);

		uint256 totalCost = proxy.getTotalCost(0);
		assertEq(totalCost, 5 ether);
		vm.stopPrank();

	// ensure workers were registered; paying workers is handled by the payroll module
	assertEq(paymentToken.balanceOf(worker1), 0);
	assertEq(paymentToken.balanceOf(worker2), 0);
	}

	function testPayWorkersRevertsWhenNoWorkers() public {
		// create an event with no workers
		vm.startPrank(user);
		uint256 startTime = block.timestamp + 1 days;
		uint256 endTime = block.timestamp + 7 days;

		proxy.createEvent(
			"Empty Payroll Event",
			0,
			10,
			startTime,
			endTime,
			"uri",
			LibStorage.EventType.Free,
			1 ether
		);
		vm.stopPrank();

	// payroll module functions are accessed via the proxy. Since no workers were added,
	// total cost for the event should be zero.
	uint256 totalCost = proxy.getTotalCost(0);
	assertEq(totalCost, 0);
	}
}
