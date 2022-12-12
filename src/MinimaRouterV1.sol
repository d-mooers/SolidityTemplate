// SPDX-License-Identifier: MIT
pragma solidity 0.6.8;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./interfaces/ISwappaPairV1.sol";
import "./interfaces/ISwappaRouterV1.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./interfaces/IFarm.sol";
import "./interfaces/INative.sol";

contract MinimaRouterV1 is ISwappaRouterV1, Ownable {
    using SafeMath for uint256;

    mapping(address => bool) private adminSigner;
    mapping(uint256 => uint256) private partnerFees;
    mapping(uint256 => address) private partnerAdmin;

    // Maximum fee that a partner can set is 5%
    // Minima takes no additional fee - fee is only taken by partners who integrate
    uint256 public constant MAX_PARTNER_FEE = 5 * 10**8;
    uint256 public constant FEE_DENOMINATOR = 10**10;

    uint256[49] private __GAP; // gap for upgrade safety

    event Swap(
        address indexed sender,
        address to,
        address indexed input,
        address output,
        uint256 inputAmount,
        uint256 outputAmount,
        uint256 indexed tenantId
    );

    event MultiSwap(
        address indexed sender,
        address to,
        address input,
        address output,
        uint256[] inputAmounts,
        uint256 outputAmount,
        uint256 indexed tenantId
    );

    event FeeChanged(
        uint256 indexed partnerId,
        address indexed initiator,
        bool indexed isAdminFee,
        uint256 oldFee,
        uint256 newFee
    );

    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, "SwappaRouter: Expired!");
        _;
    }

    modifier partnerAuthorized(uint256 partnerId) {
        require(
            adminSigner[msg.sender] || partnerAdmin[partnerId] == msg.sender,
            "Unauthorized"
        );
        _;
    }

    modifier onlyAdmin() {
        require(
            adminSigner[msg.sender] || msg.sender == owner(),
            "Unauthorized"
        );
        _;
    }

    /**
		admin should be a multisig wallet
	 */
    constructor(address admin, address[] memory initialSigners)
        public
        Ownable()
    {
        transferOwnership(admin);

        // Make the null tenant the admin wallet
        partnerAdmin[0] = admin;
        partnerFees[0] = 0;

        // Add the initial signers
        for (uint8 i = 0; i < initialSigners.length; i++) {
            adminSigner[initialSigners[i]] = true;
        }
    }

    function recoverAdminFee(address token, address reciever)
        external
        onlyAdmin
    {
        uint256 toClaim = IERC20(token).balanceOf(address(this));
        IERC20(token).transfer(reciever, toClaim);
    }

    function splitSignature(bytes memory sig)
        internal
        pure
        returns (
            uint8,
            bytes32,
            bytes32
        )
    {
        require(sig.length == 65, "signature is not 65 bytes");

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            // first 32 bytes, after the length prefix
            r := mload(add(sig, 32))
            // second 32 bytes
            s := mload(add(sig, 64))
            // final byte (first byte of the next 32 bytes)
            v := byte(0, mload(add(sig, 96)))
        }

        return (v, r, s);
    }

    function setAdmin(address addr, bool isAdmin) external onlyOwner {
        adminSigner[addr] = isAdmin;
    }

    function setPartnerAdmin(uint256 partnerId, address admin)
        external
        partnerAuthorized(partnerId)
    {
        partnerAdmin[partnerId] = admin;
    }

    function setPartnerFee(uint256 partnerId, uint256 feeNumerator)
        external
        partnerAuthorized(partnerId)
    {
        require(feeNumerator <= MAX_PARTNER_FEE, "MinimaRouter: Fee too high");
        uint256 oldFee = partnerFees[partnerId];
        partnerFees[partnerId] = feeNumerator;
        emit FeeChanged(partnerId, msg.sender, false, oldFee, feeNumerator);
    }

    // Builds a prefixed hash to mimic the behavior of eth_sign.
    function prefixed(bytes32 hash) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked("\x19Ethereum Signed Message:\n32", hash)
            );
    }

    function recoverSigner(bytes32 message, bytes memory sig)
        internal
        pure
        returns (address)
    {
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = splitSignature(sig);

        return ecrecover(message, v, r, s);
    }

    function getFees(uint256 partnerId)
        external
        view
        returns (uint256[2] memory)
    {
        return [partnerFees[partnerId], 0];
    }

    function getPartnerFee(uint256 partnerId) external view returns (uint256) {
        return partnerFees[partnerId];
    }

    function getPartnerInfo(
        uint256 partnerId,
        uint256 deadline,
        address tokenIn,
        address tokenOut,
        bytes memory sig
    ) internal view returns (uint256 partner) {
        if (sig.length != 65) return 0; // Allow for unauthorized swaps, default to null tenant

        bytes32 message = prefixed(
            keccak256(abi.encodePacked(partnerId, deadline, tokenIn, tokenOut))
        );
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = splitSignature(sig);
        address signer = ecrecover(message, v, r, s);

        if (adminSigner[signer]) {
            return partnerId;
        }
        return 0;
    }

    function getOutputAmount(
        address[] calldata path,
        address[] calldata pairs,
        bytes[] calldata extras,
        uint256 inputAmount
    ) external view override returns (uint256 outputAmount) {
        outputAmount = inputAmount;
        for (uint256 i; i < pairs.length; i++) {
            outputAmount = ISwappaPairV1(pairs[i]).getOutputAmount(
                path[i],
                path[i + 1],
                outputAmount,
                extras[i]
            );
        }
    }

    function disperseWithFee(
        address output,
        uint256 minOutputAmount,
        uint256 expectedOutput,
        uint256 outputAmount,
        address to,
        uint256 partnerId
    ) internal returns (uint256) {
        uint256 partnerFee = outputAmount.mul(partnerFees[partnerId]).div(
            FEE_DENOMINATOR
        );
        outputAmount = outputAmount.sub(partnerFee);
        outputAmount = outputAmount < expectedOutput
            ? outputAmount
            : expectedOutput; // Capture positive slippage

        require(
            outputAmount >= minOutputAmount,
            "MinimaRouter: Insufficient output amount!"
        );

        require(
            ERC20(output).transfer(to, outputAmount),
            "MinimaRouter: Final transfer failed!"
        );

        if (
            partnerFee > 0 &&
            !ERC20(output).transfer(partnerAdmin[partnerId], partnerFee)
        ) {
            revert("MinimaRouter: Partner fee transfer failed");
        }

        return outputAmount;
    }

    function swapMultiExactInputForOutputNativeIn(
        MultiSwapPayload calldata details,
        address wrappedAddr
    ) external payable override returns (uint256[] memory) {
        require(details.deadline >= block.timestamp, "SwappaRouter: Expired!");
        require(
            details.path.length == details.pairs.length,
            "MinimaRouter: Path and Pairs mismatch!"
        );
        require(
            details.pairs.length == details.extras.length,
            "MinimaRouter: Pairs and Extras mismatch!"
        );
        require(
            details.pairs.length > 0,
            "MinimaRouter: Must have at least one pair!"
        );

        INative(wrappedAddr).deposit{value: msg.value}();
        uint256 usedWrapped = 0;

        for (uint256 i = 0; i < details.path.length; i++) {
            address output = details.path[i][details.path[i].length - 1];

            uint256 outputBalanceBefore = ERC20(output).balanceOf(
                address(this)
            );
            if (output == wrappedAddr) {
                outputBalanceBefore -= details.inputAmounts[i]; //If output is the wrapped token, we are taking the balance after that deposit happens
            }

            require(
                ERC20(wrappedAddr).transferFrom(
                    address(this),
                    details.pairs[i][0],
                    details.inputAmounts[i]
                ),
                "MinimaRouter: Wrapped transferfrom failed!"
            );

            usedWrapped += details.inputAmounts[i];
            require(
                usedWrapped <= msg.value,
                "MinimaRouter: Attempt to use more wrapped token the provided native token."
            );

            for (uint256 j; j < details.pairs[i].length; j++) {
                (address pairInput, address pairOutput) = (
                    details.path[i][j],
                    details.path[i][j + 1]
                );
                address next = j < details.pairs[i].length - 1
                    ? details.pairs[i][j + 1]
                    : (
                        details.forwardTo[i] == 0
                            ? address(this)
                            : details.pairs[details.forwardTo[i]][0]
                    );
                bytes memory data = details.extras[i][j];
                ISwappaPairV1(details.pairs[i][j]).swap(
                    pairInput,
                    pairOutput,
                    next,
                    data
                );
            }

            uint256 partnerId = getPartnerInfo(
                details.partner,
                details.deadline,
                details.path[i][0],
                output,
                details.sig
            );
            uint256 outputAmount = disperseWithFee(
                output,
                details.minOutputAmount,
                details.expectedOutputAmount,
                ERC20(output).balanceOf(address(this)) - outputBalanceBefore,
                details.to,
                partnerId
            );
            emit Swap(
                msg.sender,
                details.to,
                details.path[i][0],
                output,
                details.inputAmounts[i],
                outputAmount,
                partnerId
            );
        }
    }

    function swapMultiExactInputForOutputNativeOut(
        MultiSwapPayload calldata details,
        address wrappedAddr
    ) external override returns (uint256[] memory) {
        require(details.deadline >= block.timestamp, "SwappaRouter: Expired!");
        require(
            details.path.length == details.pairs.length,
            "MinimaRouter: Path and Pairs mismatch!"
        );
        require(
            details.pairs.length == details.extras.length,
            "MinimaRouter: Pairs and Extras mismatch!"
        );
        require(
            details.pairs.length > 0,
            "MinimaRouter: Must have at least one pair!"
        );

        uint256 withdrawAmount;

        for (uint256 i = 0; i < details.path.length; i++) {
            uint256 wrappedBalanceBefore = ERC20(wrappedAddr).balanceOf(
                address(this)
            );

            require(
                ERC20(details.path[i][0]).transferFrom(
                    msg.sender,
                    details.pairs[i][0],
                    details.inputAmounts[i]
                ),
                "MinimaRouter: Initial transferFrom failed!"
            );

            for (uint256 j; j < details.pairs[i].length; j++) {
                (address pairInput, address pairOutput) = (
                    details.path[i][j],
                    details.path[i][j + 1]
                );
                address next = j < details.pairs[i].length - 1
                    ? details.pairs[i][j + 1]
                    : (
                        details.forwardTo[i] == 0
                            ? address(this)
                            : details.pairs[details.forwardTo[i]][0]
                    );
                bytes memory data = details.extras[i][j];
                ISwappaPairV1(details.pairs[i][j]).swap(
                    pairInput,
                    pairOutput,
                    next,
                    data
                );
            }
            uint256 wrappedBalanceAfter = ERC20(wrappedAddr).balanceOf(
                address(this)
            );

            uint256 partnerId = getPartnerInfo(
                details.partner,
                details.deadline,
                details.path[i][0],
                wrappedAddr,
                details.sig
            );
            //Output is always the wrapped address, we are capturing positive slippage with that then unwrapping the output amount and transfering that to the user.
            uint256 outputAmount = disperseWithFee(
                wrappedAddr,
                details.minOutputAmount,
                details.expectedOutputAmount,
                wrappedBalanceAfter - wrappedBalanceBefore,
                address(this),
                partnerId
            );
            withdrawAmount += outputAmount;
            emit Swap(
                msg.sender,
                details.to,
                details.path[i][0],
                wrappedAddr,
                details.inputAmounts[i],
                outputAmount,
                partnerId
            );
        }
        INative(wrappedAddr).withdraw(withdrawAmount);
        payable(address(details.to)).transfer(withdrawAmount);
    }

    function swapMultiExactInputForOutput(MultiSwapPayload calldata details)
        external
        override
        returns (uint256[] memory)
    {
        require(details.deadline >= block.timestamp, "SwappaRouter: Expired!");
        require(
            details.path.length == details.pairs.length,
            "MinimaRouter: Path and Pairs mismatch!"
        );
        require(
            details.pairs.length == details.extras.length,
            "MinimaRouter: Pairs and Extras mismatch!"
        );
        require(
            details.pairs.length > 0,
            "MinimaRouter: Must have at least one pair!"
        );

        for (uint256 i = 0; i < details.path.length; i++) {
            require(
                ERC20(details.path[i][0]).transferFrom(
                    msg.sender,
                    details.pairs[i][0],
                    details.inputAmounts[i]
                ),
                "MinimaRouter: Initial transferFrom failed!"
            );
            address output = details.path[i][details.path[i].length - 1];
            uint256 outputBalanceBefore = ERC20(output).balanceOf(
                address(this)
            );
            address receiver = details.forwardTo[i] == 0
                ? address(this)
                : details.pairs[details.forwardTo[i]][0];

            for (uint256 j; j < details.pairs[i].length; j++) {
                (address pairInput, address pairOutput) = (
                    details.path[i][j],
                    details.path[i][j + 1]
                );
                address next = j < details.pairs[i].length - 1
                    ? details.pairs[i][j + 1]
                    : receiver;
                bytes memory data = details.extras[i][j];
                ISwappaPairV1(details.pairs[i][j]).swap(
                    pairInput,
                    pairOutput,
                    next,
                    data
                );
            }

            uint256 tradeOutput = ERC20(output).balanceOf(address(this)) -
                outputBalanceBefore;
            uint256 partnerId = getPartnerInfo(
                details.partner,
                details.deadline,
                details.path[0][0],
                output,
                details.sig
            );
            uint256 outputAmount = disperseWithFee(
                output,
                details.minOutputAmount,
                details.expectedOutputAmount,
                tradeOutput,
                details.to,
                partnerId
            );
            emit Swap(
                msg.sender,
                details.to,
                details.path[i][0],
                output,
                details.inputAmounts[i],
                outputAmount,
                partnerId
            );
        }
    }

    function swapExactInputForOutput(SwapPayload calldata details)
        external
        override
        ensure(details.deadline)
        returns (uint256 outputAmount)
    {
        require(
            details.path.length == details.pairs.length + 1,
            "MinimaRouter: Path and Pairs mismatch!"
        );
        require(
            details.pairs.length == details.extras.length,
            "MinimaRouter: Pairs and Extras mismatch!"
        );
        require(
            details.pairs.length > 0,
            "MinimaRouter: Must have at least one pair!"
        );

        require(
            ERC20(details.path[0]).transferFrom(
                msg.sender,
                details.pairs[0],
                details.inputAmount
            ),
            "MinimaRouter: Initial transferFrom failed!"
        );
        address output = details.path[details.path.length - 1];
        uint256 outputBalanceBefore = ERC20(output).balanceOf(address(this));
        for (uint256 i; i < details.pairs.length; i++) {
            (address pairInput, address pairOutput) = (
                details.path[i],
                details.path[i + 1]
            );
            address next = i < details.pairs.length - 1
                ? details.pairs[i + 1]
                : address(this);
            bytes memory data = details.extras[i];
            ISwappaPairV1(details.pairs[i]).swap(
                pairInput,
                pairOutput,
                next,
                data
            );
        }
        uint256 tradeOutput = ERC20(output).balanceOf(address(this)) -
            outputBalanceBefore;
        uint256 partnerId = getPartnerInfo(
            details.partner,
            details.deadline,
            details.path[0],
            output,
            details.sig
        );
        outputAmount = disperseWithFee(
            output,
            details.minOutputAmount,
            details.expectedOutputAmount,
            tradeOutput,
            details.to,
            partnerId
        );
        emit Swap(
            msg.sender,
            details.to,
            details.path[0],
            output,
            details.inputAmount,
            outputAmount,
            partnerId
        );
    }

    function swapExactInputForOutputNativeIn(
        SwapPayload calldata details,
        address wrappedAddr
    )
        external
        payable
        override
        ensure(details.deadline)
        returns (uint256 outputAmount)
    {
        require(
            details.path.length == details.pairs.length + 1,
            "MinimaRouter: Path and Pairs mismatch!"
        );
        require(
            details.pairs.length == details.extras.length,
            "MinimaRouter: Pairs and Extras mismatch!"
        );
        require(
            details.pairs.length > 0,
            "MinimaRouter: Must have at least one pair!"
        );

        uint256 outputBalanceBefore;
        uint256 wrappedBalanceBefore;
        uint256 wrappedBalanceAfter;
        address output = details.path[details.path.length - 1];

        wrappedBalanceBefore = ERC20(wrappedAddr).balanceOf(address(this));
        INative(wrappedAddr).deposit{value: msg.value}();
        wrappedBalanceAfter = ERC20(wrappedAddr).balanceOf(address(this));
        ERC20(wrappedAddr).transferFrom(
            address(this),
            details.pairs[0],
            wrappedBalanceAfter - wrappedBalanceBefore
        );

        for (uint256 i; i < details.pairs.length; i++) {
            (address pairInput, address pairOutput) = (
                details.path[i],
                details.path[i + 1]
            );
            address next = i < details.pairs.length - 1
                ? details.pairs[i + 1]
                : address(this);
            bytes memory data = details.extras[i];
            ISwappaPairV1(details.pairs[i]).swap(
                pairInput,
                pairOutput,
                next,
                data
            );
        }

        uint256 tradeOutput = ERC20(output).balanceOf(address(this)) -
            outputBalanceBefore;

        uint256 partnerId = getPartnerInfo(
            details.partner,
            details.deadline,
            details.path[0],
            output,
            details.sig
        );
        outputAmount = disperseWithFee(
            output,
            details.minOutputAmount,
            details.expectedOutputAmount,
            tradeOutput,
            details.to,
            partnerId
        );
        emit Swap(
            msg.sender,
            details.to,
            details.path[0],
            output,
            details.inputAmount,
            outputAmount,
            partnerId
        );
    }

    function swapExactInputForOutputNativeOut(
        SwapPayload calldata details,
        address wrappedAddr
    )
        external
        override
        ensure(details.deadline)
        returns (uint256 outputAmount)
    {
        require(
            details.path.length == details.pairs.length + 1,
            "MinimaRouter: Path and Pairs mismatch!"
        );
        require(
            details.pairs.length == details.extras.length,
            "MinimaRouter: Pairs and Extras mismatch!"
        );
        require(
            details.pairs.length > 0,
            "MinimaRouter: Must have at least one pair!"
        );

        uint256 wrappedBalanceBefore = ERC20(wrappedAddr).balanceOf(
            address(this)
        );
        address output = details.path[details.path.length - 1];

        require(
            ERC20(details.path[0]).transferFrom(
                msg.sender,
                details.pairs[0],
                details.inputAmount
            ),
            "MinimaRouter: Initial transferFrom failed!"
        );

        for (uint256 i; i < details.pairs.length; i++) {
            (address pairInput, address pairOutput) = (
                details.path[i],
                details.path[i + 1]
            );
            address next = i < details.pairs.length - 1
                ? details.pairs[i + 1]
                : address(this);
            bytes memory data = details.extras[i];
            ISwappaPairV1(details.pairs[i]).swap(
                pairInput,
                pairOutput,
                next,
                data
            );
        }

        uint256 tradeOutput = ERC20(wrappedAddr).balanceOf(address(this)) -
            wrappedBalanceBefore;
        uint256 partnerId = getPartnerInfo(
            details.partner,
            details.deadline,
            details.path[0],
            output,
            details.sig
        );
        //Capture the slippage in the wrapped token, not the native.
        outputAmount = disperseWithFee(
            wrappedAddr,
            details.minOutputAmount,
            details.expectedOutputAmount,
            tradeOutput,
            address(this),
            partnerId
        );
        emit Swap(
            msg.sender,
            details.to,
            details.path[0],
            output,
            details.inputAmount,
            outputAmount,
            partnerId
        );
        INative(wrappedAddr).withdraw(outputAmount);
        payable(address(details.to)).transfer(outputAmount);
    }

    receive() external payable {}
}
