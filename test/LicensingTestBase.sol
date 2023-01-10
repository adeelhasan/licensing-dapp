// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "openzeppelin-contracts/token/ERC20/ERC20.sol";

/// @notice just a helper contract
contract PaymentToken is ERC20 {
    constructor(string memory name, string memory symbol, uint initialSupply) ERC20(name,symbol) {
        _mint(msg.sender,initialSupply);
    }
}

contract LicensingTestBase is Test {
    
    uint licenseId1;
    uint licenseId2;
    uint licenseId3;
    address testAccount1;
    address testAccount2;
    address testAccount3;
    uint licenseTokenId1;
    uint licenseTokenId2;


    PaymentToken paymentToken;

    function setUp() public virtual {
        paymentToken = new PaymentToken("SILVER","SLV",UINT256_MAX);
    }

}