require('chai')
  .use(require('bn-chai')(web3.utils.BN))
  .use(require('chai-as-promised'))
  .should();

const a = require('web3-utils');
const { toBN } = a;
console.log("---------------------",a);
const { takeSnapshot, revertSnapshot } = require('./ganacheHelper');

const SmartExchangeRouterTest = artifacts.require(
  './SmartExchangeRouterTest.sol',
);
const TRC20Mock = artifacts.require('./TRC20Mock.sol');
const PoolStableMock = artifacts.require('./PoolStableMock.sol');
const ExchangerV1Mock = artifacts.require('./ExchangerV1Mock.sol');
const RouterV1Mock = artifacts.require('./RouterV1Mock.sol');
const RouterV2Mock = artifacts.require('./RouterV2Mock.sol');
const RouterV3Mock = artifacts.require('./RouterV3Mock.sol');
const wethMock = artifacts.require("./tokens/WETH9.sol");
contract('SmartExchangeRouterTest', (accounts) => {
  // only-test let gasPrice;
  let old3pool;
  let usdcpool;
  let v1Factory;
  let v2Router;
  let v3Router;
  let usdd2Pool;
  let usdt, usdj, tusd, usdc, weth, usdd;
  let exchangeRouter;
  const sender = accounts[0];
  const receiver = accounts[1];
  const zeroAddress = '0x0000000000000000000000000000000000000000';
  const invalidAddress = '0x1000000000000000000000000000000000000000';
  const infiniteTime = 999999999999;
  // eslint-disable-next-line no-unused-vars
  let snapshotId;

  // only-test function gasUsed(receipt) {
  // only-test   let price = gasPrice;
  // only-test   if (receipt.effectiveGasPrice) price = receipt.effectiveGasPrice;
  // only-test   return toBN(receipt.gasUsed).mul(toBN(price));
  // only-test }

  const mockV1Token = async (token, amountsOut) => {
    await v1Factory
      .getExchange(token.address)
      .then(async (address) => {
        return await new web3.eth.Contract(ExchangerV1Mock.abi, address);
      })
      .then(async (exchange) => {
        await exchange.methods.setTokenOut(amountsOut).send({ from: sender });
      });
  };

  before(async () => {
    // only-test gasPrice = await web3.eth.getGasPrice();
    usdt = await TRC20Mock.new();
    usdj = await TRC20Mock.new();
    tusd = await TRC20Mock.new();
    usdc = await TRC20Mock.new();
    weth = await wethMock.new();
    usdd = await TRC20Mock.new();
    usdd2Pool = await PoolStableMock.new(
      [usdd.address, usdt.address],
      10000000000,
    );
    old3pool = await PoolStableMock.new(
      [usdj.address, tusd.address, usdt.address],
      10000000000,
    );
    usdcpool = await PoolStableMock.new(
      [usdc.address, usdj.address, tusd.address, usdt.address],
      10000000000,
    );
    v1Factory = await RouterV1Mock.new();
    await web3.eth.sendTransaction({
      to: v1Factory.address,
      from: accounts[2],
      value: web3.utils.toWei(toBN(10), 'ether'),
    });
    await v1Factory.setUp(
      [usdc.address, usdj.address, tusd.address, usdt.address],
      web3.utils.toWei(toBN(1), 'ether'),
    );
    v2Router = await RouterV2Mock.new();
    await web3.eth.sendTransaction({
      to: v2Router.address,
      from: accounts[3],
      value: web3.utils.toWei(toBN(10), 'ether'),
    });
    await v2Router.setUp(
      [usdc.address, usdj.address, tusd.address, usdt.address],
      web3.utils.toWei(toBN(1), 'ether'),
    );
    v3Router = await RouterV3Mock.new();

    await web3.eth.sendTransaction({
      to: v3Router.address,
      from: accounts[4],
      value: web3.utils.toWei(toBN(10), 'ether'),
    });
    await v3Router.setUp(
      [usdc.address, usdj.address, tusd.address, usdt.address],
      web3.utils.toWei(toBN(1), 'ether'),
    );
    
    exchangeRouter = await SmartExchangeRouterTest.new(
      v2Router.address,
      v3Router.address,
      v1Factory.address,
      usdd.address,
      weth.address,
      usdt.address
    );
    await exchangeRouter.addUsdcPool("oldusdcpool", usdcpool.address, [usdc.address,usdj.address,tusd.address,usdt.address]);
    await exchangeRouter.addPool("old3pool", old3pool.address, [usdj.address,tusd.address,usdt.address]);
    snapshotId = await takeSnapshot();
  });

  describe('#constructPathSlice', () => {
    it('invalid args', async () => {
      let path = [usdc.address];
      await exchangeRouter
        .constructPathSlice(path, 0, 1)
        .should.be.rejectedWith('INVALID_ARGS');
      path = [usdc.address, usdj.address, tusd.address, usdt.address];
      await exchangeRouter
        .constructPathSlice(path, 1, 4)
        .should.be.rejectedWith('INVALID_ARGS');
      let fee = [100];
      await exchangeRouter.constructFeesSlice(fee,0,1).should.be.rejectedWith("INVALID_FEES");
      fee = [100,0,0,1];
      await exchangeRouter.constructFeesSlice(fee,1,4).should.be.rejectedWith("INVALID_FEES");
    });
    it('construct', async () => {
      const path = [usdc.address, usdj.address, tusd.address, usdt.address];
      const pathSlice = await exchangeRouter.constructPathSlice(path, 1, 3);
      expect(pathSlice).to.have.lengthOf(3);
      expect(path.slice(1)).to.have.ordered.members(pathSlice);
    });
  });

  describe('#tokenSafeTransferFrom', () => {
    it('A->B', async () => {
      await usdt.mint(sender, 100);
      const balanceBefore = [
        await usdt.balanceOf(sender),
        await usdt.balanceOf(receiver),
      ];
      await usdt.approve(exchangeRouter.address, 100, { from: sender });
      const result = await exchangeRouter.tokenSafeTransferFrom(
        usdt.address,
        sender,
        receiver,
        50,
      );
      const balanceAfter = [
        await usdt.balanceOf(sender),
        await usdt.balanceOf(receiver),
      ];
      const actual = result.logs[0].args.value.toNumber();
      expect(actual).to.be.at.most(50);
      const balanceExpect = [-50, actual];
      expect(
        balanceAfter.map(function (x, i) {
          return x.sub(balanceBefore[i]).toNumber();
        }),
      ).to.have.ordered.members(balanceExpect);
    });
    it('A->A', async () => {
      await usdt.mint(sender, 100);
      await usdt.approve(exchangeRouter.address, 100, { from: sender });
      await exchangeRouter
        .tokenSafeTransferFrom(usdt.address, sender, sender, 50)
        .should.be.rejectedWith('INVALID_ARGS');
    });
    it('address 0', async () => {
      await usdt.mint(sender, 100);
      await usdt.approve(exchangeRouter.address, 100, { from: sender });
      await exchangeRouter
        .tokenSafeTransferFrom(usdt.address, sender, zeroAddress, 50)
        .should.be.rejectedWith(Error);
    });
    it('insufficient fund', async () => {
      await usdt.approve(exchangeRouter.address, 100000000000, {
        from: sender,
      });
      await exchangeRouter
        .tokenSafeTransferFrom(usdt.address, sender, receiver, 100000000000)
        .should.be.rejectedWith(Error);
    });
  });

  describe('#stablePoolExchange', () => {
    it('pool not exist', async () => {
      await exchangeRouter
        .stablePoolExchange(
          'wrong version',
          [usdc.address, usdt.address],
          50,
          1,
        )
        .should.be.rejectedWith('pool not exist');
    });
    it('invalide path', async () => {
      await exchangeRouter
        .stablePoolExchange('old3pool', [], 50, 1)
        .should.be.rejectedWith('INVALID_PATH_SLICE');

      await exchangeRouter
        .stablePoolExchange('old3pool', [usdj.address, usdj.address], 50, 1)
        .should.be.rejectedWith('INVALID_PATH_SLICE');
    });
    it('exchange failed', async () => {
      await usdj.mint(exchangeRouter.address, 100);
      await old3pool.setTokenOut([0]);
      await exchangeRouter
        .stablePoolExchange('old3pool', [usdj.address, usdt.address], 50, 1)
        .should.be.rejectedWith('amountMin not satisfied');
    });
    it('old3pool', async () => {
      await usdj.mint(exchangeRouter.address, 1000000);
      const amount = 1000000;
      const path = [usdj.address, tusd.address, usdt.address];
      await old3pool.setTokenOut([amount * 0.997, amount * 0.997 * 0.997]);
      const balanceBefore = [
        await usdj.balanceOf(exchangeRouter.address),
        await tusd.balanceOf(exchangeRouter.address),
        await usdt.balanceOf(exchangeRouter.address),
      ];
      const result = await exchangeRouter.stablePoolExchange(
        'old3pool',
        path,
        amount,
        1,
      );
      const balanceAfter = [
        await usdj.balanceOf(exchangeRouter.address),
        await tusd.balanceOf(exchangeRouter.address),
        await usdt.balanceOf(exchangeRouter.address),
      ];
      const amountsOut = result.logs[0].args.amountsOut.map(function (x) {
        return x.toNumber();
      });
      let expectOut = [amount, amount * 0.997, amount * 0.997 * 0.997];
      expect(amountsOut).to.have.lengthOf(expectOut.length);
      expect(amountsOut).to.have.ordered.members(expectOut);
      expectOut = [-amount, 0, amount * 0.997 * 0.997];
      expect(
        balanceAfter.map(function (x, i) {
          return x.sub(balanceBefore[i]).toNumber();
        }),
      ).to.have.ordered.members(expectOut);
    });
    it('usdcpool', async () => {
      await usdc.mint(exchangeRouter.address, 1000000);
      const amount = 1000000;
      const path = [usdc.address, usdj.address, tusd.address, usdt.address];
      await usdcpool.setTokenOut([amount * 0.997, amount, amount * 0.997]);
      const balanceBefore = [
        await usdc.balanceOf(exchangeRouter.address),
        await usdj.balanceOf(exchangeRouter.address),
        await tusd.balanceOf(exchangeRouter.address),
        await usdt.balanceOf(exchangeRouter.address),
      ];
      const result = await exchangeRouter.stablePoolExchange(
        'oldusdcpool',
        path,
        amount,
        1,
      );
      const balanceAfter = [
        await usdc.balanceOf(exchangeRouter.address),
        await usdj.balanceOf(exchangeRouter.address),
        await tusd.balanceOf(exchangeRouter.address),
        await usdt.balanceOf(exchangeRouter.address),
      ];
      const amountsOut = result.logs[0].args.amountsOut.map(function (x) {
        return x.toNumber();
      });
      let expectOut = [amount, amount * 0.997, amount, amount * 0.997];
      expect(amountsOut).to.have.lengthOf(expectOut.length);
      expect(amountsOut).to.have.ordered.members(expectOut);
      expectOut = [-amount, 0, 0, amount * 0.997];
      expect(
        balanceAfter.map(function (x, i) {
          return x.sub(balanceBefore[i]).toNumber();
        }),
      ).to.have.ordered.members(expectOut);
    });
    it('psmpool', async () => {
      const owner = await exchangeRouter.owner();
      await exchangeRouter.addPsmPool(
        'usdd2pool',
        usdd2Pool.address,
        usdd2Pool.address,
        [usdd.address, usdt.address],
        { from: owner },
      );
      const amount = 1000;
      await usdd.mint(exchangeRouter.address, amount);
      const path = [usdd.address, usdt.address, usdd.address, usdt.address];
      const balanceBefore = [
        await usdd.balanceOf(exchangeRouter.address),
        await usdd.balanceOf(usdd2Pool.address),
        await usdt.balanceOf(usdd2Pool.address),
        await usdt.balanceOf(exchangeRouter.address),
      ];
      const result = await exchangeRouter.stablePoolExchange(
        'usdd2pool',
        path,
        amount,
        1,
      );
      const balanceAfter = [
        await usdd.balanceOf(exchangeRouter.address),
        await usdd.balanceOf(usdd2Pool.address),
        await usdt.balanceOf(usdd2Pool.address),
        await usdt.balanceOf(exchangeRouter.address),
      ];
      const amountsOut = result.logs[0].args.amountsOut.map(function (x) {
        return x.toNumber();
      });
      expect(amountsOut).to.have.lengthOf(4);
      expect(amountsOut).to.have.ordered.members([
        amount,
        amount,
        amount,
        amount,
      ]);
      expect(
        balanceAfter.map(function (x, i) {
          return x.sub(balanceBefore[i]).toNumber();
        }),
      ).to.have.ordered.members([-amount, amount, -amount, amount]);
    });
  });

  describe('#trxToTokenTransferInput', () => {
    it('address 0', async () => {
      await exchangeRouter
        .trxToTokenTransferInput(zeroAddress, 1, receiver, infiniteTime)
        .should.be.rejectedWith('exchanger not found');
    });
    it('error', async () => {
      await mockV1Token(usdt, [0]);
      await exchangeRouter
        .trxToTokenTransferInput(usdt.address, 1, receiver, infiniteTime)
        .should.be.rejectedWith('Transaction failed.');
    });
    it('success', async () => {
      await mockV1Token(usdt, [1]);
      const balanceBefore = [
        // only-test await web3.eth.getBalance(sender).then(async (x) => {
        // only-test   return toBN(x);
        // only-test }),
        await web3.eth.getBalance(exchangeRouter.address).then(async (x) => {
          return toBN(x);
        }),
        await usdt.balanceOf(receiver),
      ];
      const amount = web3.utils.toWei(toBN(1), 'ether');
      const result = await exchangeRouter.trxToTokenTransferInput(
        usdt.address,
        1,
        receiver,
        infiniteTime,
        { value: amount },
      );
      const balanceAfter = [
        // only-test await web3.eth.getBalance(sender).then(async (x) => {
        // only-test   return toBN(x);
        // only-test }),
        await web3.eth.getBalance(exchangeRouter.address).then(async (x) => {
          return toBN(x);
        }),
        await usdt.balanceOf(receiver),
      ];
      // only-test const gas = gasUsed(result.receipt);
      const amountOut = result.logs[0].args.amountOut;
      expect(amountOut.toNumber()).to.be.equal(1);
      expect(
        balanceAfter.map(function (x, i) {
          return x.sub(balanceBefore[i]).toString();
        }),
      ).to.have.ordered.members([
        // only-test amount.neg().sub(gas).toString(),
        '0',
        '1',
      ]);
    });
  });

  describe('#tokenToTrxTransferInput', () => {
    it('address 0', async () => {
      await usdt.mint(exchangeRouter.address, 100);
      await exchangeRouter
        .tokenToTrxTransferInput(zeroAddress, 1, 1, receiver, infiniteTime)
        .should.be.rejectedWith('exchanger not found');
    });
    it('error', async () => {
      await mockV1Token(usdt, [0]);
      await usdt.mint(exchangeRouter.address, 100);
      await exchangeRouter
        .tokenToTrxTransferInput(usdt.address, 100, 1, receiver, infiniteTime)
        .should.be.rejectedWith('Transaction failed.');
    });
    it('success', async () => {
      const weiOut = web3.utils.toWei(toBN(1), 'ether');
      await mockV1Token(usdt, [weiOut]);
      await usdt.mint(exchangeRouter.address, 100);
      const balanceBefore = [
        await usdt.balanceOf(exchangeRouter.address),
        await web3.eth.getBalance(receiver).then(async (x) => {
          return toBN(x);
        }),
      ];
      const result = await exchangeRouter.tokenToTrxTransferInput(
        usdt.address,
        1,
        1,
        receiver,
        infiniteTime,
      );
      const balanceAfter = [
        await usdt.balanceOf(exchangeRouter.address),
        await web3.eth.getBalance(receiver).then(async (x) => {
          return toBN(x);
        }),
      ];
      const amountOut = result.logs[0].args.amountOut;
      expect(amountOut.toString()).to.be.equal(weiOut.toString());
      expect(
        balanceAfter.map(function (x, i) {
          return x.sub(balanceBefore[i]).toString();
        }),
      ).to.have.ordered.members(['-1', amountOut.toString()]);
    });
  });

  describe('#tokenToTokenTransferInput', () => {
    it('address 0', async () => {
      await usdt.mint(exchangeRouter.address, 100);
      await exchangeRouter
        .tokenToTokenTransferInput(
          zeroAddress,
          usdt.address,
          1,
          1,
          receiver,
          infiniteTime,
        )
        .should.be.rejectedWith('exchanger not found');
    });
    it('error', async () => {
      await mockV1Token(usdt, [0]);
      await usdt.mint(exchangeRouter.address, 100);
      await exchangeRouter
        .tokenToTokenTransferInput(
          usdt.address,
          usdc.address,
          100,
          1,
          receiver,
          infiniteTime,
        )
        .should.be.rejectedWith('Transaction failed.');
    });
    it('success', async () => {
      await mockV1Token(usdt, [100]);
      await mockV1Token(usdc, [97]);
      await usdt.mint(exchangeRouter.address, 100);
      const balanceBefore = [
        await usdt.balanceOf(exchangeRouter.address),
        await usdc.balanceOf(receiver),
      ];
      const result = await exchangeRouter.tokenToTokenTransferInput(
        usdt.address,
        usdc.address,
        100,
        1,
        receiver,
        infiniteTime,
      );
      const balanceAfter = [
        await usdt.balanceOf(exchangeRouter.address),
        await usdc.balanceOf(receiver),
      ];
      const amountOut = result.logs[0].args.amountOut;
      expect(amountOut.toNumber()).to.be.equal(97);
      expect(
        balanceAfter.map(function (x, i) {
          return x.sub(balanceBefore[i]).toNumber();
        }),
      ).to.have.ordered.members([-100, amountOut.toNumber()]);
    });
  });

  describe('#swapExactTokensForTokensV1', () => {
    it('invalid path', async () => {
      await exchangeRouter
        .swapExactTokensForTokensV1(1, 1, [], receiver, infiniteTime)
        .should.be.rejectedWith('INVALID_PATH_SLICE');
    });
    it('invalid address', async () => {
      await exchangeRouter
        .swapExactTokensForTokensV1(
          1,
          1,
          [invalidAddress, usdt.address],
          receiver,
          infiniteTime,
        )
        .should.be.rejectedWith('exchanger not found');
    });
    it('error', async () => {
      await usdc.mint(exchangeRouter.address, 1000000);
      const amount = 1000000;
      const path = [usdc.address, usdj.address, tusd.address, usdt.address];
      await mockV1Token(usdc, [0]);
      await exchangeRouter
        .swapExactTokensForTokensV1(amount, 1, path, receiver, infiniteTime)
        .should.be.rejectedWith('Transaction failed.');
    });
    it('trx2token2trx2token2token', async () => {
      const amount = web3.utils.toWei(toBN(1), 'ether');
      const path = [
        zeroAddress,
        usdc.address,
        zeroAddress,
        usdj.address,
        tusd.address,
        usdt.address,
      ];
      await mockV1Token(usdc, [997]);
      await mockV1Token(usdj, [1000]);
      await mockV1Token(tusd, [997]);
      await mockV1Token(usdt, [994]);
      const balanceBefore = [
        // only-test await web3.eth.getBalance(sender).then(async (x) => {
        // only-test   return toBN(x);
        // only-test }),
        await web3.eth.getBalance(exchangeRouter.address).then(async (x) => {
          return toBN(x);
        }),
        await usdc.balanceOf(exchangeRouter.address),
        await usdj.balanceOf(exchangeRouter.address),
        await tusd.balanceOf(exchangeRouter.address),
        await usdt.balanceOf(exchangeRouter.address),
        await usdt.balanceOf(receiver),
      ];
      const result = await exchangeRouter.swapExactTokensForTokensV1(
        amount,
        1,
        path,
        receiver,
        infiniteTime,
        { value: amount },
      );
      const balanceAfter = [
        // only-test await web3.eth.getBalance(sender).then(async (x) => {
        // only-test   return toBN(x);
        // only-test }),
        await web3.eth.getBalance(exchangeRouter.address).then(async (x) => {
          return toBN(x);
        }),
        await usdc.balanceOf(exchangeRouter.address),
        await usdj.balanceOf(exchangeRouter.address),
        await tusd.balanceOf(exchangeRouter.address),
        await usdt.balanceOf(exchangeRouter.address),
        await usdt.balanceOf(receiver),
      ];
      const amountsOut = result.logs[0].args.amountsOut.map(function (x) {
        return x.toString();
      });
      let expectOut = [
        toBN(amount).toString(),
        '997',
        '997',
        '1000',
        '997',
        '994',
      ];
      expect(amountsOut).to.have.lengthOf(expectOut.length);
      expect(amountsOut).to.have.ordered.members(expectOut);
      // only-test const gas = gasUsed(result.receipt);
      expectOut = [
        // only-test amount.neg().sub(gas).toString(),
        '0',
        '0',
        '0',
        '0',
        '0',
        '994',
      ];
      expect(
        balanceAfter.map(function (x, i) {
          return x.sub(balanceBefore[i]).toString();
        }),
      ).to.have.ordered.members(expectOut);
    });
    it('token2token', async () => {
      await usdc.mint(exchangeRouter.address, 1000000);
      const amount = 1000000;
      const path = [usdc.address, usdj.address, tusd.address, usdt.address];
      await mockV1Token(usdc, [amount * 0.997]);
      await mockV1Token(usdj, [amount]);
      await mockV1Token(tusd, [amount * 0.997]);
      await mockV1Token(usdt, [amount * 0.997 * 0.997]);
      const balanceBefore = [
        await usdc.balanceOf(exchangeRouter.address),
        await usdj.balanceOf(exchangeRouter.address),
        await tusd.balanceOf(exchangeRouter.address),
        await usdt.balanceOf(exchangeRouter.address),
        await usdt.balanceOf(receiver),
      ];
      const result = await exchangeRouter.swapExactTokensForTokensV1(
        amount,
        1,
        path,
        receiver,
        infiniteTime,
      );
      const balanceAfter = [
        await usdc.balanceOf(exchangeRouter.address),
        await usdj.balanceOf(exchangeRouter.address),
        await tusd.balanceOf(exchangeRouter.address),
        await usdt.balanceOf(exchangeRouter.address),
        await usdt.balanceOf(receiver),
      ];
      const amountsOut = result.logs[0].args.amountsOut.map(function (x) {
        return x.toNumber();
      });
      let expectOut = [amount, amount, amount * 0.997, amount * 0.997 * 0.997];
      expect(amountsOut).to.have.lengthOf(expectOut.length);
      expect(amountsOut).to.have.ordered.members(expectOut);
      expectOut = [-amount, 0, 0, 0, amount * 0.997 * 0.997];
      expect(
        balanceAfter.map(function (x, i) {
          return x.sub(balanceBefore[i]).toNumber();
        }),
      ).to.have.ordered.members(expectOut);
    });
  });

  describe('#swapExactTokensForTokensV2', () => {
    it('invalid path', async () => {
      await exchangeRouter
        .swapExactTokensForTokensV2(1, 1, [], receiver, infiniteTime)
        .should.be.rejectedWith('INVALID_PATH_SLICE');
    });
    it('trx->wtrx->usdj->tusd->wtrx->trx', async () => {
      const amount = web3.utils.toWei(toBN(1), 'ether');
      const path = [
        zeroAddress,
        weth.address,
        usdj.address,
        tusd.address,
        weth.address,
        zeroAddress,
      ];
      const weiOut = amount.mul(toBN(997)).mul(toBN(997)).div(toBN(1000000));
      await v2Router.setTokenOut(['1000', '997', weiOut.toString()]);
      const balanceBefore = [
        // only-test await web3.eth.getBalance(sender).then(async (x) => {
        // only-test   return toBN(x);
        // only-test }),
        await web3.eth.getBalance(v2Router.address).then(async (x) => {
          return toBN(x);
        }),
        await usdc.balanceOf(v2Router.address),
        await usdj.balanceOf(v2Router.address),
        await tusd.balanceOf(v2Router.address),
        await web3.eth.getBalance(receiver).then(async (x) => {
          return toBN(x);
        }),
      ];
      const result = await exchangeRouter.swapExactTokensForTokensV2(
        amount,
        1,
        path,
        receiver,
        infiniteTime,
        {
          from: sender,
          value: amount,
        },
      );
      const balanceAfter = [
        // only-test await web3.eth.getBalance(sender).then(async (x) => {
        // only-test   return toBN(x);
        // only-test }),
        await web3.eth.getBalance(v2Router.address).then(async (x) => {
          return toBN(x);
        }),
        await usdc.balanceOf(v2Router.address),
        await usdj.balanceOf(v2Router.address),
        await tusd.balanceOf(v2Router.address),
        await web3.eth.getBalance(receiver).then(async (x) => {
          return toBN(x);
        }),
      ];
      const amountsOut = result.logs[0].args.amountsOut.map(function (x) {
        return x.toString();
      });
      let expectOut = [
        amount.toString(),
        amount.toString(),
        '1000',
        '997',
        weiOut.toString(),
        weiOut.toString(),
      ];
      expect(amountsOut).to.have.lengthOf(expectOut.length);
      expect(amountsOut).to.have.ordered.members(expectOut);
      // only-test const gas = gasUsed(result.receipt);
      expectOut = [
        // only-test amount.neg().sub(gas).toString(),
        //amount.sub(weiOut).toString(),
        '0',
        '0',
        '0',
        '0',
        weiOut.toString(),
      ];
      expect(
        balanceAfter.map(function (x, i) {
          return x.sub(balanceBefore[i]).toString();
        }),
      ).to.have.ordered.members(expectOut);
    });
    it('trx->wtrx->tusd->usdt', async () => {
      const amount = web3.utils.toWei(toBN(1), 'ether');
      const path = [zeroAddress, weth.address, tusd.address, usdt.address];
      await v2Router.setTokenOut(['997', '994']);
      const balanceBefore = [
        // only-test await web3.eth.getBalance(sender).then(async (x) => {
        // only-test   return toBN(x);
        // only-test }),
        await web3.eth.getBalance(v2Router.address).then(async (x) => {
          return toBN(x);
        }),
        await tusd.balanceOf(v2Router.address),
        await usdt.balanceOf(v2Router.address),
        await usdt.balanceOf(receiver),
      ];
      const result = await exchangeRouter.swapExactTokensForTokensV2(
        amount,
        1,
        path,
        receiver,
        infiniteTime,
        {
          from: sender,
          value: amount,
        },
      );
      const balanceAfter = [
        // only-test await web3.eth.getBalance(sender).then(async (x) => {
        // only-test   return toBN(x);
        // only-test }),
        await web3.eth.getBalance(v2Router.address).then(async (x) => {
          return toBN(x);
        }),
        await tusd.balanceOf(v2Router.address),
        await usdt.balanceOf(v2Router.address),
        await usdt.balanceOf(receiver),
      ];
      const amountsOut = result.logs[0].args.amountsOut.map(function (x) {
        return x.toString();
      });
      let expectOut = [amount.toString(), amount.toString(), '997', '994'];
      expect(amountsOut).to.have.lengthOf(expectOut.length);
      expect(amountsOut).to.have.ordered.members(expectOut);
      // only-test const gas = gasUsed(result.receipt);
      expectOut = [
        // only-test amount.neg().sub(gas).toString(),
        //amount.toString(),
        '0',
        '0',
        '-994',
        '994',
      ];
      expect(
        balanceAfter.map(function (x, i) {
          return x.sub(balanceBefore[i]).toString();
        }),
      ).to.have.ordered.members(expectOut);
    });
    // it('usdj->tusd->wtrx->trx', async () => {
    //   const amount = 1000000;
    //   await usdj.mint(exchangeRouter.address, amount);
    //   console.log("111111");
    //   const path = [usdj.address, tusd.address, weth.address, zeroAddress];
    //   const weiOut = web3.utils.toWei(toBN(1), 'ether');
    //   await v2Router.setTokenOut(['997', weiOut.toString()]);
    //   console.log("222222");
    //   const balanceBefore = [
    //     await usdj.balanceOf(exchangeRouter.address),
    //     await usdj.balanceOf(v2Router.address),
    //     await tusd.balanceOf(v2Router.address),
    //     await web3.eth.getBalance(v2Router.address).then(async (x) => {
    //       return toBN(x);
    //     }),
    //     await web3.eth.getBalance(receiver).then(async (x) => {
    //       return toBN(x);
    //     }),
    //   ];
    //   const result = await exchangeRouter.swapExactTokensForTokensV2(
    //     amount,
    //     1,
    //     path,
    //     receiver,
    //     infiniteTime
    //   );
    //   console.log("333333");
    //   const balanceAfter = [
    //     await usdj.balanceOf(exchangeRouter.address),
    //     await usdj.balanceOf(v2Router.address),
    //     await tusd.balanceOf(v2Router.address),
    //     await web3.eth.getBalance(v2Router.address).then(async (x) => {
    //       return toBN(x);
    //     }),
    //     await web3.eth.getBalance(receiver).then(async (x) => {
    //       return toBN(x);
    //     }),
    //   ];
    //   const amountsOut = result.logs[0].args.amountsOut.map(function (x) {
    //     return x.toString();
    //   });
    //   let expectOut = [
    //     toBN(amount).toString(),
    //     '997',
    //     weiOut.toString(),
    //     weiOut.toString(),
    //   ];
    //   expect(amountsOut).to.have.lengthOf(expectOut.length);
    //   expect(amountsOut).to.have.ordered.members(expectOut);
    //   expectOut = [
    //     toBN(-amount).toString(),
    //     toBN(amount).toString(),
    //     '0',
    //     weiOut.neg().toString(),
    //     weiOut.toString(),
    //   ];
    //   expect(
    //     balanceAfter.map(function (x, i) {
    //       return x.sub(balanceBefore[i]).toString();
    //     }),
    //   ).to.have.ordered.members(expectOut);
    // });
  });

  describe('#transferOwnership', () => {
    it('error', async () => {
      await exchangeRouter
        .transferOwnership(receiver, { from: receiver })
        .should.be.rejectedWith('Permission denied, not an owner');
    });
    it('success', async () => {
      const owner = await exchangeRouter.owner();
      await exchangeRouter.transferOwnership(receiver, { from: owner });
      await exchangeRouter.transferOwnership(owner, { from: receiver });
    });
  });

  describe('#transferAdminship', () => {
    it('error', async () => {
      await exchangeRouter
        .transferAdminship(receiver, { from: receiver })
        .should.be.rejectedWith('Permission denied, not an admin');
    });
    it('success', async () => {
      const admin = await exchangeRouter.admin();
      await exchangeRouter.transferAdminship(receiver, { from: admin });
      await exchangeRouter.transferAdminship(admin, { from: receiver });
    });
  });

  describe('#addPool', () => {
    it('no permission', async () => {
      await exchangeRouter
        .addPool('usdd2pool', usdd2Pool.address, [usdd.address, usdt.address], {
          from: receiver,
        })
        .should.be.rejectedWith('Permission denied, not an owner');
    });
    it('pool exist', async () => {
      const owner = await exchangeRouter.owner();
      await exchangeRouter
        .addPool(
          'old3pool',
          old3pool.address,
          [usdj.address, tusd.address, usdt.address],
          { from: owner },
        )
        .should.be.rejectedWith('pool exist');
    });
    it('invalid args', async () => {
      const owner = await exchangeRouter.owner();
      await exchangeRouter
        .addPool('usdd2pool', usdd2Pool.address, [usdd.address], {
          from: owner,
        })
        .should.be.rejectedWith('at least 2 tokens');
    });
  });

  describe('#addUsdcPool', () => {
    it('success', async () => {
      const owner = await exchangeRouter.owner();
      await exchangeRouter.addUsdcPool(
        'usdd2pool',
        usdd2Pool.address,
        [usdd.address, usdt.address],
        { from: owner },
      );
    });
  });

  describe('#addPsmPool', () => {
    it('invalid tokens', async () => {
      const owner = await exchangeRouter.owner();
      await exchangeRouter
        .addPsmPool(
          'usdd2pool',
          usdd2Pool.address,
          usdd2Pool.address,
          [usdc.address, usdt.address],
          { from: owner },
        )
        .should.be.rejectedWith('invalid tokens');
    });
    it('success', async () => {
      const owner = await exchangeRouter.owner();
      await exchangeRouter.addPsmPool(
        'usdd2pool',
        usdd2Pool.address,
        usdd2Pool.address,
        [usdd.address, usdt.address],
        { from: owner },
      );
    });
  });

  describe('#changePool', () => {
    it('no permission', async () => {
      await exchangeRouter
        .changePool(usdd2Pool.address, [usdd.address, usdt.address], {
          from: receiver,
        })
        .should.be.rejectedWith('Permission denied, not an admin');
    });
    it('pool not exist', async () => {
      const admin = await exchangeRouter.admin();
      await exchangeRouter
        .changePool(v1Factory.address, [usdd.address, usdt.address], {
          from: admin,
        })
        .should.be.rejectedWith('pool not exist');
    });
    it('invalid args', async () => {
      const admin = await exchangeRouter.admin();
      await exchangeRouter
        .changePool(usdcpool.address, [usdc.address], {
          from: admin,
        })
        .should.be.rejectedWith('at least 2 tokens');
    });
    it('success', async () => {
      const admin = await exchangeRouter.admin();
      await exchangeRouter.changePool(
        usdcpool.address,
        [usdc.address, usdj.address, tusd.address, usdt.address],
        {
          from: admin,
        },
      );
    });
  });

  // describe('#swapExactETHForTokens', () => {
  //   it('v1->v2->oldusdcpool', async () => {
  //     const amount = web3.utils.toWei(toBN(1), 'ether');
  //     const path = [
  //       zeroAddress,
  //       usdc.address,
  //       usdj.address,
  //       tusd.address,
  //       usdt.address,
  //     ];
  //     const version = ['v1', 'v2', 'oldusdcpool'];
  //     const versionLen = [3, 1, 1];
  //     await mockV1Token(usdc, [997, 1000]);
  //     await mockV1Token(usdj, [1000]);
  //     await v2Router.setTokenOut([1000]);
  //     await usdcpool.setTokenOut([994]);
  //     const balanceBefore = [
  //       // only-test await web3.eth.getBalance(sender).then(async (x) => {
  //       // only-test   return toBN(x);
  //       // only-test }),
  //       await usdt.balanceOf(receiver),
  //     ];
  //     const result = await exchangeRouter.swapExactETHForTokens(
  //       amount,
  //       1,
  //       path,
  //       version,
  //       versionLen,
  //       receiver,
  //       infiniteTime,
  //       {
  //         from: sender,
  //         value: amount,
  //       },
  //     );
  //     const balanceAfter = [
  //       // only-test await web3.eth.getBalance(sender).then(async (x) => {
  //       // only-test   return toBN(x);
  //       // only-test }),
  //       await usdt.balanceOf(receiver),
  //     ];
  //     const amountsOut = result.logs[0].args.amountsOut.map(function (x) {
  //       return x.toString();
  //     });
  //     let expectOut = [amount.toString(), '997', '1000', '1000', '994'];
  //     expect(amountsOut).to.have.lengthOf(expectOut.length);
  //     expect(amountsOut).to.have.ordered.members(expectOut);
  //     // only-test const gas = gasUsed(result.receipt);
  //     expectOut = [
  //       // only-test amount.neg().sub(gas).toString(),
  //       '994',
  //     ];
  //     expect(
  //       balanceAfter.map(function (x, i) {
  //         return x.sub(balanceBefore[i]).toString();
  //       }),
  //     ).to.have.ordered.members(expectOut);
  //   });

  //   it('v2->v1->oldusdcpool', async () => {
  //     const amount = web3.utils.toWei(toBN(1), 'ether');
  //     const path = [
  //       zeroAddress,
  //       weth.address,
  //       usdc.address,
  //       usdj.address,
  //       tusd.address,
  //       usdt.address,
  //     ];
  //     const version = ['v2', 'v1', 'oldusdcpool'];
  //     const versionLen = [3, 2, 1];
  //     await v2Router.setTokenOut([1000]);
  //     await mockV1Token(usdc, [997]);
  //     await mockV1Token(usdj, [1000]);
  //     await mockV1Token(tusd, [997]);
  //     await usdcpool.setTokenOut([994]);
  //     const balanceBefore = [
  //       // only-test await web3.eth.getBalance(sender).then(async (x) => {
  //       // only-test   return toBN(x);
  //       // only-test }),
  //       await usdt.balanceOf(receiver),
  //     ];
  //     const result = await exchangeRouter.swapExactETHForTokens(
  //       amount,
  //       1,
  //       path,
  //       version,
  //       versionLen,
  //       receiver,
  //       infiniteTime,
  //       {
  //         from: sender,
  //         value: amount,
  //       },
  //     );
  //     const balanceAfter = [
  //       // only-test await web3.eth.getBalance(sender).then(async (x) => {
  //       // only-test   return toBN(x);
  //       // only-test }),
  //       await usdt.balanceOf(receiver),
  //     ];
  //     const amountsOut = result.logs[0].args.amountsOut.map(function (x) {
  //       return x.toString();
  //     });
  //     let expectOut = [
  //       amount.toString(),
  //       amount.toString(),
  //       '1000',
  //       '1000',
  //       '997',
  //       '994',
  //     ];
  //     expect(amountsOut).to.have.lengthOf(expectOut.length);
  //     expect(amountsOut).to.have.ordered.members(expectOut);
  //     // only-test const gas = gasUsed(result.receipt);
  //     expectOut = [
  //       // only-test amount.neg().sub(gas).toString(),
  //       '994',
  //     ];
  //     expect(
  //       balanceAfter.map(function (x, i) {
  //         return x.sub(balanceBefore[i]).toString();
  //       }),
  //     ).to.have.ordered.members(expectOut);
  //   });
  // });

  // describe('#swapExactTokensForTokens', () => {
  //   it('oldusdcpool->v1->v2', async () => {
  //     const path = [usdc.address, usdj.address, tusd.address, usdt.address];
  //     const version = ['oldusdcpool', 'v1', 'v2'];
  //     const versionLen = [2, 1, 1];
  //     const amount = 1000000;
  //     await usdc.mint(sender, amount);
  //     await usdc.approve(exchangeRouter.address, amount, { from: sender });
  //     await usdcpool.setTokenOut([amount * 0.997]);
  //     await mockV1Token(usdj, [amount * 0.997]);
  //     await mockV1Token(tusd, [amount]);
  //     await v2Router.setTokenOut([amount * 0.997 * 0.997]);
  //     const balanceBefore = [
  //       await usdc.balanceOf(sender),
  //       await usdt.balanceOf(receiver),
  //     ];
  //     const result = await exchangeRouter.swapExactTokensForTokens(
  //       amount,
  //       1,
  //       path,
  //       version,
  //       versionLen,
  //       receiver,
  //       infiniteTime,
  //       { from: sender },
  //     );
  //     const balanceAfter = [
  //       await usdc.balanceOf(sender),
  //       await usdt.balanceOf(receiver),
  //     ];
  //     const amountsOut = result.logs[0].args.amountsOut.map(function (x) {
  //       return x.toNumber();
  //     });
  //     let expectOut = [amount, amount * 0.997, amount, amount * 0.997 * 0.997];
  //     expect(amountsOut).to.have.lengthOf(expectOut.length);
  //     expect(amountsOut).to.have.ordered.members(expectOut);
  //     expectOut = [-amount, amount * 0.997 * 0.997];
  //     expect(
  //       balanceAfter.map(function (x, i) {
  //         return x.sub(balanceBefore[i]).toNumber();
  //       }),
  //     ).to.have.ordered.members(expectOut);
  //   });
  //   it('v1->v2->oldusdcpool', async () => {
  //     const path = [usdc.address, usdj.address, tusd.address, usdt.address];
  //     const version = ['v1', 'v2', 'oldusdcpool'];
  //     const versionLen = [2, 1, 1];
  //     const amount = 1000000;
  //     await usdc.mint(sender, amount);
  //     await usdc.approve(exchangeRouter.address, amount, { from: sender });
  //     await mockV1Token(usdc, [amount]);
  //     await mockV1Token(usdj, [amount * 0.997]);
  //     await v2Router.setTokenOut([amount * 0.997 * 0.997]);
  //     await usdcpool.setTokenOut([amount * 0.997]);
  //     const balanceBefore = [
  //       await usdc.balanceOf(sender),
  //       await usdt.balanceOf(receiver),
  //     ];
  //     const result = await exchangeRouter.swapExactTokensForTokens(
  //       amount,
  //       1,
  //       path,
  //       version,
  //       versionLen,
  //       receiver,
  //       infiniteTime,
  //     );
  //     const balanceAfter = [
  //       await usdc.balanceOf(sender),
  //       await usdt.balanceOf(receiver),
  //     ];
  //     const amountsOut = result.logs[0].args.amountsOut.map(function (x) {
  //       return x.toNumber();
  //     });
  //     let expectOut = [
  //       amount,
  //       amount * 0.997,
  //       amount * 0.997 * 0.997,
  //       amount * 0.997,
  //     ];
  //     expect(amountsOut).to.have.lengthOf(expectOut.length);
  //     expect(amountsOut).to.have.ordered.members(expectOut);
  //     expectOut = [-amount, amount * 0.997];
  //     expect(
  //       balanceAfter.map(function (x, i) {
  //         return x.sub(balanceBefore[i]).toNumber();
  //       }),
  //     ).to.have.ordered.members(expectOut);
  //   });
  // });

  afterEach(async () => {
    await revertSnapshot(snapshotId.result);
    // eslint-disable-next-line require-atomic-updates
    snapshotId = await takeSnapshot();
  });
});
