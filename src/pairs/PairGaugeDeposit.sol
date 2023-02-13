// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin08/contracts/utils/math/SafeMath.sol";
import "@openzeppelin08/contracts/token/ERC20/ERC20.sol";
import "../interfaces/aave-v2/ILendingPoolV2.sol";
import "../interfaces/ISwappaPairV1.sol";
import "../interfaces/curve/ILiquidityGaugeV3.sol";

contract PairGaugeDeposit is ISwappaPairV1 {
    using SafeMath for uint256;

    function swap(
        address input,
        address output,
        address to,
        bytes calldata data
    ) external override {
        uint8 inputType = parseData(data);
        uint256 inputAmount = ERC20(input).balanceOf(address(this));
        require(
            ERC20(input).approve(output, inputAmount),
            "PairGaugeDeposit: approve failed!"
        );

        if (inputType == 1) {
            // AToken -> Underlying.
            ILiquidityGaugeV3(input).withdraw(inputAmount);
            require(
                ERC20(input).transfer(to, inputAmount),
                "PairGaugeDeposit: transfer failed!"
            );
        } else if (inputType == 2) {
            // Underlying -> AToken.
            ILiquidityGaugeV3(output).deposit(inputAmount, to);
        }
    }

    function parseData(bytes memory data)
        private
        pure
        returns (uint8 inputType)
    {
        require(data.length == 1, "PairGaugeDeposit: invalid data!");
        inputType = uint8(data[0]);
    }

    function getOutputAmount(
        address,
        address,
        uint256 amountIn,
        bytes calldata
    ) external view override returns (uint256 amountOut) {
        return amountIn;
    }

    receive() external payable {}
}
