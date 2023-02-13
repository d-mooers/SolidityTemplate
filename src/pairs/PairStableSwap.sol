// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin08/contracts/utils/math/SafeMath.sol";
import "@openzeppelin08/contracts/token/ERC20/ERC20.sol";
import "../interfaces/stableswap/ISwap.sol";
import "../interfaces/ISwappaPairV1.sol";
import "../interfaces/IFarm.sol";
import "../interfaces/curve/ILiquidityGaugeV3.sol";

contract PairStableSwap is ISwappaPairV1, IFarm {
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
            "PairStableSwap: approve failed!"
        );
        ISwap swapPool = ISwap(swapPoolAddr);
        uint256 outputAmount;
        // TODO(zviadm): This will need to change to support multi-token pools.
        if (swapPool.getToken(0) == input) {
            outputAmount = swapPool.swap(0, 1, inputAmount, 0, block.timestamp);
        } else {
            outputAmount = swapPool.swap(1, 0, inputAmount, 0, block.timestamp);
        }
        require(
            ERC20(output).transfer(to, outputAmount),
            "PairStableSwap: transfer failed!"
        );
    }

    function parseData(bytes memory data)
        private
        pure
        returns (address swapPoolAddr)
    {
        require(data.length == 20, "PairStableSwap: invalid data!");
        assembly {
            swapPoolAddr := mload(add(data, 20))
        }
    }

    function parseDataDeposit(bytes memory data)
        private
        pure
        returns (address swapPoolAddr, address gaugeAddress)
    {
        require(data.length == 40, "PairStableSwap: invalid deposit data!");

        assembly {
            swapPoolAddr := mload(add(data, 20))
            gaugeAddress := mload(add(data, 40))
        }
    }

    function deposit(
        uint256 minExpected,
        address to,
        bytes calldata data
    ) external override returns (uint256 amountReceived) {
        (address swapPoolAddr, address gaugeAddr) = parseDataDeposit(data);
        uint256[] memory amounts = new uint256[](2);
        ISwap iSwap = ISwap(swapPoolAddr);

        // Will have to be changed to allow for more than 2 tokens per pool
        for (uint8 i = 0; i < 2; i++) {
            ERC20 tokenI = ERC20(iSwap.getToken(i));
            amounts[i] = tokenI.balanceOf(address(this));
            require(
                tokenI.approve(swapPoolAddr, amounts[i]),
                "PairStableSwap: Approval in deposit failed!"
            );
        }

        amountReceived = iSwap.addLiquidity(
            amounts,
            minExpected,
            block.timestamp + 60
        );

        require(
            amountReceived >= minExpected,
            "PairStableSwap: Not enough lp received"
        );

        ERC20(iSwap.getLpToken()).approve(gaugeAddr, amountReceived);
        ILiquidityGaugeV3(gaugeAddr).deposit(amountReceived, to);
    }

    function withdraw(address to, bytes calldata data) external override {
        (address swapPoolAddr, address gaugeAddr) = parseDataDeposit(data);
        ILiquidityGaugeV3 gauge = ILiquidityGaugeV3(gaugeAddr);
        ISwap iSwap = ISwap(swapPoolAddr);
        uint256 amount = gauge.balanceOf(address(this));
        require(
            gauge.approve(gaugeAddr, amount),
            "PairStableSwap: Approval failed in withdraw!"
        );
        gauge.withdraw(amount);

        require(
            ERC20(iSwap.getLpToken()).approve(swapPoolAddr, amount),
            "PairStableSwap: Approval failed in withdraw!"
        );
        uint256[] memory withdrawAmounts = iSwap.removeLiquidity(
            amount,
            new uint256[](2),
            block.timestamp + 60
        );

        for (uint8 i = 0; i < withdrawAmounts.length; i++) {
            ERC20 tokenI = ERC20(iSwap.getToken(i));
            require(
                tokenI.transfer(to, withdrawAmounts[i]),
                "PairStableSwap: Transfer failed in withdraw!"
            );
        }
    }

    function getOutputAmount(
        address input,
        address,
        uint256 amountIn,
        bytes calldata data
    ) external view override returns (uint256 amountOut) {
        address swapPoolAddr = parseData(data);
        ISwap swapPool = ISwap(swapPoolAddr);
        // TODO(zviadm): This will need to change to support multi-token pools.
        if (swapPool.getToken(0) == input) {
            return swapPool.calculateSwap(0, 1, amountIn);
        } else {
            return swapPool.calculateSwap(1, 0, amountIn);
        }
    }

    receive() external payable {}
}
