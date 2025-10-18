 // SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

error INVALID_AMOUNT_TO_DEPOSIT();
error NO_INCOME_TO_DISTRIBUTE();

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ISponsor} from "./interface/ISponsor.sol";
import {LibStorage} from "./libraries/LibStorage.sol";

error EVENT_HAS_ENOUGH_BALANCE();

contract SponsorVault is ISponsor {

    function sponsorEvent(uint256 amount, uint256 event_id) external  {
        LibStorage.AppStorage storage libStorage = LibStorage.appStorage();
        require(event_id < libStorage.nextEventId, "Event does not exist");
        if (amount == 0) revert INVALID_AMOUNT_TO_DEPOSIT();
        if (libStorage.eventBalances[event_id] >= libStorage.events[event_id].amountNeededForExpenses) revert EVENT_HAS_ENOUGH_BALANCE();

        IERC20 paymentToken = IERC20(libStorage.paymentToken);
        paymentToken.transferFrom(msg.sender, address(this), amount);
        
        uint256 amountNeeded = libStorage.events[event_id].amountNeededForExpenses;
        uint256 _percentageContributed = (amount * 10000) /amountNeeded; 

        LibStorage.SponsorInfo memory sponsor = LibStorage.SponsorInfo({
            sponsor: msg.sender,
            amount: amount,
            position: libStorage.eventSponsorList[event_id].length,
            eventId: event_id,
            percentageContribution: _percentageContributed
        });

        libStorage.eventSponsors[event_id][msg.sender] = sponsor;
        libStorage.eventSponsorList[event_id].push(sponsor);
        libStorage.totalSponsorship[event_id] += amount;
        libStorage.eventBalances[event_id] += amount;
        libStorage.expensesBalance[event_id] += amount;
        emit EventSponsored(msg.sender, amount, event_id);        
    }


    function getSponsorInfo(address sponsor, uint256 event_id) external view returns (LibStorage.SponsorInfo memory){
        LibStorage.AppStorage storage libStorage = LibStorage.appStorage();
        require(event_id < libStorage.nextEventId, "Event does not exist");
        return libStorage.eventSponsors[event_id][sponsor];
    }
    function getTotalSponsorship(uint256 event_id) external view returns (uint256){
        LibStorage.AppStorage storage libStorage = LibStorage.appStorage();
        require(event_id < libStorage.nextEventId, "Event does not exist");
        return libStorage.totalSponsorship[event_id];
    }
    function getAllSponsors(uint256 event_id) external view returns (LibStorage.SponsorInfo[] memory){
        LibStorage.AppStorage storage libStorage = LibStorage.appStorage();
        require(event_id < libStorage.nextEventId, "Event does not exist");
        require(libStorage.eventSponsorList[event_id].length > 0,"event has no sponsor");
        return libStorage.eventSponsorList[event_id];
    }
    event moduleOwner(address indexed owner, string moduleName);

    function getSponsorOwner() external  returns (address) {
        LibStorage.AppStorage storage libStorage = LibStorage.appStorage();
    emit moduleOwner(libStorage.owner, "sponsor valut");

        return libStorage.owner;
    }


    function distributeSponsorship(uint256 event_id) external{
        LibStorage.AppStorage storage libStorage = LibStorage.appStorage();
        require(event_id < libStorage.nextEventId, "Event does not exist");
        uint256 platformFee = (libStorage.eventBalances[event_id] * libStorage.adminFee) /100;

        IERC20 paymentToken = IERC20(libStorage.paymentToken);
        (bool success1 ) = paymentToken.transfer(libStorage.adminFeeAddress, platformFee);
        require(success1, "Payment failed");

        uint256 totalIncome = libStorage.eventBalances[event_id] - platformFee;
        if (totalIncome == 0) revert NO_INCOME_TO_DISTRIBUTE();
        LibStorage.SponsorInfo [] storage sponsorInfo = libStorage.eventSponsorList[event_id];

        for (uint i = 0; i < sponsorInfo.length; i++){
            LibStorage.SponsorInfo storage sponsor = sponsorInfo[i];
            uint256 share = sponsor.percentageContribution;

            uint sponsorShare = (totalIncome * share) / 10000;
            require(paymentToken.transfer(sponsor.sponsor, sponsorShare), "payment failed");
            libStorage.eventBalances[event_id] -= sponsorShare;
            emit SponsorshipDistributed(sponsor.sponsor, sponsorShare, event_id);
        }


    }
}