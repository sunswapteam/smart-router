const { mainnet, nile } = require('../scripts/config.js');
var router = artifacts.require('./SmartExchangeRouter.sol');

module.exports = function (deployer, network) {
  if (network == 'nile') {
    deployer.deploy(
      router,
      nile.routerV2,
      nile.routerV1,
      nile.psmUsddToken,
      nile.routerV3,
      nile.wtrxToken
    );
  } else if (network == 'mainnet') {
    deployer.deploy(
      router,
      mainnet.routerV2,
      mainnet.routerV1,
      mainnet.psmUsddToken,
      mainnet.routerV3,
      mainnet.wtrxToken
    );
  }
};
