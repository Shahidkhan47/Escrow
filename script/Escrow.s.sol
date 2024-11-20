// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Escrow} from "../src/Escrow.sol";

contract EscrowScript is Script {

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.broadcast(deployerPrivateKey);
        Escrow escrow = new Escrow(1000);
        console.log("address of escrow contract", address(escrow));
    }
}

///Contract_address on holesky testnet = 0x9De4F96250C4541d4DdBc42be675a2A34fF4e1de 