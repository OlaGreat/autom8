// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {ISPonsor} from "./interface/ISPonsor.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


error INVALID_AMOUNT();
error SPONSOR_ALREADY_EXISTS();
error SPONSOR_DOES_NOT_EXIST();
error NO_SPONSOR_TO_DISTRIBUTE();
error DISTRIBUTION_FAILED();

contract Sponsors is ISPonsor, ReentrancyGuard {
    IERC20 public paymentToken;

    mapping(uint => mapping(address => SponsorInfo)) private eventSponsors;
    mapping(uint => uint) private totalSponsorship; 
    mapping(uint => SponsorInfo[]) private eventSponsorList;


    constructor(address _token){
        paymentToken = IERC20(_token);
    }

    function getSponsorInfo(address sponsor, uint256 eventId) external view returns (SponsorInfo memory){
        return eventSponsors[eventId][sponsor];
    }
    function getTotalSponsorship(uint256 eventId) external view returns (uint256){
        return totalSponsorship[eventId]; 
    }
    function getAllSponsors(uint256 eventId) external view returns (SponsorInfo[] memory){
        return eventSponsorList[eventId];
    }
    function distributeSponsorship(uint256 eventId) external {

    }


    function sponsorEvent(uint256 amount, uint256 eventId) external {
        require(amount > 0, INVALID_AMOUNT());
        if (eventSponsors[eventId][msg.sender].sponsor != address(0)) {
            eventSponsors[eventId][msg.sender].amount += amount;
            totalSponsorship[eventId] += amount;
            // todo calculate percentageContribution
            emit EventSponsored(msg.sender, amount, eventId);

        }



    }

}