pragma solidity ^0.6.4;
pragma experimental ABIEncoderV2;

import "../interfaces/ISwappaRouterV1.sol";
import "../interfaces/IFarm.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract OneClickFarm {
    function oneClickDeposit(
        ISwappaRouterV1.SwapPayload[] calldata details,
        address router,
        address depositPairAddr,
        uint256 minExpected,
        address to,
        bytes calldata data
    ) external {
        for (uint8 i = 0; i < details.length; i++) {
            ERC20 token = ERC20(details[i].path[0]);

            if (details[i].path.length == 1) {
                require(
                    token.transferFrom(
                        msg.sender,
                        depositPairAddr,
                        details[i].inputAmount
                    ),
                    "OneClickFarm: Initial transfer failed"
                );
            } else {
                require(
                    token.transferFrom(
                        msg.sender,
                        address(this),
                        details[i].inputAmount
                    ),
                    "OneClickFarm: Initial transfer failed"
                );
                require(
                    token.approve(router, details[i].inputAmount),
                    "OneClickFarm: Initial approval failed"
                );
                ISwappaRouterV1(router).swapExactInputForOutput(details[i]);
            }
        }
        IFarm(depositPairAddr).deposit(minExpected, to, data);
    }
}
