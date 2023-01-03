# Decentralized Licensing 

Licensing can be thought of as an authenticity or validity check. For example, in the context of software licenses there can be a runtime test if the executable has been paid for. Or for content services, whether a subscription or membership is current or not. This project aims to provide a flexible mechanism for licensing, using the infrastructure of trust to provide more utility.

A license purchase is accounted for as a NFT, which allows for exploiting established ERC 721 standards. For example, when the token ownership is transferred, the license is also re-assigned. And it can also participate in the broader NFT marketplace. A license can also be rented out following IERC4907. These decentralized facilities are not available in the centralized version.

The provider eg. a software vendor can setup a variety of licenses which are grouped in a project. A license can have duration, or be perpetual. It can be free, or paid for in ether or tokens. The licensee relationship, when it expires, can be optionally extended automatically (if there are pre-approved tokens.) The licensee relationship can also be rented out, for the duration of time remaining.


## Rental

The RentableLicenseProject is elaborated for renting out a license. It can be thought of as a reservation system for the duration of the license validity. The end user will buy a lease, based on a listing created by the license / token holder. The listing specifies the rate for a chunk of time called a RentalTimeUnit. These are hourly, daily, weekly monthly or annual.

So eg, you can create a listing which lays out a daily rental rate. You can also pick a minimum or maximum number of rental units that need to be bought to start a lease. So eg, you can have an hourly rate, but restrict the user to at least 1 hour or at most 12 hours. At the same time, the same license can have a monthly rate quoted. At the moment there is no support for arbitrary start and end dates for a lease.

Each license can have a single listing per RentalTimeUnit. Eg, you cannot have two hourly rates quoted for the same license.

Leases cannot overlap, eg. if the 15th of April is rented out then a month long lease from the 10th of April to the 10th of May won't be given.



<!-- In the future:
- we can make an api to access
- demonstrate use on mainnet, eg, to restrict access to a Flashloan script
- make it easier to manage a batch of licenses
- have the NFTs be on OpenSea
- identify projects that could make use of these contracts, maybe valist.io
- analytics with the Graph
- other features to think about
    auto renewing rental; with pre-approved tokens
    renting custom dates / custom period -- this can be from front end side too
    renting till the end of some time period
        this could stack the timeUnits, but that is an awkward thing to do
 -->
## Usage

Create LicenseProject contract, and add license(s) to that using

```solidity

function addLicense

```


The check for a license is done via the following function on the LicenseProject contract:

```solidity
function checkValidity(uint tokenId) public virtual returns (bool)
```

The context can guide how often the check should be called. Also note that the RentableLicenseProject overrides this function, effectively the same interface is used for both contracts.

```solidity
function getLicensee(uint tokenId) public returns (Licensee memory)
```

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
