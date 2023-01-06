//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import "openzeppelin-contracts/access/Ownable.sol";
import "./LicenseProject.sol";

struct LicenseProjectInfo {
    address contractAddress;
    string name;
    string symbol;
}

/// @notice this is an optional container for license projects
/// multiple products can be associated with the same organization
/// @dev create project and register it with an organisation contract if needed
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

    function projects() external view returns (LicenseProjectInfo[] memory) {
        uint projectsCount = _projects.length;
        LicenseProjectInfo[] memory projects_ = new LicenseProjectInfo[](projectsCount);
        for( uint i; i < projectsCount; i++) {
            projects_[i] = LicenseProjectInfo(address(_projects[i]),_projects[i].name(),_projects[i].symbol());
        }
        return projects_;
    }
}
