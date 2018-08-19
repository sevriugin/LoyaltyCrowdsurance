var TokenLoyalty = artifacts.require("TokenLoyalty");
var ERC20Adapter = artifacts.require("ERC20Adapter");
var TokenContainer = artifacts.require("TokenContainer");
var TokenPool = artifacts.require("TokenPool");

module.exports = function(deployer) {
  
        return deployer.deploy(ERC20Adapter, "0x5d1b26aa7b2955913665f783191a6e5d3353cfd9", "0x0EB2516c083FCa43AbB77298AE84C1dA3748E971", "ERC20 Loyalty Token Smart Token", "LTST20", 10);
      
};
