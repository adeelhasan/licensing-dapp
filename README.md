# Decentralized Licensing 

Software License NFTs are relatively straightforward, where token ownership validates a runtime check for DRM purposes. This project adds to that concept by having the option to specify an expiration date for validity.

This is more in line with how software subscription models work. Additionally, by grouping licenses under a LicensingProject contract, it is simpler to express various tiers of a product, both in terms of pricing as well as supported functionality.

For example, there can be a limited free trial, a lifetime as well as hourly pricing, represented by different licenses. Finally, with the RentableLicenseProject, licensees have the option to rent out their license.

<!-- Licensing can be thought of as an authenticity or validity check. For example, in the context of software licenses there can be a runtime test if the executable has been paid for. Or for content services, whether a subscription or membership is current or not. This project aims to provide a flexible mechanism for licensing, using the infrastructure of trust to provide more utility.

A license purchase is accounted for as a NFT, which allows for exploiting established ERC 721 standards. For example, when the token ownership is transferred, the license is also re-assigned. And it can also participate in the broader NFT marketplace. A license can also be rented out following IERC4907. These decentralized facilities are not available in the centralized version.

The provider eg. a software vendor can setup a variety of licenses which are grouped in a project. A license can have duration, or be perpetual. It can be free, or paid for in ether or tokens. The licensee relationship, when it expires, can be optionally extended automatically (if there are pre-approved tokens.) The licensee relationship can also be rented out, for the duration of time remaining.
 -->


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

Deploy a LicenseProject contract, and then call 

```solidity
    function addLicense(string memory name, uint256 maxRenewals, uint256 length, uint256 price) 
```



to get a license id; this id is then referenced in a call to purchase the license, and at that point an NFT is minted:

```solidity
    function buyLicense(uint256 licenseId, uint256 startTime) 
```

The check for a license is done via the following function on the LicenseProject or RentableLicenseProject contract:

```solidity
function checkValidity(uint tokenId) public virtual returns (bool)
```
https://github.com/adeelhasan/licensing-dapp/blob/c066c9b0ed45508381614f9cd7af473c1e694430/src/LicenseProject.sol#L73

The context can guide how often the check should be called. Even if the license is current, the check will return false if called by an address which is neither the owner or the renter.

## Rental

The RentableLicenseProject contract is elaborated for renting out a license. It can be thought of as a reservation system for the duration of license validity. The end user will buy a lease, based on a listing created by the license / token holder. The listing specifies the rate for a block of time called a RentalTimeUnit. These are hourly, daily, weekly monthly or annual.

So eg, you can create a listing which lays out a daily rental rate. You can also pick a minimum or maximum number of rental units that need to be bought to start a lease. So eg, you can have an hourly rate, but restrict the user to at least 1 hour or at most 12 hours. At the same time, the same license can have a monthly rate quoted. At the moment there is no support for arbitrary start and end dates for a lease.

Each license can have a single listing per RentalTimeUnit. Eg, you cannot have two hourly rates quoted for the same license.

Leases cannot overlap, eg. if the 15th of April is rented out from 12 pm to 10 pm, then a month long lease from the 10th of April to the 10th of May won't be given.



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


<!-- ## Deployment on Local Chain:

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
 -->