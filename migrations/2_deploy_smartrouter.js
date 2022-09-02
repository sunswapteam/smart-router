var exchangeRouter = artifacts.require("./ExchangeRouter.sol");

var old3pool = '0x332124D9aCCbCd2FFD3Be081Cfb36E959f5969c6'
var usdcPool = '0x332124D9aCCbCd2FFD3Be081Cfb36E959f5969c6'
var v2Router = '0x332124D9aCCbCd2FFD3Be081Cfb36E959f5969c6'
var v1Foctroy = '0x332124D9aCCbCd2FFD3Be081Cfb36E959f5969c6'
var usdt = '0x332124D9aCCbCd2FFD3Be081Cfb36E959f5969c6'
var usdj = '0x332124D9aCCbCd2FFD3Be081Cfb36E959f5969c6'
var tusd = '0x332124D9aCCbCd2FFD3Be081Cfb36E959f5969c6'
var usdc = '0x332124D9aCCbCd2FFD3Be081Cfb36E959f5969c6'

module.exports = function(deployer) {
  deployer.deploy(exchangeRouter, old3pool, usdcPool, v2Router, v1Foctroy, usdt, usdj, tusd, usdc);
};
