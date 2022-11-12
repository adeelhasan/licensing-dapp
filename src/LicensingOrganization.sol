//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import "openzeppelin-contracts/access/Ownable.sol";
import "./LicenseStructs.sol";
import "./LicenseProject.sol";

//one software product would have one project
contract LicensingOrganisation is Ownable {

    string public name;
    LicenseProject[] private _projects;

    constructor(string memory name_) {
        name = name;
    }

    function addProject(LicenseProject project) onlyOwner external {
        require(project.owner() == msg.sender,"only owned projects can be added");
        _projects.push(project);
    }

    function projects() external view returns (LicenseStructs.LicenseProjectStub[] memory) {
        uint projectsCount = _projects.length;
        LicenseStructs.LicenseProjectStub[] memory stubs = new LicenseStructs.LicenseProjectStub[](projectsCount);
        for( uint i; i<projectsCount; i++) {
            stubs[i] = LicenseStructs.LicenseProjectStub(address(_projects[i]),_projects[i].name(),_projects[i].symbol());
        }
        return stubs;
    }





}
