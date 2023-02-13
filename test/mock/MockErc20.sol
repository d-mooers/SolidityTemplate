pragma solidity 0.8.18;

import {ERC20} from "@openzeppelin08/contracts/token/ERC20/ERC20.sol";

contract MockErc20 is ERC20 {
    constructor(string memory name, string memory symbol)
        public
        ERC20(name, symbol)
    {}

    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }

    function freeTransfer(address account, uint256 amount) external virtual{
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) external {
        _burn(account, amount);
    }
}
