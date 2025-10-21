// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "forge-std/Test.sol";
import "../../src/contract/refactor/Event.sol";
import {LibStorage} from "../../src/contract/libraries/ELibStorage.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {GlobalEventRegistry} from "../../src/contract/refactor/manager/GlobalEventRegistry.sol";


contract MockERC20 is ERC20 {
    constructor() ERC20("Test Token", "TEST") {
        _mint(msg.sender, 1000000 * 10**18);
    }
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract EventImplementationSponsorsTest is Test {
    EventImplementation public eventImpl;
    MockERC20 public paymentToken;
    address public owner = address(1);
    address public user = address(2);
    address public admin = address(3);
    uint256 public constant ADMIN_FEE = 5;
    uint256 public constant EVENT_EXPENSES = 50 ether;
    GlobalEventRegistry public registry;
    function setUp() public {
        paymentToken = new MockERC20();
        eventImpl = new EventImplementation();
        registry = new GlobalEventRegistry();
        eventImpl.initialize(owner, "TestOrg", address(paymentToken), ADMIN_FEE, admin, admin, address(registry));
        paymentToken.mint(user, 100 ether);
    }
    function createTestEvent() internal returns (uint256) {
        vm.startPrank(owner);
        uint256 startTime = block.timestamp + 1 days;
        uint256 endTime = block.timestamp + 7 days;
        string[] memory tags = new string[](2);
        tags[0] = "sponsored";
        tags[1] = "community";
        eventImpl.createEvent("Test Event", 1 ether, 100, startTime, endTime, "uri", LibStorage.EventType.Paid, EVENT_EXPENSES, "Community", "Online", tags);
        vm.stopPrank();
        return 0;
    }
    function testSponsorEvent_HappyPath() public {
        uint256 eventId = createTestEvent();
        vm.startPrank(user);
        paymentToken.approve(address(eventImpl), 10 ether);
        eventImpl.sponsorEvent(eventId, 10 ether);
        vm.stopPrank();
        LibStorage.SponsorInfo memory info = eventImpl.getSponsorInfo(user, eventId);
        assertEq(info.amount, 10 ether);
        assertEq(info.sponsor, user);
        uint256 total = eventImpl.getTotalSponsorship(eventId);
        assertEq(total, 10 ether);
    }
}
