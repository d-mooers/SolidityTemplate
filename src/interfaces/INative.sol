// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface INative {
    function deposit() external payable;

    function withdraw(uint256 wad) external;
}
