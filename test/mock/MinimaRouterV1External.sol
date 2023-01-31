pragma solidity 0.6.8;
pragma experimental ABIEncoderV2;

import {MinimaRouterV1} from "../../src/MinimaRouterV1.sol";

// This contract provides external function wrappers for all internal functions in MinimaRouterV1
contract MinimaRouterV1External is MinimaRouterV1 {
    /**
		admin should be a multisig wallet
	 */
    constructor(address admin, address[] memory initialSigners)
        public
        MinimaRouterV1(admin, initialSigners)
    {}

    function splitSignature__External(bytes calldata sig)
        external
        pure
        returns (
            uint8 v,
            bytes32 r,
            bytes32 s
        )
    {
        return splitSignature(sig);
    }

    function prefixed__External(bytes32 hash)
        external
        pure
        returns (bytes32 prefixedHash)
    {
        return prefixed(hash);
    }

    function recoverSigner__External(bytes32 hash, bytes calldata sig)
        external
        pure
        returns (address signer)
    {
        return recoverSigner(hash, sig);
    }

    function getPartnerInfo__External(
        uint256 partnerId,
        uint256 deadline,
        address tokenIn,
        address tokenOut,
        bytes calldata sig
    ) external view returns (uint256) {
        return getPartnerInfo(partnerId, deadline, tokenIn, tokenOut, sig);
    }

    function disperseWithFee__External(
        address output,
        uint256 minOutputAmount,
        uint256 expectedOutput,
        uint256 outputAmount,
        address to,
        uint256 partnerId
    ) external returns (uint256) {
        return
            disperseWithFee(
                output,
                minOutputAmount,
                expectedOutput,
                outputAmount,
                to,
                partnerId
            );
    }

    function updateBalances__External(address output)
        internal
        returns (uint256)
    {
        return updateBalances(output);
    }

    function getDivisorTransferAmounts__External(Divisor[] calldata divisors)
        external
        view
        returns (uint256[] memory)
    {
        return getDivisorTransferAmounts(divisors);
    }
}
