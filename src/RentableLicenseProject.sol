//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import "forge-std/console.sol";
import "./IERC4907.sol";
import "./LicenseProject.sol";

enum RentalTimeUnit { Hourly, Daily, Weekly, Monthly, Annual }
struct RentalListing {
    RentalTimeUnit timeUnit;
    uint256 pricePerTimeUnit;
    uint256 minimumUnits;
    uint256 maximumUnits;
}

struct RentalLease {
    address renter;
    uint256 rentPaid;
    uint256 startTime;
    uint256 endTime;
}

contract RentableLicenseProject is LicenseProject, IERC4907 {

    mapping (uint256 => RentalListing[]) public listings;
    mapping (uint256 => RentalLease[]) public leases;
    mapping (address => uint256) public balances;

    uint256[5] private timeUnitLengths = [3600,86400,604800,2592000,31536000];

    event ListingAdded(
        uint256 indexed tokenId,
        address indexed lister,
        uint256 timeUnit,
        uint256 pricePerUnit,
        uint256 minUnits,
        uint256 maxUnits
    );

    event ListingUpdated(
        uint256 indexed tokenId,
        address indexed lister,
        uint256 timeUnit,
        uint256 pricePerUnit,
        uint256 minUnits,
        uint256 maxUnits
    );

    event ListingRemoved(
        uint256 indexed tokenId,
        uint256 timeUnit
    );

    event LeaseStarted(
        uint256 indexed tokenId,
        address indexed renter,
        uint256 startTime,
        uint256 endTime
    );

    constructor(string memory name, string memory symbol, address token) LicenseProject(name, symbol, token) {
    }

    /// @notice the renter takes precendence over the licensee/owner
    /// @dev there is only one active lease at a time
    function checkValidity(uint256 tokenId) override public view returns(bool) {
        RentalLease memory lease = _getCurrentLease(tokenId);
        if (lease.renter != address(0))
            return lease.renter == msg.sender;
        return super.checkValidity(tokenId);
    }

    /// @notice each time unit can have only one listing per token. eg, if an hourly
    /// rate is quoted for a tokenId, then there cannot be another hourly listing
    function addRentalListing(
        uint256 tokenId,
        RentalTimeUnit timeUnit,
        uint256 timeUnitPrice,
        uint256 minimumUnits,
        uint256 maximumUnits
    )
        public 
    {
        if (maximumUnits > 0)
            require(maximumUnits >= minimumUnits, "inconsistent max and min units");
        require(checkValidity(tokenId),"token not eligible for renting");
        require(msg.sender == ownerOf(tokenId),"only token owner can list");

        uint256 timeLength = timeUnitLengths[uint256(timeUnit)] * minimumUnits;
        if ((timeLength > 0) && (licensees[tokenId].endTime > 0)) {
            require(block.timestamp + timeLength <= licensees[tokenId].endTime, "listing will expire before minimum time");
        }

        uint256 count = listings[tokenId].length;
        for (uint256 index; index < count; index++) {
            require(listings[tokenId][index].timeUnit != timeUnit, "listing timeUnit already exists");
        }

        listings[tokenId].push(RentalListing(timeUnit, timeUnitPrice, minimumUnits, maximumUnits));

        emit ListingAdded(tokenId, msg.sender, uint256(timeUnit), timeUnitPrice, minimumUnits, maximumUnits);
    }

    /// @notice each time unit can have only one listing per token
    function updateRentalListing(
        uint256 tokenId,
        RentalTimeUnit timeUnit,
        uint256 timeUnitPrice,
        uint256 minimumUnits,
        uint256 maximumUnits
    )
        public 
        returns(
            bool updated
        )
    {
        if (maximumUnits > 0)
            require(maximumUnits >= minimumUnits, "inconsistent max and min units");
        require(msg.sender == ownerOf(tokenId),"only token owner can list");

        uint256 timeLength = timeUnitLengths[uint256(timeUnit)] * minimumUnits;
        if ((timeLength > 0) && (licensees[tokenId].endTime > 0)) {
            require(block.timestamp + timeLength <= licensees[tokenId].endTime, "listing will expire before minimum time");
        }

        uint256 count = listings[tokenId].length;
        for (uint256 index; index < count; index++) {
            if (listings[tokenId][index].timeUnit == timeUnit) {
                listings[tokenId][index].pricePerTimeUnit = timeUnitPrice;
                listings[tokenId][index].minimumUnits = minimumUnits;
                listings[tokenId][index].maximumUnits = maximumUnits;

                emit ListingAdded(tokenId, msg.sender, uint256(timeUnit), timeUnitPrice, minimumUnits, maximumUnits);

                updated = true;
                break;
            }
        }

        return updated;
    }

    function removeRentalListing(uint256 tokenId, RentalTimeUnit timeUnit) external {
        require(msg.sender == ownerOf(tokenId),"only for token owners");        
        uint256 count = listings[tokenId].length;
        for (uint256 index; index < count; index++) {
            RentalListing memory listing = listings[tokenId][index];
            if (listing.timeUnit == timeUnit) {
                if (count-1 == index)
                    listings[tokenId].pop();
                else {
                    listings[index] = listings[listings[index].length-1];
                    listings[tokenId].pop();                
                }

                emit ListingRemoved(tokenId, uint256(timeUnit));
            }
        }
    }

    /// @dev cannot overlap with an existing lease, even if its the same user's
    function buyLease(
        uint256 tokenId,
        RentalTimeUnit timeUnit,
        uint256 startTime,
        uint256 timeUnitsCount
    ) 
        public
        payable
    {
        require(_checkValidity(tokenId,address(0)),"license not current");

        uint256 count = listings[tokenId].length;
        bool foundTimeUnit;
        RentalListing memory listing;
        for (uint256 index; index < count; index++) {
            listing = listings[tokenId][index];
            if (listing.timeUnit == timeUnit) {
                foundTimeUnit = true;
                break;
            }
        }

        require(foundTimeUnit, "listing time unit is not valid");
        require(timeUnitsCount > 0,"have to buy some time");
        require(timeUnitsCount >= listing.minimumUnits,"not enough time bought");
        if (listing.maximumUnits > 0)
            require(timeUnitsCount <= listing.maximumUnits,"cannot buy that much time");

        uint256 rentalTimeLength = timeUnitsCount * timeUnitLengths[uint256(listing.timeUnit)];
        uint256 endTime = startTime + rentalTimeLength;
        if (licensees[tokenId].endTime > 0)
            require(endTime < licensees[tokenId].endTime,"cannot rent beyond end of license");
        uint256 rentalPrice = listing.pricePerTimeUnit * timeUnitsCount;

        uint256 leasesCount = leases[tokenId].length;
        for (uint256 index; index<leasesCount; index++) {
            RentalLease memory lease = leases[tokenId][index];
            require (!(((startTime >= lease.startTime) && (startTime <= lease.endTime)) || 
                       ((endTime >= lease.startTime) && (endTime <= lease.endTime))), 
                       "overlaps an existing lease");
        }

        _collectPayment(rentalPrice);
        balances[ownerOf(tokenId)] += rentalPrice;

        leases[tokenId].push(RentalLease(msg.sender, rentalPrice, startTime, startTime + rentalTimeLength));

        emit LeaseStarted(tokenId, msg.sender, startTime, endTime);
    }

    /// @notice adds a lease period to the end of the current lease
    function extendLease(
        uint256 tokenId,
        RentalTimeUnit timeUnit,
        uint256 timeUnitsCount
    ) 
        external
        payable
    {
        require(_checkValidity(tokenId,address(0)),"license not current");
        RentalLease memory lease = _getCurrentLease(tokenId);
        require(lease.renter == msg.sender, "only current renter can extend lease");
        uint256 startTime = lease.endTime + 1;
        buyLease(tokenId, timeUnit, startTime, timeUnitsCount);
    }


    /// @notice IERC4907 support - this can effectively start a lease
    function setUser(uint256 tokenId, address user, uint64 expires) external override {
        //should start a new lease, and revert if there is a current one in this time period
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

    /// @notice implements the withdraw pattern
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

    /// @notice balance available to withdrawl pattern
    function getBalance() external view returns(uint) {
        return balances[msg.sender];
    }

    /// @notice get all leases for a token
    function leasesForLicense(uint256 tokenId) external view returns (RentalLease[] memory) {
        require(this.ownerOf(tokenId) != address(0),"token id has not been minted");        
        uint256 count = leases[tokenId].length;
        RentalLease[] memory result = new RentalLease[](count);
        for (uint256 index = 0; index < count; index++) {
            result[index] = leases[tokenId][index];
        }
        return result;
    }

    /// @notice get all leases for a token
    function listingsForLicense(uint256 tokenId) external view returns (RentalListing[] memory) {
        require(this.ownerOf(tokenId) != address(0),"token id has not been minted");        
        uint256 count = listings[tokenId].length;
        RentalListing[] memory result = new RentalListing[](count);
        for (uint256 index = 0; index < count; index++) {
            result[index] = listings[tokenId][index];
        }
        return result;
    }

    /// @notice find the lease which is currently active for this token id
    function _getCurrentLease(uint256 tokenId) internal view returns (RentalLease memory) {
        RentalLease[] memory tokenLeases = leases[tokenId];
        RentalLease memory lease;
        uint256 leasesCount = tokenLeases.length;
        if (leasesCount > 0) {
            for (uint256 index; index < leasesCount; index++) {
                lease = tokenLeases[index];
                if (lease.renter != address(0)) {
                    if (block.timestamp >= lease.startTime && block.timestamp <= lease.endTime) {
                        return lease;
                    }
                }
            }
        }
        return RentalLease(address(0),0,0,0);
    }

    /// @notice garbage collection for expired leases
    /// @dev this is separated out, so that who bears the cost is clearly delineated
    /// it's the token owner should be bearing this cost, if they don't call it
    /// then the project owner should be taking care of it
    /// makes sense to save some ether from the token owner for the transaction cost
    /// in both setting up the lease initially, and also in clearing it up
    function cleanupExpiredLeases(uint256 tokenId) external {
        RentalLease[] memory tokenLeases = leases[tokenId];
        RentalLease memory lease;
        uint256 leasesCount = tokenLeases.length;
        if (leasesCount > 0) {
            for (uint256 index; index<leasesCount; index++) {
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
