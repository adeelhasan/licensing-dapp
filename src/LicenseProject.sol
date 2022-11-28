//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import "openzeppelin-contracts/utils/Counters.sol";
import "openzeppelin-contracts/access/Ownable.sol";
import "openzeppelin-contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "forge-std/Test.sol";
import "./LicenseStructs.sol";


contract LicenseProject is ERC721Enumerable, Ownable {

    using Counters for Counters.Counter;

    event LicenseAdded(uint licenseId);
    event LicenseBought(address indexed licensee, uint tokenId, uint licenseId);
    event LicenseExtended(address indexed licensee, uint tokenId, uint licenseId);
    event LicenseGifted(address indexed licensee, uint tokenId);
    event LicenseRented(address indexed renter, uint tokentId);
    event LicenseAutoRenewed(address indexed liscensee , uint licenseId, uint tokensPaid);

    Counters.Counter private _tokenIds;

    //ERC20Token for payments
    address public paymentToken; 

    LicenseStructs.License[] private _licenses;
    
    //mapping(uint => LicenseStructs.Licensee) public licensees;
    mapping(uint => LicenseeStatus) public licensees;

    constructor(string memory name, string memory symbol, address token_) ERC721(name,symbol) {
        paymentToken = token_;
    }

    function checkValidityWithAutoRenewal(uint tokenId) public returns(bool) {
        require(this.ownerOf(tokenId) != address(0),"token id has not been minted");

        LicenseeStatus memory status = licensees[tokenId];

        require(status.user == msg.sender,"valid for user of record only");

        bool durationCheck = (status.endTime==0 ||
              (block.timestamp >= status.startTime && block.timestamp <= status.endTime));


        if ((!durationCheck && this.paymentToken() != address(0)) && (this.ownerOf(tokenId) == status.user) && (IERC20(paymentToken).allowance(msg.sender,address(this))>=_licenses[status.licenseId].price)) {
            buyLicense(tokenId, status.licenseId, 0);            
            durationCheck = true;

            emit LicenseAutoRenewed(msg.sender, status.licenseId, _licenses[status.licenseId].price);
        }
        
        return durationCheck;
    }

    function checkValidity(uint tokenId) public view returns(bool) {

        LicenseeStatus memory status = licensees[tokenId];
        require (status.user != address(0),"not assigned or minted");
        require(status.user == msg.sender,"valid for user of record only");

        return (status.endTime==0 ||
              (block.timestamp >= status.startTime && block.timestamp <= status.endTime));
    }


    function addLicense(bytes32 name, uint maxCycles, uint cycleLength, uint price) onlyOwner external returns(uint) {
        _licenses.push(LicenseStructs.License(name,maxCycles,cycleLength,price,true));
        uint licenseId = _licenses.length-1;

        emit LicenseAdded(licenseId);
        
        return licenseId;
    }

    function buyLicense(uint tokenId, uint licenseProductId, uint startTime) payable public returns(uint) {
        require(startTime == 0 || startTime > block.timestamp);
        require(licenseProductId < _licenses.length,"product id is not valid");
        LicenseStructs.License memory license = _licenses[licenseProductId];

        if (paymentToken == address(0)) {
            require(license.price == msg.value,"only exact change taken");
        }
        else {
            require(msg.value == 0, "payment via tokens only, ether was sent too");
            require(paymentToken != address(0), "token address not set");
            
            if (license.price > 0) // no debit if this is a free one
                IERC20(paymentToken).transferFrom(msg.sender, address(this), license.price);
        }

        return addCycle(msg.sender, tokenId, licenseProductId, startTime, license.cycleLength, license.maxCycles);
    }

    function giftLicense(address to, uint licenseProductId, uint startTime) external onlyOwner returns(uint) {
        require(startTime == 0 || startTime > block.timestamp);
        require(licenseProductId < _licenses.length,"product id is not valid");
        LicenseStructs.License memory license = _licenses[licenseProductId];
        uint tokenId =  addCycle(to, 0, licenseProductId, startTime, license.cycleLength, license.maxCycles);

        emit LicenseGifted(to, tokenId);

        return tokenId;
    }

    function addCycle(address user, uint tokenId, uint licenseProductId, uint startTime, uint cycleLength, uint maxCycles) private returns(uint) {
        if (tokenId == 0) {
            _tokenIds.increment();
            tokenId = _tokenIds.current();
            _safeMint(user, tokenId);
        }
        LicenseeStatus memory status = licensees[tokenId];

        require(status.cyclesDone < maxCycles);

        if (status.cyclesDone == 0) {
            uint endTime;            
            if (startTime == 0)
                startTime = block.timestamp;

            if (cycleLength > 0)
                endTime = startTime + cycleLength;

            licensees[tokenId] = LicenseeStatus(user,licenseProductId,1,startTime,endTime);

            emit LicenseBought(msg.sender, tokenId, licenseProductId);
        }
        else        
        {
            require(status.endTime != 0,"cycle is already perpetual");
            require(licenseProductId == status.licenseId, "cannot extend another license");

            if (block.timestamp < status.endTime)
                status.endTime += cycleLength;
            else {
                if (startTime == 0)
                    status.startTime = block.timestamp;
                else
                    status.startTime = startTime;
                status.endTime = block.timestamp + cycleLength;
            }
            status.cyclesDone++;
            licensees[tokenId] = status;
            
            emit LicenseExtended(msg.sender, tokenId, licenseProductId);
        }
        return tokenId;
    }

    function currentLicences() external view returns(LicenseStructs.License[] memory) {
        uint count = _licenses.length;
        LicenseStructs.License[] memory activeLicenses = new LicenseStructs.License[](count);
        for (uint i; i<_licenses.length; i++){
            if (_licenses[i].active)
                activeLicenses[i] = _licenses[i];
        }
        return activeLicenses;
    }

    function allLicences() onlyOwner external view returns(LicenseStructs.License[] memory) {
        uint count = _licenses.length;
        LicenseStructs.License[] memory allLicenses = new LicenseStructs.License[](count);
        for (uint i; i<_licenses.length; i++){
                allLicenses[i] = _licenses[i];
        }
        return allLicenses;
    }
    
    function myLicenses() external view returns(LicenseStructs.LicenseInfo[] memory) {
        uint count = balanceOf(msg.sender);
        LicenseStructs.LicenseInfo[] memory result = new LicenseStructs.LicenseInfo[](count);
        for (uint i; i<count; i++) {
            uint tokenId = tokenOfOwnerByIndex(msg.sender,i);
            result[i] = LicenseStructs.LicenseInfo(tokenId,licensees[tokenId], _licenses[licensees[tokenId].licenseId]);
        }
        return result;
    }


    function _afterTokenTransfer(
        address from,
        address to,
        uint256 firstTokenId,
        uint256 batchSize
    ) internal override virtual {
        require(batchSize == 1,"bulk transfers are not supported for licenses");
        super._afterTokenTransfer(from,to,firstTokenId,batchSize);

        if (licensees[firstTokenId].user != address(0))
            licensees[firstTokenId].user = to;
    }

    function getLicenseeData(uint tokenId) external view returns(LicenseeStatus memory) {
        return licensees[tokenId];
    }

    function getLicenseData(uint licenseIndex) external view returns(LicenseStructs.License memory) {
        return _licenses[licenseIndex];
    }

    function rentLicenseTo(uint tokenId, address renter) external {
        LicenseeStatus memory status = licensees[tokenId];
        require(status.cyclesDone > 0, "token is not bought as yet");
        require(checkValidity(tokenId),"token is not valid");
        require(status.user == ownerOf(tokenId),"token already rented out)");

        licensees[tokenId].user = renter;
        
        emit LicenseRented(renter, tokenId);
    }

}
