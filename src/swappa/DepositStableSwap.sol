// SPDX-License-Identifier: MIT
pragma solidity 0.6.8;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../interfaces/stableswap/ISwap.sol";
import "../interfaces/IFarm.sol";
import "../interfaces/curve/ILiquidityGaugeV3.sol";

contract DepositStableSwap is IFarm {
	using SafeMath for uint;


	function parseDataDeposit(bytes memory data) private pure returns (address swapPoolAddr, address gaugeAddress) {
		require(data.length == 40, "PairStableSwap: invalid deposit data!");

		assembly {
			swapPoolAddr := mload(add(data, 20))
			gaugeAddress := mload(add(data, 40))
		}
	}

	function deposit(uint256 minExpected, address to, bytes calldata data) override external returns (uint256 amountReceived) {
		(address swapPoolAddr, address gaugeAddr) = parseDataDeposit(data);
		uint256[] memory amounts = new uint256[](2);
		ISwap iSwap = ISwap(swapPoolAddr);

		// Will have to be changed to allow for more than 2 tokens per pool
		for (uint8 i = 0; i< 2; i++) {
			ERC20 tokenI = ERC20(iSwap.getToken(i));
			amounts[i] = tokenI.balanceOf(address(this));
			require(tokenI.approve(swapPoolAddr, amounts[i]), "PairStableSwap: Approval in deposit failed!");
		}

		uint256 liquidity = iSwap.addLiquidity(amounts, minExpected, block.timestamp + 60);

		require(liquidity >= minExpected, "PairStableSwap: Not enough lp received");

		ERC20(iSwap.getLpToken()).approve(gaugeAddr, liquidity);
		ILiquidityGaugeV3(gaugeAddr).deposit(liquidity, to);
	}

	function withdraw(address to, bytes calldata data) external override {
		(address swapPoolAddr, address gaugeAddr) = parseDataDeposit(data);
		ILiquidityGaugeV3 gauge = ILiquidityGaugeV3(gaugeAddr);
		ISwap iSwap = ISwap(swapPoolAddr);
		uint256 amount = gauge.balanceOf(address(this));
		require(gauge.approve(gaugeAddr, amount), "PairStableSwap: Approval failed in withdraw!");
		gauge.withdraw(amount);

		require(ERC20(iSwap.getLpToken()).approve(swapPoolAddr, amount), "PairStableSwap: Approval failed in withdraw!");
		uint256[] memory withdrawAmounts = iSwap.removeLiquidity(amount, new uint256[](2), block.timestamp + 60);

		for (uint8 i = 0; i < withdrawAmounts.length; i++) {
			ERC20 tokenI = ERC20(iSwap.getToken(i));
			require(tokenI.transfer(to, withdrawAmounts[i]), "PairStableSwap: Transfer failed in withdraw!");
		}
	}

	receive() external payable {}

}