// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

import {VerifiableProxy} from "./Event-proxy.sol";
import {EventImplementation} from "./Event.sol";


error USER_ALREADY_REGISTERED();
error USER_NOT_REGISTERD();
error INVALID_ADDRESS();

contract EventFactory is Ownable {
    address public implementation;
    address public paymentToken;
    uint public adminFee;
    address public adminFeeAddress;
    address public dev;
    
    mapping(address => address) public proxies;
    mapping(address => bool) public authorizedDeployers;
    address[] public proxiesList;

    event ProxyCreated(address indexed proxyAddress, address indexed owner, address indexed implementationAddress);
    event ImplementationUpdated(address indexed oldImpl, address indexed newImpl);
    event DeployerAuthorized(address indexed deployer);
    event DeployerRevoked(address indexed deployer);

    constructor(address _implementation, address _paymentToken, uint _adminFee, address _adminFeeAddress) Ownable(msg.sender) {
        implementation = _implementation;
        paymentToken = _paymentToken;
        adminFee = _adminFee;
        adminFeeAddress = _adminFeeAddress;
        dev = msg.sender;
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

   

    function createProxy(string memory orgName) external returns (address) {
        if (proxies[msg.sender] != address(0)) revert USER_ALREADY_REGISTERED();
        
        bytes memory initData = abi.encodeWithSelector(
            EventImplementation.initialize.selector,
            msg.sender, orgName, paymentToken, adminFee, adminFeeAddress, dev
        );

        VerifiableProxy proxy = new VerifiableProxy(implementation, msg.sender, initData);
        address proxyAddress = address(proxy);

        proxies[msg.sender] = proxyAddress;
        proxiesList.push(proxyAddress);

        emit ProxyCreated(proxyAddress, msg.sender, implementation);
        return proxyAddress;
    }

    function getOwnerProxy(address owner) external view returns (address) {
        if (owner == address(0)) revert INVALID_ADDRESS();
        if (proxies[owner] == address(0)) revert USER_NOT_REGISTERD();
        return proxies[owner];
    }

}
