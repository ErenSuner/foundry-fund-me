// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {FundMe} from "../../src/FundMe.sol";
import {DeployFundMe} from "../../script/DeployFundMe.s.sol";

contract FundMeTest is Test {
    FundMe fundMe;

    address USER = makeAddr("user"); // creating a fake user
    uint256 constant SEND_VALUE = 0.1 ether; // 10e17
    uint256 constant STARTING_BALANCE = 10 ether;
    uint256 constant GAS_PRICE = 1;

    function setUp() external {
        //fundMe = new FundMe(0x694AA1769357215DE4FAC081bf1f309aDC325306);
        DeployFundMe deployFundMe = new DeployFundMe();
        fundMe = deployFundMe.run();
        vm.deal(USER, STARTING_BALANCE); // we gave the fake user some money (10 ether) to be able to send transaction
    }

    function testMinimumDolarIsFive() public {
        assertEq(fundMe.MINIMUM_USD(), 5e18);
    }

    // biz -> FundMeTest -> fundMe ==> msg.sender biziz ama owner FundMeTest
    // o yüzden msg.sender değil address(this) owner oluyor
    // tekrar msg.sende a döndü çünkü addressi deploydan almaya başladık, ben de tam anlamadım
    function testOwnerIsMsgSender() public {
        assertEq(fundMe.getOwner(), msg.sender);
    }

    function testPriceFeedVersionIsAccurate() public {
        uint256 version = fundMe.getVersion();
        assertEq(version, 4);
    }

    function testFundFailsWithoutEnoughETH() public {
        vm.expectRevert(); // hey, the next line should revert
        // vm. ile kullanılan kodlara cheatcode deniyor
        fundMe.fund(); // send 0 value
    }

    function testFundUpdatesFundedDataStructure() public {
        vm.prank(USER); // The next transaction will sent by USER
        fundMe.fund{value: SEND_VALUE}();

        uint256 amountFunded = fundMe.getAddressToAmountFunded(USER);
        assertEq(amountFunded, SEND_VALUE);
    }

    function testAddsFunderToArrayOfFunders() public {
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();

        address funder = fundMe.getFunder(0);
        assertEq(funder, USER);
    }

    modifier funded() {
        // funded çağırıldığı zaman önce bu iki kod çalışacak daha sonra kalanı
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();
        _;
    }

    function testOnlyOwnerCanWithdraw() public funded {
        vm.expectRevert();
        vm.prank(USER); // USER is not the owner, o parayı gönderen sadece
        fundMe.withdraw();
    }

    function testWithDrawWithASingleFunder() public funded {
        // Arrange
        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;

        // Act
        vm.prank(fundMe.getOwner()); // cost: 200 gas    , only owner can withdraw
        fundMe.withdraw();

        // Assert
        uint256 endingOwnerBalance = fundMe.getOwner().balance;
        uint256 endingFundMeBalance = address(fundMe).balance;
        assertEq(endingFundMeBalance, 0);
        assertEq(
            startingFundMeBalance + startingOwnerBalance,
            endingOwnerBalance
        );
    }

    function testWithdrawFromMultipleFunders() public funded {
        // Arrange
        uint160 numberOfFunders = 10;
        uint160 staringFunderIndex = 1;
        for (uint160 i = staringFunderIndex; i < numberOfFunders; i++) {
            hoax(address(i), SEND_VALUE); // combine of vm.prank + vm.deal, sonraki tx bu adresten yapılır ve SEND_VALUE kadar başlangıç balance ı olur
            fundMe.fund{value: SEND_VALUE}();
        }

        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;

        // Act
        vm.startPrank(fundMe.getOwner()); // start - stop arası tüm tx ler bu addresstedn yapılır
        fundMe.withdraw();
        vm.stopPrank();

        // Assert
        assert(address(fundMe).balance == 0);
        assert(
            startingFundMeBalance + startingOwnerBalance ==
                fundMe.getOwner().balance
        );
    }
}
