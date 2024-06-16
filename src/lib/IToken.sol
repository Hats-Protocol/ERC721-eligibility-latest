// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @dev Excerpt sourced from
/// https://github.com/ourzora/nouns-protocol/blob/98b65e2368c52085ff3844779afd45162eb1cc7d/src/token/IToken.sol
interface IToken {
  /// @notice The founder type
  /// @param wallet The address where tokens are sent
  /// @param ownershipPct The percentage of token ownership
  /// @param vestExpiry The timestamp when vesting ends
  struct Founder {
    address wallet;
    uint8 ownershipPct;
    uint32 vestExpiry;
  }
  /// @notice The address of the auction house

  function auction() external view returns (address);

  /// @notice The total number of tokens that can be claimed from the reserve
  function remainingTokensInReserve() external view returns (uint256);

  /// @notice The total supply of tokens
  function totalSupply() external view returns (uint256);

  /// @notice The owner of a token
  /// @param tokenId The ERC-721 token id
  function ownerOf(uint256 tokenId) external view returns (address);

  /// @notice Mints the specified amount of tokens to the recipient and handles founder vesting
  function mintTo(address recipient) external returns (uint256 tokenId);

  /// @notice Transfers a token from one address to another
  function transferFrom(address from, address to, uint256 tokenId) external;

  /// @notice The founder scheduled to receive the given token id
  /// NOTE: If a founder is returned, there's no guarantee they'll receive the token as vesting expiration is not
  /// considered
  /// @param _tokenId The ERC-721 token id
  function getScheduledRecipient(uint256 _tokenId) external view returns (Founder memory);

  /// @notice The founders total percent ownership
  function totalFounderOwnership() external view returns (uint256);
}
