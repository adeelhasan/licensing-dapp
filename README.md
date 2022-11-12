# Decentralized Licensing 

Licensing can be thought of as a permission check. For example, in the context of software licenses there can be a runtime test if the executable has been paid for. Or for content services, whether a subscription or membership is current or not. This project aims to provide a flexible mechanism for licensing. A license purchase is referenced as a NFT, which allows exploiting established standards.

The provider eg. a software vendor can setup a variety of licenses which are grouped in a project. The license can have duration, or be perpetual. It can be free, or paid for in ether or by tokens. The licensee relationship, when it expires, can be automatically extended on failed check if there are pre-approved tokens.

The licensee relationship can also be rented out, for the duration of time remaining. Renting amounts to a temporary transfer of usage privileges without surrendering ownership.

## Installation

Install Foundry if not already done so.


## Deployment on Local Chain:

- first start anvil in a separate console
- fill in the .env file with the private keys listed for anvil
```
PK_ANVIL_PROJECT_OWNER=""
PK_ANVIL_1=""
PK_ANVIL_2=""
PK_ANVIL_3=""
```

- run the deployment script
```
forge script script/LicenseProject.s.sol:LicenseProjectScript --rpc-url http://localhost:8545 --broadcast
```

- import the private keys above into Metamask to make it easier to see the frontend

- more on the readme
- rentable
- holding Account or LicensingCompany
- some comments
- starting from a time offset? not done as yet

## Front End notes

