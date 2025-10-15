// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./SponsorVault.sol";
import "./EventImplementation.sol";

contract EventFactory is Ownable, ReentrancyGuard {
    address public implementation;
    address public sponsorVault;
    uint256 public eventIdCounter;

    mapping(address => address[]) public ownerEvents;
    mapping(address => bool) public authorizedDeployers;

    event EventCreated(address indexed owner, address indexed eventAddress, uint256 eventId, uint256 fundingGoal, uint256 startTime, uint256 endTime);
    event ImplementationUpdated(address indexed oldImpl, address indexed newImpl);
    event DeployerAuthorized(address indexed deployer);
    event DeployerRevoked(address indexed deployer);

    constructor(address _implementation, address _sponsorVault) Ownable(msg.sender) {
        implementation = _implementation;
        sponsorVault = _sponsorVault;
    }

    modifier onlyAuthorized() {
        require(authorizedDeployers[msg.sender] || msg.sender == owner(), "Not authorized to deploy");
        _;
    }

    function setImplementation(address _implementation) external onlyOwner {
        address oldImpl = implementation;
        implementation = _implementation;
        emit ImplementationUpdated(oldImpl, _implementation);
    }

    function authorizeDeployer(address deployer) external onlyOwner {
        authorizedDeployers[deployer] = true;
        emit DeployerAuthorized(deployer);
    }

    function revokeDeployer(address deployer) external onlyOwner {
        authorizedDeployers[deployer] = false;
        emit DeployerRevoked(deployer);
    }

    function createEvent(
        uint256 fundingGoal,
        uint256 startTime,
        uint256 endTime,
        string memory eventName,
        string memory description,
        address ticketContract,
        address payrollContract,
        address paymentToken,
        EventImplementation.TicketTier[] memory ticketTiers
    ) external onlyAuthorized nonReentrant returns (address) {
        require(startTime < endTime, "Invalid time range");

        uint256 eventId = eventIdCounter;
        eventIdCounter++;

        bytes memory initData = abi.encodeWithSelector(
            EventImplementation.initialize.selector,
            msg.sender, eventId, fundingGoal, startTime, endTime, eventName, description, ticketContract, payrollContract, paymentToken, sponsorVault, 7000, 500, owner(), ticketTiers
        );

        ERC1967Proxy proxy = new ERC1967Proxy(implementation, initData);
        address eventAddress = address(proxy);

        ownerEvents[msg.sender].push(eventAddress);

        // Set the event contract in SponsorVault for access control
        SponsorVault(sponsorVault).setEventContract(eventId, eventAddress);

        emit EventCreated(msg.sender, eventAddress, eventId, fundingGoal, startTime, endTime);

        return eventAddress;
    }

    function getOwnerEvents(address owner) external view returns (address[] memory) {
        return ownerEvents[owner];
    }

    function getOwnerEventCount(address owner) external view returns (uint256) {
        return ownerEvents[owner].length;
    }
}
