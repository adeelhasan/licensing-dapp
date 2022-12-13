//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import "./LicenseProject.sol";
import "./LicenseStructs.sol";
import "./IERC4907.sol";
import "forge-std/console.sol";


//the licensee relationship is what will be rented out
//will need to set the rent price
//and also be able to collect the rent
//some method to be able to begin to rent


enum RentalTimeUnit { Hourly, Daily, Weekly, Annual, Entirety }
struct RentalListing {
    RentalTimeUnit timeUnit;
    uint pricePerTimeUnit;
    uint minimumUnits;
    bool isActive;
}

/// should the LicenseProject get rental capability at all?
/// is there any use of keeping user in licensee
/// need more commenting
/// need some more tests
/// and should probably checkin
/// should the listings be possibly multiple as well?
/// should there be a limit on the number of listings


/// @notice the lease is not used in runtime checks
///         its purpose is to keep a record
struct RentalLease {
    address renter;
    uint rentPaid;
    uint startTime;
    uint endTime;
}

/// when the underlying license is extended by the user, that has no bearing on the rental
/// rental lease extension and pricing are beyond the scope

contract RentableLicenseProject is LicenseProject, IERC4907  {

    mapping (uint256 => RentalListing) public listings;
    mapping (uint256 => RentalLease[]) public leases;
    mapping (address => uint256) public balances;

    uint256[5] timeUnitLengths = [3600,86400,604800,31536000,0];

    constructor(string memory name, string memory symbol, address token) LicenseProject(name,symbol,token) {

    }

    /// @notice the renter takes precendence over the licensee/owner
    /// @dev    there is only one active lease at a time
    function checkValidity(uint tokenId) override view public returns(bool) {
        RentalLease memory lease = _getCurrentLease(tokenId);
        if (lease.renter != address(0)) {
            require(lease.renter == msg.sender,"valid for user of record only");
            return true;
        }
        return super.checkValidity(tokenId);
    }

    /// @notice by the token owner
    /// @dev does not look for listings overlapping in terms of time period
    function addRentalListing(uint256 tokenId, RentalTimeUnit timeUnit, uint256 timeUnitPrice, uint256 minimumUnits) public {
        require(checkValidity(tokenId),"token not eligible for renting");
        require(msg.sender == ownerOf(tokenId),"only token owner can list");

        uint256 timeLength = timeUnitLengths[uint256(timeUnit)] * minimumUnits;
        if ((timeLength > 0) && (licensees[tokenId].endTime > 0)) {
            require(block.timestamp + timeLength <= licensees[tokenId].endTime, "listing will expire before minimum time");
        }

        listings[tokenId] = RentalListing(timeUnit,timeUnitPrice,minimumUnits,true);
    }

    function removeRentalListing(uint tokenId) external {
        require(msg.sender == ownerOf(tokenId),"only for token owners");
        listings[tokenId].isActive = false;
    }

    /// @dev has to check for overlapping
    function rent(uint256 tokenId, uint256 startTime, uint256 timeUnits) payable external {
        require(_checkValidity(tokenId,address(0)),"license not current");
        require(timeUnits > 0, "full duration rental not supported as yet");

        RentalListing memory listing = listings[tokenId];
        require(timeUnits >= listing.minimumUnits,"not enough time bought");

        uint256 rentalTimeLength = timeUnits * timeUnitLengths[uint256(listing.timeUnit)];
        uint endTime = startTime + rentalTimeLength;
        if (licensees[tokenId].endTime > 0)
            require(endTime < licensees[tokenId].endTime,"cannot rent beyond end of license");
        uint256 rentalPrice = listing.pricePerTimeUnit * timeUnits;
        _collectPayment(rentalPrice);
        balances[ownerOf(tokenId)] += rentalPrice;

        leases[tokenId].push(RentalLease(msg.sender,rentalPrice,startTime,startTime + rentalTimeLength));

        //emit LeaseStarted(tokenId, msg.sender,startTime,endTime);
    }

    /// @notice this can effectively start a lease
    function setUser(uint256 tokenId, address user, uint64 expires) external override {
        licensees[tokenId].user = user;
        licensees[tokenId].endTime = expires;
    }

    
    function userOf(uint256 tokenId) external view override returns(address) {
        return licensees[tokenId].user;
    }

    /// what should be returned if the token id is invalid? throw an error?
    /// or if the user has already expired
    function userExpires(uint256 tokenId) external view override returns(uint256) {
        RentalLease memory lease = _getCurrentLease(tokenId);
        if (lease.renter != address(0))
            return lease.endTime;
        else
            return licensees[tokenId].endTime;
    }

    /// @notice find the lease which is currently active for this token id
    function _getCurrentLease(uint256 tokenId) internal view returns (RentalLease memory) {
        RentalLease[] memory tokenLeases = leases[tokenId];
        RentalLease memory lease;
        uint leasesCount = tokenLeases.length;
        if (leasesCount > 0) {
            for (uint index; index<leasesCount; index++) {
                lease = tokenLeases[index];
                if (lease.renter != address(0)) {
                    if (block.timestamp>=lease.startTime && block.timestamp<=lease.endTime) {
                        return lease;
                    }
                }
            }
        }

        return RentalLease(address(0),0,0,0);
    }


    /// @notice implements the withdraw pattern
    ///         to send back either ether or tokens to the balance holder
    function withdraw() external {
        uint256 wholeAmount = balances[msg.sender];
        require(wholeAmount > 0, "nothing to withdraw");
        if (paymentToken == address(0)) {
            balances[msg.sender] = 0;
            (bool success,) = payable(msg.sender).call{value: wholeAmount}("");
            require(success, "unable to withdraw");
        }
        else {
            IERC20(paymentToken).transfer(msg.sender,wholeAmount);
        }
    }

    function getBalance() external view returns(uint) {
        return balances[msg.sender];
    }

    /// @notice cleanup up any leases which have expired
    ///         this is separated out, so that who bears the cost is clearly delineated
    ///         it's the token owner should be bearing this cost, if they don't call it
    ///         then the project owner should be taking care of it
    ///         makes sense to save some ether from the token owner for the transaction cost
    ///         in both setting up the lease initially, and also in clearing it up
    function cleanupExpiredLeases(uint256 tokenId) external {
        RentalLease[] memory tokenLeases = leases[tokenId];
        RentalLease memory lease;
        uint leasesCount = tokenLeases.length;
        if (leasesCount > 0) {
            for (uint index; index<leasesCount; index++) {
                lease = tokenLeases[index];
                if (lease.renter != address(0) && (block.timestamp > lease.endTime)) {
                    if (leasesCount-1 == index) //already on the last one
                        leases[tokenId].pop();
                    else { //switch and then pop, but have to operate on main storage
                        leases[index] = leases[leases[index].length-1];
                        leases[tokenId].pop();
                    }
                }
            }
        }
    }

}
