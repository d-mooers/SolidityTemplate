// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface ISwap {
	function paused() external view returns (bool);
	function getToken(uint8 index) external view returns (address);
	function getBalances() external view returns (uint256[] memory);
	function getSwapFee() external view returns (uint256);
	function getAPrecise() external view returns (uint256);
	function getLpToken() external view returns (address);

	function swap(
		uint8 tokenIndexFrom,
		uint8 tokenIndexTo,
		uint256 dx,
		uint256 minDy,
		uint256 deadline
	) external returns (uint256);

	function calculateSwap(
		uint8 tokenIndexFrom,
		uint8 tokenIndexTo,
		uint256 dx
	) external view returns (uint256);

	function addLiquidity(
        uint256[] calldata amounts,
        uint256 minToMint,
        uint256 deadline
    )
        external
        returns (uint256);

	function removeLiquidity(
        uint256 amount,
        uint256[] calldata minAmounts,
        uint256 deadline
    ) external returns (uint256[] memory);
}
