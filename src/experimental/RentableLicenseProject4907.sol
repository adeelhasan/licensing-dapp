//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import "./IERC4907.sol";
import "./../RentableLicenseProject.sol";


/// @notice this project is currently experimental, the 4907 needs to be made compatible with
/// internal data structures such as RentalLease and listing. marked abstract to prevent
/// usage as well as so that Foundry does not deploy it

abstract contract RentableLicenseProject4907 is RentableLicenseProject, IERC4907 {


    constructor(string memory name, string memory symbol, address token) RentableLicenseProject(name, symbol, token) {}

    /// @notice IERC4907 support - this can effectively start a lease
    function setUser(uint256 tokenId, address user, uint64 expires) external override {
        //should start a new lease, and revert if there is a current one in this time period
        for (uint256 index; index < leaseIdsByToken[tokenId].length; index++) {
            RentalLease memory lease = leases[tokenId][leaseIdsByToken[tokenId][index]];
            if (((block.timestamp >= lease.startTime) && (block.timestamp <= lease.endTime)) || 
                       ((expires >= lease.startTime) && (expires <= lease.endTime)))
                       revert LeasesCannotOverlap();
        }
        licensees[tokenId].user = user;
        licensees[tokenId].endTime = expires;
    }
    
    /// @notice IERC4907 support 
    function userOf(uint256 tokenId) external view override returns(address) {
        RentalLease memory lease = _getCurrentLease(tokenId);
        if (lease.renter != address(0))
            return lease.renter;
        else
            return licensees[tokenId].user; 
    }

    /// @notice IERC4907 support 
    /// what should be returned if the token id is invalid? throw an error?
    /// or if the user has already expired
    function userExpires(uint256 tokenId) external view override returns(uint256) {
        RentalLease memory lease = _getCurrentLease(tokenId);
        if (lease.renter != address(0))
            return lease.endTime;
        else
             return licensees[tokenId].endTime; //TBD what to do about the 0
    }


}
