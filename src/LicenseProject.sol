//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import "openzeppelin-contracts/utils/Counters.sol";
import "openzeppelin-contracts/access/Ownable.sol";
import "openzeppelin-contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/token/ERC721/ERC721.sol";
import "forge-std/Test.sol";


//one software product would have one project
contract LicenseProject is ERC721, Ownable {

    using Counters for Counters.Counter;

    enum CycleStatus { Unpaid, Free, Paid }
    struct Cycle {
        CycleStatus status;
        uint startTime; //a 0 would mean start immediately
        uint endTime;   //a 0 would mean perpetual
    }

    struct License {
        bytes32 name;
        uint maxCycles;
        uint cycleLength;
        uint price;
        bool active;
    }

    struct Licensee {
        uint licenseIndex; //Discussion, instead of index, we can have a license code?
        address user;
        Cycle[] cycles;
    }

    event LicenseAdded(uint licenseId);

    Counters.Counter private _tokenIds;

    //ERC20Token for payments
    address public paymentToken; 

    License[] private _licenses;
    
    mapping(uint => Licensee) public licensees;

    constructor(string memory name, string memory symbol, address token_) ERC721(name,symbol) {
        paymentToken = token_;
    }

    function checkValidity(uint tokenId) external view returns(bool) {
        require(this.ownerOf(tokenId) != address(0),"token id has not been minted");

        Licensee memory l = licensees[tokenId];
        require(l.user == msg.sender,"valid for user of record, not token owner");

        Cycle memory mostRecentCycle = l.cycles[l.cycles.length-1];

        return (mostRecentCycle.status == CycleStatus.Free || mostRecentCycle.status == CycleStatus.Paid)
             && (mostRecentCycle.endTime==0 ||
              (block.timestamp >= mostRecentCycle.startTime && block.timestamp <= mostRecentCycle.endTime));
    }

    function addLicense(bytes32 name, uint maxCycles, uint cycleLength, uint price) onlyOwner external returns(uint) {
        _licenses.push(License(name,maxCycles,cycleLength,price,true));
        uint licenseId = _licenses.length-1;

        emit LicenseAdded(licenseId);
        
        return licenseId;
    }

    function buyLicense(uint tokenId, uint licenseProductId, uint amount) payable public returns(uint) {
        require(licenseProductId < _licenses.length,"product id is not valid");
        License memory license = _licenses[licenseProductId];

        if (paymentToken == address(0)) {
            require(license.price == msg.value,"only exact change taken");
        }
        else {
            require(msg.value == 0, "payment via tokens only, ether was sent too");
            require(paymentToken != address(0), "token address not set");
            require(license.price <= amount,"not enough tokens set");
            
            if (license.price > 0) // no debit if this is a free one
                IERC20(paymentToken).transferFrom(msg.sender, address(this), amount);
        }

        return addCycle(msg.sender, tokenId, licenseProductId, license.cycleLength, license.maxCycles);
    }

    function giftLicense(uint licenseProductId, address user) external onlyOwner returns(uint) {
        require(licenseProductId < _licenses.length,"product id is not valid");
        License memory license = _licenses[licenseProductId];

        return addCycle(user, 0, licenseProductId, license.cycleLength, license.maxCycles);
    }

    function addCycle(address user, uint tokenId,uint licenseProductId,uint cycleLength, uint maxCycles) private returns(uint) {
        if (tokenId == 0) {
            _tokenIds.increment();
            tokenId = _tokenIds.current();
            _safeMint(user, tokenId);
        }
        Licensee storage licensee = licensees[tokenId];

        require(licensee.cycles.length < maxCycles);

        if (licensee.cycles.length == 0) {
            uint endTime;
            if (cycleLength > 0)
                endTime = block.timestamp + cycleLength;

            licensee.cycles.push(Cycle(CycleStatus.Paid,block.timestamp,endTime));
            licensee.user = user;
            licensee.licenseIndex = licenseProductId;
            licensees[tokenId] = licensee;
        }
        else
        {
            Cycle memory mostRecentCycle = licensee.cycles[licensee.cycles.length-1];

            require(mostRecentCycle.endTime != 0,"cycle is already perpetual");
            
            if (block.timestamp < mostRecentCycle.endTime)
                licensee.cycles[licensee.cycles.length-1].endTime += cycleLength;
            else
                licensee.cycles.push(Cycle(CycleStatus.Paid,block.timestamp,block.timestamp + cycleLength));
        }
        return tokenId;
    }

    function currentLicences() external view returns(License[] memory) {
        uint count = _licenses.length;
        License[] memory activeLicenses = new License[](count);
        for (uint i; i<_licenses.length; i++){
            if (_licenses[i].active)
                activeLicenses[i] = _licenses[i];
        }
        return activeLicenses;
    }

    function allLicences() onlyOwner external view returns(License[] memory) {
        uint count = _licenses.length;
        License[] memory allLicenses = new License[](count);
        for (uint i; i<_licenses.length; i++){
                allLicenses[i] = _licenses[i];
        }
        return allLicenses;
    }

    function myLicenses() external view returns(Licensee[] memory) {
        //the license info (name, id) should also go back with this
        //cycles have to be included too
        //the token ids would go back too ... all tokenIds owned by msg.sender
        Licensee[] memory myLicenses = new Licensee[](1);
        return myLicenses;
    }


}
