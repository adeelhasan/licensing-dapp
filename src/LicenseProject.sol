//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import "openzeppelin-contracts/utils/Counters.sol";
import "openzeppelin-contracts/access/Ownable.sol";
import "openzeppelin-contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/token/ERC721/ERC721.sol";
import "forge-std/Test.sol";
import "../lib/LicenseStructs.sol";

//one software product would have one project
contract LicenseProject is ERC721, Ownable {

    using Counters for Counters.Counter;

    event LicenseAdded(uint licenseId);
    event LicenseBought(address indexed licensee, uint tokenId, uint licenseId);
    event LicenseExtended(address indexed licensee, uint tokenId, uint licenseId);
    event LicenseGifted(address indexed licensee, uint tokenId);
    event AutoRenewed(address indexed liscensee , uint licenseId, uint tokensPaid);

    Counters.Counter private _tokenIds;

    //ERC20Token for payments
    address public paymentToken; 

    LicenseStructs.License[] private _licenses;
    
    mapping(uint => LicenseStructs.Licensee) public licensees;

    constructor(string memory name, string memory symbol, address token_) ERC721(name,symbol) {
        paymentToken = token_;
    }

    function checkValidity(uint tokenId) external returns(bool) {
        require(this.ownerOf(tokenId) != address(0),"token id has not been minted");

        LicenseStructs.Licensee memory l = licensees[tokenId];
        require(l.user == msg.sender,"valid for user of record, not token owner");

        LicenseStructs.Cycle memory mostRecentCycle = l.cycles[l.cycles.length-1];
        bool billingCheck = (mostRecentCycle.status == LicenseStructs.CycleStatus.Free || mostRecentCycle.status == LicenseStructs.CycleStatus.Paid);
        bool durationCheck = (mostRecentCycle.endTime==0 ||
              (block.timestamp >= mostRecentCycle.startTime && block.timestamp <= mostRecentCycle.endTime));


        if ((!durationCheck && this.paymentToken() != address(0)) && (this.ownerOf(tokenId) == l.user) && (IERC20(paymentToken).allowance(msg.sender,address(this))>=_licenses[l.licenseIndex].price)) {
            buyLicense(tokenId, l.licenseIndex, _licenses[l.licenseIndex].price);            
            durationCheck = true;

            emit AutoRenewed(msg.sender, l.licenseIndex, _licenses[l.licenseIndex].price);
        }
        
        return billingCheck && durationCheck;
    }

    function addLicense(bytes32 name, uint maxCycles, uint cycleLength, uint price) onlyOwner external returns(uint) {
        _licenses.push(LicenseStructs.License(name,maxCycles,cycleLength,price,true));
        uint licenseId = _licenses.length-1;

        emit LicenseAdded(licenseId);
        
        return licenseId;
    }

    function buyLicense(uint tokenId, uint licenseProductId, uint amount) payable public returns(uint) {
        require(licenseProductId < _licenses.length,"product id is not valid");
        LicenseStructs.License memory license = _licenses[licenseProductId];

        if (paymentToken == address(0)) {
            require(license.price == msg.value,"only exact change taken");
        }
        else {
            require(msg.value == 0, "payment via tokens only, ether was sent too");
            require(paymentToken != address(0), "token address not set");
            require(license.price <= amount,"not enough tokens set");
            
            if (license.price > 0) // no debit if this is a free one
                IERC20(paymentToken).transferFrom(msg.sender, address(this), license.price);
        }

        return addCycle(msg.sender, tokenId, licenseProductId, license.cycleLength, license.maxCycles);
    }

    function giftLicense(uint licenseProductId, address user) external onlyOwner returns(uint) {
        require(licenseProductId < _licenses.length,"product id is not valid");
        LicenseStructs.License memory license = _licenses[licenseProductId];
        uint tokenId =  addCycle(user, 0, licenseProductId, license.cycleLength, license.maxCycles);

        emit LicenseGifted(user, tokenId);

        return tokenId;
    }

    function addCycle(address user, uint tokenId,uint licenseProductId,uint cycleLength, uint maxCycles) private returns(uint) {
        if (tokenId == 0) {
            _tokenIds.increment();
            tokenId = _tokenIds.current();
            _safeMint(user, tokenId);
        }
        LicenseStructs.Licensee storage licensee = licensees[tokenId];

        require(licensee.cycles.length < maxCycles);

        if (licensee.cycles.length == 0) {
            uint endTime;
            if (cycleLength > 0)
                endTime = block.timestamp + cycleLength;

            licensee.cycles.push(LicenseStructs.Cycle(LicenseStructs.CycleStatus.Paid,block.timestamp,endTime));
            licensee.user = user;
            licensee.licenseIndex = licenseProductId;
            licensees[tokenId] = licensee;

            emit LicenseBought(msg.sender, tokenId, licenseProductId);
        }
        else
        {
            LicenseStructs.Cycle memory mostRecentCycle = licensee.cycles[licensee.cycles.length-1];

            require(mostRecentCycle.endTime != 0,"cycle is already perpetual");
            
            if (block.timestamp < mostRecentCycle.endTime)
                licensee.cycles[licensee.cycles.length-1].endTime += cycleLength;
            else
                licensee.cycles.push(LicenseStructs.Cycle(LicenseStructs.CycleStatus.Paid,block.timestamp,block.timestamp + cycleLength));
            
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
    
    function myLicenses() external view returns(LicenseStructs.LicenseInfo[100] memory) {
        //Added a static length of 100 to the array as push function was not 
        //supported for array stored in memory and storage variables cannot be returned.
        LicenseStructs.LicenseInfo[100] memory myLicensesArr;
        uint j = 0;
        for (uint i=1; i<=_tokenIds.current(); i++){
            if(licensees[i].user == msg.sender){
                myLicensesArr[j] = LicenseStructs.LicenseInfo(i,licensees[i], _licenses[licensees[i].licenseIndex]);
                j++;
                if(j == 99){
                    break;
                }
            }
        }
        return myLicensesArr;
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 firstTokenId,
        uint256 batchSize
    ) internal override virtual {
        require(batchSize == 1,"bulk transfers are not supported for licenses");

        LicenseStructs.Licensee memory l = licensees[firstTokenId];

        //if this is fired from a new mint, then there will be no cycles as yet
        if (l.cycles.length > 0) {
            LicenseStructs.Cycle memory mostRecentCycle = l.cycles[l.cycles.length-1];

            if (mostRecentCycle.endTime==0 ||
                (block.timestamp >= mostRecentCycle.startTime &&
                block.timestamp <= mostRecentCycle.endTime))
                {
                    licensees[firstTokenId].user = to;
                }

            }
    }

    function getLicenseeData(uint tokenId) external view returns(LicenseStructs.Licensee memory) {
        return licensees[tokenId];
    }
}
