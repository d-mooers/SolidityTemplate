pragma solidity 0.8.18;

import {MockErc20} from "./MockErc20.sol";

contract MockFailingErc20 is MockErc20 {
    constructor(string memory name, string memory symbol)
    public
    MockErc20(name, symbol)
    {}

    function transfer(address recipient, uint256 amount) public override returns(bool){
        super.transfer(recipient, amount);
        return false;
    }
}   