// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "src/LicenseProject.sol";

contract LicenseProjectScript is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_PROJECT");
        vm.startBroadcast(deployerPrivateKey);

        LicenseProject licenseProject = new LicenseProject("WordStart","WRDS",address(0));
        uint licenseId1 = licenseProject.addLicense("Free", 1, 0, 0);
        uint licenseId2 = licenseProject.addLicense("Basic", 12, 30, 1 ether);
        uint licenseId3 = licenseProject.addLicense("Pro", 12, 30, 2 ether);

        vm.stopBroadcast();
    }
}
