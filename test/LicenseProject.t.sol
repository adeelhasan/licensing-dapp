// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "src/License.sol";
import "src/LicenseProject.sol";
import "openzeppelin-contracts/token/ERC20/ERC20.sol";

contract PaymentToken is ERC20 {
    constructor(string memory name, string memory symbol, uint initialSupply) ERC20(name,symbol) public {
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

    function setUp() public {
        licenseProject = new LicenseProject("A Project","LPRO",address(0));

        //a license with one cycle, worth 1 ether, and no duration ie. perpetual
        licenseId1 = licenseProject.addLicense("Evergreen Perpetual",1,0,1 ether);

        testAccount = vm.addr(0xABCD);
        testAccount2 = vm.addr(0xDABC);
        testAccount3 = vm.addr(0xCDAB);

        paymentToken = new PaymentToken("SILVER","SLV",1000000);
        licenseProjectTakingTokens = new LicenseProject("Token Payment Project","LPT",address(paymentToken));
        //license with 12 cycles, cycle duration of 1 hr, and price of 100 tokens
        licenseId2 = licenseProjectTakingTokens.addLicense("Pro",12,3600,100);
        paymentToken.transfer(testAccount3,1000);
    }

    function testPerpetualLicense() public {
        vm.deal(testAccount,10 ether);
        vm.startPrank(testAccount);
        uint tokenId = licenseProject.buyLicense{value: 1 ether}(0,licenseId1,0);
        assert(tokenId>0);
        assert(licenseProject.checkValidity(tokenId));
        assert(licenseProject.ownerOf(tokenId) == testAccount);
        vm.stopPrank();
    }

    function testFailAddLicenseIfNotOwner() public {
        vm.prank(testAccount);
        licenseProject.addLicense("license name",1,0,1 ether);
    }

    
/*     function testExpectEmitAddLicenseEvent() public {
        vm.expectEmit(false, false, false, true);
        uint licenseId = licenseProject.addLicense("Evergreen Perpetual 2",1,0,1 ether);
        emit LicenseAdded(licenseId);
    }
 */
    function testPaymentByToken() public {
        //AR
        vm.startPrank(testAccount3);
        paymentToken.approve(address(licenseProjectTakingTokens), 1000);
        uint newTokenId = licenseProjectTakingTokens.buyLicense(0,licenseId2,500);
        assert(newTokenId > 0);
        assert(licenseProjectTakingTokens.checkValidity(newTokenId));
        vm.stopPrank();
    }

    function testValidityFailAfterCycleEnd() public {
        //AR
        vm.startPrank(testAccount3);
        paymentToken.approve(address(licenseProjectTakingTokens), 1000);
        uint newTokenId = licenseProjectTakingTokens.buyLicense(0,licenseId2,500);
        assert(newTokenId > 0);
        vm.warp(block.timestamp + 4000);
        assert(licenseProjectTakingTokens.checkValidity(newTokenId) == false);
        vm.stopPrank();
    }

    // function testValidityFailBeforeCycleStart() public {
    //     //AR
    //      As we have removed start time for now, this is not needed.
    // }

    function testValidityPassBeforeCycleEnd() public {
        //AR
        vm.startPrank(testAccount3);
        paymentToken.approve(address(licenseProjectTakingTokens), 1000);
        uint newTokenId = licenseProjectTakingTokens.buyLicense(0,licenseId2,500);
        assert(newTokenId > 0);
        assert(licenseProjectTakingTokens.checkValidity(newTokenId));
        vm.stopPrank();
    }


    function testCycleExtendsIfPayingBeforeEndDate() public {
        //AR
        vm.startPrank(testAccount3);
        paymentToken.approve(address(licenseProjectTakingTokens), 1000);
        uint tokenId = licenseProjectTakingTokens.buyLicense(0, licenseId2, 200);
        uint initialEndDate = licenseProjectTakingTokens.getLicenseeData(tokenId).cycles[0].endTime;
        vm.warp(block.timestamp + 100);
        tokenId = licenseProjectTakingTokens.buyLicense(tokenId, licenseId2, 200);
        vm.stopPrank();
        uint newEndDate = licenseProjectTakingTokens.getLicenseeData(tokenId).cycles[0].endTime;
        assert(initialEndDate + 3600 == newEndDate);
    }

    function testFailIfPayingTwiceForPerpetualLicense() public {
        vm.startPrank(testAccount2);
        uint tokenId = licenseProject.buyLicense(0, licenseId1, 0);
        tokenId = licenseProject.buyLicense(tokenId, licenseId1, 0);
        vm.stopPrank();
    }

    function testFailIfCheckingValidityFromNonLicensee() public {
        vm.prank(testAccount2);
        uint tokenId = licenseProject.buyLicense(0, licenseId1, 0);
        assert(tokenId > 0);
        assert(licenseProject.checkValidity(tokenId));
    }

    function testFailWhenPayingWithEtherAndTokensAtSameTime() public {
        vm.deal(testAccount3,10 ether);
        vm.prank(testAccount3);
        uint newTokenId = licenseProjectTakingTokens.buyLicense{value: 1 ether}(0,licenseId2,1000);
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
        uint newTokenId = licenseProject.giftLicense(licenseId1, testAccount);
        assertEq(licenseProject.ownerOf(newTokenId), testAccount);
        vm.prank(testAccount);
        assert(licenseProject.checkValidity(newTokenId));
    }

    function testAutomaticRenewalByToken() public {
        vm.startPrank(testAccount3);
        paymentToken.approve(address(licenseProjectTakingTokens), 1200);
        uint tokenId = licenseProjectTakingTokens.buyLicense(0, licenseId2, 100);
        //TBD: balance was correctly debited
        //console.log(paymentToken.balanceOf(testAccount3));
        require(tokenId>0,"tokenId not valid");
        require(licenseProjectTakingTokens.checkValidity(tokenId) == true,"validity check failed");
        vm.warp(4000);
        require(licenseProjectTakingTokens.checkValidity(tokenId) == false,"token still valid");
        vm.stopPrank();
    }

    function testTokenTransferShouldPreserveValidity() public {
        vm.deal(testAccount,10 ether);
        vm.startPrank(testAccount);
        uint tokenId = licenseProject.buyLicense{value: 1 ether}(0,licenseId1,0);
        assert(tokenId>0);
        assert(licenseProject.checkValidity(tokenId));
        licenseProject.approve(testAccount2, tokenId);
        licenseProject.transferFrom(testAccount, testAccount2, tokenId);
        vm.stopPrank();
        vm.prank(testAccount2);
        require(licenseProject.checkValidity(tokenId),"license was not transfered with the token");
        vm.expectRevert("valid for user of record, not token owner");
        vm.prank(testAccount);
        licenseProject.checkValidity(tokenId);
    }


    function testFailIfNotExactChangeGiven() public {
        vm.deal(testAccount2,10 ether);
        vm.startPrank(testAccount2);
        vm.expectRevert("only exact change taken");
        uint newTokenId = licenseProject.buyLicense{value: 2 ether}(0,licenseId1,0);
        vm.stopPrank();
    }

}
