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
    event Funded(uint subPoolId, uint payment, uint timeStamp, uint closure);
    /// payment event
    event Paid(uint subPoolId, uint tokenId, uint payment, uint timeStamp, uint closure);

    function _createExtension(uint _subPoolId) internal {
        spextensions[_subPoolId] = SubPoolExtension ({
            timeStamp: now,
            closure: now + 1 days,
            members: uint(0),
            activated: uint(0),
            funded: false,
            payment: uint(0)
        });
        // emit event
        emit SPExtension(_subPoolId, spextensions[_subPoolId].timeStamp, spextensions[_subPoolId].closure);
    }
    /// create loyalty token
    function create(address _member, string _clientId, bool _claim) ownerOnly public {
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
        uint tokenId = pool.connector_createNFT(uint256(5), _member);
        if(tokenId == uint(0)) {
            emit Error("can't create new token");
            return;
        }
        // token is created
        // set metadata to _clientId
        pool.connector_setMetadata(tokenId, _clientId);
        // if _claim is true set status
        if(_claim) {
            pool.setState(tokenId, StateClaim);
        }
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
        emit Created(_member, _clientId, _claim, tokenId, subPoolId);
        spextensions[subPoolId].members = spextensions[subPoolId].members + 1;
        if(_claim) {
            spextensions[subPoolId].activated = spextensions[subPoolId].activated + 1;
        }
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
    function fund(uint _subPoolId, uint _payment) ownerOnly public payable {
        require(_subPoolId != uint256(0));
        uint256 amount = msg.value;
        require(amount >= spextensions[_subPoolId].activated * _payment);
        spextensions[_subPoolId].funded = true;
        spextensions[_subPoolId].payment = _payment;

        emit Funded(_subPoolId, _payment, spextensions[_subPoolId].timeStamp, spextensions[_subPoolId].closure);
    }
    function payment(uint256 _id) public {
        require(_id != uint256(0));
        require(pool.connector_owns(msg.sender, _id));
        require(pool.getState(_id) == StateClaim);
        uint _subPoolId = pool.getSubPool(_id);
        require(_subPoolId != uint256(0));
        require(spextensions[_subPoolId].timeStamp != uint256(0));
        require(spextensions[_subPoolId].funded);
        msg.sender.transfer(spextensions[_subPoolId].payment);
        pool.setState(_id, StatePaid);

        emit Paid(_subPoolId, _id, spextensions[_subPoolId].payment, spextensions[_subPoolId].timeStamp, spextensions[_subPoolId].closure);
    }
    function getSubPoolExtension(uint256 _subPoolId) public view returns(uint, uint, uint, uint, bool, uint) {
        return(
            spextensions[_subPoolId].timeStamp, 
            spextensions[_subPoolId].closure, 
            spextensions[_subPoolId].members, 
            spextensions[_subPoolId].activated, 
            spextensions[_subPoolId].funded, 
            spextensions[_subPoolId].payment
        );
    }
    function getCurrentSubPoolExtension() public view returns(uint, uint, uint, uint, bool, uint) {
        return getSubPoolExtension(subPoolId);
    }
    constructor(address _pool) public {
        subPoolId = 3;
        pool = ITokenPool(_pool);
    }
    function() public payable { }                           //  fallback function to get Ether on contract account
}