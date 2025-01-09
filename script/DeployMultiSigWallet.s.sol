
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/MultiSigWallet.sol";

contract DeployMultiSigWallet is Script {
    function run() external {
        // On pourrait récupérer des variables d'environnements, etc.
        // ex: address s1 = vm.envAddress("SIGNER1");
        // ex: address s2 = vm.envAddress("SIGNER2");
        // ex: address s3 = vm.envAddress("SIGNER3");

        // Hard-coded pour l’exemple
        address signer1 = 0x1111111111111111111111111111111111111111;
        address signer2 = 0x2222222222222222222222222222222222222222;
        address signer3 = 0x3333333333333333333333333333333333333333;

        address[] memory signers = new address[](3);
        signers[0] = signer1;
        signers[1] = signer2;
        signers[2] = signer3;

        uint required = 2;

        vm.startBroadcast();
        MultiSigWallet multiSig = new MultiSigWallet(signers, required);
        vm.stopBroadcast();
    }
}
