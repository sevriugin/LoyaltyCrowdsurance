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
// Version: 0.0.2 TokenLoyalty
//  

pragma solidity ^0.4.17;

import "./interfaces/ITokenContainer.sol";
import "./interfaces/ITokenPool.sol";
import "./Owned.sol";

/// TokenPool is TokenContainer with 4 level pool structure: 
/// Super Pool (Level 0), Pool (Level 1), Sub Pool (Level 2) and Token (Level 3)
/// Level       Container / Member
/// ------------------------------------------------
///   0         SuperPool
///   1              |______Pool
///   2                      |______SubPool
///   3                                |_______Token
contract TokenPool is ITokenPool, Owned() {
    /// TokenPool insertPool event
    /// @param id inserted token ID
    /// @param poolId pool ID
    /// @param level pool level
    event InsertPool(uint256 id, uint256 poolId, uint8 level);
    /// TokenPool value distribution event
    /// @param id NFT token ID for value distribution 
    /// @param superPoolValue SuperPool Share
    /// @param poolValue Pool Share
    /// @param subPoolValue SubPool Share
    /// @param comission Comission = the rest after all pools 
    event DistributeValue(uint256 id, uint256 superPoolValue, uint256 poolValue, uint256 subPoolValue, uint256 comission);
    /// TokenPool Second Tier Call event
    /// @param id NFT token ID that emits event
    /// @param value 2nd tier capital call value
    event SecondTierCall(uint256 id, uint256 value);
    /// TokenPool ShortOfFunds event
    /// @param id NFT token ID that emits event
    /// @param poolId pool ID that can't pay
    /// @param value that pool can't pay
    /// @param level pool level that can't 
    event ShortOfFunds(uint256 id, uint256 poolId, uint256 value, uint8 level);
    /// TokenPool Payment Value event
    /// @param id NFT token ID that emits event
    /// @param value paid value
    /// @param level pool level that paid
    event PaymentValue(uint256 id, uint256 value, uint8 level);
    /// @dev Pool defines pool structure
    /// @param level Pool level: 0,1,2,3
    /// @param maxNumber Maximum number of pools on this lavel
    /// @param maxMember Maximum number of members for the pool
    /// @param number Pool number for this level
    /// @param last NFT ID for last availible pool (with member capacity)
    struct Pool {
        uint8   level;      // Pool level: 0,1,2,3
        uint256 maxNumber;  // Maximum number of pools on this lavel
        uint256 maxMember;  // Maximum number of members for the pool
        uint256 number;     // Pool number for this level
        uint256 last;       // NFT ID for last availible pool (with member capacity)
        uint256 share;      // Pool share from token investment
    }
    /// @dev Pool structure 
    Pool[] pools;           // Pool structure
    ITokenContainer public container;
    uint256 public maxLevel;
    /// inset new member in the pool
    /// @param _id NFT token ID to inserr
    /// @param _level Pool level to insert
    /// @return TRUE if insert is done 
    function _getParent(uint256 _id, uint8 _level) internal view returns (uint256 parentId) {
        // by default returns pools[_level].last but must be overloaded to use score to calculate right pool
        _id;
        parentId = pools[_level].last;
    }
    function _getCapacity(uint256 _id, uint8 _level) internal view returns (uint256 parentId) {
        // by default returns pools[_level].maxMember - 1; but can be overloaded to use score to calculate right pool capacity
        _id;
        parentId = pools[_level].maxMember - 1;
    }
    function _insertPool(uint256 _id, uint8 _level) internal returns (bool) {
        uint256 parentId = _getParent(_id, _level); // pool NFT token ID
        uint256 size = container.getPoolSize(parentId);      // current pool size
        uint256 max = _getCapacity(_id, _level);    // max pool size - 1
        // check if there is a place to insert 
        if (size < max) {
            // simple insert
            container.addToken(_id, parentId); // add to pool 
            emit InsertPool(_id, parentId, _level); // event 
            return true;
        }
        else {
            // no capacity in the current pool, so, need to add new pool
            // check if it's possible
            if(pools[_level].number == pools[_level].maxNumber) {
                // no capacity to add new pool at this lavel
                return false;
            }
            else {
                // make a copy from the last pool
                uint newPool = container.createNFT(uint256(0), container.getNFTMetadata(parentId), container.getNFTKind(parentId), owner);
                if (newPool != uint(0)) { 
                    // insert pool in the pool structure
                    if (_insertPool(newPool, _level-1)) {
                        // insert token to the new pool
                        container.addToken(_id, newPool); // add to pool
                        emit InsertPool(_id, newPool, _level); // event 
                        // record new pool data in the structure 
                        pools[_level].last = newPool; // new pool is last one
                        pools[_level].number++;
                        // new pool and member are inserted 
                        return true;
                    }
                    else {
                        return false;
                    }
                }
                else {
                    return false;
                }
            }
        }
    }
    /// distribute value of the token _id to pools
    /// @dev make it as simmple as possible for fixed pool staructure
    /// @param _id NFT token ID to distribute value
    /// @return TRUE if distribution is complited 
    function _distributeValue(uint256 _id) internal returns (bool) {
        // need to make sure that _id is terminal node in the structure 
        require(_id != uint256(0));
        require(container.getNFTLevel(_id) == maxLevel - 1);
        // now we can check then the path has all pools
        uint256 subPoolId = container.tokenIndexToPoolToken(_id);
        require(subPoolId != uint256(0)); // SubPool
        uint256 poolId = container.tokenIndexToPoolToken(subPoolId);
        require(poolId != uint256(0)); // Pool
        uint256 superPoolId = container.tokenIndexToPoolToken(poolId);
        require(superPoolId != uint256(0)); // SuperPool
        // calculate values to distribute based of pool structure shares
        uint256 value = container.getNFTValue(_id);
        uint256 subPoolValue = value * pools[2].share / 100;
        require(subPoolValue != uint256(0));
        uint256 poolValue = value * pools[1].share / 100;
        require(poolValue != uint256(0));
        uint256 superPoolValue = value * pools[0].share / 100;
        require(superPoolValue != uint256(0));
        uint256 commission = value - subPoolValue - poolValue - superPoolValue;
        require(commission != uint256(0));
        // ready to distribute
        container.setNFTValue(subPoolId, container.getNFTValue(subPoolId) + subPoolValue);
        container.setNFTValue(poolId, container.getNFTValue(poolId) + poolValue);
        container.setNFTValue(superPoolId, container.getNFTValue(superPoolId) + superPoolValue);
        
        // we will keep comission in the reserved token with ID = 0
        container.setNFTValue(uint256(0), container.getNFTValue(uint256(0)) + commission);
    
        // the distribution is done 0 --> _id value
        container.setNFTValue(_id, uint256(0));
        emit DistributeValue(_id, superPoolValue, poolValue, subPoolValue, commission);
        return true;
    }
    /// insert token in pool structure
    /// @param _id NFT token ID to insert
    /// @return TRUE if insert is done 
    function insertPool(uint256 _id) ownerOnly public returns(bool) {
        require(_id != uint256(0));
        // call internal function
        assert(_insertPool(_id, 2));
        // if inserted then make value distribution 
        assert(_distributeValue(_id));
        return true;
    }
    function insertSubPool() connectorOnly public returns(uint256 subPoolId) {
        subPoolId = container.createNFT(uint256(0), "SubPool", uint256(2), owner);
        require(subPoolId != uint256(0));
        // call internal function
        assert(_insertPool(subPoolId, 1));
    }
    /// insert token in pool structure
    /// @param _id NFT token ID to insert
    /// @return TRUE if insert is done 
    function _addTokenToSubPool(uint256 _id) internal returns(bool) {
        require(_id != uint256(0));
        // call internal function
        assert(_insertPool(_id, 2));
        // if inserted then make value distribution 
        assert(_distributeValue(_id));
        return true;
    }
    /// TokenPool Connectors helpers
    function connector_owns(address _claimant, uint256 _tokenId) public view connectorOnly returns (bool) {
        return container.owns(_claimant, _tokenId);
    }
    function connector_getMetadata(uint256 _id) view public connectorOnly returns (string) {
        return container.getNFTMetadata(_id);
    }
    function connector_setMetadata(uint256 _id, string _metadata) public connectorOnly {
        container.setNFTMetadata(_id, _metadata);
    }
    function connector_createNFT(uint256 _amount, address _member) public connectorOnly returns(uint256) {
        return container.createNFT(_amount, "Loyalty", uint256(0), _member);
    }
    function connector_addTokenToSubPool(uint256 _id) public connectorOnly returns(bool) {
        return _addTokenToSubPool(_id);
    }
    function connector_tokensOfOwner(address _owner) view public connectorOnly returns(uint256[] ownerTokens) {
        return container.tokensOfOwner(_owner);
    }
    function getSubPool(uint256 _id) public view returns (uint256) {
        return container.tokenIndexToPoolToken(_id);
    }
    function getState(uint256 _id) public view returns (uint256) {
        container.getNFTState(_id);
    }
    function setState(uint256 _id, uint256 _state) public connectorOnly {
        container.setNFTState(_id, _state);
    }
    function init() public ownerOnly {
        // Creating templates
        uint superPoolId = container.createNFT(10 ether, "SuperPool", uint256(1), owner);    // fix initial capital for 10 Ether
        uint poolId = container.createNFT(uint256(0), "Pool", uint256(1), owner);
        uint subPoolId = container.createNFT(uint256(0), "SubPool", uint256(2), owner);

        // Build initil structure SubPool --> Pool --> SuperPool
        container.addToken(poolId, superPoolId);
        container.addToken(subPoolId, poolId);

        // Build configuration 
        // SuperPool configuration
        Pool memory superPool = Pool({
            level: uint8(0),
            maxNumber: uint256(1),
            maxMember: uint256(10),
            number: uint256(1),
            last: uint256(superPoolId),
            share: uint256(10)
        });
        pools.push(superPool);
        // Pool configuration 
        Pool memory pool = Pool({
            level: uint8(1),
            maxNumber: uint256(10),
            maxMember: uint256(1000),
            number: uint256(1),
            last: uint256(poolId),
            share: uint256(20)
        });
        pools.push(pool);
        // SubPool configuration 
        Pool memory subPool = Pool({
            level: uint8(2),
            maxNumber: uint256(1000),
            maxMember: uint256(1000),
            number: uint256(1),
            last: uint256(subPoolId),
            share: uint256(50)
        });
        pools.push(subPool);
        // set comission to 0
        container.setNFTValue(uint256(0), uint256(0));
    }
    /// TokenPool Constructor
    constructor(ITokenContainer _container)  public { 
        container = _container;
        maxLevel = 4;
    }
}