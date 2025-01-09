// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title MultiSigWallet
/// @author ...
/// @notice A simple multi-signature wallet requiring m-of-n approvals.
/// @dev This contract allows submit, approve, revoke, execute transactions.
///      It also allows adding/removing signers with constraints.

contract MultiSigWallet {
    // ============ Events ============

    /// @notice Emitted when a transaction is submitted.
    event SubmitTransaction(
        address indexed owner,
        uint indexed txIndex,
        address indexed to,
        uint value,
        bytes data
    );

    /// @notice Emitted when a signer approves a transaction.
    event ApproveTransaction(address indexed owner, uint indexed txIndex);

    /// @notice Emitted when a signer revokes its approval of a transaction.
    event RevokeTransaction(address indexed owner, uint indexed txIndex);

    /// @notice Emitted when a transaction is executed.
    event ExecuteTransaction(address indexed owner, uint indexed txIndex);

    /// @notice Emitted when a new signer is added.
    event SignerAdded(address indexed newSigner);

    /// @notice Emitted when a signer is removed.
    event SignerRemoved(address indexed removedSigner);

    // ============ State variables ============

    address[] public signers;      // tableau des addresses signataires
    mapping(address => bool) public isSigner; 
    uint public required;          // nombre de signatures requises

    struct Transaction {
        address to;                // destinataire de la tx
        uint value;                // valeur en wei
        bytes data;                // calldata
        bool executed;            
        uint numConfirmations;     // nb de confirmations
    }

    Transaction[] public transactions;

    // mapping (txIndex => (address => bool))
    mapping(uint => mapping(address => bool)) public approved;

    // ============ Modifiers ============

    /// @dev Vérifie que l'appelant est un signataire.
    modifier onlySigner() {
        require(isSigner[msg.sender], "Not a signer");
        _;
    }

    /// @dev Vérifie l'existence d'une transaction.
    modifier txExists(uint _txIndex) {
        require(_txIndex < transactions.length, "tx does not exist");
        _;
    }

    /// @dev Vérifie que la transaction n'est pas déjà exécutée.
    modifier notExecuted(uint _txIndex) {
        require(!transactions[_txIndex].executed, "tx already executed");
        _;
    }

    // ============ Constructor ============

    /// @param _signers Liste initiale des signataires (doivent être au moins 3).
    /// @param _required Nombre de signatures requises (doit être au moins 2).
    constructor(address[] memory _signers, uint _required) {
        require(_signers.length >= 3, "at least 3 signers required");
        require(_required >= 2 && _required <= _signers.length, "invalid required number of signers");

        for (uint i = 0; i < _signers.length; i++) {
            address signer = _signers[i];
            require(signer != address(0), "invalid signer");
            require(!isSigner[signer], "signer not unique");

            isSigner[signer] = true;
            signers.push(signer);
        }
        required = _required;
    }

    // ============ External functions ============

    /// @notice Permet à un signataire de soumettre une transaction.
    /// @param _to adresse de destination
    /// @param _value montant en wei
    /// @param _data calldata
    function submitTransaction(
        address _to,
        uint _value,
        bytes calldata _data
    ) 
        external
        onlySigner
    {
        uint txIndex = transactions.length;

        transactions.push(Transaction({
            to: _to,
            value: _value,
            data: _data,
            executed: false,
            numConfirmations: 0
        }));

        emit SubmitTransaction(msg.sender, txIndex, _to, _value, _data);
    }

    /// @notice Approuve une transaction non exécutée.
    /// @param _txIndex index de la transaction
    function approveTransaction(uint _txIndex)
        external
        onlySigner
        txExists(_txIndex)
        notExecuted(_txIndex)
    {
        require(!approved[_txIndex][msg.sender], "tx already approved");

        approved[_txIndex][msg.sender] = true;
        transactions[_txIndex].numConfirmations += 1;

        emit ApproveTransaction(msg.sender, _txIndex);
    }

    /// @notice Révoque sa propre approbation sur la transaction.
    /// @param _txIndex index de la transaction
    function revokeApproval(uint _txIndex)
        external
        onlySigner
        txExists(_txIndex)
        notExecuted(_txIndex)
    {
        require(approved[_txIndex][msg.sender], "tx not approved");

        approved[_txIndex][msg.sender] = false;
        transactions[_txIndex].numConfirmations -= 1;

        emit RevokeTransaction(msg.sender, _txIndex);
    }

    /// @notice Exécute la transaction si assez de signatures.
    /// @param _txIndex index de la transaction
    function executeTransaction(uint _txIndex)
        external
        onlySigner
        txExists(_txIndex)
        notExecuted(_txIndex)
    {
        require(
            transactions[_txIndex].numConfirmations >= required,
            "cannot execute tx"
        );

        Transaction storage transaction = transactions[_txIndex];
        transaction.executed = true;

        (bool success, ) = transaction.to.call{value: transaction.value}(transaction.data);
        require(success, "tx failed");

        emit ExecuteTransaction(msg.sender, _txIndex);
    }

    /// @notice Ajoute un nouveau signataire. Toujours garder au moins 3 signataires et un "required >= 2".
    /// @param _newSigner Le nouvel addresse à ajouter.
    function addSigner(address _newSigner)
        external
        onlySigner
    {
        require(_newSigner != address(0), "invalid address");
        require(!isSigner[_newSigner], "already a signer");

        signers.push(_newSigner);
        isSigner[_newSigner] = true;
        
        // On laisse la logique de required pour plus tard. On pourrait exiger un consensus ou non.

        emit SignerAdded(_newSigner);
    }

    /// @notice Retire un signataire (en veillant à ce qu'il en reste au moins 3).
    /// @param _signer Le signataire à enlever.
    function removeSigner(address _signer)
        external
        onlySigner
    {
        require(isSigner[_signer], "not a signer");
        require(signers.length > 3, "cannot have fewer than 3 signers");

        // On supprime l'adresse du mapping
        isSigner[_signer] = false;
        
        // On parcourt le tableau pour la retirer
        for (uint i = 0; i < signers.length; i++) {
            if (signers[i] == _signer) {
                signers[i] = signers[signers.length - 1];
                signers.pop();
                break;
            }
        }

        emit SignerRemoved(_signer);

        // On met à jour required si nécessaire (optionnel, selon ta logique).
        if (required > signers.length) {
            required = signers.length;
        }
    }

    receive() external payable {}
}
