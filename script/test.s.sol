// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
// import {EventTicket} from "../src/contract/Ticket.sol";
// import {Payroll} from "../src/contract/Payroll.sol";
// import {SponsorVault} from "../src/contract/SponsorVault.sol";
// import {EventImplementation} from "../src/contract/EventImplementation.sol";
// import {EventFactory} from "../src/contract/EventFactory.sol";
// import {MockUSDT} from "../src/contract/MockUsdt.sol";
import {VerifiableProxy} from "../src/contract/EventProxy.sol";

contract EventDeployScript is Script {
    VerifiableProxy public eventProxy;


    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        eventProxy = VerifiableProxy(payable(0xbfecb2809Dff571D71dCDeF295074E4874bE3809));

        // bytes memory initData = abi.encodeWithSelector(
        //     EventImplementation.initialize.selector,
        //     msg.sender, "", ticketContract, payrollContract, sponsorVault, paymentToken, 0, msg.sender, msg.sender
        // );
        
        // uint start = block.timestamp + 1day;
        // uint end = block.timestamp + 3day;
        bytes memory data = "0xee906a740000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000000000000000064000000000000000000000000000000000000000000000000000000000a7eccf2000000000000000000000000000000000000000000000000000000000a7eccf90000000000000000000000000000000000000000000000000000000000000140000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000027100000000000000000000000000000000000000000000000000000000000000008476f642061626567000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000777777769756f6900000000000000000000000000000000000000000000000000";

        // eventProxy.createEvent("Gd abeg", 10, 100, 1760830440, 1760830460, "www", 1, 10000);
        address(eventProxy).call(data);
        
        vm.stopBroadcast();
    }
}