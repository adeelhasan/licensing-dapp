// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "src/LicenseProject.sol";
import "openzeppelin-contracts/token/ERC20/ERC20.sol";

/// @notice just a helper contract
contract PaymentToken is ERC20 {
    constructor(string memory name, string memory symbol, uint initialSupply) ERC20(name,symbol) {
        _mint(msg.sender,initialSupply);
    }
}

contract LicenseProjectTest is Test {
    LicenseProject public licenseProject;
    LicenseProject public licenseProjectTakingTokens;
    uint licenseId1;
    uint licenseId2;
    uint licenseId3;
    address testAccount;
    address testAccount2;
    address testAccount3;
    PaymentToken paymentToken;

    event LicenseAdded(uint256 indexed licenseId);    

    function setUp() public {
        licenseProject = new LicenseProject("A Project","LPRO",address(0));

        //a license with one cycle, worth 1 ether, and no duration ie. perpetual
        licenseId1 = licenseProject.addLicense("Evergreen Perpetual",1,0,1 ether);
        licenseId3 = licenseProject.addLicense("Evergreen Perpetual Again",1,0,1 ether);

        testAccount = vm.addr(0xABCD);
        testAccount2 = vm.addr(0xDABC);
        testAccount3 = vm.addr(0xCDAB);

        paymentToken = new PaymentToken("SILVER","SLV",1000000);
        licenseProjectTakingTokens = new LicenseProject("Token Payment Project","LPT",address(paymentToken));
        //license with 12 cycles, cycle duration of 1 hr, and price of 100 tokens
        licenseId2 = licenseProjectTakingTokens.addLicense("Pro",12,3600,100);
        paymentToken.transfer(testAccount3,1000);
    }

    function compareStrings(string memory string1, string memory string2) public pure returns (bool) {
        return keccak256(abi.encodePacked(string1)) == keccak256(abi.encodePacked(string2));
    }

    function testPerpetualLicense() public {
        vm.deal(testAccount,10 ether);
        vm.startPrank(testAccount);
        uint tokenId = licenseProject.buyLicense{value: 1 ether}(licenseId1,0);
        assert(tokenId>0);
        assert(licenseProject.checkValidity(tokenId));
        assert(licenseProject.ownerOf(tokenId) == testAccount);
        vm.stopPrank();
    }

    function testFailAddLicenseIfNotOwner() public {
        vm.prank(testAccount);
        licenseProject.addLicense("license name",1,0,1 ether);
    }
    
    function testExpectEmitAddLicenseEvent() public {
        vm.expectEmit(true, false, false, false);
        emit LicenseAdded(2);
        licenseProject.addLicense("Evergreen Perpetual 2",1,0,1 ether);
    }

    function testPaymentByToken() public {
        vm.startPrank(testAccount3);
        paymentToken.approve(address(licenseProjectTakingTokens), 1000);
        uint newTokenId = licenseProjectTakingTokens.buyLicense(licenseId2,0);
        assert(newTokenId > 0);
        assert(licenseProjectTakingTokens.checkValidity(newTokenId));
        vm.stopPrank();
    }

    function testValidityFailAfterCycleEnd() public {
        vm.startPrank(testAccount3);
        paymentToken.approve(address(licenseProjectTakingTokens), 100);
        uint newTokenId = licenseProjectTakingTokens.buyLicense(licenseId2,0);
        assert(newTokenId > 0);
        vm.warp(block.timestamp + 4000);
        assert(licenseProjectTakingTokens.checkValidity(newTokenId) == false);
        vm.stopPrank();
    }

    function testValidityPassBeforeCycleEnd() public {
        vm.startPrank(testAccount3);
        paymentToken.approve(address(licenseProjectTakingTokens), 1000);
        uint newTokenId = licenseProjectTakingTokens.buyLicense(licenseId2,0);
        assert(newTokenId > 0);
        assert(licenseProjectTakingTokens.checkValidity(newTokenId));
        vm.stopPrank();
    }

    function testCycleExtendsIfPayingBeforeEndDate() public {
        vm.startPrank(testAccount3);
        paymentToken.approve(address(licenseProjectTakingTokens), 1000);
        uint tokenId = licenseProjectTakingTokens.buyLicense(licenseId2, 0);
        uint initialEndDate = licenseProjectTakingTokens.getLicenseeData(tokenId).endTime;
        vm.warp(block.timestamp + 100);
        licenseProjectTakingTokens.renewLicense(tokenId, 0);
        vm.stopPrank();
        uint newEndDate = licenseProjectTakingTokens.getLicenseeData(tokenId).endTime;
        assert(initialEndDate + 3600 == newEndDate);
    }

    function testFailIfPayingTwiceForPerpetualLicense() public {
        vm.startPrank(testAccount2);
        uint tokenId = licenseProject.buyLicense(licenseId1, 0);
        licenseProject.renewLicense(tokenId, 0);
        vm.stopPrank();
    }

    function testFailIfCheckingValidityFromNonLicensee() public {
        vm.prank(testAccount2);
        uint tokenId = licenseProject.buyLicense(licenseId1, 0);
        assert(tokenId > 0);
        assert(licenseProject.checkValidity(tokenId));
    }

    function testFailWhenPayingWithEtherAndTokensAtSameTime() public {
        vm.deal(testAccount3,10 ether);
        vm.prank(testAccount3);
        licenseProjectTakingTokens.buyLicense{value: 1 ether}(licenseId2,0);
    }

    function testAllLicenseListingOnlyByOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(testAccount);
        licenseProject.allLicences();
        //Licenses may be better off in a library, to make them accessible here?
        //Licenses[] memory licenses = licenseProject.allLicences();
        //separate commit for that
    }

    function testAddingLicenseOnlyByOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(testAccount);
        uint newLicense;
        newLicense = licenseProject.addLicense("Test License", 10, 10, 0);
        assert(newLicense==0);
        newLicense = licenseProject.addLicense("Test License", 10, 10, 0);
        assert(newLicense>0);
    }

    function testGiftLicense() public {
        uint newTokenId = licenseProject.giftLicense(testAccount, licenseId1, 0);
        assertEq(licenseProject.ownerOf(newTokenId), testAccount);
        vm.prank(testAccount);
        assert(licenseProject.checkValidity(newTokenId));
    }

    function testAutomaticRenewalByToken() public {
        vm.startPrank(testAccount3);
        paymentToken.approve(address(licenseProjectTakingTokens), 1200);
        uint tokenId = licenseProjectTakingTokens.buyLicense(licenseId2, 0);
        //TBD: balance was correctly debited
        //console.log(paymentToken.balanceOf(testAccount3));
        require(tokenId>0,"tokenId not valid");
        require(licenseProjectTakingTokens.checkValidity(tokenId) == true,"validity check failed");
        vm.warp(4000);
        require(licenseProjectTakingTokens.checkValidityWithAutoRenewal(tokenId),"token still valid");
        vm.stopPrank();
    }

    function testTokenTransferShouldPreserveValidity() public {
        vm.deal(testAccount,10 ether);
        vm.startPrank(testAccount);
        uint tokenId = licenseProject.buyLicense{value: 1 ether}(licenseId1,0);
        assert(tokenId>0);
        assert(licenseProject.checkValidity(tokenId));
        licenseProject.approve(testAccount2, tokenId);
        licenseProject.transferFrom(testAccount, testAccount2, tokenId);
        vm.stopPrank();
        vm.prank(testAccount2);
        require(licenseProject.checkValidity(tokenId),"license was not transfered with the token");
        vm.startPrank(testAccount);
        require(licenseProject.checkValidity(tokenId) == false, "not valid for non license holder");
        vm.stopPrank();
    }

    function testFailIfNotExactChangeGiven() public {
        vm.deal(testAccount2,10 ether);
        vm.startPrank(testAccount2);
        licenseProject.buyLicense{value: 2 ether}(licenseId1,0);
        vm.stopPrank();
    }

    function testAllLicensesList() public {
        LicenseProject licenseProject4;
        licenseProject4 = new LicenseProject("List Project","LIPRO",address(0));
        uint numOfLicenses = 3;
        uint[] memory licenseIndexArr = new uint[](numOfLicenses);
        for(uint i; i < numOfLicenses; i++){
            licenseIndexArr[i] = licenseProject4.addLicense("Evergreen Perpetual",1,0,1 ether);
        }
        License[] memory res;
        res = licenseProject4.allLicences();
        for(uint i; i < numOfLicenses; i++){
            require(compareStrings(licenseProject4.getLicenseData(licenseIndexArr[i]).name, res[i].name), "License Name don't match");
            require(licenseProject4.getLicenseData(licenseIndexArr[i]).maxRenewals == res[i].maxRenewals, "License maxCycles don't match");
            require(licenseProject4.getLicenseData(licenseIndexArr[i]).duration == res[i].duration, "License cycleLength don't match");
            require(licenseProject4.getLicenseData(licenseIndexArr[i]).price == res[i].price, "License price don't match");
            require(licenseProject4.getLicenseData(licenseIndexArr[i]).status == res[i].status, "License active don't match");
        }
    }

    function testMyLicensesList() public {
        vm.deal(testAccount2,10 ether);
        vm.startPrank(testAccount2);
        uint tokenId1 = licenseProject.buyLicense{value: 1 ether}(licenseId1,0);
        uint tokenId2 = licenseProject.buyLicense{value: 1 ether}(licenseId3,0);
        LicenseeInfo[] memory res = licenseProject.myLicenses();
        require(res[0].tokenId == tokenId1, "Token Id don't match");
        require(res[1].tokenId == tokenId2, "Token Id don't match");
        License memory license1 = licenseProject.getLicenseData(licenseId1);
        License memory license3 = licenseProject.getLicenseData(licenseId3);
        Licensee memory licensee1 = licenseProject.getLicenseeData(tokenId1);
        Licensee memory licensee2 = licenseProject.getLicenseeData(tokenId2);

        require(compareStrings(license1.name, res[0].license.name), "License Name don't match");
        require(license1.maxRenewals == res[0].license.maxRenewals, "License maxCycles don't match");
        require(license1.duration == res[0].license.duration, "License cycleLength don't match");
        require(license1.price == res[0].license.price, "License price don't match");
        require(license1.status == res[0].license.status, "License active don't match");
        require(compareStrings(license3.name, res[1].license.name), "License Name don't match");
        require(license3.maxRenewals == res[1].license.maxRenewals, "License maxCycles don't match");
        require(license3.duration == res[1].license.duration, "License cycleLength don't match");
        require(license3.price == res[1].license.price, "License price don't match");
        require(license3.status == res[1].license.status, "License active don't match");

        require(licensee1.licenseId == res[0].licensee.licenseId, "Licensee licenseIndex don't match");
        require(licensee1.user == res[0].licensee.user, "Licensee user don't match");
        require(licensee1.renewalsCount == res[0].licensee.renewalsCount, "Licensee cycles don't match");
        require(licensee2.licenseId == res[1].licensee.licenseId, "Licensee licenseIndex don't match");
        require(licensee2.user == res[1].licensee.user, "Licensee user don't match");
        require(licensee2.renewalsCount == res[1].licensee.renewalsCount, "Licensee cycles don't match");
    }

    function testRentingLicense() public {
        uint newlicenseId = licenseProject.addLicense("Simple Monthly",3,1 hours,1 ether);
        vm.deal(testAccount3, 10 ether);
        vm.startPrank(testAccount3);
        uint newTokenId = licenseProject.buyLicense{value: 1 ether}(newlicenseId,0);
        require(licenseProject.checkValidity(newTokenId),"expected licensee not there");
        licenseProject.assignLicenseTo(newTokenId,testAccount2);
        vm.stopPrank();
        vm.prank(testAccount2);
        require(licenseProject.checkValidity(newTokenId),"renter not licensee");
        vm.startPrank(testAccount3);
        require(licenseProject.checkValidity(newTokenId) == false, "should not be valid");
        licenseProject.approve(testAccount, newTokenId);
        vm.expectRevert("cannot transfer rented token");
        licenseProject.transferFrom(testAccount3, testAccount, newTokenId);
        vm.stopPrank();
    }

    function testStartingLicenseInFuture() public {
        uint newlicenseId = licenseProject.addLicense("Simple Monthly", 3, 1 hours, 1 ether);
        vm.deal(testAccount3, 10 ether);
        vm.startPrank(testAccount3);
        uint timeInFuture = block.timestamp + 2 hours;
        uint tokenId = licenseProject.buyLicense{value: 1 ether}(newlicenseId, timeInFuture);
        require(licenseProject.checkValidity(tokenId)==false,"should not be valid yet");
        vm.warp(timeInFuture + 10 minutes);
        require(licenseProject.checkValidity(tokenId),"should be valid now");
        vm.warp(timeInFuture + 90 minutes);
        require(licenseProject.checkValidity(tokenId) == false,"should not be valid now");
        licenseProject.renewLicense{value: 1 ether}(tokenId, block.timestamp + 3 hours);
        vm.warp(block.timestamp + 30 minutes);
        require(licenseProject.checkValidity(tokenId) == false,"should not be valid now");
        vm.warp(block.timestamp + 3 hours + 10 minutes);
        require(licenseProject.checkValidity(tokenId) == true,"should be valid now");
        vm.stopPrank();
    }
}
