// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "src/LicenseProject.sol";
import "src/LicensingOrganization.sol";
import "openzeppelin-contracts/token/ERC20/ERC20.sol";

contract PaymentToken is ERC20 {
    constructor(string memory name, string memory symbol, uint initialSupply) ERC20(name,symbol) public {
        _mint(msg.sender,initialSupply);
    }
}

contract LicenseProjectScript is Script {
    uint deployerPrivateKey;
    uint pk_anvilAccount1;
    uint pk_anvilAccount2;
    uint pk_anvilAccount3;
    address testAccount1;
    address testAccount2;
    address testAccount3;

    function setUp() public {
        deployerPrivateKey = vm.envUint("PK_ANVIL_PROJECT_OWNER");
        pk_anvilAccount1 = vm.envUint("PK_ANVIL_1");
        pk_anvilAccount2 = vm.envUint("PK_ANVIL_2");
        pk_anvilAccount3 = vm.envUint("PK_ANVIL_3");
        testAccount1 = vm.addr(pk_anvilAccount1);
        testAccount2 = vm.addr(pk_anvilAccount2);
        testAccount3 = vm.addr(pk_anvilAccount3);
    }

    function run() public {
        vm.startBroadcast(deployerPrivateKey);

        LicenseProject licenseProject1 = new LicenseProject("WordStar","WRDS",address(0));
        uint licenseId1 = licenseProject1.addLicense("Free", 1, 7 days, 0);
        uint licenseId2 = licenseProject1.addLicense("Basic", 12, 30 days, 1 ether);
        uint licenseId3 = licenseProject1.addLicense("Pro", 12, 30 days, 5 ether);

        LicenseProject licenseProject2 = new LicenseProject("BitFlix","BLX",address(0));
        uint licenseId4 = licenseProject2.addLicense("Free", 1, 0, 0);
        uint licenseId5 = licenseProject2.addLicense("Pro", 1, 365 days, 5 ether);

        PaymentToken paymentToken = new PaymentToken("Silver","SLV",10000000);

        LicenseProject licenseProject3 = new LicenseProject("APEAPI","AAPI",address(paymentToken));
        uint licenseId6 = licenseProject3.addLicense("Short", 1, 1 minutes, 10);

        LicensingOrganisation theCompany = new LicensingOrganisation("The Sky Store");
        theCompany.addProject(licenseProject1);
        theCompany.addProject(licenseProject2);
        theCompany.addProject(licenseProject3);        

        paymentToken.transfer(testAccount1, 100);
        paymentToken.transfer(testAccount2, 100);
        paymentToken.transfer(testAccount3, 100);

        vm.stopBroadcast();

        vm.startBroadcast(pk_anvilAccount1);

        uint tokenId = licenseProject1.buyLicense(0,licenseId1, 0);
        tokenId = licenseProject2.buyLicense{value: 5 ether}(0,licenseId5,0);

        paymentToken.approve(address(licenseProject3), 20);
        tokenId = licenseProject3.buyLicense(0,licenseId6,10);

        vm.stopBroadcast();

        vm.startBroadcast(pk_anvilAccount2);

        tokenId = licenseProject1.buyLicense(0,licenseId1, 0);
        tokenId = licenseProject2.buyLicense(0,licenseId4,0);

        paymentToken.approve(address(licenseProject3), 20);
        tokenId = licenseProject3.buyLicense(0,licenseId6,10);

        vm.stopBroadcast();

        vm.startBroadcast(pk_anvilAccount3);

        tokenId = licenseProject1.buyLicense(0,licenseId1, 0);
        tokenId = licenseProject2.buyLicense{value: 5 ether}(0,licenseId5,0);

        paymentToken.approve(address(licenseProject3), 20);
        tokenId = licenseProject3.buyLicense(0,licenseId6,10);

        vm.stopBroadcast();
    }
}
