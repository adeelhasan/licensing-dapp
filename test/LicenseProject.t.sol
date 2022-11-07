// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/License.sol";
import "../src/LicenseProject.sol";

contract LicenseProjectTest is Test {
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
}
