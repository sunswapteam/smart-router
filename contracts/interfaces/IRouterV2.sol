// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;
pragma experimental ABIEncoderV2;

interface v2 {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    // function swapTokensForExactTokens(
    //     uint256 amountOut,
    //     uint256 amountInMax,
    //     address[] calldata path,
    //     address to,
    //     uint256 deadline
    // ) external returns (uint256[] memory amounts);

    // function swapExactETHForTokens(uint256 amountOutMin,
    //                                address[] calldata path,
    //                                address to,
    //                                uint256 deadline)
    // external payable returns (uint256[] memory amounts);

    // function swapTokensForExactETH(uint256 amountOut,
    //                                uint256 amountInMax,
    //                                address[] calldata path,
    //                                address to,
    //                                uint256 deadline)
    // external returns (uint256[] memory amounts);

    // function swapExactTokensForETH(uint256 amountIn,
    //                                uint256 amountOutMin,
    //                                address[] calldata path,
    //                                address to,
    //                                uint256 deadline)
    // external returns (uint256[] memory amounts);

    // function swapETHForExactTokens(uint256 amountOut,
    //                                address[] calldata path,
    //                                address to,
    //                                uint256 deadline)
    // external payable returns (uint256[] memory amounts);
}
