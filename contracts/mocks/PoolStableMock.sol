// SPDX-License-Identifier: MIT
pragma solidity >=0.6.8 <0.9.0;
pragma experimental ABIEncoderV2;

import "./TRC20Mock.sol";
import "../helpers/ReentrancyGuard.sol";
import "../interfaces/IPoolPsm.sol";
import "../interfaces/IPoolStable.sol";

contract PoolStableMock is poolStable, usdcPoolF, psm, ReentrancyGuard {
  address[] tokens;
  uint256[] tokenOut;
  uint256 next;

  constructor(address[] memory _tokens, uint256 amount) public {
    tokens = _tokens;
    for (uint128 i = 0; i < tokens.length; i++) {
      TRC20Mock(tokens[i]).mint(address(this), amount);
    }
    tokenOut = [0];
  }

  function setTokenOut(uint128[] memory _tokenOut) public {
    require(_tokenOut.length > 0, "INVALID_ARGS");
    tokenOut = _tokenOut;
    next = 0;
  }

  function exchange(uint128 tokenIdIn,
                    uint128 tokenIdOut,
                    uint256 amountIn,
                    uint256 amountOutMin) external nonReentrant override {
    require(tokenIdIn != tokenIdOut
            && tokenIdIn < tokens.length
            && tokenIdOut < tokens.length, "INVALID_ARGS");
    uint256 amountOut = tokenOut[next];
    require(amountOut >= amountOutMin, "amountMin not satisfied");
    TRC20Mock(tokens[uint256(tokenIdIn)]).transferFrom(msg.sender,
                                                       address(this),
                                                       amountIn);
    TRC20Mock(tokens[uint256(tokenIdOut)]).transfer(msg.sender, amountOut);
    next = (next + 1) % tokenOut.length;
  }

  function exchange_underlying(int128 tokenIdIn,
                               int128 tokenIdOut,
                               uint256 amountIn,
                               uint256 amountOutMin)
      external nonReentrant override {
    require(tokenIdIn != tokenIdOut
            && uint256(tokenIdIn) < tokens.length
            && uint256(tokenIdOut) < tokens.length, "INVALID_ARGS");
    uint256 amountOut = tokenOut[next];
    require(amountOut >= amountOutMin, "amountMin not satisfied");
    TRC20Mock(tokens[uint256(tokenIdIn)]).transferFrom(msg.sender,
                                                       address(this),
                                                       amountIn);
    TRC20Mock(tokens[uint256(tokenIdOut)]).transfer(msg.sender, amountOut);
    next = (next + 1) % tokenOut.length;
  }

  function buyGem(address recipient, uint256 amount)
      external nonReentrant override {
    TRC20Mock(tokens[0]).transferFrom(msg.sender, address(this), amount);
    TRC20Mock(tokens[1]).transfer(recipient, amount);
    next = (next + 1) % tokenOut.length;
  }

  function sellGem(address recipient, uint256 amount)
      external nonReentrant override {
    TRC20Mock(tokens[1]).transferFrom(msg.sender, address(this), amount);
    TRC20Mock(tokens[0]).transfer(recipient, amount);
    next = (next + 1) % tokenOut.length;
  }

  function coins(uint256 tokenId) external override view returns (address) {
    require(tokenId < tokens.length, "INVALID_ARGS");
    return tokens[tokenId];
  }
}
