pragma solidity 0.6.8;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../interfaces/IFarm.sol";
import "../interfaces/balancerV2/IPairBalancerWeightedVault.sol";

contract DepositBalancerV2 is IFarm {
	using SafeMath for uint;

	function parseDataDeposit(bytes memory data) private pure returns (address vaultAddr, bytes32 poolId) {
		require(data.length == 52, "Invalid call data");

        assembly{
            vaultAddr := mload(add(data, 20))
            poolId := mload(add(data, 52))
        }
	}

    function deposit(uint256 minExpected, address to, bytes calldata data) override external returns (uint256 amountReceived) {
		(address vaultAddr, bytes32 poolId) = parseDataDeposit(data);
		IPairBalancerWeightedVault vault = IPairBalancerWeightedVault(vaultAddr);
        (address poolAddr,) = vault.getPool(poolId);
        ERC20 lpToken = ERC20(poolAddr);

        (ERC20[] memory tokens, , ) = vault.getPoolTokens(poolId);
        uint256[] memory amounts = new uint256[](tokens.length);

		// Will have to be changed to allow for more than 2 tokens per pool
		for (uint256 i = 0; i< tokens.length; i++) {
			amounts[i] = tokens[i].balanceOf(address(this));
			require(tokens[i].approve(vaultAddr, amounts[i]), "PairBalancerV2Deposits: Approval in deposit failed!");
		}

        IPairBalancerWeightedVault.JoinPoolRequest memory request;
        request.assets = tokens;
        request.maxAmountsIn = amounts;
        request.userData = abi.encode(1, amounts, minExpected);

        vault.joinPool(poolId, address(this), address(this), request);
        amountReceived = lpToken.balanceOf(address(this));
        lpToken.approve(to, amountReceived);
        lpToken.transferFrom(address(this), to, amountReceived);
	}

    function withdraw(address to, bytes calldata data) external override{
        (address vaultAddr, bytes32 poolId) = parseDataDeposit(data);
        IPairBalancerWeightedVault vault = IPairBalancerWeightedVault(vaultAddr);
        (address poolAddr,) = vault.getPool(poolId);

        (ERC20[] memory tokens, , ) = vault.getPoolTokens(poolId);
        ERC20 lpToken = ERC20(poolAddr);
        uint256 amount = lpToken.balanceOf(address(this));
        lpToken.approve(poolAddr, amount);
        
        IPairBalancerWeightedVault.ExitPoolRequest memory request;
        request.assets = tokens;
        request.minAmountsOut = new uint256[](tokens.length); //Asking for no minimum out.
        request.userData = abi.encode(1, amount);

        vault.exitPool(poolId, address(this), payable(to), request);
    }

}