// SPDX-License-Identifier: MIT
pragma solidity >=0.6.8 <0.9.0;
pragma experimental ABIEncoderV2;

import "./TRC20Mock.sol";
import "../interfaces/IRouterV2.sol";
import "../helpers/ReentrancyGuard.sol";

contract RouterV2Mock is v2, ReentrancyGuard {
  uint256[] tokenOut;
  uint256 next;

  constructor() public {
    tokenOut = [0];
  }
  event SwapExactTokensForTokens(
    uint256 amountIn,
    uint256 amountOutMin,
    address to,
    uint256[] amountOut
  );

  fallback() external payable {}
  receive() external payable {}

  function setTokenOut(uint256[] memory _tokenOut) public {
    require(_tokenOut.length > 0, "INVALID_ARGS");
    tokenOut = _tokenOut;
    next = 0;
  }

  function setUp(address[] memory tokens, uint256 amount) public payable {
    for (uint128 i = 0; i < tokens.length; i++) {
      TRC20Mock(tokens[i]).mint(address(this), amount);
    }
  }

  function swapExactTokensForTokens(uint256 amountIn,
                                    uint256 amountOutMin,
                                    address[] calldata path,
                                    address to,
                                    uint256 deadline)
      external nonReentrant override returns(uint256[] memory amounts) {
    require(path.length > 1, "INVALID_PATH");
    require(deadline >= block.timestamp, "deadline exceeded");
    require(TRC20Mock(path[0]).transferFrom(msg.sender, address(this), amountIn),
           "transfer failed");
    amounts = new uint256[](path.length);
    amounts[0] = amountIn;
    for (uint128 i = 1; i < path.length; i++) {
      require(tokenOut[next] > 0, "amountMin not satisfied");
      amounts[i] = tokenOut[next];
      next = (next + 1) % tokenOut.length;
    }
    require(amounts[path.length - 1] >= amountOutMin, "amountMin not satisfied");
    require(TRC20Mock(path[path.length - 1]).transfer(
      to, amounts[path.length - 1]), "transfer failed");
    emit SwapExactTokensForTokens(amountIn,amountOutMin,to,amounts);
  }
  
}
