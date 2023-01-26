// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./LicensingTestBase.sol";
import "src/RentableLicenseProject.sol";

contract RentableLicenseProjectTest is LicensingTestBase {

    RentableLicenseProject public licenseProject;
    RentableLicenseProject public licenseProject2;

    uint listingId1;
    uint listingId2;

    address renter1;
    address renter2;

    function setUp() public override {
        super.setUp();

        licenseProject = new RentableLicenseProject("A Project With Rentables", "RPRO", address(0));
        licenseProject2 = new RentableLicenseProject("Rent with Tokens", "RPROT", address(paymentToken));

        //a license with one cycle, worth 1 ether, and no duration ie. perpetual
        licenseId1 = licenseProject.addLicense("Evergreen Perpetual", 1, 0, 1 ether);
        licenseId2 = licenseProject.addLicense("Evergreen Perpetual Again", 1, 100, 100);

        licenseId3 = licenseProject2.addLicense("Annual License", 1, 365 days, 500);

        testAccount1 = vm.addr(0xABCD);
        testAccount2 = vm.addr(0xDABC);
        renter1 = vm.addr(0xCDAB);
        renter2 = vm.addr(0xBCDA);

        vm.deal(testAccount1, 10 ether);
        vm.deal(testAccount2, 10 ether);
        vm.deal(renter1, 5 ether);
        vm.deal(renter2, 5 ether);

        paymentToken.transfer(testAccount2, 1000 * 7 days);
        paymentToken.transfer(renter2, 1000);

        vm.startPrank(testAccount1);

        licenseTokenId1 = licenseProject.buyLicense{value: 1 ether}(licenseId1, 0);
        listingId1 = licenseProject.addRentalListing(licenseTokenId1, RentalTimeUnit.Daily, 0.1 ether, 3, 0, false);

        vm.stopPrank();

        vm.startPrank(testAccount2);
        paymentToken.approve(address(licenseProject2), 1000);
        licenseTokenId2 = licenseProject2.buyLicense(licenseId3, 0);
        listingId2 = licenseProject2.addRentalListing(licenseTokenId2, RentalTimeUnit.Daily, 1, 10, 0, false);
        vm.stopPrank();

    }

    function testRentPerpetualLicense() public {
        vm.prank(testAccount1);
        require(licenseProject.checkValidity(licenseTokenId1),"license is good for owner");

        vm.startPrank(renter1);
        licenseProject.buyLease{value: 0.4 ether}(licenseTokenId1, listingId1, block.timestamp, 4, false);
        require(licenseProject.checkValidity(licenseTokenId1),"license valid after renting");
        vm.stopPrank();

        vm.prank(testAccount1);
        require(licenseProject.checkValidity(licenseTokenId1) == false,"owner should not have rights");

        vm.startPrank(renter1);
        vm.warp(block.timestamp + 3 days);
        require(licenseProject.checkValidity(licenseTokenId1),"license not valid after a few days");
        vm.warp(block.timestamp + 2 days);
        require(licenseProject.checkValidity(licenseTokenId1) == false,"rental lease finished");
        vm.stopPrank();

        vm.prank(testAccount1);
        require(licenseProject.checkValidity(licenseTokenId1),"license is good for owner");

        licenseProject.cleanupExpiredLeases(licenseTokenId1);
    }

    function testFailIfRentingLessThanRequiredMinimum() public {
        licenseProject.buyLease{value: 0.4 ether}(licenseTokenId1, listingId1, block.timestamp, 2, false);
    }

    function testFailIfRentingWithLessEther() public {
        licenseProject.buyLease{value: 0.3 ether}(licenseTokenId1, listingId1, block.timestamp, 4, false);
    }

    function testRentingWithToken() public {
        vm.startPrank(renter2);
        IERC20(paymentToken).approve(address(licenseProject2), 10);
        licenseProject2.buyLease(licenseTokenId2, listingId1, block.timestamp, 10, false);
        require(licenseProject2.checkValidity(licenseTokenId2), "renter should have licensing rights");
        vm.stopPrank();

        vm.startPrank(testAccount2);
        uint balanceBefore = paymentToken.balanceOf(testAccount2);
        licenseProject2.withdraw();
        uint balanceAfter = paymentToken.balanceOf(testAccount2);
        require(balanceAfter > balanceBefore,"balance was not transferred");
        vm.stopPrank();
    }

    function testFailIfOverlappingLeases() public {
        vm.startPrank(renter1);
        licenseProject.buyLease{value: 0.4 ether}(licenseTokenId1, listingId1, block.timestamp, 4, false);
        vm.warp(block.timestamp + 2 days);        
        licenseProject.checkValidity(licenseTokenId1);        
        licenseProject.buyLease{value: 0.4 ether}(licenseTokenId1, listingId1, block.timestamp, 4, false);
        vm.stopPrank();
    }

    function testFailIfOverlappingLeasesInFuture() public {
        vm.startPrank(renter1);
        licenseProject.buyLease{value: 0.4 ether}(licenseTokenId1, listingId1, block.timestamp + 4 days, 4, false);
        licenseProject.buyLease{value: 0.4 ether}(licenseTokenId1, listingId1, block.timestamp + 6 days, 4, false);
        vm.stopPrank();
    }

    function testTokenTransferPreservesLeases() public {
        vm.startPrank(renter1);
        licenseProject.buyLease{value: 0.4 ether}(licenseTokenId1, listingId1, block.timestamp, 4, false);
        licenseProject.checkValidity(licenseTokenId1);
        vm.stopPrank();
        vm.prank(testAccount1);
        licenseProject.transferFrom(testAccount1, testAccount2, licenseTokenId1);
        vm.prank(renter1);
        licenseProject.checkValidity(licenseTokenId1);
    }

    function testExtendLease() public {
        vm.startPrank(renter1);
        licenseProject.buyLease{value: 0.3 ether}(licenseTokenId1, listingId1, block.timestamp, 3, false);
        require(licenseProject.checkValidity(licenseTokenId1),"license valid after renting");
        licenseProject.extendLease{value: 0.4 ether}(licenseTokenId1, listingId1, 4);
        vm.warp(block.timestamp + 5 days);
        require(licenseProject.checkValidity(licenseTokenId1),"license valid after extending");
        vm.stopPrank();
    }

    function testFailIfNonRenterExtendsLease() public {
        vm.startPrank(renter1);
        licenseProject.buyLease{value: 0.3 ether}(licenseTokenId1, listingId1, block.timestamp, 3, false);
        require(licenseProject.checkValidity(licenseTokenId1),"license valid after renting");
        vm.stopPrank();
        vm.startPrank(renter2);
        licenseProject.extendLease{value: 0.4 ether}(licenseTokenId1, listingId1, 4);
        vm.stopPrank();
    }

    function testStreamingLeaseEndedByRenter() public {
        vm.prank(testAccount1);
        uint256 streamableListingId = licenseProject.addRentalListing(licenseTokenId1, RentalTimeUnit.Seconds, 1000, 1 days, 0, true);

        vm.startPrank(testAccount2);
        uint256 streamingLeaseId = licenseProject.buyLease{value: (3 days * 1000)}(licenseTokenId1, streamableListingId, block.timestamp + 2 days, 3 days, true);

        uint256 balanceBefore = testAccount2.balance;
        vm.warp(block.timestamp + 3 days);
        licenseProject.endStreamingLease(licenseTokenId1, streamingLeaseId);
        licenseProject.withdraw();
        uint256 balanceAfter = testAccount2.balance;
        vm.stopPrank();

        //stream was for 3 days, canceling after 1 day, so refunded for 2 days
        require(2 days * 1000 == (balanceAfter - balanceBefore), "renter balance not as expected");

        //the token holder would get the 1 day of rent that was used by the stream
        balanceBefore = testAccount1.balance;
        vm.prank(testAccount1);
        licenseProject.withdraw();
        balanceAfter = testAccount1.balance;
        require(1 days * 1000 == (balanceAfter - balanceBefore), "token holder balance not as expected");
    }

    function testStreamingLeaseEndedByRenterBeforeStart() public {
        vm.prank(testAccount1);
        uint256 streamableListingId = licenseProject.addRentalListing(licenseTokenId1, RentalTimeUnit.Seconds, 1000, 1 days, 0, true);

        vm.startPrank(testAccount2);
        uint256 streamingLeaseId = licenseProject.buyLease{value: (3 days * 1000)}(licenseTokenId1, streamableListingId, block.timestamp + 2 days, 3 days, true);

        uint256 balanceBefore = testAccount2.balance;
        vm.warp(block.timestamp + 1 days);
        licenseProject.endStreamingLease(licenseTokenId1, streamingLeaseId);
        licenseProject.withdraw();
        uint256 balanceAfter = testAccount2.balance;
        vm.stopPrank();

        //stream was for 3 days, so refunded for all the days when canceling before its start
        require(3 days * 1000 == (balanceAfter - balanceBefore), "renter balance not as expected");

        //the token holder would get the 1 day of rent that was used by the stream
        balanceBefore = testAccount1.balance;
        vm.prank(testAccount1);
        licenseProject.withdraw();
        balanceAfter = testAccount1.balance;
        require(0 == (balanceAfter - balanceBefore), "token holder balance not as expected");
    }

    function testStreamingLeaseAfterEndDate() public {
        vm.prank(testAccount1);
        uint256 streamableListingId = licenseProject.addRentalListing(licenseTokenId1, RentalTimeUnit.Seconds, 1000, 1 days, 0, true);

        uint256 tokenHolderbalanceBefore = testAccount1.balance;

        vm.startPrank(testAccount2);
        uint256 streamingLeaseId = licenseProject.buyLease{value: (3 days * 1000)}(licenseTokenId1, streamableListingId, block.timestamp + 2 days, 3 days, true);

        uint256 balanceBefore = testAccount2.balance;
        vm.warp(block.timestamp + 5 days);
        vm.expectRevert(RentableLicenseProject.StreamingLeaseCanOnlyCancelBeforeEnd.selector);
        licenseProject.endStreamingLease(licenseTokenId1, streamingLeaseId);
        licenseProject.withdraw();
        uint256 balanceAfter = testAccount2.balance;
        vm.stopPrank();

        //full rent is taken in this scenario
        require(balanceAfter == balanceBefore, "renter balance not as expected");

        //the token holder would get full rent
        vm.startPrank(testAccount1);
        licenseProject.getRentFromStreamingLease(licenseTokenId1, streamingLeaseId);
        licenseProject.withdraw();
        vm.stopPrank();
        balanceAfter = testAccount1.balance;
        require((3 days * 1000) == (balanceAfter - tokenHolderbalanceBefore), "token holder balance not as expected");
    }

    function testStreamingLeaseByTokens() public {
        vm.prank(testAccount2); //token owner
        uint256 streamableListingId = licenseProject2.addRentalListing(licenseTokenId2, RentalTimeUnit.Seconds, 1000, 1 days, 0, true);

        paymentToken.transfer(testAccount1, 3 days * 1000);
        vm.startPrank(testAccount1);
        paymentToken.approve(address(licenseProject2), 1000 * 3 days);        
        uint256 streamingLeaseId = licenseProject2.buyLease(licenseTokenId2, streamableListingId, block.timestamp + 2 days, 3 days, true);

        uint256 balanceBefore = paymentToken.balanceOf(testAccount1);
        vm.warp(block.timestamp + 3 days);
        licenseProject2.endStreamingLease(licenseTokenId2, streamingLeaseId);
        licenseProject2.withdraw();
        uint256 balanceAfter = paymentToken.balanceOf(testAccount1);
        vm.stopPrank();

        //stream was for 3 days, canceling after 1 day, so refunded for 2 days
        require(2 days * 1000 == (balanceAfter - balanceBefore), "renter balance not as expected");

        //the token holder would get the 1 day of rent that was used by the stream
        balanceBefore = paymentToken.balanceOf(testAccount2);
        vm.prank(testAccount2);
        licenseProject2.withdraw();
        balanceAfter = paymentToken.balanceOf(testAccount2);
        require(1 days * 1000 == (balanceAfter - balanceBefore), "token holder balance not as expected");
    }
}
