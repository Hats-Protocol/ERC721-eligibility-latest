// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { Test, console2 } from "forge-std/Test.sol";
import { LatestNounsBuilderNFTEligibility } from "../src/LatestNounsBuilderNFTEligibility.sol";
import { IToken } from "../src/lib/IToken.sol";
import { IAuction } from "../src/lib/IAuction.sol";
import { DeployImplementation, DeployInstance } from "../script/Deploy.s.sol";
import {
  HatsModuleFactory, IHats, deployModuleInstance, deployModuleFactory
} from "hats-module/utils/DeployFunctions.sol";
import { IHats } from "hats-protocol/Interfaces/IHats.sol";

contract LatestNounsBuilderNFTEligibilityTest is DeployImplementation, Test {
  /// @dev Inherit from DeployPrecompiled instead of Deploy if working with pre-compiled contracts

  /// @dev variables inhereted from module DeployImplementation script
  // LatestNounsBuilderNFTEligibility public implementation;
  // bytes32 public SALT;

  uint256 public fork;
  uint256 public BLOCK_NUMBER = 15_794_717; // June 14, 2024
  IHats public HATS = IHats(0x3bc1A0Ad72417f2d411118085256fC53CBdDd137); // v1.hatsprotocol.eth
  HatsModuleFactory public FACTORY = HatsModuleFactory(0x0a3f85fa597B6a967271286aA0724811acDF5CD9);
  LatestNounsBuilderNFTEligibility public instance;
  bytes public otherImmutableArgs;
  bytes public initArgs;
  uint256 public hatId = 10;
  uint256 saltNonce = 1;
  string public MODULE_VERSION = "test module";

  address public alice = makeAddr("alice");

  // Purple DAO's contracts on Base
  // The token on auction at block 15794717 is #554, so we expect #553 to be the last auctioned token
  IToken public token = IToken(0x8de71d80eE2C4700bC9D4F8031a2504Ca93f7088);
  IAuction public auctionContract = IAuction(0x73Ab6d816FB9FE1714E477C5a70D94E803b56576);

  function setUp() public virtual {
    // create and activate a fork, at BLOCK_NUMBER
    fork = vm.createSelectFork(vm.rpcUrl("base"), BLOCK_NUMBER);

    // deploy implementation via the script
    prepare(false, MODULE_VERSION);
    run();
  }

  function _getCurrentAuctionTokenId() internal view returns (uint256) {
    IAuction auction = IAuction(token.auction());
    return auction.auction().tokenId;
  }

  function _pauseAuction() internal returns (IAuction auction) {
    // get the auction contract
    auction = IAuction(token.auction());
    // get the auction owner
    address auctionOwner = auction.owner();
    // pause the auction
    vm.prank(auctionOwner);
    auction.pause();
  }

  function _settlePausedAuction() internal {
    // get the auction contract
    IAuction auction = IAuction(token.auction());
    // get the auction status
    IAuction.Auction memory currentAuction = auction.auction();
    // advance time to the end of the auction
    vm.warp(currentAuction.endTime + 1);
    // settle the auction
    auction.settleAuction();
  }

  function _pauseAndSettleAuction() internal {
    // pause the auction and get the auction contract
    IAuction auction = _pauseAuction();
    // get the current auction status
    IAuction.Auction memory currentAuction = auction.auction();
    // advance time to the end of the auction
    vm.warp(currentAuction.endTime + 1);
    // settle the auction
    auction.settleAuction();
  }

  function _settleCurrentAndCreateNewAuction() internal {
    // get the current auction
    IAuction auction = IAuction(token.auction());
    // get the current auction status
    IAuction.Auction memory currentAuction = auction.auction();
    // advance time to the end of the auction
    vm.warp(currentAuction.endTime + 1);
    // settle the current auction
    auction.settleCurrentAndCreateNewAuction();
  }

  function _createBidForAccount(address _bidder) internal {
    // get the current token on auction
    uint256 tokenId = _getCurrentAuctionTokenId();
    // give the winner ETH to bid and prank their address
    hoax(_bidder, 1 ether);
    // winner bids on the current auction
    auctionContract.createBid{ value: 1 ether }(tokenId);
  }

  function _settleAuctionForWinner(address _winner) internal {
    // create a bid for the winner
    _createBidForAccount(_winner);

    // settle the auction
    _settleCurrentAndCreateNewAuction();
  }

  function _transferFrom(address _from, address _to, uint256 _tokenId) internal {
    vm.prank(_from);
    token.transferFrom(_from, _to, _tokenId);
  }
}

contract WithInstanceTest is LatestNounsBuilderNFTEligibilityTest {
  function setUp() public virtual override {
    super.setUp();

    // deploy the DeployInstance Script
    DeployInstance deployInstance = new DeployInstance();

    // run the script to deploy the module instance
    deployInstance.prepare(false, address(implementation), hatId, address(token), saltNonce);
    instance = deployInstance.run();
  }
}

