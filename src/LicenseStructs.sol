//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

library LicenseStructs {
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

    struct LicenseInfo {
        uint tokenId;
        Licensee licenseeInfo;
        License licenseinfo;
    }
}