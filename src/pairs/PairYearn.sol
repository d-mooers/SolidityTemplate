// SPDX-License-Identifier: MIT
pragma solidity 0.6.8;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../interfaces/ISwappaPairV1.sol";

import "../interfaces/yearn/IYearnVault.sol";

contract PairYearn is ISwappaPairV1 {
    using SafeMath for uint256;

    function parseDataDeposit(bytes memory data)
        private
        pure
        returns (address poolAddr, uint8 inputType)
    {
        require(data.length == 21, "Invalid call data");
        inputType = uint8(data[20]);
        assembly {
            poolAddr := mload(add(data, 20))
        }
    }

    function swap(
        address input,
        address output,
        address to,
        bytes calldata data
    ) external override {
        (address poolAddr, uint8 inputType) = parseDataDeposit(data);
        uint256 inputAmount = ERC20(input).balanceOf(address(this));

        if (inputType == 1) {
            // AToken -> Underlying.

            uint256 _before = ERC20(output).balanceOf(address(this));
            // Withdraw from yVault the balance amount of AToken
            IYearnVault(poolAddr).withdraw(inputAmount);

            uint256 _after = ERC20(output).balanceOf(address(this));
            uint256 balanceAmount = _after.sub(_before);
            //transfer back the Underlying to the sender (to)
            ERC20(output).transfer(to, balanceAmount);
        } else if (inputType == 2) {
            // Underlying -> AToken.

            require(
                ERC20(input).approve(poolAddr, inputAmount),
                "PairYearn: Approval in deposit failed!"
            );
            // Deposit into the yVault
            IYearnVault(poolAddr).deposit(inputAmount);

            uint256 balance = ERC20(output).balanceOf(address(this));

            //transfer back the AToken to the sender (to)
            ERC20(output).transfer(to, balance);
        }
    }

    function getOutputAmount(
        address,
        address,
        uint256 amountIn,
        bytes calldata data
    ) external view override returns (uint256 amountOut) {
        (address poolAddr, uint8 inputType) = parseDataDeposit(data);

        uint256 _pool = IYearnVault(poolAddr).balance();
        uint256 totalSupplyAmount = ERC20(poolAddr).totalSupply();

        if (inputType == 1) {
            //  Calculate yVault Widthdraw outputAmount
            amountOut = (_pool.mul(amountIn)).div(totalSupplyAmount);
        } else if (inputType == 2) {
            // Calculate yVault Deposit  the output
            if (totalSupplyAmount == 0) {
                amountOut = amountIn;
            } else {
                amountOut = (amountIn.mul(totalSupplyAmount)).div(_pool);
            }
        }
    }

    receive() external payable {}
}
