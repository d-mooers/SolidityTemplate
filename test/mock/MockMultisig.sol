pragma solidity 0.6.8;

import {MinimaRouterV1} from "../../src/MinimaRouterV1.sol";

contract MockMultisig {
    constructor() public{}

    function transferMinima(MinimaRouterV1 minima, address newOwner) public {
        minima.transferOwnership(newOwner);
    }
}