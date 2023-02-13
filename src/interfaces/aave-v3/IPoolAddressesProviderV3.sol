// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IPoolAddressesProviderV3 {
  function getPool() external view returns (address);
}
