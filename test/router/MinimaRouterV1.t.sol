pragma solidity 0.6.8;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {Test} from "forge-std/Test.sol";

import {MinimaRouterV1} from "../../src/MinimaRouterV1.sol";
import {MockPair} from "../mock/MockPair.sol";

import "forge-std/console.sol";

import {ExtendedDSTest} from "../utils/ExtendedDSTest.sol";

/*
    Dependency: None
*/
contract MinimaRouterV1Test is ExtendedDSTest {
    MinimaRouterV1 public minimaRouter;
    MockPair public pair;
    ERC20[] public tokens;

    uint256 constant NUM_TOKENS = 10;

    function setUp() public override {
        ExtendedDSTest.setUp();

        address[] memory adminSigners = new address[](1);
        adminSigners[0] = alice;
        minimaRouter = new MinimaRouterV1(alice, adminSigners);

        pair = new MockPair();

        for (uint8 i = 0; i < NUM_TOKENS; i++) {
            ERC20 token = new ERC20("TEST TOKEN", Strings.toString(i));
            tokens[i] = token;
            vm.label(
                address(token),
                string(abi.encodePacked("Token ", Strings.toString(i)))
            );
        }
    }

    modifier asUser(address _addr) {
        vm.startPrank(_addr);
        _;
        vm.stopPrank();
    }

    function testSetAdminFailsOnNonAuthorized(address prankster)
        public
        asUser(prankster)
    {
        if (prankster == alice) {
            return;
        }

        vm.expectRevert();
        minimaRouter.setAdmin(prankster, true);
    }

    function testSetPartnerFee(uint256 feeNumerator, uint256 partnerId)
        public
        asUser(alice)
    {
        if (feeNumerator > minimaRouter.MAX_PARTNER_FEE()) {
            vm.expectRevert();
            minimaRouter.setPartnerFee(partnerId, feeNumerator);
        } else {
            minimaRouter.setPartnerFee(partnerId, feeNumerator);
            uint256 newFee = minimaRouter.getPartnerFee(partnerId);
            assertEq(newFee, feeNumerator);
        }
    }
}
