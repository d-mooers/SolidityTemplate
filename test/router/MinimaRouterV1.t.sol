pragma solidity 0.6.8;
pragma experimental ABIEncoderV2;

import {MockErc20} from "../mock/MockErc20.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {Test} from "forge-std/Test.sol";

import {MinimaRouterV1} from "../../src/MinimaRouterV1.sol";
import {ISwappaRouterV1} from "../../src/interfaces/ISwappaRouterV1.sol";
import {MockPair} from "../mock/MockPair.sol";

import "forge-std/console.sol";

import {ExtendedDSTest} from "../utils/ExtendedDSTest.sol";

/*
    Dependency: None
*/
contract MinimaRouterV1Test is ExtendedDSTest {
    uint256 constant NUM_TOKENS = 255;

    MinimaRouterV1 public minimaRouter;
    MockPair public pair;
    MockErc20[NUM_TOKENS] public tokens;

    function setUp() public override {
        ExtendedDSTest.setUp();

        address[] memory adminSigners = new address[](1);
        adminSigners[0] = alice;
        minimaRouter = new MinimaRouterV1(alice, adminSigners);

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

        address[] memory path = new address[](tradeLen);
        address[] memory pairs = new address[](tradeLen - 1);
        bytes[] memory extras = new bytes[](tradeLen - 1);

        MockErc20 outputToken = tokens[tradeLen - 1];
        MockErc20 inputToken = tokens[0];
        uint256 outputBalanceBefore = outputToken.balanceOf(alice);
        uint256 inputBalanceBefore = inputToken.balanceOf(alice);

        if (inputBalanceBefore < inputAmount) {
            return;
        }

        for (uint8 i = 0; i < tradeLen; i++) {
            path[i] = address(tokens[i]);

            if (i > 0) {
                pairs[i - 1] = address(pair);
                extras[i - 1] = new bytes(0);
            }
        }

        ISwappaRouterV1.SwapPayload memory payload = ISwappaRouterV1
            .SwapPayload({
                path: path,
                pairs: pairs,
                extras: extras,
                inputAmount: inputAmount,
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

    function testGivesExpectedAmountAsMax(uint8 tradeLen, uint256 inputAmount)
        public
        asUser(alice)
    {
        if (tradeLen < 2 || inputAmount < 10) {
            return;
        }

        address[] memory path = new address[](tradeLen);
        address[] memory pairs = new address[](tradeLen - 1);
        bytes[] memory extras = new bytes[](tradeLen - 1);

        MockErc20 outputToken = tokens[tradeLen - 1];
        MockErc20 inputToken = tokens[0];
        uint256 outputBalanceBefore = outputToken.balanceOf(alice);
        uint256 inputBalanceBefore = inputToken.balanceOf(alice);
        if (inputBalanceBefore < inputAmount) {
            return;
        }

        for (uint8 i = 0; i < tradeLen; i++) {
            path[i] = address(tokens[i]);
            uint256 exchangeRate = 2 * 10**10;

            if (i > 0) {
                pairs[i - 1] = address(pair);
                extras[i - 1] = abi.encodePacked(exchangeRate);
            }
        }

        ISwappaRouterV1.SwapPayload memory payload = ISwappaRouterV1
            .SwapPayload({
                path: path,
                pairs: pairs,
                extras: extras,
                inputAmount: inputAmount,
                minOutputAmount: 9,
                expectedOutputAmount: 10,
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

        address[] memory path = new address[](tradeLen);
        address[] memory pairs = new address[](tradeLen - 1);
        bytes[] memory extras = new bytes[](tradeLen - 1);

        MockErc20 outputToken = tokens[tradeLen - 1];
        MockErc20 inputToken = tokens[0];
        uint256 outputBalanceBefore = outputToken.balanceOf(alice);
        uint256 inputBalanceBefore = inputToken.balanceOf(alice);

        if (inputBalanceBefore < inputAmount) {
            return;
        }

        for (uint8 i = 0; i < tradeLen; i++) {
            path[i] = address(tokens[i]);

            if (i > 0) {
                pairs[i - 1] = address(pair);
                extras[i - 1] = new bytes(0);
            }
        }

        ISwappaRouterV1.SwapPayload memory payload = ISwappaRouterV1
            .SwapPayload({
                path: path,
                pairs: pairs,
                extras: extras,
                inputAmount: inputAmount,
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

        address[] memory path = new address[](tradeLen);
        address[] memory pairs = new address[](tradeLen - 1);
        bytes[] memory extras = new bytes[](tradeLen - 1);

        MockErc20 inputToken = tokens[0];
        uint256 inputBalanceBefore = inputToken.balanceOf(alice);

        if (inputBalanceBefore < inputAmount) {
            return;
        }

        for (uint8 i = 0; i < tradeLen; i++) {
            path[i] = address(tokens[i]);

            if (i > 0) {
                pairs[i - 1] = address(pair);
                extras[i - 1] = new bytes(0);
            }
        }

        ISwappaRouterV1.SwapPayload memory payload = ISwappaRouterV1
            .SwapPayload({
                path: path,
                pairs: pairs,
                extras: extras,
                inputAmount: inputAmount,
                minOutputAmount: inputAmount + 1,
                expectedOutputAmount: inputAmount + 1,
                to: alice,
                deadline: block.timestamp + 10,
                partner: 0,
                sig: new bytes(0)
            });

        inputToken.approve(address(minimaRouter), inputAmount);

        vm.expectRevert(bytes("MinimaRouter: Insufficient output amount!"));
        minimaRouter.swapExactInputForOutput(payload);
    }
}
