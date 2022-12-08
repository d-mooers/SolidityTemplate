pragma solidity 0.6.8;
pragma experimental ABIEncoderV2;

interface INative {
  function deposit() external payable;
  function withdraw(uint256 wad) external;
}
