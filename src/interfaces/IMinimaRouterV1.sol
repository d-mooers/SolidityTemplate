// SPDX-License-Identifier: MIT
pragma solidity 0.6.8;
pragma experimental ABIEncoderV2;

interface IMinimaRouterV1 {
    struct Divisor {
        uint8 toIdx;
        uint8 divisor;
        address token;
    }

    struct MultiSwapPayload {
        address[][] path;
        address[][] pairs;
        Divisor[][] divisors;
        bytes[][] extras;
        uint256[] inputAmounts;
        uint256 minOutputAmount;
        uint256 expectedOutputAmount;
        address to;
        uint256 deadline;
        uint256 partner;
        bytes sig;
    }

    function getOutputAmount(
        address[] calldata path,
        address[] calldata pairs,
        bytes[] calldata extras,
        uint256 inputAmount
    ) external view returns (uint256 outputAmount);

    function swapExactInputForOutput(MultiSwapPayload calldata details)
        external
        returns (uint256[] memory);
}
