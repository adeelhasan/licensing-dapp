//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import "openzeppelin-contracts/access/Ownable.sol";
import "./LicenseStructs.sol";
import "./LicenseProject.sol";

/// @notice this is an optional container for license projects
///         multiple products can be associated with the same organization
/// @dev    create project and register it with an organisation contract if needed
contract LicensingOrganisation is Ownable {

    string public name;
    LicenseProject[] private _projects;

    constructor(string memory name_) {
        name = name_;
    }

    function addProject(LicenseProject project) onlyOwner external {
        require(project.owner() == msg.sender,"only owned projects can be added");
        _projects.push(project);
    }

    function projects() external view returns (LicenseProjectStub[] memory) {
        uint projectsCount = _projects.length;
        LicenseProjectStub[] memory stubs = new LicenseProjectStub[](projectsCount);
        for( uint i; i < projectsCount; i++) {
            stubs[i] = LicenseProjectStub(address(_projects[i]),_projects[i].name(),_projects[i].symbol());
        }
        return stubs;
    }





}
