// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPayroll} from "../contract/interface/IPayroll.sol";

error WORKERS_CANNOT_BE_EMPTY();
error INVALID_WORKER_ADDRESS();
error WORKER_ALREADY_EXIST();
error WORKER_DOES_NOT_EXIST();
error  NO_WORKER_TO_PAY();
error PAYMENT_FAILED();

contract Payroll is IPayroll, ReentrancyGuard {
    IERC20 paymentToken;

    constructor (address _token){
        paymentToken = IERC20(_token);
    }

    mapping(uint => mapping(address => WorkerInfo)) private eventWorkers;
    mapping(uint => uint) private totalCost; 
    mapping(uint => WorkerInfo[]) private eventWorkerList; 

    function addWorkersToPayroll(WorkerInfo[] memory workersInfo, uint eventId) external {
        if (workersInfo.length == 0) revert WORKERS_CANNOT_BE_EMPTY();

        for (uint i = 0; i < workersInfo.length; i++) {
            WorkerInfo memory worker = workersInfo[i];
            if (worker.employee == address(0)) revert INVALID_WORKER_ADDRESS();
            if (eventWorkers[eventId][worker.employee].employee != address(0)) revert WORKER_ALREADY_EXIST();

            worker.position = eventWorkerList[eventId].length;
            eventWorkers[eventId][worker.employee] = worker;
            eventWorkerList[eventId].push(worker);
            totalCost[eventId] += worker.salary;

            emit WorkerAdded(msg.sender, worker.employee, worker.salary, eventId);
        }
    }

    function addWorkerToPayroll(uint256 salary,string memory description,address employeeAddress,uint256 eventId) external {
        if (employeeAddress == address(0)) revert INVALID_WORKER_ADDRESS();
        if (eventWorkers[eventId][employeeAddress].employee != address(0)) revert WORKER_ALREADY_EXIST();

        WorkerInfo memory worker = WorkerInfo({
            salary: salary,
            paid: false,
            description: description,
            employee: employeeAddress,
            position: eventWorkerList[eventId].length
        });

        eventWorkers[eventId][employeeAddress] = worker;
        eventWorkerList[eventId].push(worker);
        totalCost[eventId] += worker.salary;

        emit WorkerAdded(msg.sender, employeeAddress, salary, eventId);
    }

    function updateWorkerAddress(address newAddress, address oldAddress, uint eventId) external {
        if (oldAddress == address(0) || newAddress == address(0)) revert INVALID_WORKER_ADDRESS();
        if (eventWorkers[eventId][oldAddress].employee == address(0)) revert WORKER_DOES_NOT_EXIST();

        WorkerInfo memory worker = eventWorkers[eventId][oldAddress];
        worker.employee = newAddress;
        eventWorkers[eventId][newAddress] = worker;
        delete eventWorkers[eventId][oldAddress];
        eventWorkerList[eventId][worker.position] = worker;

        emit WorkerAddressUpdated(msg.sender, newAddress, worker.salary, oldAddress);
    }

    function updateWorkerSalary(address employeeAddress, uint256 newSalary, uint eventId) external {
        if (employeeAddress == address(0)) revert INVALID_WORKER_ADDRESS();
        if (eventWorkers[eventId][employeeAddress].employee == address(0)) revert WORKER_DOES_NOT_EXIST();

        WorkerInfo storage worker = eventWorkers[eventId][employeeAddress];
        uint256 oldSalary = worker.salary;
        worker.salary = newSalary;
        eventWorkerList[eventId][worker.position].salary = newSalary;
        totalCost[eventId] = totalCost[eventId] - oldSalary + newSalary;

        emit WorkerSalaryUpdated(msg.sender, employeeAddress, newSalary, oldSalary);
    }

    function getWorkerInfo(address employee, uint256 eventId) external view returns (WorkerInfo memory) {
        if (eventWorkers[eventId][employee].employee == address(0)) revert WORKER_DOES_NOT_EXIST();
        return eventWorkers[eventId][employee];
    }

    function getTotalCost(uint256 event_id) external view returns (uint256){
        return totalCost[event_id];
    }

    // function payWorkers(uint256 event_id) external {
    //     WorkerInfo[] memory workers = eventWorkerList[event_id];
    //     if (workers.length == 0) revert NO_WORKER_TO_PAY();
    //     for (uint i = 0; i < workers.length; i++) {
    //         WorkerInfo memory worker = workers[i];
    //         if (!worker.paid) {
    //             eventWorkers[event_id][worker.employee].paid = true;
    //             eventWorkerList[event_id][i].paid = true;
    //             payable(worker.employee).transfer(worker.salary);

    //             emit PayrollPaid(msg.sender, worker.employee, worker.salary, block.timestamp);
    //         }
    //     }
    // }

    function payWorkers(uint event_id) external nonReentrant{
        WorkerInfo [] storage workers = eventWorkerList[event_id];
        if (workers.length == 0) revert NO_WORKER_TO_PAY();
        for(uint i = 0; i < workers.length; i++) {
            WorkerInfo memory worker = workers[i];

            if (!worker.paid) {
                eventWorkers[event_id][worker.employee].paid = true;
                eventWorkerList[event_id][i].paid = true;

                bool success = paymentToken.transferFrom(address(this), worker.employee, worker.salary);
                if (!success) revert PAYMENT_FAILED();

                emit PayrollPaid(msg.sender, worker.employee, worker.salary, block.timestamp);

            }
        }

        
    }


}
