// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Escrow} from "../src/Escrow.sol";
import {MyToken} from "../src/Usdt.sol";

contract Escrow_test is Test {
    Escrow public escrow;
    MyToken public usdt;
    address public owner = address(77777);
    address public buyer1 = address(66666);
    address public buyer2 = address(11111);
    address public buyer3 = address(55555);
    address public seller1 = address(22222);
    address public seller2 = address(33333);
    address public seller3 = address(44444);

    function setUp() public {
        vm.startPrank(owner);
        escrow = new Escrow(1000);
        usdt = new MyToken();
        vm.stopPrank();
    }

    function createDealToken(
        address _buyer,
        address _seller,
        uint _value
    ) public returns (bytes32 _iden) {
        vm.prank(owner);
        usdt.mint(_buyer, 1000000000000000000);
        vm.startPrank(_buyer);
        usdt.approve(address(escrow), _value);
        _iden = escrow.dealToken(
            _seller,
            address(usdt),
            _value,
            block.timestamp + 2 days
        );
        vm.stopPrank();
    }

    function createDealEth(
        address _buyer,
        address _seller
    ) public returns (bytes32 _iden) {
        vm.startPrank(_buyer);
        vm.deal(buyer1, 100 ether);
        _iden = escrow.dealEth{value: 1 ether}(
            _seller,
            (block.timestamp + 2 days)
        );
        vm.stopPrank();
    }

    function testDeal_createEth() public {
        createDealEth(buyer1, seller1);
        uint balanceBuyer1 = buyer1.balance;
        assertEq(balanceBuyer1, 99 ether);
        assertEq((address(escrow).balance), 1 ether);
    }

    function testDeal_refundEth() public {
        bytes32 _iden = createDealEth(buyer1, seller1);
        vm.startPrank(buyer1);
        vm.warp(block.timestamp + 1 days);
        escrow.refund(_iden);
        uint fee = escrow.getDealFee(_iden);
        uint buyerBalance = buyer1.balance;
        vm.stopPrank();
        assertEq(buyerBalance, 99.9 ether);
        assertEq(address(escrow).balance, fee);
    }

    function testFail_refundEth() public {
        bytes32 _iden = createDealEth(buyer1, seller1);
        vm.prank(buyer1);
        vm.warp(block.timestamp + 4 days);
        escrow.refund(_iden);
    }

    function testFail_refundEth_caller() public {
        bytes32 _iden = createDealEth(buyer1, seller1);
        vm.prank(seller1);
        vm.warp(block.timestamp + 1 days);
        escrow.refund(_iden);
    }

    function testFail_refundEth_double() public {
        bytes32 _iden = createDealEth(buyer1, seller1);
        vm.startPrank(buyer1);
        vm.warp(block.timestamp + 1 days);
        escrow.refund(_iden);
        vm.warp(block.timestamp + 1.5 days);
        escrow.refund(_iden);
        vm.stopPrank();
    }

    function testDeal_withdrawEth() public {
        bytes32 _iden = createDealEth(buyer1, seller1);
        vm.startPrank(seller1);
        vm.warp(block.timestamp + 3 days);
        escrow.withdraw(_iden);
        uint fee = escrow.getDealFee(_iden);
        uint sellerBalance = seller1.balance;
        vm.stopPrank();
        assertEq(sellerBalance, 0.9 ether);
        assertEq(address(escrow).balance, fee);
    }

    function testFail_withdrawEth() public {
        bytes32 _iden = createDealEth(buyer1, seller1);
        vm.prank(seller1);
        vm.warp(block.timestamp + 1 days);
        escrow.withdraw(_iden);
    }

    function testFail_withdrawEth_caller() public {
        bytes32 _iden = createDealEth(buyer1, seller1);
        vm.prank(seller2);
        vm.warp(block.timestamp + 4 days);
        escrow.withdraw(_iden);
    }

    function testFail_withdrawEth_double() public {
        bytes32 _iden = createDealEth(buyer1, seller1);
        vm.startPrank(seller1);
        vm.warp(block.timestamp + 4 days);
        escrow.withdraw(_iden);
        vm.warp(block.timestamp + 5 days);
        escrow.withdraw(_iden);
        vm.stopPrank();
    }

    function testDeal_withdrawFeesEth() public {
        bytes32 _iden = createDealEth(buyer1, seller1);
        vm.startPrank(seller1);
        vm.warp(block.timestamp + 3 days);
        escrow.withdraw(_iden);
        uint fee = escrow.getDealFee(_iden);
        vm.stopPrank();
        vm.startPrank(owner);
        escrow.withdrawFees(_iden);
        vm.stopPrank();
        assertEq(owner.balance, fee);
    }

    function testFail_withdrawFeesEth() public {
        bytes32 _iden = createDealEth(buyer1, seller1);
        vm.prank(owner);
        escrow.withdrawFees(_iden);
    }

    function testFail_withdrawFeesEth_caller() public {
        bytes32 _iden = createDealEth(buyer1, seller1);
        vm.prank(seller1);
        vm.warp(block.timestamp + 4 days);
        escrow.withdraw(_iden);
        vm.prank(buyer1);
        vm.warp(block.timestamp + 5 days);
        escrow.withdrawFees(_iden);
    }

    function testFail_withdrawFees_double() public {
        bytes32 _iden = createDealEth(buyer1, seller1);
        vm.prank(seller1);
        vm.warp(block.timestamp + 4 days);
        escrow.withdraw(_iden);
        vm.startPrank(owner);
        vm.warp(block.timestamp + 5 days);
        escrow.withdrawFees(_iden);
        vm.warp(block.timestamp + 6 days);
        escrow.withdrawFees(_iden);
        vm.stopPrank();
    }
    /////// Token Test cases----------///////////////////////////////////////////
    function testDeal_createToken() public {
        createDealToken(buyer1, seller1, 1000);
        uint balanceBuyer1 = usdt.balanceOf(buyer1);
        console.log("balanceBuyer1", balanceBuyer1);
    }

    function testDeal_refundToken() public {
        bytes32 _iden = createDealToken(buyer1, seller1, 1000);
        vm.startPrank(buyer1);
        vm.warp(block.timestamp + 1 days);
        uint buyerBalance1 = usdt.balanceOf(buyer1);
        escrow.refund(_iden);
        uint buyerBalance2 = usdt.balanceOf(buyer1);
        vm.stopPrank();
        assertEq(buyerBalance2, (buyerBalance1 + 900));
    }

    function testFail_refundToken() public {
        bytes32 _iden = createDealToken(buyer1, seller1, 1000);
        vm.prank(buyer1);
        vm.warp(block.timestamp + 4 days);
        escrow.refund(_iden);
    }

    function testFail_refundToken_caller() public {
        bytes32 _iden = createDealToken(buyer1, seller1, 1000);
        vm.prank(buyer2);
        vm.warp(block.timestamp + 1 days);
        escrow.refund(_iden);
    }

    function testFail_refundToken_double() public {
        bytes32 _iden = createDealToken(buyer1, seller1, 1000);
        vm.startPrank(buyer1);
        vm.warp(block.timestamp + 1 days);
        escrow.refund(_iden);
        vm.warp(block.timestamp + 1.5 days);
        escrow.refund(_iden);
        vm.stopPrank();
    }

    function testDeal_withdrawToken() public {
        bytes32 _iden = createDealToken(buyer1, seller1, 1000);
        vm.startPrank(seller1);
        vm.warp(block.timestamp + 3 days);
        escrow.withdraw(_iden);
        uint sellerBalance = usdt.balanceOf(seller1);
        vm.stopPrank();
        assertEq(sellerBalance, 900);
        assertEq(usdt.balanceOf(address(escrow)), 100);
    }

    function testFail_withdrawToken() public {
        bytes32 _iden = createDealToken(buyer1, seller1, 1000);
        vm.prank(seller1);
        vm.warp(block.timestamp + 1 days);
        escrow.withdraw(_iden);
    }

    function testFail_withdrawToken_caller() public {
        bytes32 _iden = createDealToken(buyer1, seller1, 1000);
        vm.prank(seller2);
        vm.warp(block.timestamp + 3 days);
        escrow.withdraw(_iden);
    }

    function testFail_withdrawToken_double() public {
        bytes32 _iden = createDealToken(buyer1, seller1, 1000);
        vm.startPrank(seller1);
        vm.warp(block.timestamp + 3 days);
        escrow.withdraw(_iden);
        vm.warp(block.timestamp + 4 days);
        escrow.withdraw(_iden);
        vm.stopPrank();
    }

    function testDeal_withdrawFeesToken() public {
        bytes32 _iden = createDealToken(buyer1, seller1, 1000);
        vm.prank(seller1);
        vm.warp(block.timestamp + 3 days);
        escrow.withdraw(_iden);
        uint fee = escrow.getDealFee(_iden);
        vm.prank(owner);
        escrow.withdrawFees(_iden);
        assertEq(usdt.balanceOf(address(escrow)), 0);
        assertEq(usdt.balanceOf(owner), fee);
    }

    function testFail_withdrawFeesToken() public {
        bytes32 _iden = createDealToken(buyer1, seller1, 1000);
        vm.prank(owner);
        escrow.withdrawFees(_iden);
    }

    function testFail_withdrawFeesToken_caller() public {
        bytes32 _iden = createDealToken(buyer1, seller1, 1000);
        vm.prank(buyer2);
        escrow.withdrawFees(_iden);
    }

    function testFail_withdrawFeesToken_double() public {
        bytes32 _iden = createDealToken(buyer1, seller1, 1000);
        vm.prank(seller1);
        vm.warp(block.timestamp + 3 days);
        escrow.withdraw(_iden);
        vm.startPrank(owner);
        vm.warp(block.timestamp + 4 days);
        escrow.withdrawFees(_iden);
        vm.warp(block.timestamp + 5 days);
        escrow.withdrawFees(_iden);
    }
}
