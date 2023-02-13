// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin08/contracts/utils/math/SafeMath.sol";
import "@openzeppelin08/contracts/token/ERC20/ERC20.sol";
import "../interfaces/stCelo/IRebasedStakedCelo.sol";
import "../interfaces/ISwappaPairV1.sol";

contract PairRStCelo is ISwappaPairV1 {
    using SafeMath for uint256;

    function swap(
        address input,
        address output,
        address to,
        bytes calldata data
    ) external override {
        (address rebaseAddr, uint8 inputType) = parseData(data);
        uint256 inputAmount = ERC20(input).balanceOf(address(this));

        if (inputType == 1) {
            // rstCelo -> stCelo
            uint256 stCeloAmount = IRebasedStakedCelo(rebaseAddr).toStakedCelo(
                inputAmount
            );
            IRebasedStakedCelo(rebaseAddr).withdraw(stCeloAmount);
        } else if (inputType == 2) {
            // stCelo -> rstCelo
            require(ERC20(input).approve(rebaseAddr, inputAmount));
            IRebasedStakedCelo(rebaseAddr).deposit(inputAmount);
        }
        uint256 outputAmount = ERC20(output).balanceOf(address(this));
        require(
            ERC20(output).transfer(to, outputAmount),
            "PairRStCelo: Transfer Failed"
        );
    }

    function parseData(bytes memory data)
        private
        pure
        returns (address rebaseAddr, uint8 inputType)
    {
        require(data.length == 21, "PairRStCelo: invalid data!");
        inputType = uint8(data[20]);
        assembly {
            rebaseAddr := mload(add(data, 20))
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
