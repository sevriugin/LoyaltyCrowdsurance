pragma solidity ^0.4.18;

contract ITokenPool {
    function connector_owns(address _claimant, uint256 _tokenId) public view  returns (bool);
    function connector_getMetadata(uint256 _id) view public  returns (string);    
    function connector_setMetadata(uint256 _id, string _metadata) public;
    function connector_createNFT(uint256 _amount, address _member) public returns(uint256);
    function connector_addTokenToSubPool(uint256 _id) public returns(bool);
    function insertSubPool() public returns(uint256 subPoolId);
    function getState(uint256 _id) public view returns (uint256);
    function setState(uint256 _id, uint256 _state) public;
    function getSubPool(uint256 _id) public view returns (uint256);
    function getValue(uint256 _id) public view returns(uint256);
    function setValue(uint256 _id, uint256 _value) public;
    function getPoolSize() public view returns (uint256);
}