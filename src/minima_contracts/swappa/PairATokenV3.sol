// SPDX-License-Identifier: MIT
pragma solidity 0.6.8;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../interfaces/aave-v3/IPoolV3.sol";
import "./ISwappaPairV1.sol";

contract PairATokenV3 is ISwappaPairV1 {
	using SafeMath for uint;

	function swap(
		address input,
		address output,
		address to,
		bytes calldata data
	) external override {
		(address poolAddr, uint8 inputType) = parseData(data);
		uint inputAmount = ERC20(input).balanceOf(address(this));
		if (inputType == 1) {
			// AToken -> Underlying.
			IPoolV3(poolAddr).withdraw(output, inputAmount, to);
		} else if (inputType == 2) {
			// Underlying -> AToken.
			require(
				ERC20(input).approve(poolAddr, inputAmount),
				"PairATokenV2: approve failed!");
			IPoolV3(poolAddr).supply(input, inputAmount, to, 0x0);
		}
	}

	function parseData(bytes memory data) private pure returns (address poolAddr, uint8 inputType) {
		require(data.length == 21, "PairATokenV3: invalid data!");
		inputType = uint8(data[20]);
    assembly {
      poolAddr := mload(add(data, 20))
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