// SPDX-License-Identifier: MIT
pragma solidity >=0.6.8 <0.9.0;
pragma experimental ABIEncoderV2;

import "./SmartExchangeRouter.sol";

contract SmartExchangeRouterTest is SmartExchangeRouter {

  event TokenSafeTransferFrom(address indexed token,
                              address indexed from,
                              address indexed to,
                              uint256 value);
  event StablePoolExchange(string indexed poolVersion,
                           address indexed tokenIn,
                           address indexed tokenOut,
                           uint256 amountIn,
                           uint256[] amountsOut);
  event TrxToTokenTransferInput(address indexed token,
                                address indexed buyer,
                                address indexed recipient,
                                uint256 amountIn,
                                uint256 amountOut);
  event TokenToTrxTransferInput(address indexed token,
                                address indexed buyer,
                                address indexed recipient,
                                uint256 amountIn,
                                uint256 amountOut);
  event TokenToTokenTransferInput(address indexed tokenIn,
                                  address indexed tokenOut,
                                  address indexed buyer,
                                  address recipient,
                                  uint256 amountIn,
                                  uint256 amountOut);
  event SwapExactTokensForTokensV1(address indexed tokenIn,
                                   address indexed tokenOut,
                                   address indexed buyer,
                                   address recipient,
                                   uint256 amountIn,
                                   uint256[] amountsOut);
  event SwapExactTokensForTokensV2(address indexed tokenIn,
                                   address indexed tokenOut,
                                   address indexed buyer,
                                   address recipient,
                                   uint256 amountIn,
                                   uint256[] amountsOut);
  event SwapExactInputV3( address indexed tokenIn,
                          address indexed tokenOut,
                          address indexed buyer,
                          address recipient,
                          uint256 amountIn,
                          uint256[] amountsOut);

  address usdt;

  constructor(
    address _v2Router,
    address _v3Router,
    address _v1Foctroy,
    address _usdd,
    address _wtrx,
    address _usdt
  ) public SmartExchangeRouter(_v2Router,
                               _v1Foctroy,
                               _usdd,
                               _v3Router,
                               _wtrx) {
    usdt = _usdt;
  }

  function constructPathSlice(address[] memory path, uint256 pos, uint256 len)
      public pure returns(address[] memory pathOut) {
    return _constructPathSlice(path, pos, len);
  }

  function constructFeesSlice(uint24[] memory fee, uint256 pos, uint256 len)
      public pure returns(uint24[] memory pathOut) {
    return _constructFeesSlice(fee, pos, len);
  }

  function tokenSafeTransferFrom(address token,
                                 address from,
                                 address to,
                                 uint256 value) public returns(uint256 amountOut) {
    amountOut = _tokenSafeTransferFrom(token, from, to, value);
    emit TokenSafeTransferFrom(token, from, to, amountOut);
  }

  function stablePoolExchange(string memory poolVersion,
                              address[] memory path,
                              uint256 amountIn,
                              uint256 amountOutMin)
      public returns(uint256[] memory amountsOut) {
    amountsOut = _stablePoolExchange(poolVersion, path, amountIn, amountOutMin);
    emit StablePoolExchange(poolVersion,
                            path[0],
                            path[path.length - 1],
                            amountIn,
                            amountsOut);
  }

  function trxToTokenTransferInput(address token,
                                   uint256 amountOutMin,
                                   address recipient,
                                   uint256 deadline)
      public payable returns(uint256 amountOut) {
    amountOut = _trxToTokenTransferInput(token,
                                         msg.value,
                                         amountOutMin,
                                         recipient,
                                         deadline);
    emit TrxToTokenTransferInput(token,
                                 msg.sender,
                                 recipient,
                                 msg.value,
                                 amountOut);
  }

  function tokenToTrxTransferInput(address token,
                                   uint256 amountIn,
                                   uint256 amountOutMin,
                                   address recipient,
                                   uint256 deadline)
      public returns(uint256 amountOut) {
    amountOut = _tokenToTrxTransferInput(token,
                                         amountIn,
                                         amountOutMin,
                                         recipient,
                                         deadline);
    emit TokenToTrxTransferInput(token,
                                 msg.sender,
                                 recipient,
                                 amountIn,
                                 amountOut);
  }

  function tokenToTokenTransferInput(address tokenIn,
                                     address tokenOut,
                                     uint256 amountIn,
                                     uint256 amountOutMin,
                                     address recipient,
                                     uint256 deadline)
      public returns(uint256 amountOut) {
    Context memory context;
    context.amountIn = amountIn;
    context.amountOutMin = amountOutMin;
    context.recipient = recipient;
    context.deadline = deadline;
    amountOut = _tokenToTokenTransferInput(tokenIn,
                                           tokenOut,
                                           context);
    emit TokenToTokenTransferInput(tokenIn,
                                   tokenOut,
                                   msg.sender,
                                   recipient,
                                   amountIn,
                                   amountOut);
  }

  function swapExactTokensForTokensV1(uint256 amountIn,
                                      uint256 amountOutMin,
                                      address[] memory path,
                                      address recipient,
                                      uint256 deadline)
      public payable returns(uint256[] memory amountsOut) {
    Context memory context;
    context.amountIn = amountIn;
    context.pathSlice = path;
    context.amountOutMin = amountOutMin;
    context.recipient = recipient;
    context.deadline = deadline;
    amountsOut = _swapExactTokensForTokensV1(context);
    emit SwapExactTokensForTokensV1(path[0],
                                    path[path.length - 1],
                                    msg.sender,
                                    recipient,
                                    amountIn,
                                    amountsOut);
  }

  function swapExactTokensForTokensV2(uint256 amountIn,
                                      uint256 amountOutMin,
                                      address[] memory path,
                                      address recipient,
                                      uint256 deadline)
      public payable returns (uint256[] memory amountsOut) {
    Context memory context;
    context.amountIn = amountIn;
    context.pathSlice = path;
    context.amountOutMin = amountOutMin;
    context.recipient = recipient;
    context.deadline = deadline;
    amountsOut = _swapExactTokensForTokensV2(context);
    emit SwapExactTokensForTokensV2(path[0],
                                    path[path.length - 1],
                                    msg.sender,
                                    recipient,
                                    amountIn,
                                    amountsOut);
  }

  function swapExactInputV3(uint256 amountIn,
                                      uint256 amountOutMin,
                                      address[] memory path,
                                      address recipient,
                                      uint256 deadline)
      public payable returns (uint256[] memory amountsOut) {
    Context memory context;
    context.amountIn = amountIn;
    context.pathSlice = path;
    context.amountOutMin = amountOutMin;
    context.recipient = recipient;
    context.deadline = deadline;
    amountsOut = _swapExactInputV3(context);
    emit SwapExactTokensForTokensV2(path[0],
                                    path[path.length - 1],
                                    msg.sender,
                                    recipient,
                                    amountIn,
                                    amountsOut);
  }
  // to override walkaround usdt address issue
  function _tokenSafeTransfer(address token, address to, uint256 value)
      internal override returns(uint256 amountOut) {
    require(to != address(this) && to != address(0), "INVALID_ARGS");

    uint256 balanceBefore = erc20(token).balanceOf(to);
    // bytes4(keccak256(bytes('transfer(address,uint256)')));
    TransactionResult memory result;
    (result.isSuccess, result.data) = token
      .call(abi.encodeWithSelector(0xa9059cbb, to, value));
    require(result.isSuccess , "Transfer failed");
    if (token != usdt && result.data.length > 0) {
      require(abi.decode(result.data, (bool)), "Transfer failed");
    }
    uint256 balanceAfter = erc20(token).balanceOf(to);
    return balanceAfter - balanceBefore;
  }

}