contract Deployment is WithInstanceTest {
  /// @dev ensure that both the implementation and instance are properly initialized
  function test_initialization() public {
    // implementation
    vm.expectRevert("Initializable: contract is already initialized");
    implementation.setUp("setUp attempt");
    // instance
    vm.expectRevert("Initializable: contract is already initialized");
    instance.setUp("setUp attempt");
  }

  function test_version() public view {
    assertEq(instance.version(), MODULE_VERSION);
  }

  function test_implementation() public view {
    assertEq(address(instance.IMPLEMENTATION()), address(implementation));
  }

  function test_hats() public view {
    assertEq(address(instance.HATS()), address(HATS));
  }

  function test_hatId() public view {
    assertEq(instance.hatId(), hatId);
  }

  function test_token() public view {
    assertEq(address(instance.TOKEN()), address(token));
  }
}

contract GetLastAuctionedTokenId is WithInstanceTest {
  function test_unpaused_unsettled() public view {
    // the target token is the previous token
    uint256 targetToken = _getCurrentAuctionTokenId() - 1;
    uint256 lastAuctionedTokenId = instance.getLastAuctionedTokenId();

    assertEq(lastAuctionedTokenId, targetToken);
  }

  function test_paused_unsettled() public {
    // the target token is the previous token
    uint256 targetToken = _getCurrentAuctionTokenId() - 1;

    _pauseAuction();
    uint256 lastAuctionedTokenId = instance.getLastAuctionedTokenId();
    // should be the previous token
    assertEq(lastAuctionedTokenId, targetToken);
  }

  function test_paused_settled() public {
    // the target token is the current token
    uint256 targetToken = _getCurrentAuctionTokenId();

    _pauseAndSettleAuction();
    uint256 lastAuctionedTokenId = instance.getLastAuctionedTokenId();
    // should be the current token
    assertEq(lastAuctionedTokenId, targetToken);
  }

  /// @dev An auction will never be in unpaused and settled state, since unpause() starts a new auction if the previous
  /// one is settled
}

contract GetWearerStatus is WithInstanceTest {
  /// @dev Asserts that an account is eligible and in good standing the hat.
  function assertEligible(address _account, uint256 _hatId) public view {
    (bool eligible, bool standing) = instance.getWearerStatus(_account, _hatId);
    assertEq(eligible, true);
    assertEq(standing, true);
  }

  /// @dev Asserts that an account is ineligible (but in good standing) for the hat.
  function assertIneligible(address _account, uint256 _hatId) public view {
    (bool eligible, bool standing) = instance.getWearerStatus(_account, _hatId);
    assertEq(eligible, false);
    assertEq(standing, true);
  }

  function test_unpaused_unsettled() public view {
    // the target token is the previous token
    uint256 targetToken = _getCurrentAuctionTokenId() - 1;
    // get the current owner
    address currentOwner = token.ownerOf(targetToken);

    assertEligible(currentOwner, hatId);
    assertIneligible(alice, hatId);
  }

  function test_paused_unsettled() public {
    // the target token is the previous token
    uint256 targetToken = _getCurrentAuctionTokenId() - 1;
    // get the current owner
    address currentOwner = token.ownerOf(targetToken);

    _pauseAuction();

    assertEligible(currentOwner, hatId);
    assertIneligible(alice, hatId);
  }

  function test_paused_settled() public {
    // the target token is the current token
    uint256 targetToken = _getCurrentAuctionTokenId();
    // get the current owner
    address currentOwner = token.ownerOf(targetToken);

    _pauseAndSettleAuction();

    assertIneligible(currentOwner, hatId);
    assertIneligible(alice, hatId);
  }

  function test_unpaused_aliceWinsAuction() public {
    // alice starts out ineligible
    assertIneligible(alice, hatId);

    // alice wins the current auction
    _settleAuctionForWinner(alice);

    assertEligible(alice, hatId);
  }

  function test_paused_aliceWinsAuction() public {
    // alice starts out ineligible
    assertIneligible(alice, hatId);

    // alice wins the current auction,
    _settleAuctionForWinner(alice);
    assertEligible(alice, hatId);

    // now the auction is paused; alice remains eligible
    _pauseAuction();
    assertEligible(alice, hatId);
  }

  function test_paused_settled_aliceWinsAuction() public {
    // alice starts out ineligible
    assertIneligible(alice, hatId);

    // alice wins the current auction, making her eligible
    _settleAuctionForWinner(alice);
    assertEligible(alice, hatId);

    // now the auction is paused; alice remains eligible
    _pauseAuction();
    assertEligible(alice, hatId);

    // now the auction is settled; alice remains eligible
    _settlePausedAuction();
    assertEligible(alice, hatId);
  }

  function test_unpaused_aliceWinsAuction_nextAuctionSettlesWithWinner() public {
    // alice starts out ineligible
    assertIneligible(alice, hatId);

    // alice wins the current auction, making her eligible
    _settleAuctionForWinner(alice);
    assertEligible(alice, hatId);

    // somebody else wins the next auction, making alice ineligible
    _settleAuctionForWinner(address(11));
    assertIneligible(alice, hatId);
  }

  function test_unpaused_aliceWinsAuction_nextAuctionSettlesWithoutWinner() public {
    // alice starts out ineligible
    assertIneligible(alice, hatId);

    // alice wins the current auction, making her eligible
    // the auction is settled and a second one is created
    _settleAuctionForWinner(alice); // settled auction 554
    assertEligible(alice, hatId);

    // now the second auction is settled and new one is created, making alice ineligible
    _settleCurrentAndCreateNewAuction(); // settled auction 555
    assertIneligible(alice, hatId);
  }
}
