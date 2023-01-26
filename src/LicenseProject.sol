//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import "openzeppelin-contracts/utils/Counters.sol";
import "openzeppelin-contracts/access/Ownable.sol";
import "openzeppelin-contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/token/ERC721/ERC721.sol";
import "utility/FundsCollector.sol";

struct Licensee {
    address user;
    uint256 licenseId;
    uint256 renewalsCount;
    uint256 startTime;
    uint256 endTime;
}

enum LicenseStatus { None, Active, NotActive }

struct License {
    string name;
    uint256 maxRenewals;
    uint256 duration;
    uint256 price;
    LicenseStatus status;
}

struct LicenseeInfo {
    uint256 tokenId;
    Licensee licensee;
    License license;
}

/// @title License Project
/// @notice container for licenses, and the licensees for those licenses
/// one project for a software product, eg, and different licenses for
/// different plans. users purchase licenses and have a licensee relationship
/// @dev each licensee relationship is mapped to a ERC 721 token
contract LicenseProject is ERC721, Ownable, FundsCollector {

    using Counters for Counters.Counter;

    event LicenseAdded(uint256 indexed licenseId);
    event LicenseBought(address indexed licensee, uint256 tokenId, uint256 licenseId);
    event LicenseRenewed(address indexed licensee, uint256 tokenId, uint256 licenseId);
    event LicenseGifted(address indexed licensee, uint256 tokenId);
    event LicenseAssignedTo(address indexed to, uint256 tokentId);
    event LicenseAutoRenewed(address indexed liscensee , uint256 licenseId, uint256 tokensPaid);

    mapping(uint256 => Licensee) public licensees;
    mapping(uint256 => License) public licenses;
    mapping(address => uint256[]) public tokensOwned;

    // for readability
    uint256 constant internal START_NOW = 0;
    uint256 constant internal PERPETUAL = 0;

    Counters.Counter private _tokenIdCounter;
    Counters.Counter private _licenseIdCounter;

    error LicenseStatusNotValid();
    error LicenseNotCurrent(uint256 tokenId);
    error TokenNotMinted(uint256 tokenId);
    error TokenNotValid(uint256 tokenId);
    error OnlyTokenOwner();
    error StartTimeNotValid();
    error CannotExtendWithDifferentLicense();
    error CannotExtendPerpetualLicense();
    error NoRenewalsLeft();
    error TokenAlreadyReassigned();
    error BulkTransfersNotSupported();
    
    /// @notice setup the ERC 721 token
    /// @param token the ERC20 token that is accepted as payment, or pass address(0) if the 
    /// mode of payment is to be Ether. It has to be one or the other, not both
    constructor(
        string memory name,
        string memory symbol,
        address token
    )
        ERC721(name,symbol)
        FundsCollector(token)
    {}

    /// @notice the primary check for the licensee validity
    function checkValidity(uint256 tokenId) public view virtual returns(bool) {
        return _checkValidity(tokenId, msg.sender);
    }

    /// @notice this will auto renewal as part of the validity check
    ///         this is 3x more gas costly, but very useful if so needed
    function checkValidityWithAutoRenewal(uint256 tokenId) public returns(bool) {
        if (this.ownerOf(tokenId) == address(0)) revert TokenNotMinted(tokenId);

        Licensee memory licensee = licensees[tokenId];
        if (licensee.user != msg.sender)
            return false;

        bool durationCheck = (licensee.endTime == PERPETUAL ||
              (block.timestamp >= licensee.startTime && block.timestamp <= licensee.endTime));

        if ((!durationCheck && this.paymentToken() != address(0)) &&
             (this.ownerOf(tokenId) == licensee.user) && 
             (IERC20(paymentToken).allowance(msg.sender,address(this)) >=
                licenses[licensee.licenseId].price)
        ) {
            renewLicense(tokenId, START_NOW);
            durationCheck = true;

            emit LicenseAutoRenewed(msg.sender, licensee.licenseId, licenses[licensee.licenseId].price);
        }
        
        return durationCheck;
    }

    /// @notice add a license, restricted to the license project owner
    /// @param name name for the license, as it would appear in the UI
    /// @param maxRenewals a value of 0 would be for unlimited renewals
    /// @param duration of time, in seconds, for the validity period
    /// @param price interpreted as tokens or eth units, depending on the project setting
    function addLicense(
        string memory name, 
        uint256 maxRenewals, 
        uint256 duration, 
        uint256 price
    ) 
        external
        onlyOwner 
        returns(
            uint256 licenseId
        )
    {
        _licenseIdCounter.increment();
        licenseId = _licenseIdCounter.current();
        licenses[licenseId] = License(name, maxRenewals, duration, price, LicenseStatus.Active);

        emit LicenseAdded(licenseId);
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
        if (startTime != START_NOW && startTime < block.timestamp) revert StartTimeNotValid();
        License memory license = licenses[licenseId];
        if (license.status == LicenseStatus.None) revert LicenseStatusNotValid();

        _collectPayment(msg.sender, owner(), license.price);
        uint256 newTokenId = _getNewTokenId(msg.sender);        
        _addDuration(newTokenId, msg.sender, licenseId, startTime, license.duration, license.maxRenewals);

        tokensOwned[msg.sender].push(newTokenId);

        return newTokenId;
    }

    /// @notice extend the duration for an existing licensee
    /// @param tokenId the token representing the licensee
    /// @param startTime the starting time, or 0 if needing to start immediately
    function renewLicense(uint256 tokenId, uint256 startTime) public payable {
        if (this.ownerOf(tokenId) == address(0)) revert TokenNotMinted(tokenId);
        if (startTime != START_NOW && startTime < block.timestamp) revert StartTimeNotValid();

        Licensee memory licensee = licensees[tokenId];
        License memory license = licenses[licensee.licenseId];
        _collectPayment(msg.sender, owner(), license.price);
        _addDuration(tokenId, msg.sender, licensee.licenseId, startTime, license.duration, license.maxRenewals);
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
        if (startTime != START_NOW && startTime < block.timestamp) revert StartTimeNotValid();
        License memory license = licenses[licenseId];
        if (license.status == LicenseStatus.None) revert LicenseStatusNotValid();

        uint256 newTokenId = _getNewTokenId(to);
        _addDuration(newTokenId, to, licenseId, startTime, startTime + license.duration, license.maxRenewals);

        emit LicenseGifted(to, newTokenId);

        return newTokenId;
    }

    /// @notice return licensee data, mainly for frontend consumption
    function getLicensee(uint256 tokenId) external view returns(Licensee memory) {
        return licensees[tokenId];
    }

    /// @notice return licensee data, mainly for frontend consumption
    function getLicense(uint256 licenseId) external view returns(License memory) {
        return licenses[licenseId];
    }

    /// @notice you can soft transfer your license if its valid
    /// @dev by default the re-assignment is always to the end of the current duration
    /// for renting, see the RentableLicenseProject; in theory if you get payment for 
    /// assigning the licensee relationship, then that is renting. but here the payment is not stipulated
    function assignLicenseTo(uint256 tokenId, address to) external virtual {
        if (!checkValidity(tokenId)) revert LicenseNotCurrent(tokenId);
        if (licensees[tokenId].user != ownerOf(tokenId)) revert TokenAlreadyReassigned();

        licensees[tokenId].user = to;
        
        emit LicenseAssignedTo(to, tokenId);
    }

    /// @notice all licensee relationships for msg.sender
    function myLicenses() external view returns(LicenseeInfo[] memory) {
        uint256[] memory myTokensOwned = tokensOwned[msg.sender];
        uint256 count = myTokensOwned.length;
        LicenseeInfo[] memory result = new LicenseeInfo[](count);
        for (uint256 i; i < count; i++) {
            uint256 tokenId = myTokensOwned[i];
            result[i] = LicenseeInfo(tokenId, licensees[tokenId], licenses[licensees[tokenId].licenseId]);
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

    /// @notice sets the status, mainly for what would be shown in list of available to buy licenses
    function setLicenseStatus(uint256 licenseId, LicenseStatus status) external onlyOwner() {
        License memory license = licenses[licenseId];
        if (license.status == LicenseStatus.None) revert LicenseStatusNotValid();
        licenses[licenseId].status = status;
    }

    /// @notice a common spot to get the next token id
    function _getNewTokenId(address mintedTo) internal returns (uint) {
        _tokenIdCounter.increment();
        uint256 newTokenId = _tokenIdCounter.current();
        _safeMint(mintedTo, newTokenId);
        return newTokenId;
    }

    /// @notice this is shared functionality for running a filter
    function _filterLicenses(LicenseStatus status) internal view returns (License[] memory) {
        uint256 count = _licenseIdCounter.current();
        License[] memory result = new License[](count);
        for (uint256 i = 1; i <= count; i++) {
            if (status == LicenseStatus.None)
                result[i-1] = licenses[i];
            else
                if (status == licenses[i].status)
                    result[i-1] = licenses[i];
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
    ) 
        internal
        override
        virtual
    {
        if (batchSize > 1) revert BulkTransfersNotSupported();
        super._afterTokenTransfer(from,to,firstTokenId,batchSize);

        // have to account for the initial transfer during minting
        if (licensees[firstTokenId].user != address(0)) {
            if (licensees[firstTokenId].user != from) revert TokenAlreadyReassigned();
            licensees[firstTokenId].user = to;
        }

        //account for the transfer in the token ownership list
        if (from != to && to != address(0) && from != address(0)) {
            tokensOwned[to].push(firstTokenId);

            uint256 count = tokensOwned[from].length;
            for (uint256 index; index < count; index++) {
                if (tokensOwned[from][index] == firstTokenId) {
                    if (count-1 == index)
                        tokensOwned[from].pop();
                    else {
                        tokensOwned[from][index] = tokensOwned[from][count-1];
                        tokensOwned[from].pop();                
                    }
                }
            }   
        }
    }

    /// @dev common code for validity check
    function _checkValidity(uint256 tokenId, address user) internal view returns (bool) {
        Licensee memory licensee = licensees[tokenId];
        if (licensee.user == address(0)) revert TokenNotMinted(tokenId);
        if (user != address(0) && licensee.user != user)
            return false;
        return (licensee.endTime == PERPETUAL ||
              (block.timestamp >= licensee.startTime && block.timestamp <= licensee.endTime));
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
    ) 
        private
    {
        Licensee memory licensee = licensees[tokenId];
        if ((maxRenewals > 0) && (licensee.renewalsCount == maxRenewals))
            revert NoRenewalsLeft();

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
            if (licenseId != licensee.licenseId) revert CannotExtendWithDifferentLicense();
            if (licensee.endTime == PERPETUAL) revert CannotExtendPerpetualLicense();

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

}


