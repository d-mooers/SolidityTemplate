pragma solidity 0.8.18;

interface IManager {
    function deposit() external payable;

    function toStakedCelo(uint256 celoAmount) external view returns (uint256);
    function toCelo(uint256 stCeloAmount) external view returns (uint256);
}