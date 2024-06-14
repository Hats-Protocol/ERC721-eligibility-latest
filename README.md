# Latest Nouns Builder NFT Eligibility

A [Hats Protocol](https://github.com/hats-protocol) Module that determines eligibility for a hat based on ownership of the most recently auctioned NFT for a DAO using the [Nouns Builder](https://nouns.build) V2 framework.

## Overview and Usage

Nounish DAOs auction off a new NFT automatically on a regular, periodic basis (often daily). Nounish DAOs can use this module to automatically assign eligibility for a given hat to the owner of the NFT that was most recently auctioned off. 

An account is considered the owner of the most recently auctioned NFT (and therefore eligible) if the following are true:

1. The account is the current owner of the NFT
2. The auction for their NFT has been settled
3. No subsequent auctions have been settled

If a subsequent auction has been settled without a winner (e.g. because there were no valid bids) then no account is considered eligible.

## Development

This repo uses Foundry for development and testing. To get started:

1. Fork the project
2. Install [Foundry](https://book.getfoundry.sh/getting-started/installation)
3. To install dependencies, run `forge install`
4. To compile the contracts, run `forge build`
5. To test, run `forge test`

### IR-Optimized Builds

This repo also supports contracts compiled via IR. Since compiling all contracts via IR would slow down testing workflows, we only want to do this for our target contract(s), not anything in this `test` or `script` stack. We accomplish this by pre-compiled the target contract(s) and then loading the pre-compiled artifacts in the test suite.

First, we compile the target contract(s) via IR by running`FOUNDRY_PROFILE=optimized forge build` (ensuring that FOUNDRY_PROFILE is not in our .env file)

Next, ensure that tests are using the `DeployOptimized` script, and run `forge test` as normal.

See the wonderful [Seaport repo](https://github.com/ProjectOpenSea/seaport/blob/main/README.md#foundry-tests) for more details and options for this approach.
