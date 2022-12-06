// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../src/Contract.sol";
import "forge-std/Test.sol";

contract ContractTest is DSTest { 
    Contract public sContract;

    function setUp() public {
        sContract = new Contract(10);
    }

    function testGetAmount() public {
        uint  value;
        value = sContract.getAmount();
        assertEq(value, 10);
    }
}
