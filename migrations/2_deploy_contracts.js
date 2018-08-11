var TokenLoyalty = artifacts.require("TokenLoyalty");
var ERC20Adapter = artifacts.require("ERC20Adapter");
var TokenContainer = artifacts.require("TokenContainer");
var TokenPool = artifacts.require("TokenPool");

module.exports = function(deployer) {
  return deployer.deploy(TokenContainer, "Loyalty Token Smart Token", "LTST", {gas:6400000}).then(function() {
    return deployer.deploy(TokenPool, TokenContainer.address, {gas:5000000}).then(function() {
      return deployer.deploy(TokenLoyalty, TokenPool.address, {gas:3000000}).then(function() {
        return deployer.deploy(ERC20Adapter, TokenContainer.address, TokenLoyalty.address, "ERC20 Loyalty Token Smart Token", "LTST20", 10);
      });
    });
  }).catch(function(err) {console.log(err);});
};
