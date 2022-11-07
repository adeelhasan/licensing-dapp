//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import "./License.sol";
import "lib/openzeppelin-contracts/contracts/utils/Counters.sol";
import "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";



//one software product would have one project
contract LicenseProject is ERC721, Ownable {

    using Counters for Counters.Counter;

    enum CycleStatus { Unpaid, Free, Paid, GracePeriod }
    struct Cycle {
        CycleStatus status;
        uint startTime; //a 0 would mean start immediately
        uint endTime;   //a 0 would mean perpetual
    }

    struct Licensee {
        uint licenseIndex; //Discussion, instead of index, we can have a license code?
        address user;
        Cycle[] cycles;
    }

    Counters.Counter private _tokenIds;

   address public token; //ERCToken

    //the list of licenses which are available, kind of like product catalog
    License[] private licenses;
    
    //the licenscee relationship is the NFT
    //an analogy is say a ticket to concert
    mapping(uint => Licensee) public licensees;

    //Discussion: licenses are part of constructor, or can be added later, or both
    //Discussion: product catalog is easier to add to, rather than to deploy them and then pass as a memory array
    constructor(string memory name, string memory symbol, address token_) ERC721(name,symbol) {
        token = token_;
    }

    //main check that will be called
    function checkValidity(uint tokenId) external view returns(bool) {
        //pull license, check for id validity
        Licensee memory l = licensees[tokenId];
        Cycle memory mostRecentCycle = l.cycles[l.cycles.length-1];

        return (((mostRecentCycle.status == CycleStatus.Free)) || (mostRecentCycle.status == CycleStatus.Paid))
             && ((mostRecentCycle.endTime==0) || ((block.timestamp > mostRecentCycle.startTime)
              && (block.timestamp < mostRecentCycle.endTime)));
    }

    //Discussion we can create a license in the dapp, and then pass it here
    //or we can pass all the License constructor params here as well
    function addLicense(License l) external onlyOwner returns(uint){
        licenses.push(l);
        return licenses.length-1;
    }

    //user buys a license via ether
    function buyLicense(uint licenseProductId) payable public returns(uint) {

        require(licenseProductId < licenses.length,"product id is not valid");
        License license = licenses[licenseProductId];

        require(token == address(0), "only accepts ether");
        //we need to send back a refund if paying more
        require(license.price() <= msg.value,"not enough ether sent");

        //set the cycle of the licensee to be paid up
        //check if the licenscee mapping exists, if not then add it
        //set the cycle status of the licenscee relationship to be paid up
        _tokenIds.increment();
        uint tokenId = _tokenIds.current(); //get the next tokenID
        _safeMint(msg.sender, tokenId);
        Licensee storage licensee = licensees[tokenId];
        if (licensee.cycles.length == 0) {
            uint endTime;
            if (license.cycleLength() > 0)
                endTime == block.timestamp+license.cycleLength();

            licensee.cycles.push(Cycle(CycleStatus.Paid,block.timestamp,endTime));
            licensee.user = msg.sender;
            licensee.licenseIndex = licenseProductId;
            licensees[tokenId] = licensee;
        }
        else
        {
            //if there is a cycle already there, we check if there is duration left in it
            //then decide if we want to add to that or "carry it over" to the new extended duration
            //the analogy would be like you pay in advance for a subscription, so the end date it pushed out
        }
        return tokenId;
    }

    //Discussion, should it be possible to add a license when a valid one
    //could possibly already be there?
/*     function addCycle(uint startTime_, uint endTime_, bool perpetual_) public {
        require(perpetual_ || endTime_ > startTime_,"duration not valid");
        require(maxCycles > cycles.length,"no more cycles allowed");

        Cycle memory cycle = Cycle(startTime_,endTime_,perpetual_);
        cycles.push(cycle);
    }
 */
}
