// SPDX-License-Identifier: MIT
pragma solidity >=0.6.8 <0.9.0;
pragma experimental ABIEncoderV2;

import "./TRC20Mock.sol";
import "../interfaces/IRouterV1.sol";
import "../helpers/ReentrancyGuard.sol";

contract ExchangerV1Mock is ReentrancyGuard {
  address v1Factory;
  address token;
  uint256[] amountOut;
  uint256 next;

  constructor(address _token) public {
    v1Factory = msg.sender;
    token = _token;
    amountOut = [0];
  }

  fallback() external payable {}
  receive() external payable {}

  function setTokenOut(uint256[] memory _amountOut) public {
    require(_amountOut.length > 0, "INVALID_ARGS");
    amountOut = _amountOut;
    next = 0;
  }

  function trxToTokenTransferInput(uint256 amountOutMin,
                                   uint256 deadline,
                                   address recipient)
      public payable nonReentrant returns(uint256 amount) {
    amount = amountOut[next];
    require(amount >= amountOutMin, "amountMin not satisfied");
    require(deadline >= block.timestamp, "deadline exceeded");
    require(TRC20Mock(token).transfer(recipient, amount),
            "transfer failed");
    next = (next + 1) % amountOut.length;
  }

  function tokenToTrxTransferInput(uint256 amountIn,
                                   uint256 amountOutMin,
                                   uint256 deadline,
                                   address payable recipient)
      public nonReentrant returns(uint256 amount) {
    amount = amountOut[next];
    require(amount >= amountOutMin, "amountMin not satisfied");
    require(deadline >= block.timestamp, "deadline exceeded");
    require(TRC20Mock(token).transferFrom(msg.sender, address(this), amountIn),
           "transfer failed");
    recipient.transfer(amount);
    next = (next + 1) % amountOut.length;
  }

  function tokenToTokenTransferInput(uint256 amountIn,
                                     uint256 amountOutMin,
                                     uint256 amountTrxMin,
                                     uint256 deadline,
                                     address recipient,
                                     address tokenOut)
      external nonReentrant returns(uint256 amount) {
    address payable next_exchange = v1(v1Factory).getExchange(tokenOut);
    require(next_exchange != address(0), "exchange not found");
    uint256 trxBought = amountOut[next];
    require(trxBought >= amountTrxMin, "amountMin not satisfied");
    require(deadline >= block.timestamp, "deadline exceeded");

    require(TRC20Mock(token).transferFrom(msg.sender, address(this), amountIn),
           "transfer failed");
    amount = ExchangerV1Mock(next_exchange).trxToTokenTransferInput{value: trxBought}(
        amountOutMin, deadline, recipient);
    next = (next + 1) % amountOut.length;
  }
}

contract RouterV1Mock is v1 {
  mapping(address => address) token2exchange;

  fallback() external payable {}
  receive() external payable {}

  function setUp(address[] memory tokens, uint256 amount) public payable {
    for (uint128 i = 0; i < tokens.length; i++) {
      createExchange(tokens[i], amount);
    }
  }

  function getExchange(address token)
      public view override returns(address payable) {
    return payable(token2exchange[token]);
  }

  function createExchange(address token, uint256 amount)
      internal returns(address) {
    require(token != address(0), "illegal token");
    require(token2exchange[token] == address(0), "exchange already created");
    ExchangerV1Mock exchange = new ExchangerV1Mock(token);
    TRC20Mock(token).mint(address(exchange), amount);
    payable(address(exchange)).transfer(amount);
    token2exchange[token] = address(exchange);
    return address(exchange);
  }
}
