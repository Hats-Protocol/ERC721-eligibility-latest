// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { Test, console2, stdStorage, StdStorage } from "forge-std/Test.sol";
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
  IAuction public auctionContract;

  function setUp() public virtual {
    // create and activate a fork, at BLOCK_NUMBER
    fork = vm.createSelectFork(vm.rpcUrl("base"), BLOCK_NUMBER);

    // deploy implementation via the script
    prepare(false, MODULE_VERSION);
    run();
  }

  function _getCurrentAuctionTokenId() internal view returns (uint256) {
    return auctionContract.auction().tokenId;
  }

  function _pauseAuction() internal {
    // get the auction owner
    address auctionOwner = auctionContract.owner();
    // pause the auction
    vm.prank(auctionOwner);
    auctionContract.pause();
  }

  function _settlePausedAuction() internal {
    // get the auction status
    IAuction.Auction memory currentAuction = auctionContract.auction();
    // advance time to the end of the auction
    vm.warp(currentAuction.endTime + 1);
    // settle the auction
    auctionContract.settleAuction();
  }

  function _pauseAndSettleAuction() internal {
    // pause the auction
    _pauseAuction();
    // get the current auction status
    IAuction.Auction memory currentAuction = auctionContract.auction();
    // advance time to the end of the auction
    vm.warp(currentAuction.endTime + 1);
    // settle the auction
    auctionContract.settleAuction();
  }

  function _settleCurrentAndCreateNewAuction() internal {
    // get the current auction status
    IAuction.Auction memory currentAuction = auctionContract.auction();
    // advance time to the end of the auction
    vm.warp(currentAuction.endTime + 1);
    // settle the current auction
    auctionContract.settleCurrentAndCreateNewAuction();
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

    // set the auction contract
    auctionContract = IAuction(token.auction());
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
  using stdStorage for StdStorage;

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

  function test_founderToken() public {
    // select a token id just prior to a future founder token
    uint256 targetToken = 599;

    // have some other account win the auctions between now and the target token
    address otherAccount = address(11);
    // HACK: this takes a while in tests
    while (_getCurrentAuctionTokenId() < targetToken) {
      _settleAuctionForWinner(otherAccount);
    }

    // have alice win the auction for the target token
    _settleAuctionForWinner(alice);

    // confirm that the next two tokens have been minted
    assertNotEq(token.ownerOf(targetToken + 1), address(0));
    assertNotEq(token.ownerOf(targetToken + 2), address(0));

    // alice should be eligible
    assertEligible(alice, hatId);
  }

  /**
   * @dev Fast forwards to the auction for a given (assumed) future tokenId.
   * Sets the following values directly in storage:
   * - the current auction's token id => _tokenId
   * - the owner of the target token => auctionContract
   * - updates the settings.mintCount to reconcile with the above
   */
  function _skipToAuctionForToken(uint256 _targetTokenId) internal {
    // cache the current auction token id
    uint256 ogTokenId = _getCurrentAuctionTokenId();

    // set the current auction's token id to the target
    stdstore.target(address(auctionContract)).sig("auction()").depth(0).checked_write(_targetTokenId);
    // confirm that the current token id is the target
    assertEq(_getCurrentAuctionTokenId(), _targetTokenId);

    // set the target token's owner to the auction contract. We need to calculate the storage slot manually because
    // stdstore doesn't work when the function reverts, which happens for ownerOf when the tokenId has not yet been
    // minted
    vm.store(address(token), _getOwnerSlot(_targetTokenId), bytes32(uint256(uint160(address(auctionContract)))));
    // confirm that the owner of the target token is the auction contract
    assertEq(token.ownerOf(_targetTokenId), address(auctionContract));

    // increment the mintCount to be true for the target token
    // FIXME: the "mintCoun()" function doesn't exist, so need to find another way
    uint256 mintCount = stdstore.target(address(token)).sig("mintCount()").depth(4).read_uint();
    uint256 increment = _targetTokenId - ogTokenId;
    stdstore.target(address(token)).sig("mintCount()").depth(4).checked_write(mintCount + increment);
  }

  /// @dev Calculates the storage slot for the owner of a tokenId.
  function _getOwnerSlot(uint256 tokenId) internal pure returns (bytes32) {
    // The `owners` mapping begins at slot 10 in Token.sol
    return keccak256(abi.encode(tokenId, uint256(10)));
  }
}

contract IsFounderToken is WithInstanceTest {
  // test a few know cases
  function test_founderToken() public view {
    // Purple DAO has two founders, each with 1% ownership. This means that the first two tokens of each set of 100 are
    // founder tokens
    assertTrue(instance.isFounderToken(0));
    assertTrue(instance.isFounderToken(1));
    assertFalse(instance.isFounderToken(2));
    assertFalse(instance.isFounderToken(99));
    assertTrue(instance.isFounderToken(100));
    assertTrue(instance.isFounderToken(101));
    assertFalse(instance.isFounderToken(102));
    assertTrue(instance.isFounderToken(400));
    assertFalse(instance.isFounderToken(250));
    assertTrue(instance.isFounderToken(1000));
    assertFalse(instance.isFounderToken(100_000_003));
  }
}
