// SPDX-License-Identifier: MIT
pragma solidity 0.6.8;
pragma experimental ABIEncoderV2;

interface ISwappaRouterV1 {

	struct SwapPayload {
		address[] path;
		address[] pairs;
		bytes[] extras;
		uint256 inputAmount;
		uint256 minOutputAmount;
		uint256 expectedOutputAmount;
		address to;
		uint deadline;
		uint256 partner;
		bytes sig;
	}

	struct MultiSwapPayload {
		address[][] path;
		address[][] pairs;
		bytes[][] extras;
		uint256[] inputAmounts;
		uint256[] forwardTo;
		uint256 minOutputAmount;
		uint256 expectedOutputAmount;
		address to;
		uint deadline;
		uint256 partner;
		bytes sig;
	}

	function getOutputAmount(
		address[] calldata path,
		address[] calldata pairs,
		bytes[] calldata extras,
		uint256 inputAmount
	) external view returns (uint256 outputAmount);

	function swapExactInputForOutput(
		SwapPayload calldata details
	) external returns (uint256 outputAmount);

	function swapExactInputForOutputNativeIn(
		SwapPayload calldata details, 
		address wrappedAddr
	) external payable returns (uint256 outputAmount);

	function swapExactInputForOutputNativeOut(
		SwapPayload calldata details, 
		address wrappedAddr
	) external returns (uint256 outputAmount);

	function swapMultiExactInputForOutput(
		MultiSwapPayload calldata details
	) external returns (uint256[] memory);

	function swapMultiExactInputForOutputNativeIn(
		MultiSwapPayload calldata details,
		address wrappedAddr
	) external payable returns (uint256[] memory);

	function swapMultiExactInputForOutputNativeOut(
		MultiSwapPayload calldata details,
		address wrappedAddr
	) external returns (uint256[] memory);
}
