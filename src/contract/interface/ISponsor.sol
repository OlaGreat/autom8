// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {LibStorage} from "../libraries/LibStorage.sol";


interface ISponsor {
    // event SponsorAdded(address indexed sponsor, uint256 amount, uint256 eventId);
    // event SponsorRemoved(address indexed sponsor, uint256 amount, uint256 eventId);
    event SponsorshipDistributed(address indexed distributor, uint256 totalAmount, uint256 eventId);
    event EventSponsored(address indexed sponsor, uint256 amount, uint256 eventId);


    function sponsorEvent(uint256 amount, uint256 eventId) external;
    // function addSponsor(address sponsor, uint256 amount, uint256 eventId) external;
    // function removeSponsor(address sponsor, uint256 eventId) external;
    function getSponsorInfo(address sponsor, uint256 eventId) external view returns (LibStorage.SponsorInfo memory);
    function getTotalSponsorship(uint256 eventId) external view returns (uint256);
    function getAllSponsors(uint256 eventId) external view returns (LibStorage.SponsorInfo[] memory);
    function distributeSponsorship(uint256 eventId) external;
}