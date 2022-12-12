// SPDX-License-Identifier: MIT
pragma solidity 0.6.8;

interface IPoolAddressesProviderV3 {
  function getPool() external view returns (address);
}
