// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "src/License.sol";
import "src/LicenseProject.sol";

contract LicenseProjectTest is Test {
    LicenseProject public licenseProject;
    uint licenseId1;
    address testAccount;

    function setUp() public {
        licenseProject = new LicenseProject("A Project","LPRO",address(0));

        //a license with one cycle, worth 1 ether, and no duration ie. perpetual
        licenseId1 = licenseProject.addLicense("Evergreen Perpetual",1,0,1 ether);

        testAccount = vm.addr(0xABCD);
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
}
