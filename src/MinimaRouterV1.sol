// SPDX-License-Identifier: MIT
pragma solidity 0.6.8;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./interfaces/ISwappaPairV1.sol";
import "./interfaces/IMinimaRouterV1.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./interfaces/IFarm.sol";
import "./interfaces/INative.sol";

contract MinimaRouterV1 is IMinimaRouterV1, Ownable {
    using SafeMath for uint256;

    // Tracks signers for approving routes
    mapping(address => bool) private adminSigner;

    // Tracks fees for partners.  Fee is calculated as fee / FEE_DENOMINATOR
    mapping(uint256 => uint256) private partnerFees;

    // Tracks wallets that can control fee for a given partner
    mapping(uint256 => address) private partnerAdmin;

    // Tracks internal balances
    mapping(address => uint256) private outputBalancesBefore; //token => amount

    // Maximum fee that a partner can set is 5%
    // Minima takes no additional fee - fee is only taken by partners who integrate
    uint256 public constant MAX_PARTNER_FEE = 5 * 10**8;
    uint256 public constant FEE_DENOMINATOR = 10**10;

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
        require(deadline >= block.timestamp, "MinimaRouterV1: Expired!");
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
        outputBalancesBefore[token] = 0;

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

    // Disperse the output amount to the recipient, taking into account the partner fee and positive slippage.
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
            "MinimaRouter: Insufficient output"
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

        // Record internal balance
        updateBalances(output);
        return outputAmount;
    }

    function updateBalances(address output) internal returns (uint256) {
        outputBalancesBefore[output] = ERC20(output).balanceOf(address(this)); //Record the new fee balance
    }

    function getDivisorTransferAmounts(Divisor[] memory divisors)
        internal
        view
        returns (uint256[] memory)
    {
        uint256[] memory transferAmounts = new uint256[](divisors.length);
        for (uint256 k; k < divisors.length; k++) {
            // If a divisor is 0, dont transfer it anywhere. It will be picked up by the next swap.
            uint8 weight = divisors[k].divisor;
            require(weight <= 100, "MinimaRouter: Divisor too high");

            if (divisors[k].divisor != 0) {
                uint256 swapResult = ERC20(divisors[k].token).balanceOf(
                    address(this)
                ) - outputBalancesBefore[divisors[k].token];
                uint256 transferAmount = swapResult.mul(weight).div(100);
                transferAmounts[k] = transferAmount;
            }
        }
        return transferAmounts;
    }

    function swapExactInputForOutput(MultiSwapPayload calldata details)
        external
        override
        returns (uint256[] memory)
    {
        require(
            details.deadline >= block.timestamp,
            "MinimaRouterV1: Expired!"
        );
        require(
            details.path.length == details.pairs.length,
            "MinimaRouterV1: Path and Pairs mismatch!"
        );
        require(
            details.pairs.length == details.extras.length,
            "MinimaRouterV1: Pairs and Extras mismatch!"
        );
        require(
            details.pairs.length > 0,
            "MinimaRouterV1: Must have at least one pair!"
        );
        require(
            details.divisors.length == details.path.length - 1,
            "MinimaRouterV1: Each Path must have a divisor!"
        );
        require(
            details.inputAmounts.length == details.path.length,
            "MinimaRouterV1: Each Path must have an input amount!"
        );

        address output = details.path[details.path.length - 1][
            details.path[details.path.length - 1].length - 1
        ];

        for (uint256 i = 0; i < details.path.length; i++) {
            //Transfer initial amounts
            if (details.inputAmounts[i] > 0) {
                require(
                    ERC20(details.path[i][0]).transferFrom(
                        msg.sender,
                        details.pairs[i][0],
                        details.inputAmounts[i]
                    ),
                    "MinimaRouterV1: Initial transferFrom failed!"
                );
            }

            for (uint256 j; j < details.pairs[i].length; j++) {
                (address pairInput, address pairOutput) = (
                    details.path[i][j],
                    details.path[i][j + 1]
                );
                address next = j < details.pairs[i].length - 1
                    ? details.pairs[i][j + 1]
                    : address(this);

                ISwappaPairV1(details.pairs[i][j]).swap(
                    pairInput,
                    pairOutput,
                    next,
                    details.extras[i][j]
                );
            }

            if (i < details.path.length - 1) {
                uint256[] memory transferAmounts = getDivisorTransferAmounts(
                    details.divisors[i]
                );

                for (uint256 k; k < transferAmounts.length; k++) {
                    ERC20(details.divisors[i][k].token).transfer(
                        details.pairs[details.divisors[i][k].toIdx][0],
                        transferAmounts[k]
                    );
                }
            }
        }

        uint256 tradeOutput = ERC20(output).balanceOf(address(this)) -
            outputBalancesBefore[output];
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
            details.path[0][0],
            output,
            details.inputAmounts[0],
            outputAmount,
            partnerId
        );
    }

    receive() external payable {}
}
