# Decentralized Licensing 

Licensing can be thought of as a permission check. For example, in the context of software licenses there can be a runtime test if the executable has been paid for. Or for content services, whether a subscription or membership is current or not. This project aims to provide a mechanism for licensing.

The provider eg. a software vendor can setup a variety of licenses which are grouped in a project.


TODO: add walkthrough of licenses

## Installation

Install foundry if needed

```
git clone --recurse-submodules CLONE_URL
```

If the standard library did not come across, install that
```
forge install foundry-rs/forge-std --no-commit
```

then forge build and forge test.

## Deployment of Test Contracts:

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

