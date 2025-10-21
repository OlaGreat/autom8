// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "forge-std/Test.sol";
import "../../src/contract/refactor/Event.sol";
import {LibStorage} from "../../src/contract/libraries/ELibStorage.sol";
import {GlobalEventRegistry} from "../../src/contract/refactor/manager/GlobalEventRegistry.sol";

contract EventImplementationWorkersTest is Test {
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
    function createTestEvent() internal returns (uint256) {
        vm.startPrank(owner);
        uint256 startTime = block.timestamp + 1 days;
        uint256 endTime = block.timestamp + 7 days;
        string[] memory tags = new string[](2);
        tags[0] = "workers";
        tags[1] = "staff";
        eventImpl.createEvent("Test Event", 1 ether, 100, startTime, endTime, "uri", LibStorage.EventType.Paid, EVENT_EXPENSES, "Staff Management", "Hybrid", tags);
        vm.stopPrank();
        return 0;
    }
    function testAddWorkersToPayroll_HappyPath() public {
        uint256 eventId = createTestEvent();
        LibStorage.WorkerInfo[] memory workers = new LibStorage.WorkerInfo[](2);
        workers[0] = LibStorage.WorkerInfo({salary: 5 ether, paid: false, description: "Security", employee: address(4), position: 0});
        workers[1] = LibStorage.WorkerInfo({salary: 3 ether, paid: false, description: "Cleaner", employee: address(5), position: 1});
        vm.startPrank(owner);
        eventImpl.addWorkersToPayroll(workers, eventId);
        vm.stopPrank();
        LibStorage.WorkerInfo memory w1 = eventImpl.getWorkerInfo(address(4), eventId);
        LibStorage.WorkerInfo memory w2 = eventImpl.getWorkerInfo(address(5), eventId);
        assertEq(w1.salary, 5 ether);
        assertEq(w2.salary, 3 ether);
        assertEq(eventImpl.getTotalCost(eventId), 8 ether);
        LibStorage.WorkerInfo[] memory allWorkers = eventImpl.getEventWorkers(eventId);
        assertEq(allWorkers.length, 2);
    }
    function testAddWorkersToPayroll_EmptyArray_Revert() public {
        uint256 eventId = createTestEvent();
        LibStorage.WorkerInfo[] memory workers = new LibStorage.WorkerInfo[](0);
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSignature("WORKERS_CANNOT_BE_EMPTY()"));
        eventImpl.addWorkersToPayroll(workers, eventId);
        vm.stopPrank();
    }
    function testAddWorkersToPayroll_InvalidAddress_Revert() public {
        uint256 eventId = createTestEvent();
        LibStorage.WorkerInfo[] memory workers = new LibStorage.WorkerInfo[](1);
        workers[0] = LibStorage.WorkerInfo({salary: 1 ether, paid: false, description: "", employee: address(0), position: 0});
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSignature("INVALID_WORKER_ADDRESS()"));
        eventImpl.addWorkersToPayroll(workers, eventId);
        vm.stopPrank();
    }
    function testAddWorkersToPayroll_DuplicateWorker_Revert() public {
        uint256 eventId = createTestEvent();
        LibStorage.WorkerInfo[] memory workers = new LibStorage.WorkerInfo[](1);
        workers[0] = LibStorage.WorkerInfo({salary: 1 ether, paid: false, description: "", employee: address(4), position: 0});
        vm.startPrank(owner);
        eventImpl.addWorkersToPayroll(workers, eventId);
        LibStorage.WorkerInfo[] memory dup = new LibStorage.WorkerInfo[](1);
        dup[0] = LibStorage.WorkerInfo({salary: 2 ether, paid: false, description: "", employee: address(4), position: 1});
        vm.expectRevert(abi.encodeWithSignature("WORKER_ALREADY_EXIST()"));
        eventImpl.addWorkersToPayroll(dup, eventId);
        vm.stopPrank();
    }
    function testAddWorkersToPayroll_EventNotActive_Revert() public {
        vm.startPrank(owner);
        uint256 startTime = block.timestamp + 1 days;
        uint256 endTime = block.timestamp + 7 days;
        string[] memory tags = new string[](2);
        tags[0] = "workers";
        tags[1] = "staff";
        eventImpl.createEvent("Test Event", 1, 100, startTime, endTime, "uri", LibStorage.EventType.Paid, EVENT_EXPENSES, "Staff Management", "Hybrid", tags);
        uint eventId = 0;
        LibStorage.AppStorage storage s = LibStorage.appStorage();

        s.events[eventId].status = LibStorage.Status.Ended;
        LibStorage.Status status = s.events[eventId].status;




        console.log("Event 1 :::::::::::::::::::", uint(status));

        console.log("Event id :::::::::::::::::::", s.events[eventId].id);


        LibStorage.WorkerInfo[] memory workers = new LibStorage.WorkerInfo[](1);
        workers[0] = LibStorage.WorkerInfo({salary: 1, paid: false, description: "", employee: address(4), position: 0});
        // vm.startPrank(owner);
        vm.expectRevert(bytes("Event not active"));
        eventImpl.addWorkersToPayroll(workers, 0);
        vm.stopPrank();
    }
    function testAddWorkersToPayroll_EventNotFound_Revert() public {
        uint256 eventId = 999;
        LibStorage.WorkerInfo[] memory workers = new LibStorage.WorkerInfo[](1);
        workers[0] = LibStorage.WorkerInfo({salary: 1 ether, paid: false, description: "", employee: address(4), position: 0});
        vm.startPrank(owner);
        vm.expectRevert(bytes("Event not found"));
        eventImpl.addWorkersToPayroll(workers, eventId);
        vm.stopPrank();
    }
    function testUpdateWorkerAddress_HappyPath() public {
        uint256 eventId = createTestEvent();
        LibStorage.WorkerInfo[] memory workers = new LibStorage.WorkerInfo[](1);
        workers[0] = LibStorage.WorkerInfo({salary: 1 ether, paid: false, description: "Security", employee: address(4), position: 0});
        vm.startPrank(owner);
        eventImpl.addWorkersToPayroll(workers, eventId);
        eventImpl.updateWorkerAddress(address(6), address(4), eventId);
        vm.stopPrank();
        LibStorage.WorkerInfo memory w = eventImpl.getWorkerInfo(address(6), eventId);
        assertEq(w.employee, address(6));
    }
    function testUpdateWorkerSalary_HappyPath() public {
        uint256 eventId = createTestEvent();
        LibStorage.WorkerInfo[] memory workers = new LibStorage.WorkerInfo[](1);
        workers[0] = LibStorage.WorkerInfo({salary: 1 ether, paid: false, description: "Security", employee: address(4), position: 0});
        vm.startPrank(owner);
        eventImpl.addWorkersToPayroll(workers, eventId);
        eventImpl.updateWorkerSalary(address(4), 2 ether, eventId);
        vm.stopPrank();
        LibStorage.WorkerInfo memory w = eventImpl.getWorkerInfo(address(4), eventId);
        assertEq(w.salary, 2 ether);
        assertEq(eventImpl.getTotalCost(eventId), 2 ether);
    }
    function testRemoveWorker_HappyPath() public {
        uint256 eventId = createTestEvent();
        LibStorage.WorkerInfo[] memory workers = new LibStorage.WorkerInfo[](1);
        workers[0] = LibStorage.WorkerInfo({salary: 1 ether, paid: false, description: "Security", employee: address(4), position: 0});
        vm.startPrank(owner);
        eventImpl.addWorkersToPayroll(workers, eventId);
        eventImpl.removeworkerfromPayroll(eventId, address(4));
        vm.stopPrank();

        vm.expectRevert(bytes("event has no worker"));
        LibStorage.WorkerInfo[] memory allWorkers = eventImpl.getEventWorkers(eventId);
        assertEq(allWorkers.length, 0);
        assertEq(eventImpl.getTotalCost(eventId), 0);
    }
}
