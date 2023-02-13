// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin08/contracts/utils/math/SafeMath.sol";
import "@openzeppelin08/contracts/token/ERC20/ERC20.sol";
import "../interfaces/aave-v2/ILendingPoolV2.sol";
import "../interfaces/ISwappaPairV1.sol";

contract PairATokenV2 is ISwappaPairV1 {
    using SafeMath for uint256;

    function swap(
        address input,
        address output,
        address to,
        bytes calldata data
    ) external override {
        (address poolAddr, uint8 inputType) = parseData(data);
        uint256 inputAmount = ERC20(input).balanceOf(address(this));
        if (inputType == 1) {
            // AToken -> Underlying.
            ILendingPoolV2(poolAddr).withdraw(output, inputAmount, to);
        } else if (inputType == 2) {
            // Underlying -> AToken.
            require(
                ERC20(input).approve(poolAddr, inputAmount),
                "PairATokenV2: approve failed!"
            );
            ILendingPoolV2(poolAddr).deposit(input, inputAmount, to, 0x0);
        }
    }

    function parseData(bytes memory data)
        private
        pure
        returns (address poolAddr, uint8 inputType)
    {
        require(data.length == 21, "PairATokenV2: invalid data!");
        inputType = uint8(data[20]);
        assembly {
            poolAddr := mload(add(data, 20))
        }
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
