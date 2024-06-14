// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Sourced from
/// https://github.com/ourzora/nouns-protocol/blob/98b65e2368c52085ff3844779afd45162eb1cc7d/src/auction/storage/AuctionStorageV1
interface IAuction {
  /// @notice The auction type
  /// @param tokenId The ERC-721 token id
  /// @param highestBid The highest amount of ETH raised
  /// @param highestBidder The leading bidder
  /// @param startTime The timestamp the auction starts
  /// @param endTime The timestamp the auction ends
  /// @param settled If the auction has been settled
  struct Auction {
    uint256 tokenId;
    uint256 highestBid;
    address highestBidder;
    uint40 startTime;
    uint40 endTime;
    bool settled;
  }

  /// @notice The current auction
  function auction() external view returns (Auction memory);

  /// @notice Settles the current auction and creates the next one
  function settleCurrentAndCreateNewAuction() external;

  /// @notice Pauses the auction house
  function pause() external;

  /// @notice Unpauses the auction house
  function unpause() external;

  /// @notice Settles the latest auction when the contract is paused
  function settleAuction() external;

  function createBid(uint256 tokenId) external payable;

  /// @notice The owner of the auction house
  function owner() external view returns (address);
}
