// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;
pragma experimental ABIEncoderV2;

interface psm {
  function buyGem(address recipient, uint256 amount) external;
  function sellGem(address recipient, uint256 amount) external;
}
