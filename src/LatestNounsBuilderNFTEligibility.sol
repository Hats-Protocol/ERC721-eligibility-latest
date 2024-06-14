// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// import { console2 } from "forge-std/Test.sol"; // remove before deploy
import { HatsModule, HatsEligibilityModule, IHatsEligibility } from "hats-module/HatsEligibilityModule.sol";
import { IToken } from "./lib/IToken.sol";
import { IAuction } from "./lib/IAuction.sol";

contract LatestNounsBuilderNFTEligibility is HatsEligibilityModule {
  /*//////////////////////////////////////////////////////////////
                            CONSTANTS 
  //////////////////////////////////////////////////////////////*/

  /**
   * This contract is a clone with immutable args, which means that it is deployed with a set of
   * immutable storage variables (ie constants). Accessing these constants is cheaper than accessing
   * regular storage variables (such as those set on initialization of a typical EIP-1167 clone),
   * but requires a slightly different approach since they are read from calldata instead of storage.
   *
   * Below is a table of constants and their location.
   *
   * For more, see here: https://github.com/Saw-mon-and-Natalie/clones-with-immutable-args
   *
   * ----------------------------------------------------------------------+
   * CLONE IMMUTABLE "STORAGE"                                             |
   * ----------------------------------------------------------------------|
   * Offset  | Constant          | Type    | Length  | Source              |
   * ----------------------------------------------------------------------|
   * 0       | IMPLEMENTATION    | address | 20      | HatsModule          |
   * 20      | HATS              | address | 20      | HatsModule          |
   * 40      | hatId             | uint256 | 32      | HatsModule          |
   * 72      | TOKEN             | IToken  | 20      | this                |
   * ----------------------------------------------------------------------+
   */
  function TOKEN() public pure returns (IToken) {
    return IToken(_getArgAddress(72));
  }

  /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
  //////////////////////////////////////////////////////////////*/

  /// @notice Deploy the implementation contract and set its version
  /// @dev This is only used to deploy the implementation contract, and should not be used to deploy clones
  constructor(string memory _version) HatsModule(_version) { }

  /*//////////////////////////////////////////////////////////////
                            INITIALIZOR
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc HatsModule
  function _setUp(bytes calldata _initData) internal override {
    // decode init data
  }

  /*//////////////////////////////////////////////////////////////
                      HATS ELIGIBILITY FUNCTION
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc IHatsEligibility
  function getWearerStatus(address _wearer, uint256 /*_hatId*/ )
    public
    view
    virtual
    override
    returns (bool eligible, bool standing)
  {
    // The wearer is eligible only if they own the latest token id
    // We need to catch the case where the previous auction was settled without a winner
    try TOKEN().ownerOf(getLastAuctionedTokenId()) returns (address owner) {
      // the last auctioned token id has a value owner, so we check if it matches the wearer
      eligible = owner == _wearer;
    } catch {
      // if the last auctioned token id does not have an owner, so we know the wearer is not eligible
      // eligible is false by default
    }

    // This module does not deal with standing, so we default to good standing (true)
    standing = true;
  }

  /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Get the id of the most recently auctioned token for `_token`.
   * If the auction was settled without a winner, the returned token id will not have an owner.
   *
   * @dev Return the present auction's token id if it has been settled with a winner, otherwise it returns
   * the id of the previous auction.
   *
   * @return The id of the most recently auctioned token.
   */
  function getLastAuctionedTokenId() public view returns (uint256) {
    // get the auction contract
    IAuction auctionContract = IAuction(TOKEN().auction());

    // get the data for the current auction
    IAuction.Auction memory currentAuction = auctionContract.auction();

    // if the auction is settled with a winner, we want the current auction's token;
    if (currentAuction.settled && currentAuction.highestBidder > address(0)) {
      return currentAuction.tokenId;
    } else {
      // otherwise, we want the previous auction's token
      return currentAuction.tokenId - 1;
    }
  }
}
