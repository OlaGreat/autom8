// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {EventTicket} from "../src/contract/Ticket.sol";
import {Payroll} from "../src/contract/Payroll.sol";
import {SponsorVault} from "../src/contract/SponsorVault.sol";
import {EventImplementation} from "../src/contract/EventImplementation.sol";
import {EventFactory} from "../src/contract/EventFactory.sol";
import {MockUSDT} from "../src/contract/MockUsdt.sol";
import {VerifiableProxy} from "../src/contract/EventProxy.sol";

contract EventDeployScript is Script {
    EventFactory public factory;
    EventImplementation public implementation;
    EventTicket public ticketContract;
    Payroll public payrollContract;
    SponsorVault public sponsorVault;
    MockUSDT public paymentToken;
    VerifiableProxy public eventProxy;


    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        implementation = new EventImplementation();
        ticketContract = new EventTicket();
        payrollContract = new Payroll();
        sponsorVault = new SponsorVault();
        paymentToken = MockUSDT(0x05C3e3bAEbdDC1A658A4551f1dD853D5f922a3A9);

        bytes memory initData = abi.encodeWithSelector(
            EventImplementation.initialize.selector,
            msg.sender, "", ticketContract, payrollContract, sponsorVault, paymentToken, 0, msg.sender, msg.sender
        );

        eventProxy = new VerifiableProxy(address(implementation), msg.sender, initData);

        factory = new EventFactory (address(implementation), address(ticketContract), address(payrollContract), address(sponsorVault), address(paymentToken), 10, msg.sender);

        vm.stopBroadcast();
    }
}