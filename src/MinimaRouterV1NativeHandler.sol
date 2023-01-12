// SPDX-License-Identifier: MIT
pragma solidity 0.6.8;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./interfaces/ISwappaPairV1.sol";
import {IMinimaRouterV1} from "./interfaces/IMinimaRouterV1.sol";
import {IMinimaRouterV1NativeHandler} from "./interfaces/IMinimaRouterV1NativeHandler.sol";
import {INative} from "./interfaces/INative.sol";

contract MinimaRouterV1NativeHandler is IMinimaRouterV1NativeHandler {
    address public immutable minimaRouter;
    address public immutable wrapperContract;

    constructor(address _minimaRouter, address _wrapperContract) public {
        minimaRouter = _minimaRouter;
        wrapperContract = _wrapperContract;

        // Infinite approve minima contract
        require(
            ERC20(_wrapperContract).approve(_minimaRouter, uint256(-1)),
            "approve failed"
        );
    }

    function cleanup(address token, address recipient) internal {
        uint256 balance = ERC20(token).balanceOf(address(this));
        if (balance > 0) {
            ERC20(token).transfer(recipient, balance);
        }
    }

    function swapMultiExactInputForOutputNativeIn(
        IMinimaRouterV1.MultiSwapPayload calldata details
    ) external payable override returns (uint256[] memory outputAmounts) {
        INative(wrapperContract).deposit{value: msg.value}();
        address outputToken = details.path[details.path.length - 1][
            details.path[details.path.length - 1].length - 1
        ];

        outputAmounts = IMinimaRouterV1(minimaRouter).swapExactInputForOutput(
            details
        );

        // Transfer any tokens that got stuck in the contract
        cleanup(outputToken, msg.sender);
        return outputAmounts;
    }

    function swapMultiExactInputForOutputNativeOut(
        IMinimaRouterV1.MultiSwapPayload calldata details
    ) external override returns (uint256[] memory outputAmounts) {
        // Setup by transfering tokens from sender to the wrapper.  Will later be transferred by router.
        for (uint8 i = 0; i < details.path.length; i++) {
            uint256 inputAmount = details.inputAmounts[i];
            if (inputAmount > 0) {
                address inputToken = details.path[i][0];
                require(
                    ERC20(inputToken).transferFrom(
                        msg.sender,
                        address(this),
                        details.inputAmounts[i]
                    ),
                    "transferFrom failed"
                );
                require(
                    ERC20(inputToken).approve(
                        minimaRouter,
                        details.inputAmounts[i]
                    ),
                    "approve failed"
                );
            }
        }

        // Perform the swap
        outputAmounts = IMinimaRouterV1(minimaRouter).swapExactInputForOutput(
            details
        );

        // Unwrap the wrapped native asset
        uint256 withdrawAmount = ERC20(wrapperContract).balanceOf(
            address(this)
        );
        INative(wrapperContract).withdraw(withdrawAmount);
        payable(msg.sender).transfer(withdrawAmount);
    }

    receive() external payable {}
}
