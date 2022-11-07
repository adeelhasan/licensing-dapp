//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import "./LicenseProject.sol";
import "./IERC4907.sol";


//the licenscee relationship is what will be rented out
//will need to set the rent price
//and also be able to collect the rent
//some method to be able to begin to rent

contract RentableLicense is LicenseProject, IERC4907  {

    constructor(string memory name, string memory symbol, address token) LicenseProject(name,symbol,token) {}

    function setUser(uint256 tokenId, address user, uint64 expires) external {}

    function userOf(uint256 tokenId) external view returns(address) {}

    function userExpires(uint256 tokenId) external view returns(uint256) {}

}
