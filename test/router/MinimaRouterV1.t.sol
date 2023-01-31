pragma solidity 0.6.8;
pragma experimental ABIEncoderV2;

import {MockErc20} from "../mock/MockErc20.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {Test} from "forge-std/Test.sol";

import {MinimaRouterV1} from "../../src/MinimaRouterV1.sol";
import {IMinimaRouterV1} from "../../src/interfaces/IMinimaRouterV1.sol";
import {MockPair} from "../mock/MockPair.sol";
import {MinimaRouterV1External} from "../mock/MinimaRouterV1External.sol";

import "forge-std/console.sol";

import {ExtendedDSTest} from "../utils/ExtendedDSTest.sol";

/*
    Dependency: None
*/
contract MinimaRouterV1Test is ExtendedDSTest {
    uint256 constant NUM_TOKENS = 255;

    MinimaRouterV1 public minimaRouter;
    MockPair public pair;
    MinimaRouterV1External public minimaRouterExternal;

    MockErc20[NUM_TOKENS] public tokens;

    function setUp() public override {
        ExtendedDSTest.setUp();

        address[] memory adminSigners = new address[](1);
        adminSigners[0] = alice;
        minimaRouter = new MinimaRouterV1(alice, adminSigners);
        minimaRouterExternal = new MinimaRouterV1External(alice, adminSigners);

        pair = new MockPair();

        for (uint8 i = 0; i < NUM_TOKENS; i++) {
            MockErc20 token = new MockErc20("TEST TOKEN", Strings.toString(i));
            tokens[i] = token;
            vm.label(
                address(token),
                string(abi.encodePacked("Token ", Strings.toString(i)))
            );
            token.mint(alice, 2**127);
        }
    }

    modifier asUser(address _addr) {
        vm.startPrank(_addr);
        _;
        vm.stopPrank();
    }

    function testSetAdminFailsOnNonAuthorized(address prankster)
        public
        asUser(prankster)
    {
        if (prankster == alice) {
            return;
        }

        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        minimaRouter.setAdmin(prankster, true);
    }

    function testGetPartnerInfoReturns0OnInvalidEcRecover() public {
        uint256 partnerId = 9;
        uint256 deadline = block.timestamp + 1000;
        address tokenIn = address(tokens[0]);
        address tokenOut = address(tokens[1]);
        bytes memory sig = new bytes(65);
        bytes32 message = minimaRouterExternal.prefixed__External(
            keccak256(
                abi.encodePacked(
                    partnerId,
                    deadline,
                    tokenIn,
                    tokenOut,
                    minimaRouterExternal
                )
            )
        );

        sig[64] = 0x01;

        (uint8 v, bytes32 r, bytes32 s) = minimaRouterExternal
            .splitSignature__External(sig);

        // ecrecover should fail if v is not 27 or 28
        assertEq(uint256(v), 1);

        address expectedSigner = ecrecover(message, v, r, s);

        assertEq(expectedSigner, address(0));

        uint256 partnerInfo = minimaRouterExternal.getPartnerInfo__External(
            partnerId,
            deadline,
            tokenIn,
            tokenOut,
            sig
        );

        assertEq(partnerInfo, 0);
    }

    function testSetPartnerFee(uint256 feeNumerator, uint256 partnerId)
        public
        asUser(alice)
    {
        if (feeNumerator > minimaRouter.MAX_PARTNER_FEE()) {
            vm.expectRevert(bytes("MinimaRouter: Fee too high"));
            minimaRouter.setPartnerFee(partnerId, feeNumerator);
        } else {
            minimaRouter.setPartnerFee(partnerId, feeNumerator);
            uint256 newFee = minimaRouter.getPartnerFee(partnerId);
            assertEq(newFee, feeNumerator);
        }
    }

    function testRouteSuccessful(uint8 tradeLen, uint256 inputAmount)
        public
        asUser(alice)
    {
        if (tradeLen < 2) {
            return;
        }

        address[][] memory path = new address[][](1);
        address[][] memory pairs = new address[][](1);
        bytes[][] memory extras = new bytes[][](1);

        uint256[] memory inputAmounts = new uint256[](1); //new uint256[](1);

        IMinimaRouterV1.Divisor[][]
            memory divisors = new IMinimaRouterV1.Divisor[][](0);

        MockErc20 outputToken = tokens[tradeLen - 1];
        MockErc20 inputToken = tokens[0];
        uint256 outputBalanceBefore = outputToken.balanceOf(alice);
        uint256 inputBalanceBefore = inputToken.balanceOf(alice);

        if (inputBalanceBefore < inputAmount) {
            return;
        }
        path[0] = new address[](tradeLen);
        pairs[0] = new address[](tradeLen - 1);
        extras[0] = new bytes[](tradeLen - 1);
        inputAmounts[0] = inputAmount;
        for (uint8 i = 0; i < tradeLen; i++) {
            path[0][i] = address(tokens[i]);

            if (i > 0) {
                pairs[0][i - 1] = address(pair);
                extras[0][i - 1] = new bytes(0);
            }
        }

        IMinimaRouterV1.MultiSwapPayload memory payload = IMinimaRouterV1
            .MultiSwapPayload({
                path: path,
                pairs: pairs,
                extras: extras,
                divisors: divisors,
                inputAmounts: inputAmounts,
                minOutputAmount: inputAmount,
                expectedOutputAmount: inputAmount,
                to: alice,
                deadline: block.timestamp + 10,
                partner: 0,
                sig: new bytes(0)
            });

        inputToken.approve(address(minimaRouter), inputAmount);
        minimaRouter.swapExactInputForOutput(payload);

        uint256 outputBalanceAfter = outputToken.balanceOf(alice);
        uint256 inputBalanceAfter = inputToken.balanceOf(alice);

        assertEq(
            outputBalanceAfter,
            outputBalanceBefore + inputAmount,
            "Insufficent output"
        );
        assertEq(
            inputBalanceAfter,
            inputBalanceBefore - inputAmount,
            "Not enough input taken"
        );
    }

    function testRouteSuccessfulSplit(uint8 tradeLen, uint256 inputAmount)
        public
        asUser(alice)
    {
        if (tradeLen < 4 || inputAmount == 0) {
            return;
        }

        address[][] memory path = new address[][](2);
        address[][] memory pairs = new address[][](2);
        bytes[][] memory extras = new bytes[][](2);

        uint256[] memory inputAmounts = new uint256[](2); //new uint256[](1);

        IMinimaRouterV1.Divisor[][]
            memory divisors = new IMinimaRouterV1.Divisor[][](1);

        MockErc20 outputToken = tokens[tradeLen - 1];
        MockErc20 inputToken = tokens[0];
        uint256 outputBalanceBefore = outputToken.balanceOf(alice);
        uint256 inputBalanceBefore = inputToken.balanceOf(alice);

        if (inputBalanceBefore < inputAmount) {
            return;
        }
        path[0] = new address[]((tradeLen / 2) + 1);
        pairs[0] = new address[](tradeLen / 2);
        extras[0] = new bytes[](tradeLen / 2);
        inputAmounts[0] = inputAmount;
        for (uint8 i = 0; i <= tradeLen / 2; i++) {
            path[0][i] = address(tokens[i]);

            if (i > 0) {
                pairs[0][i - 1] = address(pair);
                extras[0][i - 1] = new bytes(0);
            }
        }
        divisors[0] = new IMinimaRouterV1.Divisor[](1);
        divisors[0][0] = IMinimaRouterV1.Divisor({
            toIdx: 1,
            divisor: 100,
            token: address(tokens[tradeLen / 2])
        });

        path[1] = new address[](tradeLen - tradeLen / 2);
        pairs[1] = new address[]((tradeLen - tradeLen / 2) - 1);
        extras[1] = new bytes[]((tradeLen - tradeLen / 2) - 1);
        for (uint8 i = 0; i < tradeLen - tradeLen / 2; i++) {
            path[1][i] = address(tokens[i + tradeLen / 2]);

            if (i > 0) {
                pairs[1][i - 1] = address(pair);
                extras[1][i - 1] = new bytes(0);
            }
        }

        IMinimaRouterV1.MultiSwapPayload memory payload = IMinimaRouterV1
            .MultiSwapPayload({
                path: path,
                pairs: pairs,
                extras: extras,
                divisors: divisors,
                inputAmounts: inputAmounts,
                minOutputAmount: inputAmount,
                expectedOutputAmount: inputAmount,
                to: alice,
                deadline: block.timestamp + 10,
                partner: 0,
                sig: new bytes(0)
            });

        inputToken.approve(address(minimaRouter), inputAmount);
        minimaRouter.swapExactInputForOutput(payload);

        uint256 outputBalanceAfter = outputToken.balanceOf(alice);
        uint256 inputBalanceAfter = inputToken.balanceOf(alice);

        assertEq(
            outputBalanceAfter,
            outputBalanceBefore + inputAmount,
            "Insufficent output"
        );
        assertEq(
            inputBalanceAfter,
            inputBalanceBefore - inputAmount,
            "Not enough input taken"
        );
    }

    function testRouteFailsWhenDivisorTooHigh(
        uint8 tradeLen,
        uint256 inputAmount
    ) public asUser(alice) {
        if (tradeLen < 4 || inputAmount == 0) {
            return;
        }

        address[][] memory path = new address[][](2);
        address[][] memory pairs = new address[][](2);
        bytes[][] memory extras = new bytes[][](2);

        uint256[] memory inputAmounts = new uint256[](2); //new uint256[](1);

        IMinimaRouterV1.Divisor[][]
            memory divisors = new IMinimaRouterV1.Divisor[][](1);

        MockErc20 outputToken = tokens[tradeLen - 1];
        MockErc20 inputToken = tokens[0];
        uint256 inputBalanceBefore = inputToken.balanceOf(alice);

        if (inputBalanceBefore < inputAmount) {
            return;
        }
        path[0] = new address[]((tradeLen / 2) + 1);
        pairs[0] = new address[](tradeLen / 2);
        extras[0] = new bytes[](tradeLen / 2);
        inputAmounts[0] = inputAmount;
        for (uint8 i = 0; i <= tradeLen / 2; i++) {
            path[0][i] = address(tokens[i]);

            if (i > 0) {
                pairs[0][i - 1] = address(pair);
                extras[0][i - 1] = new bytes(0);
            }
        }
        divisors[0] = new IMinimaRouterV1.Divisor[](1);
        divisors[0][0] = IMinimaRouterV1.Divisor({
            toIdx: 1,
            divisor: 101,
            token: address(tokens[tradeLen / 2])
        });

        path[1] = new address[](tradeLen - tradeLen / 2);
        pairs[1] = new address[]((tradeLen - tradeLen / 2) - 1);
        extras[1] = new bytes[]((tradeLen - tradeLen / 2) - 1);
        for (uint8 i = 0; i < tradeLen - tradeLen / 2; i++) {
            path[1][i] = address(tokens[i + tradeLen / 2]);

            if (i > 0) {
                pairs[1][i - 1] = address(pair);
                extras[1][i - 1] = new bytes(0);
            }
        }

        IMinimaRouterV1.MultiSwapPayload memory payload = IMinimaRouterV1
            .MultiSwapPayload({
                path: path,
                pairs: pairs,
                extras: extras,
                divisors: divisors,
                inputAmounts: inputAmounts,
                minOutputAmount: inputAmount,
                expectedOutputAmount: inputAmount,
                to: alice,
                deadline: block.timestamp + 10,
                partner: 0,
                sig: new bytes(0)
            });

        inputToken.approve(address(minimaRouter), inputAmount);
        vm.expectRevert(bytes("MinimaRouter: Divisor too high"));
        minimaRouter.swapExactInputForOutput(payload);
    }

    function testRouteHandlesDivisor(
        uint8 tradeLen,
        uint256 inputAmount,
        uint8 divisor
    ) public asUser(alice) {
        divisor = divisor % 100;
        if (tradeLen < 4 || inputAmount == 0 || divisor == 0) {
            return;
        }

        IMinimaRouterV1.MultiSwapPayload memory payload = IMinimaRouterV1
            .MultiSwapPayload({
                path: new address[][](2),
                pairs: new address[][](2),
                extras: new bytes[][](2),
                divisors: new IMinimaRouterV1.Divisor[][](1),
                inputAmounts: new uint256[](2),
                minOutputAmount: 0,
                expectedOutputAmount: inputAmount,
                to: alice,
                deadline: block.timestamp + 10,
                partner: 0,
                sig: new bytes(0)
            });
        MockErc20 outputToken;
        MockErc20 inputToken;
        uint256 outputBalanceBefore;
        uint256 inputBalanceBefore;

        {
            outputToken = tokens[tradeLen - 1];
            inputToken = tokens[0];
            outputBalanceBefore = outputToken.balanceOf(alice);
            inputBalanceBefore = inputToken.balanceOf(alice);

            if (inputBalanceBefore < inputAmount) {
                return;
            }
            payload.path[0] = new address[]((tradeLen / 2) + 1);
            payload.pairs[0] = new address[](tradeLen / 2);
            payload.extras[0] = new bytes[](tradeLen / 2);

            for (uint8 i = 0; i <= tradeLen / 2; i++) {
                payload.path[0][i] = address(tokens[i]);

                if (i > 0) {
                    payload.pairs[0][i - 1] = address(pair);
                    payload.extras[0][i - 1] = new bytes(0);
                }
            }
            payload.divisors[0] = new IMinimaRouterV1.Divisor[](1);
            payload.divisors[0][0] = IMinimaRouterV1.Divisor({
                toIdx: 1,
                divisor: divisor,
                token: address(tokens[tradeLen / 2])
            });

            payload.path[1] = new address[](tradeLen - tradeLen / 2);
            payload.pairs[1] = new address[]((tradeLen - tradeLen / 2) - 1);
            payload.extras[1] = new bytes[]((tradeLen - tradeLen / 2) - 1);
            for (uint8 i = 0; i < tradeLen - tradeLen / 2; i++) {
                payload.path[1][i] = address(tokens[i + tradeLen / 2]);

                if (i > 0) {
                    payload.pairs[1][i - 1] = address(pair);
                    payload.extras[1][i - 1] = new bytes(0);
                }
            }
        }

        payload.inputAmounts[0] = inputAmount;
        inputToken.approve(address(minimaRouter), inputAmount);
        minimaRouter.swapExactInputForOutput(payload);

        uint256 outputBalanceAfter = outputToken.balanceOf(alice);
        uint256 inputBalanceAfter = inputToken.balanceOf(alice);

        assertEq(
            outputBalanceAfter,
            outputBalanceBefore + (inputAmount * divisor) / 100,
            "Insufficent output"
        );
        assertEq(
            inputBalanceAfter,
            inputBalanceBefore - inputAmount,
            "Not enough input taken"
        );
    }

    function testGivesExpectedAmountAsMax(uint8 tradeLen, uint256 inputAmount)
        public
        asUser(alice)
    {
        if (tradeLen < 2 || inputAmount < 10) {
            return;
        }

        IMinimaRouterV1.MultiSwapPayload memory payload;
        MockErc20 outputToken;
        MockErc20 inputToken;
        uint256 outputBalanceBefore;
        uint256 inputBalanceBefore;
        {
            address[][] memory path = new address[][](1);
            address[][] memory pairs = new address[][](1);
            bytes[][] memory extras = new bytes[][](1);

            uint256[] memory inputAmounts = new uint256[](1); //new uint256[](1);

            IMinimaRouterV1.Divisor[][]
                memory divisors = new IMinimaRouterV1.Divisor[][](0);

            outputToken = tokens[tradeLen - 1];
            inputToken = tokens[0];
            outputBalanceBefore = outputToken.balanceOf(alice);
            inputBalanceBefore = inputToken.balanceOf(alice);

            if (inputBalanceBefore < inputAmount) {
                return;
            }
            path[0] = new address[](tradeLen);
            pairs[0] = new address[](tradeLen - 1);
            extras[0] = new bytes[](tradeLen - 1);
            inputAmounts[0] = inputAmount;
            for (uint8 i = 0; i < tradeLen; i++) {
                path[0][i] = address(tokens[i]);

                if (i > 0) {
                    pairs[0][i - 1] = address(pair);
                    extras[0][i - 1] = new bytes(0);
                }
            }

            payload = IMinimaRouterV1.MultiSwapPayload({
                path: path,
                pairs: pairs,
                extras: extras,
                divisors: divisors,
                inputAmounts: inputAmounts,
                minOutputAmount: 2,
                expectedOutputAmount: 10,
                to: alice,
                deadline: block.timestamp + 10,
                partner: 0,
                sig: new bytes(0)
            });
        }
        inputToken.approve(address(minimaRouter), inputAmount);
        minimaRouter.swapExactInputForOutput(payload);

        uint256 outputBalanceAfter = outputToken.balanceOf(alice);
        uint256 inputBalanceAfter = inputToken.balanceOf(alice);

        assertEq(
            outputBalanceAfter,
            outputBalanceBefore + 10,
            "Insufficent output"
        );
        assertEq(
            inputBalanceAfter,
            inputBalanceBefore - inputAmount,
            "Not enough input taken"
        );
    }

    function testPassesInbetweenExpectedAndMinimum(
        uint8 tradeLen,
        uint256 inputAmount
    ) public asUser(alice) {
        if (tradeLen < 2 || inputAmount == 0) {
            return;
        }

        address[][] memory path = new address[][](1);
        address[][] memory pairs = new address[][](1);
        bytes[][] memory extras = new bytes[][](1);

        uint256[] memory inputAmounts = new uint256[](1); //new uint256[](1);

        IMinimaRouterV1.Divisor[][]
            memory divisors = new IMinimaRouterV1.Divisor[][](0);

        MockErc20 outputToken = tokens[tradeLen - 1];
        MockErc20 inputToken = tokens[0];
        uint256 outputBalanceBefore = outputToken.balanceOf(alice);
        uint256 inputBalanceBefore = inputToken.balanceOf(alice);

        if (inputBalanceBefore < inputAmount) {
            return;
        }
        path[0] = new address[](tradeLen);
        pairs[0] = new address[](tradeLen - 1);
        extras[0] = new bytes[](tradeLen - 1);
        inputAmounts[0] = inputAmount;
        for (uint8 i = 0; i < tradeLen; i++) {
            path[0][i] = address(tokens[i]);

            if (i > 0) {
                pairs[0][i - 1] = address(pair);
                extras[0][i - 1] = new bytes(0);
            }
        }

        IMinimaRouterV1.MultiSwapPayload memory payload = IMinimaRouterV1
            .MultiSwapPayload({
                path: path,
                pairs: pairs,
                extras: extras,
                divisors: divisors,
                inputAmounts: inputAmounts,
                minOutputAmount: inputAmount - 1,
                expectedOutputAmount: inputAmount + 1,
                to: alice,
                deadline: block.timestamp + 10,
                partner: 0,
                sig: new bytes(0)
            });

        inputToken.approve(address(minimaRouter), inputAmount);
        minimaRouter.swapExactInputForOutput(payload);

        uint256 outputBalanceAfter = outputToken.balanceOf(alice);
        uint256 inputBalanceAfter = inputToken.balanceOf(alice);

        assertEq(
            outputBalanceAfter,
            outputBalanceBefore + inputAmount,
            "Insufficent output"
        );
        assertEq(
            inputBalanceAfter,
            inputBalanceBefore - inputAmount,
            "Not enough input taken"
        );
    }

    function testRevertOnNotEnoughTokens(uint8 tradeLen, uint256 inputAmount)
        public
        asUser(alice)
    {
        if (tradeLen < 2 || inputAmount == 0) {
            return;
        }

        address[][] memory path = new address[][](1);
        address[][] memory pairs = new address[][](1);
        bytes[][] memory extras = new bytes[][](1);

        uint256[] memory inputAmounts = new uint256[](1); //new uint256[](1);

        IMinimaRouterV1.Divisor[][]
            memory divisors = new IMinimaRouterV1.Divisor[][](0);

        MockErc20 outputToken = tokens[tradeLen - 1];
        MockErc20 inputToken = tokens[0];
        uint256 outputBalanceBefore = outputToken.balanceOf(alice);
        uint256 inputBalanceBefore = inputToken.balanceOf(alice);

        if (inputBalanceBefore < inputAmount) {
            return;
        }
        path[0] = new address[](tradeLen);
        pairs[0] = new address[](tradeLen - 1);
        extras[0] = new bytes[](tradeLen - 1);
        inputAmounts[0] = inputAmount;
        for (uint8 i = 0; i < tradeLen; i++) {
            path[0][i] = address(tokens[i]);

            if (i > 0) {
                pairs[0][i - 1] = address(pair);
                extras[0][i - 1] = new bytes(0);
            }
        }

        IMinimaRouterV1.MultiSwapPayload memory payload = IMinimaRouterV1
            .MultiSwapPayload({
                path: path,
                pairs: pairs,
                extras: extras,
                divisors: divisors,
                inputAmounts: inputAmounts,
                minOutputAmount: inputAmount + 1,
                expectedOutputAmount: inputAmount + 1,
                to: alice,
                deadline: block.timestamp + 10,
                partner: 0,
                sig: new bytes(0)
            });

        inputToken.approve(address(minimaRouter), inputAmount);

        vm.expectRevert(bytes("MinimaRouter: Insufficient output"));
        minimaRouter.swapExactInputForOutput(payload);
    }
}
