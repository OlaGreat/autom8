// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "forge-std/console.sol";

import {IPayroll} from "../contract/interface/IPayroll.sol";
import {LibStorage} from "./libraries/LibStorage.sol";

error WORKERS_CANNOT_BE_EMPTY();
error INVALID_WORKER_ADDRESS();
error WORKER_ALREADY_EXIST();
error WORKER_DOES_NOT_EXIST();
error NO_WORKER_TO_PAY();
error PAYMENT_FAILED();
error NOT_ENOUGH_BALANCE_TO_PAY_WORKER();

contract Payroll is IPayroll {
    // using LibStorage for LibStorage.AppStorage;

    modifier onlyAuthorized() {
        LibStorage.AppStorage storage libStorage = LibStorage.appStorage();
        require(msg.sender == libStorage.owner || libStorage.admins[msg.sender] , "payroll: Not owner");
        _;
    }

    function addWorkersToPayroll(LibStorage.WorkerInfo[] memory workersInfo, uint256 eventId) external onlyAuthorized {
        if (workersInfo.length == 0) revert WORKERS_CANNOT_BE_EMPTY();
        LibStorage.AppStorage storage libStorage = LibStorage.appStorage();
        require(eventId < libStorage.nextEventId, "Event does not exist");
        require(libStorage.events[eventId].status == LibStorage.Status.Active, "Event not active");

        for (uint256 i = 0; i < workersInfo.length; i++) {
            LibStorage.WorkerInfo memory worker = workersInfo[i];
            if (worker.employee == address(0)) revert INVALID_WORKER_ADDRESS();
            if (libStorage.eventWorkers[eventId][worker.employee].employee != address(0)) revert WORKER_ALREADY_EXIST();

            worker.position = libStorage.eventWorkerList[eventId].length;
            libStorage.eventWorkers[eventId][worker.employee] = worker;
            libStorage.eventWorkerList[eventId].push(worker);
            libStorage.totalCost[eventId] += worker.salary;

            emit WorkerAdded(msg.sender, worker.employee, worker.salary, eventId);
        }
    }

    function addWorkerToPayroll(uint256 salary, string memory description, address employeeAddress, uint256 eventId) external onlyAuthorized {
        LibStorage.AppStorage storage libStorage = LibStorage.appStorage();
        if (employeeAddress == address(0)) revert INVALID_WORKER_ADDRESS();
        require(eventId < libStorage.nextEventId, "Event does not exist");
        if (libStorage.eventWorkers[eventId][employeeAddress].employee != address(0)) revert WORKER_ALREADY_EXIST();

        LibStorage.WorkerInfo memory worker = LibStorage.WorkerInfo({
            salary: salary,
            paid: false,
            description: description,
            employee: employeeAddress,
            position: libStorage.eventWorkerList[eventId].length
        });

        libStorage.eventWorkers[eventId][employeeAddress] = worker;
        libStorage.eventWorkerList[eventId].push(worker);
        libStorage.totalCost[eventId] += worker.salary;

        emit WorkerAdded(msg.sender, employeeAddress, salary, eventId);
    }

    function updateWorkerAddress(address newAddress, address oldAddress, uint256 eventId) external onlyAuthorized {
        LibStorage.AppStorage storage libStorage = LibStorage.appStorage();
        require(eventId < libStorage.nextEventId, "Event does not exist");
        if (oldAddress == address(0) || newAddress == address(0)) revert INVALID_WORKER_ADDRESS();
        if (libStorage.eventWorkers[eventId][oldAddress].employee == address(0)) revert WORKER_DOES_NOT_EXIST();

        LibStorage.WorkerInfo memory worker = libStorage.eventWorkers[eventId][oldAddress];
        worker.employee = newAddress;
        libStorage.eventWorkers[eventId][newAddress] = worker;
        delete libStorage.eventWorkers[eventId][oldAddress];
        libStorage.eventWorkerList[eventId][worker.position] = worker;

        emit WorkerAddressUpdated(msg.sender, newAddress, worker.salary, oldAddress);
    }

    function updateWorkerSalary(address employeeAddress, uint256 newSalary, uint256 eventId) external onlyAuthorized {
        LibStorage.AppStorage storage libStorage = LibStorage.appStorage();
        if (employeeAddress == address(0)) revert INVALID_WORKER_ADDRESS();
        require(eventId < libStorage.nextEventId, "Event does not exist");
        if (libStorage.eventWorkers[eventId][employeeAddress].employee == address(0)) revert WORKER_DOES_NOT_EXIST();

        LibStorage.WorkerInfo storage worker = libStorage.eventWorkers[eventId][employeeAddress];
        uint256 oldSalary = worker.salary;
        worker.salary = newSalary;
        libStorage.eventWorkerList[eventId][worker.position].salary = newSalary;
        libStorage.totalCost[eventId] = libStorage.totalCost[eventId] - oldSalary + newSalary;

        emit WorkerSalaryUpdated(msg.sender, employeeAddress, newSalary, oldSalary);
    }

    function getWorkerInfo(address employee, uint256 eventId) external view returns (LibStorage.WorkerInfo memory) {
        LibStorage.AppStorage storage libStorage = LibStorage.appStorage();
        require(eventId < libStorage.nextEventId, "Event does not exist");
        if (libStorage.eventWorkers[eventId][employee].employee == address(0)) revert WORKER_DOES_NOT_EXIST();
        return libStorage.eventWorkers[eventId][employee];
    }

    function getTotalCost(uint256 event_id) external view returns (uint256){
        LibStorage.AppStorage storage libStorage = LibStorage.appStorage();
        require(event_id < libStorage.nextEventId, "Event does not exist");
        return libStorage.totalCost[event_id];
    }

    function getAllWorker(uint event_id) external view returns (LibStorage.WorkerInfo[] memory) {
        LibStorage.AppStorage storage libStorage = LibStorage.appStorage();
        require(event_id < libStorage.nextEventId, "Event does not exist");
        require(libStorage.eventWorkerList[event_id].length > 0, "event has no worker");
        return libStorage.eventWorkerList[event_id];
    }

    event moduleOwner(address indexed owner, string moduleName);

    function getPayrollOwner() external  returns (address) {
        LibStorage.AppStorage storage libStorage = LibStorage.appStorage();
        emit moduleOwner(libStorage.owner, "payroll");
        return libStorage.owner;
    }

    function payWorkers(uint256 event_id) external {
        LibStorage.AppStorage storage libStorage = LibStorage.appStorage();
        require(event_id < libStorage.nextEventId, "Event does not exist");
        LibStorage.WorkerInfo[] storage workers = libStorage.eventWorkerList[event_id];
        if (workers.length == 0) revert NO_WORKER_TO_PAY();

        IERC20 paymentToken = IERC20(libStorage.paymentToken);

        for (uint256 i = 0; i < workers.length; i++) {
            LibStorage.WorkerInfo storage worker = workers[i];

            if (!worker.paid) {
                if (libStorage.expensesBalance[event_id] < worker.salary) revert NOT_ENOUGH_BALANCE_TO_PAY_WORKER();

                worker.paid = true;
                libStorage.eventWorkers[event_id][worker.employee].paid = true;

                require(paymentToken.transfer(worker.employee, worker.salary), "Payment failed");
                libStorage.expensesBalance[event_id] -= worker.salary;
                libStorage.eventBalances[event_id] -= worker.salary;

                emit PayrollPaid(msg.sender, worker.employee, worker.salary, block.timestamp);
            }
        }
    }

    function removeWorker(uint256 event_id, address employee) external onlyAuthorized{
        LibStorage.AppStorage storage libStorage = LibStorage.appStorage();
        require(event_id < libStorage.nextEventId, "Event does not exist");
        if (employee == address(0)) revert INVALID_WORKER_ADDRESS();
        if (libStorage.eventWorkers[event_id][employee].employee == address(0)) revert WORKER_DOES_NOT_EXIST();

        LibStorage.WorkerInfo storage worker = libStorage.eventWorkers[event_id][employee];
        LibStorage.WorkerInfo[] storage workers = libStorage.eventWorkerList[event_id];

        uint256 position = worker.position;
        uint256 len = workers.length;
        if (len == 0) revert WORKER_DOES_NOT_EXIST();
        uint256 lastIndex = len - 1;

        if (position != lastIndex) {
            LibStorage.WorkerInfo storage lastWorker = workers[lastIndex];
            workers[position] = lastWorker;
            libStorage.eventWorkers[event_id][lastWorker.employee].position = position;
        }

        workers.pop();

        uint256 salary = worker.salary;
        delete libStorage.eventWorkers[event_id][employee];

        if (libStorage.totalCost[event_id] >= salary) {
            libStorage.totalCost[event_id] -= salary;
        } else {
            libStorage.totalCost[event_id] = 0;
        }

        emit WorkerRemoved(employee, salary, event_id);
    }
}
