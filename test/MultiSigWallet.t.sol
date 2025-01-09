// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MultiSigWallet.sol";

contract MultiSigWalletTest is Test {
    MultiSigWallet private multiSig;
    address[] private signers;

    function setUp() public {
        // Setup: créer 3 adresses "fictives" via foundry (vm.addr)
        address signer1 = vm.addr(0x1);
        address signer2 = vm.addr(0x2);
        address signer3 = vm.addr(0x3);

        signers = [signer1, signer2, signer3];

        // Donne du solde aux signers (optionnel si tu veux qu'ils puissent envoyer de l'ETH)
        vm.deal(signer1, 100 ether);
        vm.deal(signer2, 100 ether);
        vm.deal(signer3, 100 ether);

        // Déployer le contrat
        multiSig = new MultiSigWallet(signers, 2);

        // On peut alimenter le wallet
        vm.deal(address(multiSig), 10 ether);
    }

    function testInitialSigners() public {
        // On vérifie qu'on a bien 3 signers
        assertEq(multiSig.signers(0), signers[0]);
        assertEq(multiSig.signers(1), signers[1]);
        assertEq(multiSig.signers(2), signers[2]);
    }

    function testSubmitTransaction() public {
        // On se place en tant que signer1
        vm.startPrank(signers[0]);
        multiSig.submitTransaction(address(0xdeadbeef), 1 ether, "");
        vm.stopPrank();

        // On vérifie que la transaction existe bien
        (address to, uint value, , , ) = multiSig.transactions(0);
        assertEq(to, address(0xdeadbeef));
        assertEq(value, 1 ether);
    }

    function testApproveTransaction() public {
    // 1) Se place en tant que signer1 et soumet une transaction
    vm.startPrank(signers[0]);
    multiSig.submitTransaction(address(0x1234), 1 ether, "");
    vm.stopPrank();

    // 2) Se place en tant que signer2 pour approuver la tx
    vm.startPrank(signers[1]);
    multiSig.approveTransaction(0); 
    vm.stopPrank();

    // 3) Vérifie que l'approbation est enregistrée
    //    (approved[0][signers[1]] == true et numConfirmations == 1)
    bool isApproved = multiSig.approved(0, signers[1]);
    assertTrue(isApproved, "Signer2 should have approved tx 0");

    assertTrue(isApproved, "Signer2 should have approved tx 0");
    
    (, , , , uint numConfirmations) = multiSig.transactions(0);
    assertEq(numConfirmations, 1, "Num confirmations should be 1");
}

function testCannotApproveIfNotSigner() public {
    // Soumettons une tx depuis signer1
    vm.startPrank(signers[0]);
    multiSig.submitTransaction(address(0x1234), 1 ether, "");
    vm.stopPrank();

    // Tente d'approuver depuis une adresse qui n'est PAS signer
    address hacker = vm.addr(0x999);
    vm.startPrank(hacker);
    vm.expectRevert(bytes("Not a signer"));
    multiSig.approveTransaction(0);
    vm.stopPrank();
}

function testCannotApproveAlreadyApproved() public {
    // Soumettons une tx
    vm.prank(signers[0]);
    multiSig.submitTransaction(address(0x1234), 1 ether, "");

    // signer1 approuve
    vm.prank(signers[0]);
    multiSig.approveTransaction(0);

    // signer1 essaye de ré-approuver la même tx => revert
    vm.startPrank(signers[0]);
    vm.expectRevert(bytes("tx already approved"));
    multiSig.approveTransaction(0);
    vm.stopPrank();
}

function testRevokeApproval() public {
    // 1) Soumet une tx depuis signer1
    vm.prank(signers[0]);
    multiSig.submitTransaction(address(0x1234), 1 ether, "");

    // 2) Approuve depuis signer1
    vm.prank(signers[0]);
    multiSig.approveTransaction(0);

    // 3) Revoke depuis signer1
    vm.prank(signers[0]);
    multiSig.revokeApproval(0);

    // Vérifie que l’approbation est désormais false et confirmations == 0
    bool isApproved = multiSig.approved(0, signers[0]);
    assertFalse(isApproved, "Approval should be revoked");

    (, , , , uint numConfirmations) = multiSig.transactions(0);
    assertEq(numConfirmations, 0, "Num confirmations should be 0 after revoke");
}

function testCannotRevokeIfNotSigner() public {
    // Soumet une tx
    vm.prank(signers[0]);
    multiSig.submitTransaction(address(0x1234), 1 ether, "");

    // Approuve depuis signer1
    vm.prank(signers[0]);
    multiSig.approveTransaction(0);

    // Tente de revoke depuis un non-signer => revert
    address hacker = vm.addr(0x999);
    vm.startPrank(hacker);
    vm.expectRevert(bytes("Not a signer"));
    multiSig.revokeApproval(0);
    vm.stopPrank();
}

function testCannotRevokeIfNotApproved() public {
    // Soumet une tx
    vm.prank(signers[0]);
    multiSig.submitTransaction(address(0x1234), 1 ether, "");

    // signer1 n'a pas encore approuvé
    vm.startPrank(signers[0]);
    vm.expectRevert(bytes("tx not approved"));
    multiSig.revokeApproval(0);
    vm.stopPrank();
}

function testExecuteTransaction() public {
    // Soumettre et approuver la transaction par 2 signers
    vm.prank(signers[0]);
    multiSig.submitTransaction(address(0x1234), 1 ether, "");

    vm.prank(signers[0]);
    multiSig.approveTransaction(0);
    vm.prank(signers[1]);
    multiSig.approveTransaction(0);

    // Exécuter la transaction
    vm.prank(signers[0]);
    multiSig.executeTransaction(0);

    // Vérifier qu'elle est marquée executed
    (,, , bool executed, ) = multiSig.transactions(0);
    assertTrue(executed, "Transaction should be executed");
}

function testCannotExecuteIfNotEnoughApprovals() public {
    // Soumettre 1 tx
    vm.prank(signers[0]);
    multiSig.submitTransaction(address(0x1234), 1 ether, "");
    
    // Approve par 1 seul signers[0]
    vm.prank(signers[0]);
    multiSig.approveTransaction(0);

    // Tente d'exécuter => revert
    vm.startPrank(signers[0]);
    vm.expectRevert(bytes("cannot execute tx"));
    multiSig.executeTransaction(0);
    vm.stopPrank();
}

function testCannotExecuteIfAlreadyExecuted() public {
    vm.prank(signers[0]);
    multiSig.submitTransaction(address(0x1234), 1 ether, "");

    vm.prank(signers[0]);
    multiSig.approveTransaction(0);
    vm.prank(signers[1]);
    multiSig.approveTransaction(0);

    // Premier appel => OK
    vm.prank(signers[0]);
    multiSig.executeTransaction(0);

    // Deuxième appel => revert
    vm.prank(signers[0]);
    vm.expectRevert(bytes("tx already executed"));
    multiSig.executeTransaction(0);
}

function testCannotExecuteFromNonSigner() public {
    vm.prank(signers[0]);
    multiSig.submitTransaction(address(0x1234), 1 ether, "");

    vm.prank(signers[0]);
    multiSig.approveTransaction(0);
    vm.prank(signers[1]);
    multiSig.approveTransaction(0);

    // Essaye d'exécuter via un non-signer => revert
    address hacker = vm.addr(0x999);
    vm.startPrank(hacker);
    vm.expectRevert(bytes("Not a signer"));
    multiSig.executeTransaction(0);
    vm.stopPrank();
}

function testAddSigner() public {
    // Ajoutons un nouveau signer4
    address signer4 = vm.addr(0x4);

    // Only existing signer can add
    vm.prank(signers[0]);
    multiSig.addSigner(signer4);

    // On check
    bool isNewSigner = multiSig.isSigner(signer4);
    assertTrue(isNewSigner, "signer4 should be added");
}

function testCannotAddIfNotSigner() public {
    address signer4 = vm.addr(0x4);
    address hacker = vm.addr(0x999);

    vm.startPrank(hacker);
    vm.expectRevert(bytes("Not a signer"));
    multiSig.addSigner(signer4);
    vm.stopPrank();
}

function testCannotAddZeroAddress() public {
    vm.startPrank(signers[0]);
    vm.expectRevert(bytes("invalid address"));
    multiSig.addSigner(address(0));
    vm.stopPrank();
}

function testCannotAddExistingSigner() public {
    // signer1 est déjà un signer
    vm.startPrank(signers[0]);
    vm.expectRevert(bytes("already a signer"));
    multiSig.addSigner(signers[1]);
    vm.stopPrank();
}

function testRemoveSigner() public {
    // On suppose qu'on a 3 signers initiaux : signer1, signer2, signer3
    // On en rajoute un 4e pour pouvoir l'enlever plus tard
    address signer4 = vm.addr(0x4);
    vm.prank(signers[0]);
    multiSig.addSigner(signer4);

    // On retire signer4
    vm.prank(signers[0]);
    multiSig.removeSigner(signer4);

    bool isStillSigner = multiSig.isSigner(signer4);
    assertFalse(isStillSigner, "signer4 should be removed");
}

function testCannotRemoveIfNotSigner() public {
    address hacker = vm.addr(0x999);

    vm.startPrank(hacker);
    vm.expectRevert(bytes("Not a signer"));
    multiSig.removeSigner(signers[0]);
    vm.stopPrank();
}

function testCannotRemoveNonExistingSigner() public {
    // On prend un random
    address randomAddress = vm.addr(0x999);

    vm.startPrank(signers[0]);
    vm.expectRevert(bytes("not a signer"));
    multiSig.removeSigner(randomAddress);
    vm.stopPrank();
}

function testCannotGoBelowThreeSigners() public {
    // On a 3 signers initiaux. Tente d'en retirer 1 => 
    // => revert si la condition est "cannot have fewer than 3 signers"

    vm.startPrank(signers[0]);
    vm.expectRevert(bytes("cannot have fewer than 3 signers"));
    multiSig.removeSigner(signers[2]);
    vm.stopPrank();
}

function testReceiveEth() public {
    // On se place en tant que signer1
    vm.startPrank(signers[0]);

    // On envoie 1 ether directement en appelant le fallback
    (bool success, ) = address(multiSig).call{value: 1 ether}("");
    assertTrue(success, "Should be able to send ETH to contract");

    // On vérifie le solde
    uint contractBalance = address(multiSig).balance;
    assertEq(contractBalance, 10 ether + 1 ether, "Contract should have 11 ETH now");
    
    vm.stopPrank();
}

function testConstructorRevertIfLessThan3Signers() public {
    address[] memory fewSigners = new address[](2);
    fewSigners[0] = vm.addr(10);
    fewSigners[1] = vm.addr(11);

    // On s'attend à ce que le constructor revert
    vm.expectRevert(bytes("at least 3 signers required"));
    new MultiSigWallet(fewSigners, 2);
}

function testConstructorRevertIfRequiredLessThan2() public {
    address[] memory signers3 = new address[](3);
    signers3[0] = vm.addr(10);
    signers3[1] = vm.addr(11);
    signers3[2] = vm.addr(12);

    vm.expectRevert(bytes("invalid required number of signers"));
    new MultiSigWallet(signers3, 1); // required = 1 => revert
}

function testConstructorRevertIfRequiredMoreThanSignersLength() public {
    address[] memory signers3 = new address[](3);
    signers3[0] = vm.addr(10);
    signers3[1] = vm.addr(11);
    signers3[2] = vm.addr(12);

    vm.expectRevert(bytes("invalid required number of signers"));
    new MultiSigWallet(signers3, 4); // required = 4 > 3 => revert
}

function testRemoveSignerAdjustsRequired() public {
    // Prépare un tableau de 4 signers
    address[] memory fourSigners = new address[](4);
    fourSigners[0] = vm.addr(1);
    fourSigners[1] = vm.addr(2);
    fourSigners[2] = vm.addr(3);
    fourSigners[3] = vm.addr(4);

    // On set required = 4
    MultiSigWallet multiSigLocal = new MultiSigWallet(fourSigners, 4);

    // On retire un signer (signer[3]) => signers.length va passer de 4 à 3
    vm.prank(fourSigners[0]);
    multiSigLocal.removeSigner(fourSigners[3]);

    // Vérifie que required est maintenant 3
    uint newRequired = multiSigLocal.required();
    assertEq(newRequired, 3, "Required should adjust down to match signers.length");
}

function testCannotApproveNonExistingTransaction() public {
    // Aucune transaction n’a été soumise, donc transactions.length == 0
    vm.prank(signers[0]);
    vm.expectRevert(bytes("tx does not exist"));
    multiSig.approveTransaction(9999); // txIndex hors range
}

function testCannotRevokeNonExistingTransaction() public {
    vm.prank(signers[0]);
    vm.expectRevert(bytes("tx does not exist"));
    multiSig.revokeApproval(9999);
}

function testCannotExecuteNonExistingTransaction() public {
    vm.prank(signers[0]);
    vm.expectRevert(bytes("tx does not exist"));
    multiSig.executeTransaction(9999);
}

function testTransactionGetterOutOfRange() public {
    // Sans soumettre de transaction, on appelle transactions(9999)
    vm.expectRevert(); 
    multiSig.transactions(9999);
}

function testSignersGetterOutOfRange() public {
    vm.expectRevert();
    multiSig.signers(9999);
}


}
