pragma solidity 0.6.8;
pragma experimental ABIEncoderV2;

interface IFarm {
  struct FarmInfo {
    address poolTarget;
    address lpToken;
    address stakingContract;
    address[] underlyingTokens;
  }

  function deposit(uint256 minExpected, address to, bytes calldata data) external returns (uint256 liquidity);
  function withdraw(address to, bytes calldata data) external;
}
