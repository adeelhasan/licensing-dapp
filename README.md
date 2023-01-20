# Introduction

Software License NFTs are relatively straightforward, where token ownership establishes a licensee relationship which can be validated at runtime. This project augments that concept by having the option to specify an expiration date. This is more in line with how software subscription models work. Additionally, licensees can rent out their license, with a pay-as-you-go / streaming option .

A license can be thought of as a product or a product tier. By grouping licenses under a LicensingProject contract, it is simpler to express various tiers of a product, both in terms of pricing as well as supported functionality. For example, there can be a limited free trial, a standard version and its "pro" variant. And these can be on a recurring basis.

Payments can be collected in ether/native currency as well as in tokens.

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

    Payment and withdrawls
        see if you can put this in your own utility contract
    some more cleanup on ReadMe
    License Ids -- this is a bit orthogonal, can skip
    this.paymentToken() -- awkward, no?



 -->
## Usage

If you want to use duration based licenses, the LicenseProject contract will be sufficient. If the ability for licensees to rent out their license will be needed, then the RentableLicenseProject (which descends from LicenseProject) should be used. In either case, the sequence is to create a license and for an end user to purchase it.

```solidity
function addLicense(string memory name, uint256 maxRenewals, uint256 duration, uint256 price) returns (uint256 licenseId)
```

the license id returned is then referenced in a call to purchase the license, and at that point an NFT is minted:

```solidity
function buyLicense(uint256 licenseId, uint256 startTime) 
```

The validity is checked via the following function:

```solidity
function checkValidity(uint tokenId) public virtual returns (bool)
```

The context can guide how often the check should be called. Even if the license is current, the check will return false if called by an address which is neither the owner nor the renter.

## Rentals

The RentableLicenseProject contract is elaborated for renting out a license. It can be thought of as a reservation system for the duration of license validity. The end user will buy a lease, based on a listing created by the license / token holder. The listing specifies the rate for a block of time called a RentalTimeUnit. 

```solidity
enum RentalTimeUnit { Seconds, Minutes, Hourly, Daily, Weekly, Monthly, Annual }
function addRentalListing(
    uint256 tokenId,
    RentalTimeUnit timeUnit,
    uint256 timeUnitPrice,
    uint256 minimumUnits,
    uint256 maximumUnits,
    bool allowStreaming
)
    public
    returns (uint256 listingId)     
```

So eg, you can create a listing which lays out a daily rental rate. You can also pick a minimum or maximum number of rental units that need to be bought to start a lease. So eg, you can have an hourly rate, but restrict the user to at least 1 hour or at most 12 hours. At the same time, the same license can have a monthly rate quoted. At the moment there is no support for arbitrary start and end dates for a lease.

Each license can have a single listing per RentalTimeUnit. Eg, you cannot have two hourly rates quoted for the same license. When a renter buys a listing, a RentalLease is established. There can be multiple leases, eg, if a token is for a year, there can be different leases for two different time periods within that year. Leases cannot overlap, eg. if the 15th of April is rented out from 12 pm to 10 pm, then a month long lease from the 10th of April to the 10th of May won't be given.

```solidity
function buyLease(
    uint256 tokenId,
    uint256 listingId,
    uint256 startTime,
    uint256 timeUnitsCount,
    bool streamLease
) 
    public
    payable
    returns (uint256 leaseId)
```

## Streaming Rentals

For a RentalListing which has allowStreaming enabled, the RentalLease will have the option to become a stream as well. This means that the billing for the license will be pay-as-you-go based on the price per second as in the RentalListing. The renter can cancel the lease at any point before the lease expiration and get the pro-rated refund. The token holder however cannot cancel the lease, and can withdraw the rent accumulated based on usage. Note that in all other cases, the rent is paid upfront.



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