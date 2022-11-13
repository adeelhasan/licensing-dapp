# Decentralized Licensing 

Licensing can be thought of as a authenticity or validity check. For example, in the context of software licenses there can be a runtime test if the executable has been paid for. Or for content services, whether a subscription or membership is current or not. This project aims to provide a flexible mechanism for licensing, using the infrastructure of trust to provide more utility.

A license purchase is treated as a NFT, which allows for exploiting established ERC 721 standards. For example, when the token ownership is transferred, the license is also re-assigned. And it can also participate in the broader NFT marketplace. A license can also be rented out following IERC4907. These decentralized facilities are not available in the centralized version.

The provider eg. a software vendor can setup a variety of licenses which are grouped in a project. The license can have duration, or be perpetual. It can be free, or paid for in ether or by tokens. The licensee relationship, when it expires, can be automatically extended on failed check if there are pre-approved tokens. The licensee relationship can also be rented out, for the duration of time remaining. Renting amounts to a temporary transfer of usage privileges without surrendering ownership.

In the future:
- we can make an api to access
- demonstrate use on mainnet, eg, to restrict access to a Flashloan script
- make it easier to manage a batch of licenses
- have the NFTs be on OpenSea
- identify projects that could make use of these contracts, maybe valist.io

## Installation

Install Foundry if not already done so.

```
git clone --recurse-submodules CLONE_URL
```

If the standard library did not come across, install that
```
forge install foundry-rs/forge-std --no-commit
```

then forge build and forge test.


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

## Front End notes

```
cd frontend
npm install
npm run dev
```
