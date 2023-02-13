// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin08/contracts/utils/math/SafeMath.sol";
import "@openzeppelin08/contracts/token/ERC20/ERC20.sol";
import "../interfaces/uniswap/IUniswapV2Pair.sol";
import "../interfaces/ISwappaPairV1.sol";
import "../interfaces/IFarm.sol";

contract PairUniswapV2 is ISwappaPairV1, IFarm {
    using SafeMath for uint256;

    function quote(
        uint256 amountA,
        uint256 amountB,
        uint256 reserveA,
        uint256 reserveB
    ) internal pure returns (uint256 amount0, uint256 amount1) {
        require(amountA > 0, "UniswapV2Library: INSUFFICIENT_AMOUNT");
        require(
            reserveA > 0 && reserveB > 0,
            "UniswapV2Library: INSUFFICIENT_LIQUIDITY"
        );
        amount0 = amountA.mul(reserveB) / reserveA;
        amount1 = amountB.mul(reserveB) / reserveA;
    }

    function calculateDepositAmount(IUniswapV2Pair pair)
        internal
        view
        returns (uint256 amount0, uint256 amount1)
    {
        ERC20 token0 = ERC20(pair.token0());
        ERC20 token1 = ERC20(pair.token1());
        uint256 bal0 = token0.balanceOf(address(this));
        uint256 bal1 = token1.balanceOf(address(this));

        (uint256 reserves0, uint256 reserves1, ) = pair.getReserves();
        (amount0, amount1) = quote(bal0, bal1, reserves0, reserves1);
        amount0 = amount0 > bal0 ? bal0 : amount0;
        amount1 = amount1 > bal1 ? bal1 : amount1;
    }

    function cleanup(IUniswapV2Pair pair, address to) internal {
        ERC20 token0 = ERC20(pair.token0());
        ERC20 token1 = ERC20(pair.token1());
        uint256 bal0 = token0.balanceOf(address(this));
        uint256 bal1 = token1.balanceOf(address(this));

        require(
            token0.transfer(to, bal0) && token1.transfer(to, bal1),
            "PairUniswapV2: Cleanup transfer failed!"
        );
    }

    function swap(
        address input,
        address,
        address to,
        bytes calldata data
    ) external override {
        (address pairAddr, uint256 feeK) = parseData(data);
        uint256 inputAmount = ERC20(input).balanceOf(address(this));
        require(
            ERC20(input).transfer(pairAddr, inputAmount),
            "PairUniswapV2: transfer failed!"
        );
        IUniswapV2Pair pair = IUniswapV2Pair(pairAddr);
        (uint256 reserve0, uint256 reserve1, ) = pair.getReserves();
        if (pair.token0() == input) {
            uint256 outputAmount = getAmountOut(
                inputAmount,
                reserve0,
                reserve1,
                feeK
            );
            pair.swap(0, outputAmount, to, new bytes(0));
        } else {
            uint256 outputAmount = getAmountOut(
                inputAmount,
                reserve1,
                reserve0,
                feeK
            );
            pair.swap(outputAmount, 0, to, new bytes(0));
        }
    }

    function parseData(bytes memory data)
        private
        pure
        returns (address pairAddr, uint256 fee)
    {
        require(data.length == 21, "PairUniswapV2: invalid data!");
        fee = uint256(1000).sub(uint8(data[20]));
        assembly {
            pairAddr := mload(add(data, 20))
        }
    }

    function deposit(
        uint256 minExpected,
        address to,
        bytes calldata data
    ) external override returns (uint256 liquidity) {
        (address pairAddr, ) = parseData(data);
        IUniswapV2Pair pair = IUniswapV2Pair(pairAddr);
        ERC20 token0 = ERC20(pair.token0());
        ERC20 token1 = ERC20(pair.token1());

        (uint256 amount0, uint256 amount1) = calculateDepositAmount(pair);
        require(
            token0.transfer(pairAddr, amount0) &&
                token1.transfer(pairAddr, amount1),
            "PairUniswapV2: Transfer to Pair failed!"
        );

        liquidity = pair.mint(to);
        require(
            liquidity >= minExpected,
            "PairUniswapV2: Not enough lp recieved!"
        );
        cleanup(pair, to);
    }

    function withdraw(address to, bytes calldata data) external override {
        (address pairAddr, ) = parseData(data);
        IUniswapV2Pair pair = IUniswapV2Pair(pairAddr);

        require(
            pair.transfer(pairAddr, pair.balanceOf(address(this))),
            "PairUniswapV2: Failed transfer!"
        );
        pair.burn(to);
    }

    function getOutputAmount(
        address input,
        address,
        uint256 amountIn,
        bytes calldata data
    ) external view override returns (uint256 amountOut) {
        (address pairAddr, uint256 feeK) = parseData(data);
        IUniswapV2Pair pair = IUniswapV2Pair(pairAddr);
        (uint256 reserve0, uint256 reserve1, ) = pair.getReserves();
        (uint256 reserveIn, uint256 reserveOut) = pair.token0() == input
            ? (reserve0, reserve1)
            : (reserve1, reserve0);
        return getAmountOut(amountIn, reserveIn, reserveOut, feeK);
    }

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut,
        uint256 feeK
    ) internal pure returns (uint256 amountOut) {
        uint256 amountInWithFee = amountIn.mul(feeK);
        uint256 numerator = amountInWithFee.mul(reserveOut);
        uint256 denominator = reserveIn.mul(1000).add(amountInWithFee);
        amountOut = numerator / denominator;
    }

    receive() external payable {}
}
