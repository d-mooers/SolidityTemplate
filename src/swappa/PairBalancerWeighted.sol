pragma solidity 0.6.8;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../utils/WeightedMath.sol";
import "../interfaces/balancerV2/IPairBalancerWeightedVault.sol";
import "../interfaces/balancerV2/IPairBalancerBaseWeightedPool.sol";
import "./ISwappaPairV1.sol";


contract PairBalancerWeighted is ISwappaPairV1{
    function swap(
            address input,
            address output,
            address to,
            bytes calldata data
        ) external override {
            (address vaultAddr, bytes32 poolId) = parseData(data);
            uint inputAmount = ERC20(input).balanceOf(address(this));
            require(
                ERC20(input).approve(vaultAddr, inputAmount),
                "PairSymmetricSwapV2: approve failed!");

            IPairBalancerWeightedVault vault = IPairBalancerWeightedVault(vaultAddr);

            uint outputAmount;

            IPairBalancerWeightedVault.SingleSwap memory swapData;
            swapData.poolId = poolId;
            swapData.kind = IPairBalancerWeightedVault.SwapKind.GIVEN_IN;
            swapData.assetIn = input;
            swapData.assetOut = output;
            swapData.amount = inputAmount;

            IPairBalancerWeightedVault.FundManagement memory funds;
            funds.sender = address(this);
            funds.fromInternalBalance = false;
            funds.recipient = payable(address(this));
            funds.toInternalBalance = false;
            
            //The limit is set to 0 for the time being, this will need to be fixed!
            outputAmount = vault.swap(swapData, funds, 0, block.timestamp);
            
            require(
                ERC20(output).transfer(to, outputAmount),
                "PairSymmetricSwapV2: transfer failed!");
        }

    function parseData(bytes memory data) public pure returns(address vaultAddr, bytes32 poolId){
        require(data.length == 52, "Invalid call data");

        assembly{
            vaultAddr := mload(add(data, 20))
            poolId := mload(add(data, 52))
        }
    }

    function getAllPoolInfo(bytes memory data) public view returns(IPairBalancerWeightedVault, IPairBalancerBaseWeightedPool, ERC20[] memory, uint256[] memory, uint256[] memory) {
        (address vaultAddr, bytes32 poolId) = parseData(data);

        IPairBalancerWeightedVault vault = IPairBalancerWeightedVault(vaultAddr);
        (address poolAddr,) = vault.getPool(poolId);
        IPairBalancerBaseWeightedPool pool = IPairBalancerBaseWeightedPool(poolAddr);
        
        (ERC20[] memory tokens, uint256[] memory balances,) = vault.getPoolTokens(poolId);
        (uint256[] memory weights) = pool.getNormalizedWeights();
        return(vault, pool, tokens, balances, weights);
    }

    function getTokenBalanceWeightIndex(address tokenToFind, ERC20[] memory tokens, uint256[] memory balances, uint256[] memory weights) public view returns(uint256, uint256, uint256){
        
        for(uint256 tokenIndex = 0; tokenIndex < tokens.length; tokenIndex++){
            if(tokenToFind == address(tokens[tokenIndex])){
                return((balances[tokenIndex], weights[tokenIndex], tokenIndex));
            }
        }
        revert("PairBalancerWeighted: Token not found in token array");
    }

    function calcNoFees(address input, address output, uint256 amountIn, ERC20[] memory tokens, uint256[] memory balances, uint256[] memory weights) public view returns(uint256){
        (uint256 balanceIn, uint256 weightIn,) = getTokenBalanceWeightIndex(input, tokens, balances, weights);
        (uint256 balanceOut, uint256 weightOut,) = getTokenBalanceWeightIndex(output, tokens, balances, weights);

        return WeightedMath.calcOutGivenIn(
            balanceIn,
            weightIn,
            balanceOut,
            weightOut,
            amountIn
        );
    }

    function getOutputAmount(
		address input,
		address output,
		uint amountIn,
		bytes calldata data
	) external view override returns (uint256) {

        (, IPairBalancerBaseWeightedPool pool, ERC20[] memory tokens, uint256[] memory balances, uint256[] memory weights) = getAllPoolInfo(data);
        
        uint256 amountOut = calcNoFees(input, output, amountIn, tokens, balances, weights);

        return amountOut - WeightedMath.calcSwapFee(amountOut, pool.getSwapFeePercentage());
	}

    function getPoolSpecialization(bytes32 poolId) external pure returns (uint256 specialization) {
        // 10 byte logical shift left to remove the nonce, followed by a 2 byte mask to remove the address.
        uint256 value = uint256(poolId >> (10 * 8)) & (2**(2 * 8) - 1);

        // Casting a value into an enum results in a runtime check that reverts unless the value is within the enum's
        // range. Passing an invalid Pool ID to this function would then result in an obscure revert with no reason
        // string: we instead perform the check ourselves to help in error diagnosis.

        // There are three Pool specialization settings: general, minimal swap info and two tokens, which correspond to
        // values 0, 1 and 2.
        require(value < 3, "Invalid poolId");

        // Because we have checked that `value` is within the enum range, we can use assembly to skip the runtime check.
        // solhint-disable-next-line no-inline-assembly
        assembly {
            specialization := value
        }
    }



	receive() external payable {}
}