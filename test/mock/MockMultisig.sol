pragma solidity 0.8.18;

import {MinimaRouterV1} from "../../src/MinimaRouterV1.sol";

contract MockMultisig {
    constructor() public{}

    function transferMinima(MinimaRouterV1 minima, address newOwner) public {
        minima.transferOwnership(newOwner);
    }
}