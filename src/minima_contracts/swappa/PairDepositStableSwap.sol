// SPDX-License-Identifier: MIT
pragma solidity 0.6.8;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../interfaces/stableswap/ISwap.sol";
import "./ISwappaPairV1.sol";


contract PairDepositStableSwap is ISwappaPairV1 {
	using SafeMath for uint;


	function parseData(bytes memory data) private pure returns (address swapPoolAddr) {
		require(data.length == 20, "PairDepositStableSwap: invalid deposit data!");

		assembly {
			swapPoolAddr := mload(add(data, 20))
		}
	}

	function swap(address input, address output, address to, bytes calldata data) override external {
		address swapPoolAddr = parseData(data);
		if (input == address(0)) {
			deposit(output, swapPoolAddr, to);
		} else {
			withdraw(input, swapPoolAddr, to);
		}
	} 

	function deposit(address lpAddress, address swapPoolAddr, address to) internal returns (uint256 amountReceived) {
		uint256[] memory amounts = new uint256[](2);
		ISwap iSwap = ISwap(swapPoolAddr);

		// Will have to be changed to allow for more than 2 tokens per pool
		for (uint8 i = 0; i< 2; i++) {
			ERC20 tokenI = ERC20(iSwap.getToken(i));
			amounts[i] = tokenI.balanceOf(address(this));
			require(tokenI.approve(swapPoolAddr, amounts[i]), "PairDepositStableSwap: Approval in deposit failed!");
		}

		uint256 liquidity = iSwap.addLiquidity(amounts, 0, block.timestamp + 60);
		ERC20(lpAddress).transfer(to, liquidity);
	}

	function withdraw(address lpAddress, address swapPoolAddr, address to) internal {
		ISwap iSwap = ISwap(swapPoolAddr);
		ERC20 lpToken = ERC20(lpAddress);
		uint256 amount = lpToken.balanceOf(address(this));

		require(lpToken.approve(swapPoolAddr, amount), "PairDepositStableSwap: Approval failed in withdraw!");
		uint256[] memory withdrawAmounts = iSwap.removeLiquidity(amount, new uint256[](2), block.timestamp + 60);

		for (uint8 i = 0; i < withdrawAmounts.length; i++) {
			ERC20 tokenI = ERC20(iSwap.getToken(i));
			require(tokenI.transfer(to, withdrawAmounts[i]), "PairDepositStableSwap: Transfer failed in withdraw!");
		}
	}

	function getOutputAmount(
		address input,
		address output,
		uint amountIn,
		bytes calldata data
	) external view override returns (uint amountOut) {
		return amountIn;
	}


	receive() external payable {}

}