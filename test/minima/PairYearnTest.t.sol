pragma solidity ^0.8.12;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {Test} from "forge-std/Test.sol";

import "../../src/minima_contracts/swappa/PairYearn.sol";

import "forge-std/console.sol";

contract PairYearnTest is Test {

    PairYearn public pairYearn = new PairYearn(); 
    address constant private yDAIVaultAddress = 0xACd43E627e64355f1861cEC6d3a6688B31a6F952;
    address constant private DaiAddress = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address constant private DaiWhaleAddress = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address constant private yDaiAddress = 0xACd43E627e64355f1861cEC6d3a6688B31a6F952;

    function setUp() public {
        // Get Dai for test contract
        ERC20 dai = ERC20(DaiAddress);
        vm.prank(DaiWhaleAddress);
        dai.transfer(address(pairYearn), 1e18);

        uint inputAmount = dai.balanceOf(address(pairYearn));
        console.log("Dai balance", inputAmount);
    }


    // Deposit 
    function testSwap2Deposit() public {

        console.log("Deposit ...");

        uint8 inputType = 2;

        bytes memory data = abi.encodePacked(address(yDAIVaultAddress), uint8(inputType));
        
        pairYearn.swap( DaiAddress, yDaiAddress, address(this),data);

        console.log("aToken balance", ERC20(yDaiAddress).balanceOf(address(this)));
        console.log("aToken name", ERC20(yDaiAddress).name());
      
    }

    // Withdraw
    function Swap1Withdraw() public {

        // Deposit 
        console.log("\n Deposit ...");
        uint8 inputType = 2;
        bytes memory data = abi.encodePacked(address(yDAIVaultAddress), uint8(inputType));
        
        pairYearn.swap( DaiAddress, yDaiAddress, address(this),data);

        uint256 yDaiAmount = ERC20(yDaiAddress).balanceOf(address(this));
        console.log("aToken balance", yDaiAmount);
        console.log("aToken name", ERC20(yDaiAddress).name());

        // Withdraw
        console.log("\n Withdraw ...");
        inputType = 1;
        data = abi.encodePacked(address(yDAIVaultAddress), uint8(inputType));

        ERC20(yDaiAddress).transfer(address(pairYearn), yDaiAmount);
        
        pairYearn.swap(yDaiAddress, DaiAddress, address(this),data);

        console.log("Dai balance", ERC20(DaiAddress).balanceOf(address(this)));
        
    }

    function testGetOutputAmount() public view {
        uint8 inputType = 2;

        bytes memory data = abi.encodePacked(address(yDAIVaultAddress), uint8(inputType));
        uint amountIn = 1e18;
        uint256 outputAmount = pairYearn.getOutputAmount( DaiAddress, yDaiAddress,amountIn, data);
        console.log("Dait to Atoken: ",outputAmount );

        /// Widthdraw amount
        inputType = 1;
        data = abi.encodePacked(address(yDAIVaultAddress), uint8(inputType));
        uint256 outputAmountDai = pairYearn.getOutputAmount( yDaiAddress, DaiAddress, outputAmount, data);
        console.log("Atoken to Dai: ", outputAmountDai );

    }


}