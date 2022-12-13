// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "src/RentableLicenseProject.sol";
import "openzeppelin-contracts/token/ERC20/ERC20.sol";
import "src/LicenseStructs.sol";

/// @notice just a helper contract
contract PaymentToken is ERC20 {
    constructor(string memory name, string memory symbol, uint initialSupply) ERC20(name,symbol) {
        _mint(msg.sender,initialSupply);
    }
}

contract RentableLicenseProjectTest is Test {
    RentableLicenseProject public licenseProject;
    RentableLicenseProject public licenseProject2;
    uint licenseId1;
    uint licenseId2;
    uint licenseId3;
    uint licenseTokenId1;
    uint licenseTokenId2;
    address testAccount1;
    address testAccount2;
    address renter1;
    address renter2;
    PaymentToken paymentToken;


    function setUp() public {
        paymentToken = new PaymentToken("SILVER","SLV",1000000);
        licenseProject = new RentableLicenseProject("A Project With Rentables","RPRO",address(0));
        licenseProject2 = new RentableLicenseProject("Rent with Tokens","RPROT",address(paymentToken));

        //a license with one cycle, worth 1 ether, and no duration ie. perpetual
        licenseId1 = licenseProject.addLicense("Evergreen Perpetual",1,0,1 ether);
        licenseId2 = licenseProject.addLicense("Evergreen Perpetual Again",1,100,100);

        licenseId3 = licenseProject2.addLicense("Annual License",1,365 days,500);

        testAccount1 = vm.addr(0xABCD);
        testAccount2 = vm.addr(0xDABC);
        renter1 = vm.addr(0xCDAB);
        renter2 = vm.addr(0xBCDA);

        vm.deal(testAccount1, 10 ether);
        vm.deal(testAccount2, 10 ether);
        vm.deal(renter1, 5 ether);
        vm.deal(renter2, 5 ether);

        paymentToken.transfer(testAccount2,1000);
        paymentToken.transfer(renter2,1000);

        vm.startPrank(testAccount1);

        licenseTokenId1 = licenseProject.buyLicense{value: 1 ether}(licenseId1,0);
        licenseProject.addRentalListing(licenseTokenId1,RentalTimeUnit.Daily,0.1 ether,3);

        vm.stopPrank();

        vm.startPrank(testAccount2);
        paymentToken.approve(address(licenseProject2),1000);
        licenseTokenId2 = licenseProject2.buyLicense(licenseId3,0);
        licenseProject2.addRentalListing(licenseTokenId2,RentalTimeUnit.Daily,1,10);
        vm.stopPrank();

    }

    function testRentPerpetualLicense() public {
        vm.prank(testAccount1);
        require(licenseProject.checkValidity(licenseTokenId1),"license is good for owner");

        vm.startPrank(renter1);
        licenseProject.rent{value: 0.4 ether}(licenseTokenId1,block.timestamp,4);
        require(licenseProject.checkValidity(licenseTokenId1),"license valid after renting");
        vm.stopPrank();

        vm.expectRevert("valid for user of record only");
        vm.prank(testAccount1);
        require(licenseProject.checkValidity(licenseTokenId1) == false,"owner should not have rights");

        vm.startPrank(renter1);
        vm.warp(block.timestamp + 3 days);
        require(licenseProject.checkValidity(licenseTokenId1),"license not valid after a few days");
        vm.warp(block.timestamp + 2 days);
        vm.expectRevert("valid for user of record only");
        require(licenseProject.checkValidity(licenseTokenId1) == false,"rental lease finished");
        vm.stopPrank();

        vm.prank(testAccount1);
        require(licenseProject.checkValidity(licenseTokenId1),"license is good for owner");

        licenseProject.cleanupExpiredLeases(licenseTokenId1);
    }

    function testFailIfRentingLessThanRequiredMinimum() public {
        licenseProject.rent{value: 0.4 ether}(licenseTokenId1,block.timestamp,2);
    }

    function testFailIfRentingWithLessEther() public {
        licenseProject.rent{value: 0.3 ether}(licenseTokenId1,block.timestamp,4);
    }

    function testRentingWithToken() public {
        vm.startPrank(renter2);
        IERC20(paymentToken).approve(address(licenseProject2),10);
        licenseProject2.rent(licenseTokenId2,block.timestamp,10);
        require(licenseProject2.checkValidity(licenseTokenId2),"renter should have licensing rights");
        vm.stopPrank();

        vm.startPrank(testAccount2);
        uint balanceBefore = paymentToken.balanceOf(testAccount2);
        licenseProject2.withdraw();
        uint balanceAfter = paymentToken.balanceOf(testAccount2);
        require(balanceAfter > balanceBefore,"balance was not transferred");
        vm.stopPrank();
    }

}
