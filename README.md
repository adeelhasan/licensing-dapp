Licensing Smart Contracts

TODO: add slimmed down version of white paper

Deployment of Test Contracts:

- first start anvil in a separate console
- fill in the .env file with the private keys listed for anvil
PK_ANVIL_PROJECT_OWNER=""
PK_ANVIL_1=""
PK_ANVIL_2=""
PK_ANVIL_3=""

- run the deployment script
forge script script/LicenseProject.s.sol:LicenseProjectScript --rpc-url http://localhost:8545 --broadcast

- import the private keys above into Metamask to make it easier to see the frontend

