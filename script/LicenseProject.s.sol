// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "src/LicenseProject.sol";
import "src/LicensingOrganization.sol";
import "openzeppelin-contracts/token/ERC20/ERC20.sol";

/// @notice just a helper contract
contract PaymentToken is ERC20 {
    constructor(string memory name, string memory symbol, uint initialSupply) ERC20(name,symbol) {
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
        uint licenseId1 = licenseProject1.addLicense("Gratis", 1, 0, 0);
        uint licenseId2 = licenseProject1.addLicense("One Step", 12, 7 days, 1 ether);
        uint licenseId3 = licenseProject1.addLicense("Max", 12, 30 days, 5 ether);

        LicenseProject licenseProject2 = new LicenseProject("BitFlix","BLX",address(0));
        uint licenseId4 = licenseProject2.addLicense("Signup", 1, 0, 0);
        uint licenseId5 = licenseProject2.addLicense("Professional", 1, 365 days, 5 ether);

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

        uint tokenId = licenseProject1.buyLicense(licenseId1, 0);
        tokenId = licenseProject1.buyLicense{value: 1 ether}(licenseId2, 0);
        tokenId = licenseProject2.buyLicense{value: 5 ether}(licenseId5,0);
        tokenId = licenseProject1.buyLicense{value: 5 ether}(licenseId3,block.timestamp + 5 days);

        paymentToken.approve(address(licenseProject3), 20);
        tokenId = licenseProject3.buyLicense(licenseId6,block.timestamp + 10 minutes);

        vm.stopBroadcast();

        vm.startBroadcast(pk_anvilAccount2);

        tokenId = licenseProject1.buyLicense(licenseId1, 0);
        tokenId = licenseProject2.buyLicense(licenseId4,0);

        paymentToken.approve(address(licenseProject3), 20);
        tokenId = licenseProject3.buyLicense(licenseId6,0);

        vm.stopBroadcast();

        vm.startBroadcast(pk_anvilAccount3);

        tokenId = licenseProject1.buyLicense(licenseId1, 0);
        tokenId = licenseProject2.buyLicense{value: 5 ether}(licenseId5,0);
        tokenId = licenseProject1.buyLicense{value: 1 ether}(licenseId2, 0);


        paymentToken.approve(address(licenseProject3), 20);
        tokenId = licenseProject3.buyLicense(licenseId6,0);

        vm.stopBroadcast();
    }
}
