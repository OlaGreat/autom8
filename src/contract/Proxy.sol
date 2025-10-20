// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.20;

// import {LibStorage} from "./libraries/LibStorage.sol";



// contract EventProxy1 {

//     // constructor() payable {
//     //     LibDiamond.setContractOwner(_contractOwner); 
//     //        }

//     fallback() external payable {
//         LibStorage.AppStorage storage ds;
//         bytes32 position = LibStorage.STORAGE_SLOT;
//         assembly {
//             ds.slot := position
//         }
//         address impl = ds.implementation;
//         require(impl != address(0), "Proxy: implmentation does not exist");
//         // Execute external function from facet using delegatecall and return any value.
//         assembly {
//             // copy function selector and any arguments
//             calldatacopy(0, 0, calldatasize())
//             // execute function call using the facet
//             let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
//             // get any return value
//             returndatacopy(0, 0, returndatasize())
//             // return any return value or error back to the caller
//             switch result
//             case 0 {
//                 revert(0, returndatasize())
//             }
//             default {
//                 return(0, returndatasize())
//             }
//         }
//     }

//     receive() external payable {}


// }
