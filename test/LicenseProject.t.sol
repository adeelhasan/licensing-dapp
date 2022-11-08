// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/License.sol";
import "../src/LicenseProject.sol";

contract LicenseProjectTest is Test {
    event LicenseAdded(uint256 licenseId);

    LicenseProject public licenseProject;
    uint licenseId1;
    address testAccount;

    function setUp() public {
        licenseProject = new LicenseProject("A Project","LPRO",address(0));

        //a license with one cycle, worth 1 ether, and no duration ie. perpetual
        License l = new License("Evergreen Perpetual",1,1 ether,0);        
        licenseId1 = licenseProject.addLicense((l));

        testAccount = vm.addr(0xABCD);
    }

    function testPerpetualLicense() public {
        vm.deal(testAccount,10 ether);
        vm.prank(testAccount);
        uint tokenId = licenseProject.buyLicense{value: 1 ether}(licenseId1);
        assert(tokenId>0);
        assert(licenseProject.checkValidity(tokenId));
    }

    // Any thoughts on why this one might keep failing?
    // Tried testAccount 1 and 2.
    function testFailAddLicenseIfNotOwner() public {
        License l = new License("license name",1,1 ether,0);

        vm.prank(testAccount);

        licenseProject.addLicense(l);
    }

    function testExpectEmitAddLicenseEvent() public {
        vm.expectEmit(false, false, false, true);

        License l = new License("Evergreen Perpetual 2",1,1 ether,0);

        emit LicenseAdded(1);
        licenseProject.addLicense(l);
    }
}
