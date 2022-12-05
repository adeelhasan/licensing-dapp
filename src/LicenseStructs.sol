//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

struct Licensee {
    address user;
    uint licenseId;
    uint renewalsCount;
    uint startTime;
    uint endTime;
}

enum LicenseStatus { None, Active, NotActive }
struct License {
    bytes32 name;
    uint maxRenewals;
    uint length;
    uint price;
    LicenseStatus status;
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
