// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.1;

contract Contract {
    uint private counter;
    constructor(uint _counter ) {
        counter = _counter;
    }

    function getAmount() view external returns(uint){
        return counter;
    }
}

