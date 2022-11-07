//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

//Discussion: should we make this Ownable, Pausable?
contract License {
    
    bytes32 public name;
    uint public immutable maxCycles;
    uint public immutable cycleLength; //Discussion which time units? can be seconds too

    //Dsicussion, should this be priceUnits or just price?
    uint public immutable price;

    //Discussion: meant to be a bitmap of what is supported
    //eg, the 8th bit could mean extra fast compression available for WinZip
    bytes16 public featuresSupported;

    constructor(bytes32 name_, uint maxCycles_, uint price_, uint cycleLength_) {
        name = name_;
        price = price_;
        maxCycles = maxCycles_;
        cycleLength = cycleLength_;
    }
}


//other features to think about
//upgrade subscription, downgrade
//not supported: pause/resume your subscription






