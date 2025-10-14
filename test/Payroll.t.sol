// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {Payroll} from "../src/contract/Payroll.sol";
import {IPayroll} from "../src/contract/interface/IPayroll.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract PayrollTest is Test {
    error WORKERS_CANNOT_BE_EMPTY();
    error INVALID_WORKER_ADDRESS();
    error WORKER_ALREADY_EXIST();
    error WORKER_DOES_NOT_EXIST();

    event WorkerAdded(address indexed addedBy, address indexed worker, uint salary, uint eventId);
    event WorkerAddressUpdated(address indexed updatedBy, address newAddress, uint salary, address oldAddress);
    event WorkerSalaryUpdated(address indexed updatedBy, address worker, uint newSalary, uint oldSalary);

    Payroll internal payroll;

    address internal alice;
    address internal bob;
    address internal charlie;
    ERC20Mock token;

    function setUp() public {
        token = new ERC20Mock();
        address tokenAddress = address(token);
        payroll = new Payroll(tokenAddress);
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");
    }

    function testContractDeploymentSuccess() public {
        assertTrue(address(payroll) != address(0), "deployment address should not be zero");
    }

    // Since internal state is private, initial queries for non-existent workers should revert
    function testStateVariablesInitialization() public {
        uint256 eventId = 42;

        // getWorkerInfo should revert for a non-existent worker
        vm.expectRevert(WORKER_DOES_NOT_EXIST.selector);
        payroll.getWorkerInfo(alice, eventId);
    }

    function testFunctionExecutionWithValidInputs() public {
        uint256 eventId = 1;
        uint256 salary = 100 ether;
        string memory description = "Backend Dev";

        // Expect WorkerAdded event
        vm.expectEmit(true, true, false, true, address(payroll));
        emit WorkerAdded(address(this), alice, salary, eventId);
        // Add worker
        payroll.addWorkerToPayroll(salary, description, alice, eventId);

        // Validate state after add via getter
        {
            IPayroll.WorkerInfo memory aliceInfo = payroll.getWorkerInfo(alice, eventId);
            assertEq(aliceInfo.salary, salary, "salary should match");
            assertEq(aliceInfo.paid, false, "paid should be false by default");
            assertEq(keccak256(bytes(aliceInfo.description)), keccak256(bytes(description)), "description should match");
            assertEq(aliceInfo.employee, alice, "employee should match");
            assertEq(aliceInfo.position, 0, "position should be default 0");
        }

        // Update salary -> expect event
        uint256 newSalary = 150 ether;
        vm.expectEmit(true, false, false, true, address(payroll));
        emit WorkerSalaryUpdated(address(this), alice, newSalary, salary);
        payroll.updateWorkerSalary(alice, newSalary, eventId);

        {
            IPayroll.WorkerInfo memory aliceInfo = payroll.getWorkerInfo(alice, eventId);
            assertEq(aliceInfo.salary, newSalary, "salary should be updated");
        }

        // Update address from alice to bob -> expect event
        vm.expectEmit(true, false, false, true, address(payroll));
        emit WorkerAddressUpdated(address(this), bob, newSalary, alice);
        payroll.updateWorkerAddress(bob, alice, eventId);

        // Old address should now revert (no longer exists)
        vm.expectRevert(WORKER_DOES_NOT_EXIST.selector);
        payroll.getWorkerInfo(alice, eventId);

        // New address should have worker data
        {
            IPayroll.WorkerInfo memory bobInfo = payroll.getWorkerInfo(bob, eventId);
            assertEq(bobInfo.salary, newSalary, "new address should have updated salary");
            assertEq(bobInfo.paid, false, "paid should remain false");
            assertEq(keccak256(bytes(bobInfo.description)), keccak256(bytes(description)), "description should be preserved");
            assertEq(bobInfo.employee, bob, "employee should be updated to new address");
            assertEq(bobInfo.position, 0, "position should be preserved");
        }
    }

    function testInvalidInputParameterHandling() public {
        uint256 eventId = 7;

        // addWorkerToPayroll with zero address should revert
        vm.expectRevert(INVALID_WORKER_ADDRESS.selector);
        payroll.addWorkerToPayroll(1, "X", address(0), eventId);

        // updateWorkerSalary with zero address should revert
        vm.expectRevert(INVALID_WORKER_ADDRESS.selector);
        payroll.updateWorkerSalary(address(0), 10, eventId);

        // updateWorkerAddress with zero old or new address should revert
        vm.expectRevert(INVALID_WORKER_ADDRESS.selector);
        payroll.updateWorkerAddress(bob, address(0), eventId);
        vm.expectRevert(INVALID_WORKER_ADDRESS.selector);
        payroll.updateWorkerAddress(address(0), alice, eventId);

        // getWorkerInfo for non-existent worker should revert
        vm.expectRevert(WORKER_DOES_NOT_EXIST.selector);
        payroll.getWorkerInfo(alice, eventId);

        // updateWorkerSalary for non-existent worker should revert
        vm.expectRevert(WORKER_DOES_NOT_EXIST.selector);
        payroll.updateWorkerSalary(alice, 100, eventId);
    }

    function testInsufficientGasLimitBehavior() public {
        uint256 eventId = 55;

        bytes memory payload = abi.encodeWithSelector(
            payroll.addWorkerToPayroll.selector,
            1 ether,
            "Engineer",
            charlie,
            eventId
        );

        // Call the function with deliberately insufficient gas
        (bool success, ) = address(payroll).call{gas: 20000}(payload);
        assertTrue(!success, "call should fail due to insufficient gas");

        // Verify state unaffected via getter revert
        vm.expectRevert(WORKER_DOES_NOT_EXIST.selector);
        payroll.getWorkerInfo(charlie, eventId);
    }

    function testStateConsistencyAfterFailedTransactions() public {
        uint256 eventId = 88;
        uint256 salary = 5 ether;

        // First successful add
        vm.expectEmit(true, true, false, true, address(payroll));
        emit WorkerAdded(address(this), alice, salary, eventId);
        payroll.addWorkerToPayroll(salary, "Analyst", alice, eventId);

        // Attempt to add the same worker again should revert and not change state
        vm.expectRevert(WORKER_ALREADY_EXIST.selector);
        payroll.addWorkerToPayroll(2 ether, "Different", alice, eventId);

        // State remains consistent
        IPayroll.WorkerInfo memory info = payroll.getWorkerInfo(alice, eventId);
        assertEq(info.salary, salary, "salary should remain the original");
        assertEq(info.paid, false, "paid should remain false");
        assertEq(keccak256(bytes(info.description)), keccak256(bytes("Analyst")), "description should remain unchanged");
        assertEq(info.employee, alice, "employee should remain unchanged");
        assertEq(info.position, 0, "position should remain unchanged");
    }
}