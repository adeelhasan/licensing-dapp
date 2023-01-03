//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import "openzeppelin-contracts/utils/Counters.sol";
import "openzeppelin-contracts/access/Ownable.sol";
import "openzeppelin-contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/token/ERC721/extensions/ERC721Enumerable.sol";

struct Licensee {
    address user;
    uint licenseId;
    uint renewalsCount;
    uint startTime;
    uint endTime;
}

enum LicenseStatus { None, Active, NotActive }

struct License {
    string name;
    uint maxRenewals;
    uint length;
    uint price;
    LicenseStatus status;
    bool allowRenting;
}

struct LicenseeInfo {
    uint tokenId;
    Licensee licensee;
    License license;
}

struct LicenseProjectStub {
    address contractAddress;
    string name;
    string symbol;
}

/// @title License Project
/// @notice container for licenses, and the licensees for those licenses
/// one project for a software product, eg, and different licenses for
/// different plans. users purchase licenses and have a licensee relationship
/// @dev each licensee relationship is mapped to a ERC 721 token
contract LicenseProject is ERC721Enumerable, Ownable {

    using Counters for Counters.Counter;

    event LicenseAdded(uint256 indexed licenseId);
    event LicenseBought(address indexed licensee, uint256 tokenId, uint256 licenseId);
    event LicenseRenewed(address indexed licensee, uint256 tokenId, uint256 licenseId);
    event LicenseGifted(address indexed licensee, uint256 tokenId);
    event LicenseRented(address indexed renter, uint256 tokentId);
    event LicenseAutoRenewed(address indexed liscensee , uint256 licenseId, uint256 tokensPaid);

    address immutable public paymentToken;
    mapping(uint256 => Licensee) public licensees;

    uint256 constant private START_NOW = 0;
    uint256 constant private PERPETUAL = 0;
    License[] private _licenses;
    Counters.Counter private _tokenIdCounter;
    
    /// @notice setup the ERC 721 token
    /// @param token_   the ERC20 token that is accepted as payment, or pass address(0) if the 
    ///                 mode of payment is to be Ether. It has to be one or the other, not both
    constructor(string memory name, string memory symbol, address token_) ERC721(name,symbol) {
        paymentToken = token_;
    }

    /// @notice the primary check for the licensee validity
    function checkValidity(uint256 tokenId) public view virtual returns(bool) {
        return _checkValidity(tokenId, msg.sender);
    }

    /// @notice this will auto renewal as part of the validity check
    ///         this is 3x more gas costly, but very useful if so needed
    function checkValidityWithAutoRenewal(uint256 tokenId) public returns(bool) {
        require(this.ownerOf(tokenId) != address(0),"token id has not been minted");

        Licensee memory licensee = licensees[tokenId];
        require(licensee.user == msg.sender,"valid for user of record only");

        bool durationCheck = (licensee.endTime == PERPETUAL ||
              (block.timestamp >= licensee.startTime && block.timestamp <= licensee.endTime));

        if ((!durationCheck && this.paymentToken() != address(0)) &&
             (this.ownerOf(tokenId) == licensee.user) && 
             (IERC20(paymentToken).allowance(msg.sender,address(this)) >=
                _licenses[licensee.licenseId].price)
        ) {
            renewLicense(tokenId, START_NOW);
            durationCheck = true;

            emit LicenseAutoRenewed(msg.sender, licensee.licenseId, _licenses[licensee.licenseId].price);
        }
        
        return durationCheck;
    }

    /// @notice add a license, restricted to the license project owner
    /// @param name name for the license, as it would appear in the UI
    /// @param maxRenewals a value of 0 would be for unlimited renewals
    /// @param length of time, in seconds, for the validity period
    /// @param price interpreted as tokens or eth units, depending on the project setting
    function addLicense(
        string memory name, 
        uint256 maxRenewals, 
        uint256 
        length, 
        uint256 price
    ) 
        external
        onlyOwner 
        returns(
            uint256
        )
    {
        _licenses.push(License(name, maxRenewals, length, price, LicenseStatus.Active, false));
        uint256 licenseId = _licenses.length-1;

        emit LicenseAdded(licenseId);
        
        return licenseId;
    }

    /// @notice for a user to purchase a license
    /// @dev payment is accepted in ether or in pre-approved tokens, see _collectPayment
    /// @param licenseId to get the license data
    /// @param startTime can be 0 to start immediately, or has to be in the future
    function buyLicense(
        uint256 licenseId, 
        uint256 startTime
    ) 
        public
        payable
        returns(
            uint256
        )
    {
        require(startTime == START_NOW || startTime > block.timestamp,"startTime is not correct");
        require(licenseId < _licenses.length,"product id is not valid");

        License memory license = _licenses[licenseId];
        _collectPayment(license.price);
        uint256 newTokenId = _getNewTokenId(msg.sender);        
        _addDuration(newTokenId, msg.sender, licenseId, startTime, license.length, license.maxRenewals);

        return newTokenId;
    }

    /// @notice extend the duration for an existing licensee
    /// @param tokenId the token representing the licensee
    /// @param startTime the starting time, or 0 if needing to start immediately
    function renewLicense(uint256 tokenId, uint256 startTime) public payable {
        require(this.ownerOf(tokenId) != address(0),"token id has not been minted");        
        require(startTime == START_NOW || startTime > block.timestamp,"startTime is not correct");

        Licensee memory licensee = licensees[tokenId];
        License memory license = _licenses[licensee.licenseId];
        _collectPayment(license.price);
        _addDuration(tokenId, msg.sender, licensee.licenseId, startTime, license.length, license.maxRenewals);
    }

    /// @notice a way to assign a license by the project admin, bypassing any purchasing flow
    /// @param to the account to be gifted
    /// @param licenseId the license to be gifted
    /// @param startTime the datetime to start the validity
    function giftLicense(
            address to,
            uint256 licenseId, 
            uint256 startTime
        )
        external
        onlyOwner
        returns(
            uint256
        )
    {
        require(startTime == START_NOW || startTime > block.timestamp);
        require(licenseId < _licenses.length,"product id is not valid");

        License memory license = _licenses[licenseId];
        uint256 newTokenId = _getNewTokenId(to);
        _addDuration(newTokenId, to, licenseId, startTime, startTime + license.length, license.maxRenewals);

        emit LicenseGifted(to, newTokenId);

        return newTokenId;
    }

    /// @notice return licensee data, mainly for frontend consumption
    function getLicenseeData(uint256 tokenId) external view returns(Licensee memory) {
        return licensees[tokenId];
    }

    /// @notice return licensee data, mainly for frontend consumption
    function getLicenseData(uint256 licenseIndex) external view returns(License memory) {
        return _licenses[licenseIndex];
    }

    /// @notice you can soft transfer / rent your license if its valid
    /// if the license expires while rented then the licensee/license is responsible
    ///  for extending the duration rent collection is not addressed in this implementation
    ///  @dev   by default the rental is always to the end of the current duration
    function assignLicenseTo(uint256 tokenId, address renter) external virtual {
        require(checkValidity(tokenId),"token is not valid");
        require(licensees[tokenId].user == ownerOf(tokenId),"token already rented out)");

        licensees[tokenId].user = renter;
        
        emit LicenseRented(renter, tokenId);
    }

    /// @notice all licensee relationships for msg.sender
    function myLicenses() external view returns(LicenseeInfo[] memory) {
        uint256 count = balanceOf(msg.sender);
        LicenseeInfo[] memory result = new LicenseeInfo[](count);
        for (uint256 i; i<count; i++) {
            uint256 tokenId = tokenOfOwnerByIndex(msg.sender,i);
            result[i] = LicenseeInfo(tokenId,licensees[tokenId], _licenses[licensees[tokenId].licenseId]);
        }
        return result;
    }

    /// @notice licenses which are filtered to be active
    function activeLicences() external view returns(License[] memory) {
        return _filterLicenses(LicenseStatus.Active);
    }

    /// @notice this is restricted to the owner, will get all
    function allLicences() onlyOwner external view returns(License[] memory) {
        return _filterLicenses(LicenseStatus.None);
    }

    /// @notice a common spot to get the next token id
    function _getNewTokenId(address mintedTo) internal returns (uint) {
        _tokenIdCounter.increment();
        uint256 newTokenId = _tokenIdCounter.current();
        _safeMint(mintedTo, newTokenId);
        return newTokenId;
    }

    /// @notice common for billing
    /// @dev    either ether is sent in exact amount, or pre-approved tokens are transferred
    ///         if paymentToken was set then it's the default mode
    function _collectPayment(uint256 price) internal {
        if (paymentToken == address(0)) {
            require(price == msg.value,"expected ether was not sent");
        }
        else {
            require(msg.value == 0, "payment via tokens only, ether was sent too");
            require(paymentToken != address(0), "token address not set");
            
            if (price > 0)
                require(IERC20(paymentToken).transferFrom(msg.sender, address(this), price), "problem in token transfer");
        }
    }

    /// @notice this is shared functionality for running a filter
    function _filterLicenses(LicenseStatus status) internal view returns (License[] memory) {
        uint256 count = _licenses.length;
        License[] memory result = new License[](count);
        for (uint256 i; i<_licenses.length; i++) {
            if (status == LicenseStatus.None)
                result[i] = _licenses[i];
            else
                if (status == _licenses[i].status)
                    result[i] = _licenses[i];
        }
        return result;
    }

    /// @notice when a token is transferred, update the user as well, unless rented
    /// @dev batch transfers are currently not supported
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 firstTokenId,
        uint256 batchSize
    ) internal override virtual {
        require(batchSize == 1,"bulk transfers are not supported for licenses");
        super._afterTokenTransfer(from,to,firstTokenId,batchSize);

        // have to account for the initial transfer during minting
        if (licensees[firstTokenId].user != address(0)) {
            require(licensees[firstTokenId].user == from,"cannot transfer rented token");
            licensees[firstTokenId].user = to;
        }
    }

    /// @notice creates or extends the licensee relationship
    /// @param tokenId this should already be minted and owned by the licensee
    /// @param user the licensee to be
    /// @param licenseId the license which was bought or extended
    /// @param startTime when the validity starts
    /// @param length the validity period as defined in the license
    /// @param maxRenewals the upper limit on renewals, as defined in the license
    function _addDuration(
        uint256 tokenId, 
        address user, 
        uint256 licenseId, 
        uint256 startTime, 
        uint256 length, 
        uint256 maxRenewals
    ) private {
        Licensee memory licensee = licensees[tokenId];
        if (maxRenewals > 0)
            require(licensee.renewalsCount <= maxRenewals, "limit on renewals is reached");

        //buying for the first time
        if (licensee.renewalsCount == 0) {
            uint256 endTime;            
            if (startTime == START_NOW)
                startTime = block.timestamp;
            if (length > 0)
                endTime = startTime + length;
            licensees[tokenId] = Licensee(user,licenseId,1,startTime,endTime);

            emit LicenseBought(msg.sender, tokenId, licenseId);
        }
        else {
            require(licenseId == licensee.licenseId, "cannot extend another license");
            require(licensee.endTime != PERPETUAL,"license is already perpetual");

            if (checkValidity(tokenId) || (licensee.startTime > block.timestamp))
                //currently valid or valid in the future, ignore start and simply extend
                //the other choice is throw if new startTime is conflicting
                licensee.endTime += length;
            else {
                if (startTime == START_NOW)
                    licensee.startTime = block.timestamp;
                else
                    licensee.startTime = startTime;
                licensee.endTime = licensee.startTime + length;

                //this will close out renters, and only done if resetting both start and endTime
                licensee.user = ownerOf(tokenId);
            }
            licensee.renewalsCount++;
            licensees[tokenId] = licensee;
            
            emit LicenseRenewed(msg.sender, tokenId, licenseId);
        }
    }

    /// @dev common code for validity check
    function _checkValidity(uint256 tokenId, address user) internal view returns (bool) {
        Licensee memory licensee = licensees[tokenId];
        require (licensee.user != address(0),"not assigned or minted");
        if ((user != address(0)))
            require(licensee.user == user,"valid for user of record only");
        return (licensee.endTime == PERPETUAL ||
              (block.timestamp >= licensee.startTime && block.timestamp <= licensee.endTime));
    }
    
}


