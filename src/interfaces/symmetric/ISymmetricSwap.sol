// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface ISymmetricSwap {
	function paused() external view returns (bool);
	function swap(
		address from,
		address to,
		uint256 amount
	) external;
}
