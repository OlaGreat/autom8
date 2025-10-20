// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../src/contract/EventFactory.sol";
import "../src/contract/EventImplementation.sol";
import "../src/contract/Ticket.sol";
import "../src/contract/Payroll.sol";
import "../src/contract/SponsorVault.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Test Token", "TEST") {
        _mint(msg.sender, 1000000 * 10**18);
    }
}

contract EventFactoryTest is Test {
    EventFactory public factory;
    EventImplementation public implementation;
    EventTicket public ticketContract;
    Payroll public payrollContract;
    SponsorVault public sponsorVault;
    MockERC20 public paymentToken;

    address public owner = address(1);
    address public user1 = address(2);
    address public user2 = address(3);
    address public admin = address(4);

    uint256 public constant ADMIN_FEE = 5; // 5%

    function setUp() public {
        vm.startPrank(owner);

        // Deploy token and contracts
        paymentToken = new MockERC20();
        implementation = new EventImplementation();
        ticketContract = new EventTicket();
        payrollContract = new Payroll();
        sponsorVault = new SponsorVault();

        // Deploy factory
        factory = new EventFactory(
            address(implementation),
            address(ticketContract),
            address(payrollContract),
            address(sponsorVault),
            address(paymentToken),
            ADMIN_FEE,
            admin
        );

        vm.stopPrank();
    }

    function testCreateProxy() public {
        vm.startPrank(user1);
        
        address proxyAddress = factory.createProxy("Test Organization");
        
        assertNotEq(proxyAddress, address(0));
        assertEq(factory.getOwnerProxy(user1), proxyAddress);
        
        vm.stopPrank();
    }

    function testCannotCreateMultipleProxies() public {
        vm.startPrank(user1);
        
        factory.createProxy("First Organization");
        
        vm.expectRevert(USER_ALREADY_REGISTERED.selector);
        factory.createProxy("Second Organization");
        
        vm.stopPrank();
    }

    function testMultipleUsersCanCreateProxies() public {
        vm.startPrank(user1);
        address proxy1 = factory.createProxy("Organization 1");
        vm.stopPrank();

        vm.startPrank(user2);
        address proxy2 = factory.createProxy("Organization 2");
        vm.stopPrank();

        assertNotEq(proxy1, proxy2);
        assertEq(factory.getOwnerProxy(user1), proxy1);
        assertEq(factory.getOwnerProxy(user2), proxy2);
    }

    function testGetOwnerProxyRevertsForNonExistentUser() public {
        vm.expectRevert(USER_NOT_REGISTERD.selector);
        factory.getOwnerProxy(address(999));
    }

    function testGetOwnerProxyRevertsForZeroAddress() public {
        vm.expectRevert(INVALID_ADDRESS.selector);
        factory.getOwnerProxy(address(0));
    }

    function testOnlyOwnerCanSetImplementation() public {
        address newImpl = address(new EventImplementation());
        
        vm.startPrank(user1);
        vm.expectRevert();
        factory.setImplementation(newImpl);
        vm.stopPrank();

        vm.startPrank(owner);
        factory.setImplementation(newImpl);
        assertEq(factory.implementation(), newImpl);
        vm.stopPrank();
    }

    function testOnlyOwnerCanAuthorizeDeployer() public {
        vm.startPrank(user1);
        vm.expectRevert();
        factory.authorizeDeployer(user2);
        vm.stopPrank();

        vm.startPrank(owner);
        factory.authorizeDeployer(user2);
        assertTrue(factory.authorizedDeployers(user2));
        vm.stopPrank();
    }

    function testOnlyOwnerCanRevokeDeployer() public {
        vm.startPrank(owner);
        factory.authorizeDeployer(user2);
        assertTrue(factory.authorizedDeployers(user2));
        
        factory.revokeDeployer(user2);
        assertFalse(factory.authorizedDeployers(user2));
        vm.stopPrank();
    }

    function testFactoryInitialization() public {
        assertEq(factory.implementation(), address(implementation));
        assertEq(factory.ticketContract(), address(ticketContract));
        assertEq(factory.payrollContract(), address(payrollContract));
        assertEq(factory.sponsorVault(), address(sponsorVault));
        assertEq(factory.paymentToken(), address(paymentToken));
        assertEq(factory.adminFee(), ADMIN_FEE);
        assertEq(factory.adminFeeAddress(), admin);
        assertEq(factory.owner(), owner);
    }
}