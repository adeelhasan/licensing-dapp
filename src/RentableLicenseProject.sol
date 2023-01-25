//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import "forge-std/console.sol";
import "./LicenseProject.sol";

enum RentalTimeUnit { Seconds, Minutes, Hourly, Daily, Weekly, Monthly, Annual }
struct RentalListing {
    uint256 id;
    RentalTimeUnit timeUnit;
    uint256 pricePerTimeUnit;
    uint256 minimumUnits;
    uint256 maximumUnits;
    bool streamingAllowed;
}

struct RentalLease {
    uint256 id;
    address renter;
    uint256 rentPaid;
    uint256 startTime;
    uint256 endTime;
}

struct StreamingLeaseInfo {
    uint256 ratePerSecond;
    uint256 balanceAlreadyPaid;
    bool ended;
}

contract RentableLicenseProject is LicenseProject {

    using Counters for Counters.Counter;

    mapping (uint256 => mapping(uint256 => RentalListing)) public listings; //token id to listing id to listing
    mapping (uint256 => mapping(uint256 => RentalLease)) public leases; //token id to lease id to lease
    mapping (uint256 => StreamingLeaseInfo) public streamingLeases;

    //iterators for the mappings above
    mapping(uint256 => uint256[]) internal listingIdsByToken;
    mapping(uint256 => uint256[]) internal leaseIdsByToken;

    Counters.Counter private _leaseIdCounter;
    Counters.Counter private _listingIdCounter;

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
        uint256 timeUnit
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

    event StreamingLeaseEnded(
        uint256 indexed tokenId,
        uint256 indexed leaseId,
        address endedBy
    );    


    error ListingNotValid();
    error StreamingNotEnabled(uint256 listingId);
    error NotEnoughTimeBought(uint256 actual, uint256 min);
    error TooMuchTimeBought(uint256 actual, uint256 max);
    error InconsistentRange(uint256 start, uint256 end);
    error ListingCannotBeFree();
    error StreamingRateOnlyInSeconds();
    error ListingTimeUnitAlreadyExists(uint256 timeUnit);
    error ListingCannotOutlastLicense();
    error CannotRentBeyondLicenseExpiration();
    error OnlyRenter();
    error StreamingLeasesCannotBeExtended();

    constructor(string memory name, string memory symbol, address token) LicenseProject(name, symbol, token) {
    }

    /// @notice the renter takes precendence over the licensee/owner
    /// @dev there is only one active lease at any particular time
    function checkValidity(uint256 tokenId) override public view returns(bool) {
        RentalLease memory lease = _getCurrentLease(tokenId);
        if (lease.renter != address(0))
            return lease.renter == msg.sender;
        return super.checkValidity(tokenId);
    }

    /// @notice each time unit can have only one listing per token. eg, if an hourly
    /// rate is quoted for a tokenId, then there cannot be another hourly listing
    /// @param tokenId licensee nft id
    /// @param timeUnit time interval for the listing, by the second, minute etc
    /// @param timeUnitPrice time interval price
    /// @param minimumUnits have to buy at least this much; 0 to ignore
    /// @param maximumUnits have to buy at most this much; 0 to ignore
    /// @param allowStreaming give the user to be able to stream, timeUnit has to be seconds in this case
    function addRentalListing(
        uint256 tokenId,
        RentalTimeUnit timeUnit,
        uint256 timeUnitPrice,
        uint256 minimumUnits,
        uint256 maximumUnits,
        bool allowStreaming
    )
        public
        returns (uint256 listingId)
    {
        if ((maximumUnits > 0) && maximumUnits < minimumUnits) revert InconsistentRange(maximumUnits, minimumUnits);
        if (!checkValidity(tokenId)) revert TokenNotValid(tokenId);
        if (msg.sender != ownerOf(tokenId)) revert OnlyTokenOwner();
        if (timeUnitPrice == 0) revert ListingCannotBeFree();
        if (allowStreaming && (timeUnit != RentalTimeUnit.Seconds)) revert StreamingRateOnlyInSeconds();

        uint256 timeLength = RentableLicenseHelper.convertTimeUnitToSeconds(uint256(timeUnit), minimumUnits);
        if (((timeLength > 0) && (licensees[tokenId].endTime > 0)) && (block.timestamp + timeLength > licensees[tokenId].endTime))
                revert ListingCannotOutlastLicense();

        uint256 count = listingIdsByToken[tokenId].length;
        for (uint256 index; index < count; index++) {
            if (listings[tokenId][listingIdsByToken[tokenId][index]].timeUnit == timeUnit)
                revert ListingTimeUnitAlreadyExists(uint256(timeUnit));
        }

        _listingIdCounter.increment();
        listingId = _listingIdCounter.current();
        listings[tokenId][listingId] = RentalListing(listingId, timeUnit, timeUnitPrice, minimumUnits, maximumUnits, allowStreaming);
        listingIdsByToken[tokenId].push(listingId);

        emit ListingAdded(tokenId, msg.sender, uint256(timeUnit), timeUnitPrice, minimumUnits, maximumUnits);
    }

    function updateRentalListing(
        uint256 tokenId,
        uint256 listingId,
        uint256 timeUnitPrice,
        uint256 minimumUnits,
        uint256 maximumUnits
    )
        public 
    {
        if ((maximumUnits > 0) && maximumUnits < minimumUnits) revert InconsistentRange(maximumUnits, minimumUnits);
        if (msg.sender != ownerOf(tokenId)) revert OnlyTokenOwner();

/*         uint256 timeLength = timeUnitLengths[uint256(timeUnit)] * minimumUnits;
        if ((timeLength > 0) && (licensees[tokenId].endTime > 0)) {
            require(block.timestamp + timeLength <= licensees[tokenId].endTime, "listing will expire before minimum time");
        }
 */
        RentalListing memory listing = listings[tokenId][listingId];
        if (listing.id == 0) revert ListingNotValid();
        listings[tokenId][listingId].pricePerTimeUnit = timeUnitPrice;
        listings[tokenId][listingId].maximumUnits = maximumUnits;
        listings[tokenId][listingId].minimumUnits = minimumUnits;

        emit ListingUpdated(tokenId, msg.sender, listingId);
    }

    function removeRentalListing(uint256 tokenId, uint256 listingId) external {
        if (msg.sender != ownerOf(tokenId)) revert OnlyTokenOwner();

        uint256 count = listingIdsByToken[tokenId].length;
        for (uint256 index; index < count; index++) {
            if (listingIdsByToken[tokenId][index] == listingId) {
                if (count-1 == index)
                    listingIdsByToken[tokenId].pop();
                else {
                    listingIdsByToken[tokenId][index] = listingIdsByToken[tokenId][count-1];
                    listingIdsByToken[tokenId].pop();                
                }
                emit ListingRemoved(tokenId, listingId);
                break;
            }
        }
    }

    /// @dev cannot overlap with an existing lease, even if its the same user's
    /// @param tokenId the licensee nft token id, associated with a license purchase
    /// @param listingId the listing which will be the basis for the lease
    /// @param startTime has to be in the future; pass 0 to start immediately
    /// @param timeUnitsCount how many units of the RentalTimeUnit in the listing to purchase
    /// @param streamLease stream this lease, which will make it pay as you go by the second
    function buyLease(
        uint256 tokenId,
        uint256 listingId,
        uint256 startTime,
        uint256 timeUnitsCount,
        bool streamLease
    ) 
        public
        payable
        returns (uint256 leaseId)
    {
        if (!_checkValidity(tokenId,address(0)))
            revert LicenseNotCurrent(tokenId);
        require(timeUnitsCount > 0,"have to buy some time");

        RentalListing memory listing = listings[tokenId][listingId];
        if (listing.id == 0) revert ListingNotValid();

        if (streamLease && !listing.streamingAllowed)
            revert StreamingNotEnabled(listingId);
        if ((listing.minimumUnits > 0) && (timeUnitsCount < listing.minimumUnits))
            revert NotEnoughTimeBought(timeUnitsCount, listing.minimumUnits);
        if ((listing.maximumUnits > 0) && (timeUnitsCount > listing.maximumUnits))
            revert TooMuchTimeBought(timeUnitsCount, listing.maximumUnits);

        if (startTime == START_NOW)
            startTime = block.timestamp;

        uint256 rentalTimeLength = RentableLicenseHelper.convertTimeUnitToSeconds(uint256(listing.timeUnit), timeUnitsCount);
        uint256 endTime = startTime + rentalTimeLength;
        if ((licensees[tokenId].endTime > 0) && (endTime > licensees[tokenId].endTime))
            revert CannotRentBeyondLicenseExpiration();
        uint256 rentalPrice = listing.pricePerTimeUnit * timeUnitsCount;

        for (uint256 index; index < leaseIdsByToken[tokenId].length; index++) {
            RentalLease memory lease = leases[tokenId][leaseIdsByToken[tokenId][index]];
            require (!(((startTime >= lease.startTime) && (startTime <= lease.endTime)) || 
                       ((endTime >= lease.startTime) && (endTime <= lease.endTime))), 
                       "overlaps an existing lease");
        }

        _leaseIdCounter.increment();
        leaseId = _leaseIdCounter.current();

        //if lease is streamed, then the payment is held in escrow at the contract
        //till the lease starts, then it can start to be collected by the token holder
        if (!streamLease)
            _collectPayment(msg.sender, ownerOf(tokenId), rentalPrice);
        else {
            _collectPayment(msg.sender, address(0), rentalPrice);
            streamingLeases[leaseId] = StreamingLeaseInfo(listing.pricePerTimeUnit, 0, false);
        }


        leases[tokenId][leaseId] = RentalLease(leaseId, msg.sender, rentalPrice, startTime, startTime + rentalTimeLength);
        leaseIdsByToken[tokenId].push(leaseId);

        emit LeaseStarted(tokenId, msg.sender, startTime, endTime);
    }

    /// @notice adds a lease period to the end of the current lease
    function extendLease(
        uint256 tokenId,
        uint256 listingId,
        uint256 timeUnitsCount
    ) 
        external
        payable
    {
        if (!_checkValidity(tokenId,address(0)))
            revert LicenseNotCurrent(tokenId);        

        RentalLease memory lease = _getCurrentLease(tokenId);
        if (lease.renter != msg.sender) revert OnlyRenter();
        uint256 startTime = lease.endTime + 1;
        StreamingLeaseInfo memory sli = streamingLeases[lease.id];
        if (sli.ratePerSecond != 0) revert StreamingLeasesCannotBeExtended();
        buyLease(tokenId, listingId, startTime, timeUnitsCount, false);
    }

    /// @notice this lets a renter exit a streaming lease
    /// @param tokenId the nft token id
    /// @param leaseId the rental lease id
    function endStreamingLease(uint256 tokenId, uint256 leaseId) public {
        RentalLease memory lease = leases[tokenId][leaseId];
        if (lease.renter != msg.sender) revert OnlyRenter();
        require(block.timestamp < lease.endTime, "can only cancel before endTime");
        StreamingLeaseInfo memory sli = streamingLeases[leaseId];
        require(sli.ratePerSecond > 0, "streaming not valid");
        require(!sli.ended, "streaming already finished");

        //before the start, refund whole amount back to renter
        if (lease.startTime > block.timestamp) {
            balances[lease.renter] += lease.rentPaid;
        }

        //stream is active, refund according to the time period used
        if ((block.timestamp > lease.startTime) && (block.timestamp < lease.endTime)) {
            uint256 timeRemaining = lease.endTime - block.timestamp;
            balances[lease.renter] += (timeRemaining * sli.ratePerSecond);
            balances[ownerOf(tokenId)] = ((block.timestamp - lease.startTime) * sli.ratePerSecond) - sli.balanceAlreadyPaid;
        }

        streamingLeases[leaseId].ended = true;
        emit StreamingLeaseEnded(tokenId, leaseId, msg.sender);
    }

    function getRentFromStreamingLease(uint256 tokenId, uint256 leaseId) public {
        if (ownerOf(tokenId) != msg.sender) revert OnlyTokenOwner();

        RentalLease memory lease = leases[tokenId][leaseId];
        require(lease.id == leaseId, "unpexpected lease id");
        require(block.timestamp > lease.startTime, "stream has not started as yet");

        StreamingLeaseInfo memory sli = streamingLeases[leaseId];
        require(sli.ratePerSecond > 0, "stream not valid");

        if (lease.endTime >= block.timestamp) {
            //stream has ended
            balances[msg.sender] += lease.rentPaid - sli.balanceAlreadyPaid;
            streamingLeases[leaseId].balanceAlreadyPaid = lease.rentPaid;
        }

        if ((block.timestamp > lease.startTime) && (lease.endTime < block.timestamp)) {
            //middle of lease, see how much is due so far
            uint256 timeSinceStart = block.timestamp - lease.startTime;
            balances[ownerOf(tokenId)] += (timeSinceStart * sli.ratePerSecond) - sli.balanceAlreadyPaid;
            streamingLeases[leaseId].balanceAlreadyPaid += (timeSinceStart * sli.ratePerSecond);
        }
    }
    
    /// @notice get all leases for a token
    function listingsForLicense(uint256 tokenId) external view returns (RentalListing[] memory) {
        if (this.ownerOf(tokenId) == address(0)) revert TokenNotMinted(tokenId);
        uint256 count = listingIdsByToken[tokenId].length;
        RentalListing[] memory result = new RentalListing[](count);
        for (uint256 index = 0; index < count; index++) {
            result[index] = listings[tokenId][listingIdsByToken[tokenId][index]];
        }
        return result;
    }

    /// @notice find the lease which is currently active for this token id
    function _getCurrentLease(uint256 tokenId) internal view returns (RentalLease memory) {
        RentalLease memory lease;
        uint256 leasesCount = leaseIdsByToken[tokenId].length;
        if (leasesCount > 0) {
            for (uint256 index; index < leasesCount; index++) {
                lease = leases[tokenId][leaseIdsByToken[tokenId][index]];
                if (lease.renter != address(0)) {
                    if (block.timestamp >= lease.startTime && block.timestamp <= lease.endTime) {
                        return lease;
                    }
                }
            }
        }
        return RentalLease(0, address(0), 0, 0, 0);
    }

    /// @notice garbage collection for expired leases
    /// @dev this is separated out, so that who bears the cost is clearly delineated
    /// it's the token owner should be bearing this cost, if they don't call it
    /// then the project owner should be taking care of it
    /// makes sense to save some ether from the token owner for the transaction cost
    /// in both setting up the lease initially, and also in clearing it up
    function cleanupExpiredLeases(uint256 tokenId) external {
        RentalLease memory lease;
        uint256 leasesCount = leaseIdsByToken[tokenId].length;
        if (leasesCount > 0) {
            for (uint256 index; index < leasesCount; index++) {
                lease = leases[tokenId][leaseIdsByToken[tokenId][index]];
                if (lease.renter != address(0) && (block.timestamp > lease.endTime)) {
                    delete leases[tokenId][lease.id];
                    if (leasesCount-1 == index) //already on the last one
                        leaseIdsByToken[tokenId].pop();
                    else { //swap and then pop, but have to operate on main storage
                        leaseIdsByToken[tokenId][index] = leaseIdsByToken[tokenId][leaseIdsByToken[tokenId].length-1];
                        leaseIdsByToken[tokenId].pop();
                    }
                }
            }
        }
    }

}

library RentableLicenseHelper {

    function convertTimeUnitToSeconds(uint256 timeUnit_, uint256 timeUnitCount) pure public returns(uint256 timeLength) {
        uint256 timeUnit = uint256(timeUnit_);
        assembly {
            switch timeUnit
                case 0 {
                    timeLength := timeUnitCount
                }
                case 1 {
                    timeLength := mul(timeUnitCount, 60)
                }
                case 2 {
                    timeLength := mul(timeUnitCount, 3600)
                }
                case 3 {
                    timeLength := mul(timeUnitCount, 86400)
                }
                case 4 {
                    timeLength := mul(timeUnitCount, 604800)
                }
                case 5 {
                    timeLength := mul(timeUnitCount, 2592000)
                }
                case 6 {
                    timeLength := mul(timeUnitCount, 31536000)
                }
        }

    }   
}
