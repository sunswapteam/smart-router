// SPDX-License-Identifier: MIT
pragma solidity >=0.6.8 <0.9.0;
pragma experimental ABIEncoderV2;

import "./TRC20Mock.sol";
import "../interfaces/IRouterV3.sol";
import "../helpers/ReentrancyGuard.sol";
import "../helpers/V3Decode.sol";

contract RouterV3Mock is v3, ReentrancyGuard {
  uint256[] tokenOut;
  uint256 next;

  constructor() public {
    tokenOut = [0];
  }

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

  function exactInput(ExactInputParams memory params) external payable  override returns (uint256 amountOut) {
    require(params.path.length > 1, "INVALID_PATH");
    require(params.deadline >= block.timestamp, "deadline exceeded");
    uint256[] memory amounts = new uint256[](params.path.length);
    address tokenOutAddr;
  
    while(true){
      bool hasMultiplePools = Path.hasMultiplePools(params.path);

      require(tokenOut[next] > 0, "amountMin not satisfied");
      params.amountIn = tokenOut[next];
      next = (next + 1) % tokenOut.length;
      if (hasMultiplePools) {
        params.path = Path.skipToken(params.path);
        (, tokenOutAddr, ) = Path.decodeFirstPool(Path.getFirstPool(params.path));
      } else {
        amountOut = params.amountIn;
        require(amountOut >= params.amountOutMinimum, "amountMin not satisfied");
        require(TRC20Mock(tokenOutAddr).transfer(
        params.recipient, amountOut), "transfer failed");
        break;
      }
    }
  }
}
