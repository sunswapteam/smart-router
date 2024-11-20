var router = artifacts.require('./SmartExchangeRouter.sol');

var old3pool = '0x332124D9aCCbCd2FFD3Be081Cfb36E959f5969c6';
var oldusdcpool = '0x4100000000000000000000000000000000000000';
var routerV2 = '0x332124D9aCCbCd2FFD3Be081Cfb36E959f5969c6';
var routerV1 = '0x332124D9aCCbCd2FFD3Be081Cfb36E959f5969c6';
var routerV3 = '0x332124D9aCCbCd2FFD3Be081Cfb36E959f5969c6';
var usdtToken = '0x332124D9aCCbCd2FFD3Be081Cfb36E959f5969c6';
var usdjToken = '0x332124D9aCCbCd2FFD3Be081Cfb36E959f5969c6';
var tusdToken = '0x332124D9aCCbCd2FFD3Be081Cfb36E959f5969c6';
var wtrxToken = '0x332124D9aCCbCd2FFD3Be081Cfb36E959f5969c6';
var psmUsddToken = '0x332124D9aCCbCd2FFD3Be081Cfb36E959f5969c6';

module.exports = function (deployer, network) {

  deployer.deploy(
    router,
    routerV2,
    routerV1,
    psmUsddToken,
    routerV3,
    wtrxToken
  );
};
