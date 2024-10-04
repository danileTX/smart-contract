// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MultiSigWallet {
    event Deposit(address indexed sender, uint amount);
    event Submit(uint indexed txId);
    event Approve(address indexed owner, uint indexed txId);
    event Revoke(address indexed owner, uint txId);
    event Execute(uint indexed txId);

    struct Transaction {
        address to;
        uint value;
        bytes data;
        bool executed;
    }

    address[] public owners;
    mapping(address => bool) public isOwner;
    uint public required;

    Transaction[] public transactions;
    mapping(uint => mapping(address => bool)) public approved;

    modifier onlyOwner() {
        require(isOwner[msg.sender],"not owner");
        _;
    }

    modifier txExists(uint _txId) {
        require(_txId < transactions.length, "tx does not exist");
        _;
    }

    modifier notApproved(uint _txId) { 
        require(!approved[_txId][msg.sender],"tx already approved");
        _;
    }

    modifier notExecuted(uint _txId) {
        require(!transactions[_txId].executed,"tx already executed");
        _;
    }

    constructor(address[] memory _owners, uint _required) {
        require(_owners.length > 0,"owners require");
        require(_required >0 && _required <= _owners.length, "invalid required number");

        // 把初始化的owner 放入状态变量中，不是js 不能直接赋值，要用for 循环。
        for(uint i; i < _owners.length; i++) {
            //拿到owner做基础的检查
            address owner = _owners[i];
            require(owner != address(0),"invalid owner");
            // 是否已经存在。需要为新地址。
            require(!isOwner[owner],"owner is not unique");

            isOwner[owner] = true;
            owners.push(owner);
        }

        required = _required;

    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    function submit(address _to, uint _value, bytes calldata _data) external onlyOwner {
        transactions.push(Transaction({
            to: _to,
            value: _value,
            data: _data,
            executed: false
        }));
        emit Submit(transactions.length-1);
    }
    
    
    function approve(uint _txId) 
        external
        onlyOwner
        txExists(_txId)
        notApproved(_txId)
        notExecuted(_txId){
            approved[_txId][msg.sender] = true;
            emit Approve(msg.sender, _txId);
    }

    function _getApprovedCount(uint _txId) private view returns(uint count) {
        for(uint i; i<owners.length; i++) {
            if(approved[_txId][owners[i]]) {
                count +=1;
            }
        }
    }

    function execute(uint _txId) external txExists(_txId) notExecuted(_txId) {
        require(_getApprovedCount(_txId) >=required, "approvals < required");
        // storage效果，修改了状态变量。
        Transaction storage transaction = transactions[_txId];

        transaction.executed = true;
        (bool success,) = transaction.to.call{value: transaction.value}(transaction.data);
        require(success, "failed");
        emit Execute(_txId);
    }

    function revoke(uint _txId) external onlyOwner txExists(_txId) notExecuted(_txId){
        require(approved[_txId][msg.sender], "tx approved");
        approved[_txId][msg.sender] = false;
        emit Revoke(msg.sender, _txId);
    }

}