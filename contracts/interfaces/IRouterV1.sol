// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;
pragma experimental ABIEncoderV2;

interface v1 {
    function getExchange(address token) external view returns (address payable);
}
