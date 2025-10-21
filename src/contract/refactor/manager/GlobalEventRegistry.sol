// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IGlobalEventRegistry} from "../../interface/IGlobalEventRegistry.sol";
import {LibStorage} from "../../libraries/ELibStorage.sol";


error INVALID_ADDRESS_ZERO();

contract GlobalEventRegistry is IGlobalEventRegistry {

    LibStorage.EventStruct [] private allEvents;
    mapping(address => LibStorage.EventStruct [] ) private sponsorsEvent;
    mapping(address => uint256) private totalAmountPaidBySponsor;


    function getAllEvent() external view returns (LibStorage.EventStruct [] memory) {
        return allEvents;
    }
    function getSponserdEvents(address sponsorsAddress) external view returns (LibStorage.EventStruct [] memory ) {
        if (sponsorsAddress == address(0)) revert INVALID_ADDRESS_ZERO();
        return sponsorsEvent[sponsorsAddress];
    }
    function getAmountPaidInSponsorShip(address sponsorsAddress) external view returns (uint256){
        if (sponsorsAddress == address(0)) revert INVALID_ADDRESS_ZERO();
        return totalAmountPaidBySponsor[sponsorsAddress];
    }

    function addEvent(LibStorage.EventStruct memory newEvent) external {
        allEvents.push(newEvent);
    }

    function sponsorEvent (address sponsorsAddress, LibStorage.EventStruct memory sponsoredEvent) external {
        if (sponsorsAddress == address(0)) revert INVALID_ADDRESS_ZERO();    
        sponsorsEvent[sponsorsAddress].push(sponsoredEvent);
    }

    function addSponsoredAmount(address sponsorsAddress, uint amount) external {
        if (sponsorsAddress == address(0)) revert INVALID_ADDRESS_ZERO();    
        totalAmountPaidBySponsor[sponsorsAddress] += amount; 
    }

}