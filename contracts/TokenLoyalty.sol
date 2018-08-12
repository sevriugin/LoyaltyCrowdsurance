// 
// MIT License
// 
// Copyright (c) 2018 REGA Risk Sharing
//   
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
// 
// Author: Sergei Sevriugin
// Version: 0.0.1
//  

pragma solidity ^0.4.17;

import "./interfaces/ITokenPool.sol";
import "./Owned.sol";
/// TokenLoyalty is ERC721SmartToken for loyalty token.
contract TokenLoyalty is Owned {

    uint256 constant StateClaim = uint256(1023);
    uint256 constant StatePaid = uint256(1022);

    struct SubPoolExtension {
        uint    timeStamp;                          // Sub pool extension is created
        uint    closure;                            // Sub pool closere time
        uint    members;                            // Sub pool number of members
        uint    activated;                          // Sub pool number of activated tokens
        bool    funded;                             // Sub pool has recieved funds to pay claims
        uint    payment;                            // If funded is true then this is payment amount for activated token
        uint    debit;                              // This amount will be debited from Sub Pool value during the payment
    }
    ITokenPool public pool;
    mapping (uint256 => SubPoolExtension) spextensions;     // Sup pools extension mapping 
    uint public subPoolId;                          // Current subpool NFT ID

    /// loyalty token created event
    event Created(address member, string clientId, bool claim, uint256 tokenId, uint256 supPoolId);
    /// create sub pool extension event
    event SPExtension(uint256 subPoolId, uint timeStamp, uint closure);
    /// error event
    event Error(string message);
    /// sub pool added event 
    event Added(uint subPoolId, uint tokenId, uint timeStamp, uint closure, uint members, uint activated, bool funded);
    /// activation event
    event Activated(uint subPoolId, uint tokenId, uint timeStamp, uint closure);
    /// funded event
    event Funded(uint subPoolId, uint payment, uint debit, uint timeStamp, uint closure);
    /// payment event
    event Paid(uint subPoolId, uint tokenId, uint value, uint debit, uint payment, uint timeStamp, uint closure);

    function _createExtension(uint _subPoolId) internal {
        spextensions[_subPoolId] = SubPoolExtension ({
            timeStamp: now,
            closure: now + 1 days,
            members: uint(0),
            activated: uint(0),
            funded: false,
            payment: uint(0),
            debit: uint(0)
        });
        // emit event
        emit SPExtension(_subPoolId, spextensions[_subPoolId].timeStamp, spextensions[_subPoolId].closure);
    }
    /// create loyalty token
    function create(address _member, string _clientId) ownerOnly public {
        require(_member != address(0));
        if(spextensions[subPoolId].timeStamp == uint(0)) {
            // first sub pool and first token need to create sub pool extension
            _createExtension(subPoolId);
        }
        // it looks like we have subPool with extension and we need to check if sub pool is still open
        if(spextensions[subPoolId].closure <= now) {
            // sub pool is closed need to create new one
            uint newSubPoolId = pool.insertSubPool();
            if(newSubPoolId != uint(0)) {
                // new sub pool is created add extension
                _createExtension(newSubPoolId);
                // change current sub pool
                subPoolId = newSubPoolId;
            }
            else {
                emit Error("sub pool is not created, not possible to add new token");
                return;
            }
        }
        // now we have sub pool open (old one or new) and can insert token
        uint tokenId = pool.connector_createNFT(uint256(500), _member);
        if(tokenId == uint(0)) {
            emit Error("can't create new token");
            return;
        }
        // token is created
        // set metadata to _clientId
        pool.connector_setMetadata(tokenId, _clientId);
        // now we can insert it to sub pool
        pool.connector_addTokenToSubPool(tokenId);
        // it's possible that sub pool can full and new sub pool will be created need to check this 
        newSubPoolId = pool.getSubPool(tokenId);
        if(newSubPoolId != subPoolId) {
            if(spextensions[newSubPoolId].timeStamp == uint(0)) {
                _createExtension(newSubPoolId);
                // change current sub pool
                subPoolId = newSubPoolId;
            }
        }
        emit Created(_member, _clientId, false, tokenId, subPoolId);
        spextensions[subPoolId].members = spextensions[subPoolId].members + 1;
        emit Added(
            subPoolId,
            tokenId, 
            spextensions[subPoolId].timeStamp, 
            spextensions[subPoolId].closure, 
            spextensions[subPoolId].members, 
            spextensions[subPoolId].activated, 
            spextensions[subPoolId].funded
        );
    }
    function activate(uint256 _id) ownerOnly public {
        require(_id != uint256(0));
        pool.setState(_id, StateClaim);
        uint _subPoolId = pool.getSubPool(_id);
        require(_subPoolId != uint256(0));
        require(spextensions[_subPoolId].timeStamp != uint256(0));
        spextensions[_subPoolId].activated = spextensions[_subPoolId].activated + 1;

        emit Activated(_subPoolId, _id, spextensions[_subPoolId].timeStamp, spextensions[_subPoolId].closure);
    }
    function fund(uint _subPoolId, uint _payment, uint _debit) ownerOnly public payable {
        require(_subPoolId != uint256(0));
        uint256 amount = msg.value;
        uint256 value = pool.getValue(_subPoolId);
        require(amount >= spextensions[_subPoolId].activated * _payment);
        require(value >= spextensions[_subPoolId].activated * _debit);
        spextensions[_subPoolId].funded = true;
        spextensions[_subPoolId].payment = _payment;
        spextensions[_subPoolId].debit = _debit;

        emit Funded(_subPoolId, _payment, _debit, spextensions[_subPoolId].timeStamp, spextensions[_subPoolId].closure);
    }
    function payment(uint256 _id) public {
        require(_id != uint256(0));
        require(pool.connector_owns(msg.sender, _id));
        require(pool.getState(_id) == StateClaim);
        uint _subPoolId = pool.getSubPool(_id);
        uint value = pool.getValue(_subPoolId);
        require(_subPoolId != uint256(0));
        require(spextensions[_subPoolId].timeStamp != uint256(0));
        require(spextensions[_subPoolId].funded);
        require(address(this).balance >= spextensions[_subPoolId].payment);
        require(value >= spextensions[_subPoolId].debit);
        msg.sender.transfer(spextensions[_subPoolId].payment);
        value = value - spextensions[_subPoolId].debit;
        pool.setValue(_subPoolId, value);
        pool.setState(_id, StatePaid);

        emit Paid(
            _subPoolId,
            _id,
            value,
            spextensions[_subPoolId].debit,
            spextensions[_subPoolId].payment, 
            spextensions[_subPoolId].timeStamp, 
            spextensions[_subPoolId].closure
        );
    }
    function getSubPoolExtension(uint256 _subPoolId) public view returns(uint, uint, uint, uint, uint, uint, uint) {
        return(
            spextensions[_subPoolId].timeStamp, 
            spextensions[_subPoolId].closure, 
            spextensions[_subPoolId].members, 
            spextensions[_subPoolId].activated, 
            spextensions[_subPoolId].debit, 
            spextensions[_subPoolId].payment,
            pool.getValue(_subPoolId)
        );
    }
    function getCurrentSubPoolExtension() public view returns(
        uint created, 
        uint closed, 
        uint numberOfMembers, 
        uint numberOfActivated, 
        uint debitValue,
        uint paymentAmount,
        uint value
    ) {
        return getSubPoolExtension(subPoolId);
    }
    function getBizProcessId() view public returns(address contractOwner, uint8 bizProcessId) {
        contractOwner = owner;
        bizProcessId = 21;
        // wait fot init
        if (pool.getPoolSize() == 0) {
            bizProcessId = 100; 
            return;
        }
    }
    function getBalance() view public returns(uint) {
        return address(this).balance;
    }
    function checkPayment(uint _id) public view returns(uint) {
        uint result = 0;
        uint _subPoolId = pool.getSubPool(_id);
        uint value = pool.getValue(_subPoolId);
        
        if(_id != uint256(0)) {
            result = result + 1;
        }
        if(pool.connector_owns(msg.sender, _id)) {
            result = result + 10;
        }
        if(pool.getState(_id) == StateClaim) {
            result = result + 100;
        }
        if(_subPoolId != uint256(0)) {
            result = result + 1000;
        }
        if(spextensions[_subPoolId].timeStamp != uint256(0)) {
            result = result + 10000;
        }
        if(spextensions[_subPoolId].funded) {
            result = result + 100000;
        }
        if(address(this).balance >= spextensions[_subPoolId].payment) {
            result = result + 1000000;
        }
        if(value >= spextensions[_subPoolId].debit) {
            result = result + 10000000;
        }
        return result;
    }
    constructor(address _pool) public {
        subPoolId = 3;
        _createExtension(subPoolId);
        pool = ITokenPool(_pool);
    }
    function() public payable { }                           //  fallback function to get Ether on contract account
}