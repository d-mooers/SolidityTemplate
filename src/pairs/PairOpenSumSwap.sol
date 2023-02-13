// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin08/contracts/utils/math/SafeMath.sol";
import "@openzeppelin08/contracts/token/ERC20/ERC20.sol";
import "../interfaces/stableswap/IOpenSumSwap.sol";
import "../interfaces/ISwappaPairV1.sol";

contract PairOpenSumSwap is ISwappaPairV1 {
    using SafeMath for uint256;

    function swap(
        address input,
        address output,
        address to,
        bytes calldata data
    ) external override {
        address swapPoolAddr = parseData(data);
        uint256 inputAmount = ERC20(input).balanceOf(address(this));
        require(
            ERC20(input).approve(swapPoolAddr, inputAmount),
            "PairOpenSumSwap: approve failed!"
        );
        uint256 outputAmount = IOpenSumSwap(swapPoolAddr).swap(
            input,
            output,
            inputAmount,
            inputAmount,
            block.timestamp
        );
        require(
            ERC20(output).transfer(to, outputAmount),
            "PairOpenSumSwap: transfer failed!"
        );
    }

    function parseData(bytes memory data)
        private
        pure
        returns (address swapPoolAddr)
    {
        require(data.length == 20, "PairOpenSumSwap: invalid data!");
        assembly {
            swapPoolAddr := mload(add(data, 20))
        }
    }

    function getOutputAmount(
        address,
        address output,
        uint256 amountIn,
        bytes calldata data
    ) external view override returns (uint256 amountOut) {
        IOpenSumSwap pool = IOpenSumSwap(parseData(data));
        // no fees are taken if there's enough output token
        if (
            !pool.paused() && ERC20(output).balanceOf(address(pool)) >= amountIn
        ) {
            amountOut = amountIn;
        }
    }
}
