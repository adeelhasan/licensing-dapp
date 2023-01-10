//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import "forge-std/console.sol";
import "./IERC4907.sol";
import "./LicenseProject.sol";
import "utility/FundsCollector.sol";

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

contract RentableLicenseProject is LicenseProject, IERC4907 {

    using Counters for Counters.Counter;

    mapping (uint256 => mapping(uint256 => RentalListing)) public listings; //token id to listing id to listing
    mapping (uint256 => mapping(uint256 => RentalLease)) public leases; //token id to lease id to lease
    mapping (uint256 => StreamingLeaseInfo) public streamingLeases;

    //iterators for the mappings above
    mapping(uint256 => uint256[]) private listingIdsByToken;
    mapping(uint256 => uint256[]) private leaseIdsByToken;

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

    event StreamingLeaseEnded(
        uint256 indexed tokenId,
        uint256 indexed leaseId,
        address endedBy
    );    

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
        if (maximumUnits > 0)
            require(maximumUnits >= minimumUnits, "inconsistent max and min units");
        require(checkValidity(tokenId),"token not eligible for renting");
        require(msg.sender == ownerOf(tokenId),"only token owner can list");
        require(timeUnitPrice > 0, "a listing cannot be free");
        if (allowStreaming)
            require(timeUnit == RentalTimeUnit.Seconds, "streaming only when seconds are used for time unit");

        uint256 timeLength = convertTimeUnitToSeconds(timeUnit, minimumUnits);
        if ((timeLength > 0) && (licensees[tokenId].endTime > 0)) {
            require(block.timestamp + timeLength <= licensees[tokenId].endTime, "listing will expire before minimum time");
        }

        uint256 count = listingIdsByToken[tokenId].length;
        for (uint256 index; index < count; index++) {
            require(listings[tokenId][listingIdsByToken[tokenId][index]].timeUnit != timeUnit, "listing timeUnit already exists");
        }

        _listingIdCounter.increment();
        listingId = _listingIdCounter.current();
        listings[tokenId][listingId] = RentalListing(listingId, timeUnit, timeUnitPrice, minimumUnits, maximumUnits, allowStreaming);
        listingIdsByToken[tokenId].push(listingId);

        emit ListingAdded(tokenId, msg.sender, uint256(timeUnit), timeUnitPrice, minimumUnits, maximumUnits);
    }

    /// @notice each time unit can have only one listing per token
    function updateRentalListing(
        uint256 tokenId,
        uint256 listingId,
        uint256 timeUnitPrice,
        uint256 minimumUnits,
        uint256 maximumUnits
    )
        public 
    {
        if (maximumUnits > 0)
            require(maximumUnits >= minimumUnits, "inconsistent max and min units");
        require(msg.sender == ownerOf(tokenId),"only token owner can list");

/*         uint256 timeLength = timeUnitLengths[uint256(timeUnit)] * minimumUnits;
        if ((timeLength > 0) && (licensees[tokenId].endTime > 0)) {
            require(block.timestamp + timeLength <= licensees[tokenId].endTime, "listing will expire before minimum time");
        }
 */
        RentalListing memory listing = listings[tokenId][listingId];
        require(listing.id > 0, "listing not valid");
        listings[tokenId][listingId].pricePerTimeUnit = timeUnitPrice;
        listings[tokenId][listingId].maximumUnits = maximumUnits;
        listings[tokenId][listingId].minimumUnits = minimumUnits;

        emit ListingUpdated(tokenId, msg.sender, listingId, timeUnitPrice, minimumUnits, maximumUnits);
    }

    function removeRentalListing(uint256 tokenId, uint256 listingId) external {
        require(msg.sender == ownerOf(tokenId),"only for token owners");

        uint256 count = listingIdsByToken[tokenId].length;
        for (uint256 index; index < count; index++) {
            if (listingIdsByToken[tokenId][index] == listingId) {
                if (count-1 == index)
                    listingIdsByToken[tokenId].pop();
                else {
                    listingIdsByToken[tokenId][index] = listingIdsByToken[tokenId][listingIdsByToken[tokenId].length-1];
                    listingIdsByToken[tokenId].pop();                
                }

                emit ListingRemoved(tokenId, listingId);
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
        require(_checkValidity(tokenId,address(0)),"license not current");
        require(timeUnitsCount > 0,"have to buy some time");

        RentalListing memory listing = listings[tokenId][listingId];
        require(listing.id > 0, "listing not valid");

        if (streamLease)
            require(listing.streamingAllowed, "streaming is not enabled on this listing");
        require(timeUnitsCount >= listing.minimumUnits,"not enough time bought");
        if (listing.maximumUnits > 0)
            require(timeUnitsCount <= listing.maximumUnits,"cannot buy that much time");

        if (startTime == START_NOW)
            startTime = block.timestamp;

        uint256 rentalTimeLength = convertTimeUnitToSeconds(listing.timeUnit, timeUnitsCount);
        uint256 endTime = startTime + rentalTimeLength;
        if (licensees[tokenId].endTime > 0)
            require(endTime < licensees[tokenId].endTime,"cannot rent beyond end of license");
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
        require(_checkValidity(tokenId,address(0)),"license not current");
        RentalLease memory lease = _getCurrentLease(tokenId);
        require(lease.renter == msg.sender, "only current renter can extend lease");
        uint256 startTime = lease.endTime + 1;
        StreamingLeaseInfo memory sli = streamingLeases[lease.id];
        require(sli.ratePerSecond == 0, "streaming leases cannot be extended");
        buyLease(tokenId, listingId, startTime, timeUnitsCount, false);
    }

    // lease cannot be identified if its not current --- we need a lease id
    // probably a lease id as well
    function endStreamingLease(uint256 tokenId, uint256 leaseId) public {
        RentalLease memory lease = leases[tokenId][leaseId];
        require(lease.renter == msg.sender, "only the leasee can end the lease");
        require(block.timestamp < lease.endTime, "can only cancel before endTime");
        StreamingLeaseInfo memory sli = streamingLeases[leaseId];
        require(sli.ratePerSecond > 0, "streaming not valid");
        require(!sli.ended, "streaming already finished");

        if (lease.startTime > block.timestamp) {
            //can be before the start, refund what has been deposited back to the renter
            balances[lease.renter] += lease.rentPaid;
        }

        if ((block.timestamp > lease.startTime) && (block.timestamp < lease.endTime)) {
            //mark for refund what has not been used up so far
            uint256 timeRemaining = lease.endTime - block.timestamp;
            balances[lease.renter] += (timeRemaining * sli.ratePerSecond);
            console.log("when ending the streaming %s",timeRemaining * sli.ratePerSecond);
            balances[ownerOf(tokenId)] = ((block.timestamp - lease.startTime) * sli.ratePerSecond) - sli.balanceAlreadyPaid;
        }

        streamingLeases[leaseId].ended = true;
        emit StreamingLeaseEnded(tokenId, leaseId, msg.sender);
    }

    function getRentFromStreamingLease(uint256 tokenId, uint256 leaseId) public {
        require(ownerOf(tokenId) == msg.sender, "can only be called by token owner");

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

    /// @notice get all leases for a token
    function leasesForLicense(uint256 tokenId) external view returns (RentalLease[] memory) {
        require(this.ownerOf(tokenId) != address(0),"token id has not been minted");        
        uint256 count = leaseIdsByToken[tokenId].length;
        RentalLease[] memory result = new RentalLease[](count);
        for (uint256 index = 0; index < count; index++) {
            result[index] = leases[tokenId][leaseIdsByToken[tokenId][index]];
        }
        return result;
    }

    /// @notice get all leases for a token
    function listingsForLicense(uint256 tokenId) external view returns (RentalListing[] memory) {
        require(this.ownerOf(tokenId) != address(0),"token id has not been minted");        
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


    function convertTimeUnitToSeconds(RentalTimeUnit timeUnit_, uint256 timeUnitCount) pure internal returns(uint256 timeLength) {
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
