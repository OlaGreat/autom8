// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";

// import {EventTicketLib} from "../src/contract/refactor/library/TicketManger.sol";
// import {SponsorLib} from "../src/contract/refactor//library/Sponsor.sol";
// import {PayrollLib} from "../src/contract/refactor/library/Pay-roll.sol";
import {EventImplementation} from "../src/contract/refactor/Event.sol";
import {EventFactory} from "../src/contract/refactor/Event-Factory.sol";
import {MockUSDT} from "../src/contract/MockUsdt.sol";
import {VerifiableProxy} from "../src/contract/refactor/Event-proxy.sol";

contract EventDeployScript is Script {
    EventFactory public factory;
    EventImplementation public implementation;
    MockUSDT public paymentToken;
    VerifiableProxy public eventProxy;


    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        implementation = new EventImplementation();

        paymentToken = MockUSDT(0x05C3e3bAEbdDC1A658A4551f1dD853D5f922a3A9);
    
        bytes memory initData = abi.encodeWithSelector(
            EventImplementation.initialize.selector,
            msg.sender,"layer$", paymentToken, 0, msg.sender, msg.sender
        );

        eventProxy = new VerifiableProxy(address(implementation), msg.sender, initData);

        factory = new EventFactory (address(implementation), address(paymentToken), 10, msg.sender);

        vm.stopBroadcast();
    }
}