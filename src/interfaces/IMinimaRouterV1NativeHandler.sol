// SPDX-License-Identifier: MIT
pragma solidity 0.6.8;
pragma experimental ABIEncoderV2;

import {IMinimaRouterV1} from "./IMinimaRouterV1.sol";

interface IMinimaRouterV1NativeHandler {
    function swapMultiExactInputForOutputNativeIn(
        IMinimaRouterV1.MultiSwapPayload calldata details
    ) external payable returns (uint256[] memory);

    function swapMultiExactInputForOutputNativeOut(
        IMinimaRouterV1.MultiSwapPayload calldata details
    ) external returns (uint256[] memory);
}
