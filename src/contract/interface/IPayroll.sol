// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {LibStorage} from "../libraries/LibStorage.sol";


interface IPayroll {

    event WorkerAdded(address indexed addedBy, address indexed worker, uint salary, uint eventId);
    event WorkerAddressUpdated(address indexed updatedBy, address newAddress, uint salary, address oldAddress);
    event WorkerSalaryUpdated(address indexed updatedBy, address worker, uint newSalary, uint oldSalary);
    event PayrollPaid(address indexed employer,address indexed employee,uint256 amount,uint256 paymentDate);
    event WorkerRemoved(address indexed employee, uint256 salary, uint256 eventId);



   
    function addWorkersToPayroll(LibStorage.WorkerInfo[] memory worksInfo, uint eventId) external;
    function addWorkerToPayroll(uint256 salary, string memory description, address emplyeeAddress, uint256 eventId) external;

    function updateWorkerAddress(address new_address, address old_address, uint event_id) external;
    function updateWorkerSalary(address employee_address, uint256 new_salary, uint event_id) external;

    // function updatePayroll(
    //     address employee,
    //     uint256 newSalary,
    //     string memory updatedDescription
    // ) external;
    function getWorkerInfo(address employee, uint256 event_id) external view returns (LibStorage.WorkerInfo memory);   
    function getTotalCost(uint256 event_id) external view returns (uint256); 

    function payWorkers(uint256 event_id) external;
    function removeWorker(uint256 event_id, address employee) external;
    
    // function payPayroll(uint eventId) external;
}