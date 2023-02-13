pragma solidity 0.8.18;

import "@openzeppelin08/contracts/token/ERC20/ERC20.sol";

import {Test} from "forge-std/Test.sol";

import "../../src/pairs/PairYearn.sol";

import "forge-std/console.sol";

import {ExtendedDSTest} from "../utils/ExtendedDSTest.sol";

/*
    Dependency: Yearn protocol
    chain: Ethereum

    This test will fail unless ran on Eth or on a local fork of Eth
*/
contract PairYearnTest is ExtendedDSTest {
    PairYearn public pairYearn = new PairYearn();
    address private constant yDAIVaultAddress =
        0xACd43E627e64355f1861cEC6d3a6688B31a6F952;
    address private constant DaiAddress =
        0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address private constant DaiWhaleAddress =
        0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address private constant yDaiAddress =
        0xACd43E627e64355f1861cEC6d3a6688B31a6F952;

    // Used for integer approximation
    uint256 public constant DELTA = 10**5;

    function setUp() public override {
        ExtendedDSTest.setUp();
        // Get Dai for test contract
        ERC20 dai = ERC20(DaiAddress);
        vm.prank(DaiWhaleAddress);
        dai.transfer(address(pairYearn), 1e18);

        uint256 inputAmount = dai.balanceOf(address(pairYearn));
        console.log("Dai balance of pairYearn", inputAmount);
    }

    // Deposit
    function testSwap2Deposit() public {
        console.log("Deposit ...");

        uint8 inputType = 2;

        bytes memory data = abi.encodePacked(
            address(yDAIVaultAddress),
            uint8(inputType)
        );

        pairYearn.swap(DaiAddress, yDaiAddress, address(this), data);

        uint256 aTokenBalance = ERC20(yDaiAddress).balanceOf(address(this));
        console.log("aToken balance", aTokenBalance);
        console.log("aToken name", ERC20(yDaiAddress).name());

        assertRelApproxEq(aTokenBalance, 865784266049519476, DELTA);
    }

    // Withdraw
    function testswap1Withdraw() public {
        // Deposit
        console.log("\n Deposit ...");
        uint8 inputType = 2;
        bytes memory data = abi.encodePacked(
            address(yDAIVaultAddress),
            uint8(inputType)
        );

        pairYearn.swap(DaiAddress, yDaiAddress, address(this), data);

        uint256 yDaiAmount = ERC20(yDaiAddress).balanceOf(address(this));
        console.log("aToken balance", yDaiAmount);
        console.log("aToken name", ERC20(yDaiAddress).name());

        // Withdraw
        console.log("\n Withdraw ...");
        inputType = 1;
        data = abi.encodePacked(address(yDAIVaultAddress), uint8(inputType));

        ERC20(yDaiAddress).transfer(address(pairYearn), yDaiAmount);

        pairYearn.swap(yDaiAddress, DaiAddress, address(this), data);

        uint256 daiBalance = ERC20(DaiAddress).balanceOf(address(this));
        console.log("Dai balance", daiBalance);
        assertEq(daiBalance, 999999999999999999);
    }

    function testGetOutputAmount() public {
        uint8 inputType = 2;

        bytes memory data = abi.encodePacked(
            address(yDAIVaultAddress),
            uint8(inputType)
        );
        uint256 amountIn = 1e18;
        uint256 outputAmount = pairYearn.getOutputAmount(
            DaiAddress,
            yDaiAddress,
            amountIn,
            data
        );
        console.log("Dait to Atoken: ", outputAmount);
        assertRelApproxEq(outputAmount, 865784266049519476, DELTA);

        /// Widthdraw amount
        inputType = 1;
        data = abi.encodePacked(address(yDAIVaultAddress), uint8(inputType));
        uint256 outputAmountDai = pairYearn.getOutputAmount(
            yDaiAddress,
            DaiAddress,
            outputAmount,
            data
        );
        console.log("Atoken to Dai: ", outputAmountDai);
        assertRelApproxEq(outputAmountDai, 999999999999999999, DELTA);
    }
}
