// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {LibStorage} from "../libraries/ELibStorage.sol";


interface IGlobalEventRegistry {

    function getAllEvent() external view returns (LibStorage.EventStruct [] memory);
    function getSponserdEvents(address) external view returns (LibStorage.EventStruct [] memory );
    function getAmountPaidInSponsorShip(address) external view returns (uint256);
    function addEvent(LibStorage.EventStruct memory) external;
    function sponsorEvent (address , LibStorage.EventStruct memory) external;
    function addSponsoredAmount(address , uint256) external;
}