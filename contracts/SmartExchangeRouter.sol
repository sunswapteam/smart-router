// SPDX-License-Identifier: MIT
pragma solidity >=0.6.8 <0.9.0;
pragma experimental ABIEncoderV2;

import "./interfaces/IERC20.sol";
import "./interfaces/IPoolPsm.sol";
import "./interfaces/IPoolStable.sol";
import "./interfaces/IRouterV1.sol";
import "./interfaces/IRouterV2.sol";
import "./helpers/ReentrancyGuard.sol";
import "./helpers/SafeMath.sol";
import "./helpers/TransferHelper.sol";

contract SmartExchangeRouter is ReentrancyGuard {
  using SafeMath for uint256;

  struct Context {
    bytes32 version;
    uint256 len;
    uint256 path_i;
    uint256 offset;
    uint256 amountIn;
    uint256 amountOutMin;
    uint256 deadline;
    address[] pathSlice;
    uint256[] amountsOutSlice;
    address recipient;
  }

  struct TransactionResult {
    bool isSuccess;
    bytes data;
  }

  /**
   * Events & Variables
   */
  event SwapExactETHForTokens(address indexed buyer,
                              uint256 indexed amountIn,
                              uint256[] amountsOut);
  event SwapExactTokensForTokens(address indexed buyer,
                                 uint256 indexed amountIn,
                                 uint256[] amountsOut);
  event TransferOwnership(address indexed originOwner,
                          address indexed newOwner);
  event TransferAdminship(address indexed originOwner,
                          address indexed newOwner);
  event AddPool(address indexed owner,
                address indexed pool,
                address[] tokens);
  event ChangePool(address indexed admin,
                   address indexed pool,
                   address[] tokens);

  address public owner; // public for get method
  address public admin;
  address public v1Factory;
  address public v2Router;
  address public psmUsdd;
  mapping(address => mapping(address => bool)) tokenApprovedPool;
  mapping(address => bool) existPools;
  mapping(address => mapping(address => uint128)) poolToken;
  mapping(string => address) stablePools;
  mapping(string => bool) poolVersionUsdc;
  mapping(string => bool) poolVersionPsm;
  mapping(address=> uint256) psmRelativeDecimals;

  uint256 constant maxNum = type(uint256).max;
  // TODO: hard code this to saving gas
  bytes32 constant poolVersionV1 = keccak256(abi.encodePacked("v1"));
  bytes32 constant poolVersionV2 = keccak256(abi.encodePacked("v2"));

  receive() external payable {}
  fallback() external payable {}

  constructor(
    address _old3pool,
    address _usdcPool,
    address _v2Router,
    address _v1Foctroy,
    address _usdt,
    address _usdj,
    address _tusd,
    address _usdc,
    address _psmUsdd
  ) public {
    owner = msg.sender;
    admin = msg.sender;
    v1Factory = _v1Foctroy;
    v2Router = _v2Router;
    psmUsdd = _psmUsdd;

    address[] memory usdcTokens = new address[](4);
    usdcTokens[0] = _usdc;
    usdcTokens[1] = _usdj;
    usdcTokens[2] = _tusd;
    usdcTokens[3] = _usdt;
    addUsdcPool("oldusdcpool", _usdcPool, usdcTokens);
    address[] memory old3PoolTokens = new address[](3);
    old3PoolTokens[0] = _usdj;
    old3PoolTokens[1] = _tusd;
    old3PoolTokens[2] = _usdt;
    addPool("old3pool", _old3pool, old3PoolTokens);
  }

  modifier onlyOwner {
      require(msg.sender == owner, "Permission denied, not an owner");
      _;
  }

  modifier onlyAdmin {
      require(msg.sender == admin, "Permission denied, not an admin");
      _;
  }

  /**
   * external functions
   */
  function transferOwnership(address newOwner) external onlyOwner {
      owner = newOwner;
      emit TransferOwnership(owner, newOwner);
  }

  function transferAdminship(address newAdmin) external onlyAdmin {
      admin = newAdmin;
      emit TransferAdminship(admin, newAdmin);
  }

  function retrieve(address token, address to, uint256 amount)
      external onlyOwner {
    if (token == address(0)) {
      TransferHelper.safeTransferETH(to, amount);
    } else {
      require(TransferHelper.safeTransfer(token, to, amount), "Transfer failed");
    }
  }

  function addPool(string memory poolVersion,
                   address pool,
                   address[] memory tokens) public onlyOwner {
    require(existPools[pool] == false, "pool exist");
    require(tokens.length > 1, "at least 2 tokens");
    for (uint128 i = 0; i < tokens.length; i++){
        poolToken[pool][tokens[i]] = i;
        _approveToken(tokens[i], pool);
    }
    stablePools[poolVersion] = pool;
    existPools[pool] = true;
    emit AddPool(owner, pool, tokens);
  }

  function addUsdcPool(string memory poolVersion,
                       address pool,
                       address[] memory tokens) public onlyOwner {
    addPool(poolVersion, pool, tokens);
    poolVersionUsdc[poolVersion] = true;
  }

  function addPsmPool(string memory poolVersion,
                       address pool,
                       address gemJoin,
                       address[] memory tokens) public onlyOwner {
    require(existPools[pool] == false, "pool exist");
    require(tokens.length == 2 && (tokens[0] == psmUsdd || tokens[1] == psmUsdd),
            "invalid tokens");
    uint256 usddDecimals = 1;
    uint256 gemDecimals = 1;
    for (uint128 i = 0; i < tokens.length; i++){
        poolToken[pool][tokens[i]] = i;
        if (tokens[i] == psmUsdd) {
          _approveToken(tokens[i], pool);
          usddDecimals = erc20(tokens[i]).decimals();
        }
        else {
          _approveToken(tokens[i], gemJoin);
          gemDecimals = erc20(tokens[i]).decimals();
        }
    }
    psmRelativeDecimals[pool] = 10 ** (usddDecimals - gemDecimals);
    stablePools[poolVersion] = pool;
    existPools[pool] = true;
    poolVersionPsm[poolVersion] = true;
    emit AddPool(owner, pool, tokens);
  }

  function isUsdcPool(string memory poolVersion) public view returns(bool) {
    return poolVersionUsdc[poolVersion];
  }

  function isPsmPool(string memory poolVersion) public view returns(bool) {
    return poolVersionPsm[poolVersion];
  }

  function changePool(address pool,
                      address[] calldata tokens) external onlyAdmin {
    require(existPools[pool], "pool not exist");
    require(tokens.length > 1, "at least 2 tokens");
    for (uint128 i = 0; i< tokens.length; i++){
      poolToken[pool][tokens[i]] = i;
      _approveToken(tokens[i], pool);
    }
    emit ChangePool(owner, pool, tokens);
  }

  /**
   * @dev Exchange function for converting TRX to Token in a specified path.
   * @param amountIn Amount of TRX to be solded.
   * @param amountOutMin Minimal amount of Token expected.
   * @param path A specified exchange path from TRX to token.
   * @param poolVersion List of pool where tokens in path belongs to.
   * @param versionLen List of token num in each pool.
   * @param to Address where token transfer to.
   * @param deadline Time after which this transaction can no longer be executed.
   * @return amountsOut Amount of Tokens bought corresponed to path.
   */
  function swapExactETHForTokens(uint256 amountIn,
                                 uint256 amountOutMin,
                                 address[] calldata path,
                                 string[] calldata poolVersion,
                                 uint256[] calldata versionLen,
                                 address to,
                                 uint256 deadline)
      external nonReentrant payable returns(uint256[] memory amountsOut) {
    require(msg.value >= amountIn, "INSUFFIENT_TRX");
    require(poolVersion.length == versionLen.length && poolVersion.length > 0,
            "INVALID_POOL_VERSION.");
    require(path.length > 0, "INVALID_PATH");
    require(path[0] == address(0), "INVALID_PATH");
    amountsOut = new uint256[](path.length);
    Context memory context;
    context.path_i = 0;
    context.deadline = deadline;
    for (uint256 i = 0; i < poolVersion.length; i++) {
      context.version = keccak256(abi.encodePacked(poolVersion[i]));
      context.len = versionLen[i];
      require(context.len > 0 && context.path_i + context.len <= path.length,
              "INVALID_VERSION_LEN");
      context.offset = i == 0 ? 0 : 1;
      context.amountIn = i == 0 ? amountIn : amountsOut[context.path_i - 1];
      context.amountOutMin = i + 1 == poolVersion.length ? amountOutMin : 1;
      context.recipient = i + 1 == poolVersion.length ? to : address(this);
      if (context.version == poolVersionV2) {
        // v2 router
        context.pathSlice = _constructPathSlice(path,
                                                context.path_i - context.offset,
                                                context.len + context.offset);
        context.amountsOutSlice = _swapExactTokensForTokensV2(context);
        for (uint256 j = 0; j < context.len; j++) {
          amountsOut[context.path_i] = context.amountsOutSlice[j + context.offset];
          context.path_i++;
        }
      } else if (context.version == poolVersionV1) {
        // v1 factory
        context.pathSlice = _constructPathSlice(path,
                                                context.path_i - context.offset,
                                                context.len + context.offset);
        context.amountsOutSlice = _swapExactTokensForTokensV1(context);
        for (uint256 j = 0; j < context.len; j++) {
          amountsOut[context.path_i] = context.amountsOutSlice[j + context.offset];
          context.path_i++;
        }
      } else {
        // stable pool
        require(i > 0, "stablePool not support token TRX");
        context.pathSlice = _constructPathSlice(path,
                                                context.path_i - context.offset,
                                                context.len + context.offset);
        context.amountsOutSlice = _stablePoolExchange(poolVersion[i],
                                                      context.pathSlice,
                                                      context.amountIn,
                                                      context.amountOutMin);
        for (uint256 j = 0; j < context.len; j++) {
          amountsOut[context.path_i] = context.amountsOutSlice[j + 1];
          context.path_i++;
        }
        if (context.path_i == path.length) {
          amountsOut[context.path_i - 1] = _tokenSafeTransfer(
            path[context.path_i - 1],
            context.recipient,
            amountsOut[context.path_i - 1]);
          // double check
          require(amountsOut[context.path_i - 1] >= context.amountOutMin,
                  "amountOutMin not satisfied.");
        }
      }
    }
    assert(context.path_i == path.length);
    emit SwapExactETHForTokens(msg.sender, amountIn, amountsOut);
  }

  /**
   * @dev Exchange function for converting Token to Token in a specified path.
   * @param amountIn Amount of Token to be solded.
   * @param amountOutMin Minimal amount of Token expected.
   * @param path A specified exchange path from Token to token.
   * @param poolVersion List of pool where tokens in path belongs to.
   * @param versionLen List of token num in each pool.
   * @param to Address where token transfer to.
   * @param deadline Time after which this transaction can no longer be executed.
   * @return amountsOut Amount of Tokens bought corresponed to path.
   */
  function swapExactTokensForTokens(uint256 amountIn,
                                    uint256 amountOutMin,
                                    address[] calldata path,
                                    string[] calldata poolVersion,
                                    uint256[] calldata versionLen,
                                    address to,
                                    uint256 deadline)
      external nonReentrant returns(uint256[] memory amountsOut) {
    require(poolVersion.length == versionLen.length && poolVersion.length > 0,
            "INVALID_POOL_VERSION.");
    require(path.length > 1, "INVALID_PATH");
    require(path[0] != address(0), "INVALID_PATH");
    amountsOut = new uint256[](path.length);
    amountsOut[0] = _tokenSafeTransferFrom(
      path[0], msg.sender, address(this), amountIn);
    Context memory context;
    context.path_i = 1;
    context.deadline = deadline;
    for (uint256 i = 0; i < poolVersion.length; i++) {
      context.version = keccak256(abi.encodePacked(poolVersion[i]));
      context.len = i == 0 ? versionLen[i] - 1 : versionLen[i];
      require(context.len > 0 && context.path_i + context.len <= path.length,
              "INVALID_VERSION_LEN");
      context.amountIn = amountsOut[context.path_i - 1];
      // context.offset = 1;
      context.amountOutMin = i + 1 == poolVersion.length ? amountOutMin : 1;
      context.recipient = i + 1 == poolVersion.length ? to : address(this);
      if (context.version == poolVersionV2) {
        // v2 router
        context.pathSlice = _constructPathSlice(path,
                                                context.path_i - 1,
                                                context.len + 1);
        context.amountsOutSlice = _swapExactTokensForTokensV2(context);
        for (uint256 j = 0; j < context.len; j++) {
          amountsOut[context.path_i] = context.amountsOutSlice[j + 1];
          context.path_i++;
        }
      } else if (context.version == poolVersionV1) {
        // v1 factory
        context.pathSlice = _constructPathSlice(path,
                                                context.path_i - 1,
                                                context.len + 1);
        context.amountsOutSlice = _swapExactTokensForTokensV1(context);
        for (uint256 j = 0; j < context.len; j++) {
          amountsOut[context.path_i] = context.amountsOutSlice[j + 1];
          context.path_i++;
        }
      } else {
        // stable pool
        context.pathSlice = _constructPathSlice(path,
                                                context.path_i - 1,
                                                context.len + 1);
        context.amountsOutSlice = _stablePoolExchange(poolVersion[i],
                                                      context.pathSlice,
                                                      context.amountIn,
                                                      context.amountOutMin);
        for (uint256 j = 0; j < context.len; j++) {
          amountsOut[context.path_i] = context.amountsOutSlice[j + 1];
          context.path_i++;
        }
        if (context.path_i == path.length) {
          amountsOut[context.path_i - 1] = _tokenSafeTransfer(
            path[context.path_i - 1],
            context.recipient,
            amountsOut[context.path_i - 1]);
          // double check
          require(amountsOut[context.path_i - 1] >= context.amountOutMin,
                  "amountOutMin not satisfied.");
        }
      }
    }
    assert(context.path_i == path.length);
    emit SwapExactTokensForTokens(msg.sender, amountIn, amountsOut);
  }

  /**
   * internal functions
   */
  function _approveToken(address token, address pool) internal {
    if (tokenApprovedPool[token][pool] == false) {
      require(TransferHelper.safeApprove(token, pool, maxNum), "Approve failed");
      tokenApprovedPool[token][pool] = true;
    }
  }

  function _constructPathSlice(address[] memory path, uint256 pos, uint256 len)
      internal pure returns(address[] memory pathOut) {
    require(len > 1 && pos + len <= path.length, "INVALID_ARGS");
    pathOut = new address[](len);
    for (uint256 j = 0; j < len; j++) {
      pathOut[j] = path[pos + j];
    }
  }

  function _tokenSafeTransferFrom(address token,
                                  address from,
                                  address to,
                                  uint256 value) internal returns(uint256) {
    require(from != to, "INVALID_ARGS");
    uint256 balanceBefore = erc20(token).balanceOf(to);
    require(TransferHelper.safeTransferFrom(token, from, to, value),
            "Transfer failed");
    uint256 balanceAfter = erc20(token).balanceOf(to);
    return balanceAfter - balanceBefore;
  }

  function _tokenSafeTransfer(address token, address to, uint256 value)
      internal virtual returns(uint256) {
    require(to != address(this) && to != address(0), "INVALID_ARGS");
    uint256 balanceBefore = erc20(token).balanceOf(to);
    require(TransferHelper.safeTransfer(token, to, value), "Transfer failed");
    uint256 balanceAfter = erc20(token).balanceOf(to);
    return balanceAfter - balanceBefore;
  }

  /**
   * stablePool functions
   */
  function _stablePoolExchange(string memory poolVersion,
                               address[] memory path,
                               uint256 amountIn,
                               uint256 amountOutMin)
      internal returns(uint256[] memory amountsOut) {
    address pool = stablePools[poolVersion];
    require(pool != address(0), "pool not exist");
    require(path.length > 1, "INVALID_PATH_SLICE");

    amountsOut = new uint256[](path.length);
    amountsOut[0] = amountIn;
    for (uint256 i = 1; i < path.length; i++) {
      uint128 tokenIdIn = poolToken[pool][path[i - 1]];
      uint128 tokenIdOut = poolToken[pool][path[i]];
      require(tokenIdIn != tokenIdOut, "INVALID_PATH_SLICE");
      uint256 amountMin = i + 1 == path.length ? amountOutMin : 1;
      uint256 balanceBefore = erc20(path[i]).balanceOf(address(this));
      if (isUsdcPool(poolVersion)) {
          usdcPoolF(pool).exchange_underlying(int128(tokenIdIn),
                                              int128(tokenIdOut),
                                              amountsOut[i - 1],
                                              amountMin);
      } else if (isPsmPool(poolVersion)) {
        if (path[i - 1] == psmUsdd) {
          // TODO: how to deal with leak usdd ?
          psm(pool).buyGem(address(this),
                           amountsOut[i - 1] / psmRelativeDecimals[pool]);
        } else if (path[i] == psmUsdd) {
          psm(pool).sellGem(address(this), amountsOut[i - 1]);
        } else {
          revert('INVALID_PSM_TOKEN');
        }
      } else {
          poolStable(pool).exchange(tokenIdIn,
                                    tokenIdOut,
                                    amountsOut[i - 1],
                                    amountMin);
      }
      uint256 balanceAfter = erc20(path[i]).balanceOf(address(this));
      amountsOut[i] = balanceAfter - balanceBefore;
      require(amountsOut[i] >= amountMin, "amountMin not satisfied");
    }
  }

  /**
   * v1 functions
   */
  function _trxToTokenTransferInput(address token,
                                    uint256 amountIn,
                                    uint256 amountOutMin,
                                    address recipient,
                                    uint256 deadline)
      internal returns(uint256 amountOut) {
      address payable exchange =v1(v1Factory).getExchange(token);
      require(exchange != address(0), "exchanger not found");

      TransactionResult memory result;
      (result.isSuccess, result.data) =
        TransferHelper.executeTransaction(
          exchange,
          amountIn,
          "trxToTokenTransferInput(uint256,uint256,address)",
          abi.encode(amountOutMin, deadline, recipient));
      require(result.isSuccess, "Transaction failed.");
      amountOut = abi.decode(result.data, (uint256));
  }

  function _tokenToTrxTransferInput(address token,
                                    uint256 amountIn,
                                    uint256 amountOutMin,
                                    address recipient,
                                    uint256 deadline)
      internal returns(uint256 amountOut) {
      address payable exchange =v1(v1Factory).getExchange(token);
      require(exchange != address(0), "exchanger not found");
      _approveToken(token, exchange);

      TransactionResult memory result;
      (result.isSuccess, result.data) =
        TransferHelper.executeTransaction(
          exchange,
          0,
          "tokenToTrxTransferInput(uint256,uint256,uint256,address)",
          abi.encode(amountIn, amountOutMin, deadline, recipient));
      require(result.isSuccess, "Transaction failed.");
      amountOut = abi.decode(result.data, (uint256));
  }

  function _tokenToTokenTransferInput(address tokenIn,
                                      address tokenOut,
                                      Context memory context)
      internal returns(uint256 amountOut) {
    address payable exchange = v1(v1Factory).getExchange(tokenIn);
    require(exchange != address(0), "exchanger not found");
    _approveToken(tokenIn, exchange);
    TransactionResult memory result;
    (result.isSuccess, result.data) =
      TransferHelper.executeTransaction(
        exchange,
        0,
        "tokenToTokenTransferInput(uint256,uint256,uint256,uint256,address,address)",
        abi.encode(context.amountIn,
                   context.amountOutMin,
                   1,
                   context.deadline,
                   context.recipient,
                   tokenOut));
    require(result.isSuccess, "Transaction failed.");
    amountOut = abi.decode(result.data, (uint256));
  }

  function _swapExactTokensForTokensV1(Context memory context)
      internal returns(uint256[] memory amountsOut) {
    require(context.pathSlice.length > 1, "INVALID_PATH_SLICE");
    amountsOut = new uint256[](context.pathSlice.length);
    amountsOut[0] = context.amountIn;
    for (uint256 i = 1; i < context.pathSlice.length; i++) {
      require(context.pathSlice[i - 1] != context.pathSlice[i],
              "INVALID_PATH_SLICE");
      Context memory ctx;
      ctx.amountIn = amountsOut[i - 1];
      ctx.amountOutMin =
        i + 1 == context.pathSlice.length ? context.amountOutMin
                                          : 1;
      ctx.recipient = i + 1 == context.pathSlice.length ? context.recipient
                                                        : address(this);
      ctx.deadline = context.deadline;
      if (context.pathSlice[i - 1] == address(0)) {
        amountsOut[i] = _trxToTokenTransferInput(context.pathSlice[i],
                                                 ctx.amountIn,
                                                 ctx.amountOutMin,
                                                 ctx.recipient,
                                                 ctx.deadline);
      } else if (context.pathSlice[i] == address(0)) {
        amountsOut[i] = _tokenToTrxTransferInput(context.pathSlice[i - 1],
                                                 ctx.amountIn,
                                                 ctx.amountOutMin,
                                                 ctx.recipient,
                                                 ctx.deadline);
      } else {
        amountsOut[i] = _tokenToTokenTransferInput(context.pathSlice[i - 1],
                                                   context.pathSlice[i],
                                                   ctx);
      }
    }
  }

  /**
   * v2 functions
   */
  function _swapExactTokensForTokens(Context memory context)
      internal returns (uint256[] memory amounts) {
    require(context.pathSlice.length > 1, "INVALID_PATH_SLICE");
    _approveToken(context.pathSlice[0], v2Router);
    amounts = v2(v2Router).swapExactTokensForTokens(context.amountIn,
                                                    context.amountOutMin,
                                                    context.pathSlice,
                                                    context.recipient,
                                                    context.deadline);
  }

  function _swapExactETHForTokens(Context memory context)
      internal returns (uint256[] memory amounts) {
    // trx->wtrx->tokens
    require(context.pathSlice.length > 2, "INVALID_PATH_SLICE");

    amounts = new uint256[](context.pathSlice.length);
    amounts[0] = context.amountIn;
    // routerV2 will deposit trx for wtrx, shift path to wtrx->trokens
    address[] memory pathSlice = _constructPathSlice(
      context.pathSlice, 1, context.pathSlice.length - 1);
    uint256[] memory amountsOutSlice = v2(v2Router)
      .swapExactETHForTokens{value: amounts[0]}(context.amountOutMin,
                                                pathSlice,
                                                context.recipient,
                                                context.deadline);
    // merge amounts out
    for (uint256 i = 0; i < amountsOutSlice.length; i++) {
      amounts[i + 1] = amountsOutSlice[i];
    }
  }

  function _swapExactTokensForETH(Context memory context)
      internal returns (uint256[] memory amounts) {
    // tokens->wtrx->trx
    require(context.pathSlice.length > 1, "INVALID_PATH_SLICE");
    _approveToken(context.pathSlice[0], v2Router);

    amounts = new uint256[](context.pathSlice.length);
    // routerV2 will withdraw wtrx for trx, truncate path to tokens->wtrx
    address[] memory pathSlice = _constructPathSlice(
      context.pathSlice, 0, context.pathSlice.length - 1);
    uint256[] memory amountsOutSlice = v2(v2Router)
      .swapExactTokensForETH(context.amountIn,
                             context.amountOutMin,
                             pathSlice,
                             context.recipient,
                             context.deadline);
    // copy amounts out
    for (uint256 i = 0; i < amountsOutSlice.length; i++) {
      amounts[i] = amountsOutSlice[i];
    }
    // amount trx = amount wtrx
    amounts[amounts.length - 1] = amounts[amounts.length - 2];
  }

  function _swapExactETHForETH(Context memory context)
      internal returns (uint256[] memory amounts) {
    // NOTIC(air.ye): in case of trx->wtrx->tokens->wtrx->trx
    require(context.pathSlice.length > 4, "INVALID_PATH_SLICE");
    amounts = new uint256[](context.pathSlice.length);
    amounts[0] = context.amountIn;
    Context memory ctx;
    ctx.path_i = 1;
    // invoke _swapExactETHForTokens costs more gas
    // since constructPathSlice and amountOutSlice would copy twice
    ctx.amountIn = amounts[0];
    ctx.amountOutMin = 1;
    ctx.pathSlice = _constructPathSlice(context.pathSlice, ctx.path_i, 2);
    ctx.recipient = address(this);
    ctx.deadline = context.deadline;
    ctx.amountsOutSlice = v2(v2Router)
      .swapExactETHForTokens{value: ctx.amountIn}(ctx.amountOutMin,
                                                  ctx.pathSlice,
                                                  ctx.recipient,
                                                  ctx.deadline);
    // merge amounts slice
    for (uint256 i = 0; i < ctx.amountsOutSlice.length; i++) {
      amounts[ctx.path_i] = ctx.amountsOutSlice[i];
      ctx.path_i++;
    }
    // invoke _swapExactTokensForETH costs more gas
    // since constructPathSlice and amountOutSlice would copy twice
    ctx.amountIn = amounts[ctx.path_i - 1];
    ctx.amountOutMin = context.amountOutMin;
    ctx.pathSlice = _constructPathSlice(context.pathSlice,
                                        ctx.path_i - 1,
                                        context.pathSlice.length - ctx.path_i);
    ctx.recipient = context.recipient;
    _approveToken(ctx.pathSlice[0], v2Router);
    ctx.amountsOutSlice = v2(v2Router).swapExactTokensForETH(ctx.amountIn,
                                                             ctx.amountOutMin,
                                                             ctx.pathSlice,
                                                             ctx.recipient,
                                                             ctx.deadline);
    // merge amounts slice
    for (uint256 i = 1; i < ctx.amountsOutSlice.length; i++) {
      amounts[ctx.path_i] = ctx.amountsOutSlice[i];
      ctx.path_i++;
    }
    // amount trx = amount wtrx
    require(ctx.path_i == amounts.length - 1, "this should't happen");
    amounts[ctx.path_i] = amounts[ctx.path_i - 1];
  }

  function _swapExactTokensForTokensV2(Context memory context)
      internal returns (uint256[] memory amounts) {
    require(context.pathSlice.length > 1, "INVALID_PATH_SLICE");
    address tokenIn = context.pathSlice[0];
    address tokenOut = context.pathSlice[context.pathSlice.length - 1];
    if (tokenIn == address(0)) {
      return tokenOut == address(0) ? _swapExactETHForETH(context)
                                    : _swapExactETHForTokens(context);
    } else if (tokenOut == address(0)) {
      return _swapExactTokensForETH(context);
    } else {
      return _swapExactTokensForTokens(context);
    }
  }
}
