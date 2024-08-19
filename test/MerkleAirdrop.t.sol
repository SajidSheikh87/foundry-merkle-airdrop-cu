// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {MerkleAirdrop} from "../src/MerkleAirdrop.sol";
import {BagelToken} from "../src/BagelToken.sol";
import {ZkSyncChainChecker} from "foundry-devops/src/ZkSyncChainChecker.sol";
import {DeployMerkleAirdrop} from "script/DeployMerkleAirdrop.s.sol";

contract MerkleAirdropTest is ZkSyncChainChecker, Test {
    MerkleAirdrop public airdrop;
    BagelToken public token;

    bytes32 public ROOT = 0xaa5d581231e596618465a56aa0f5870ba6e20785fe436d5bfb82b08662ccc7c4;
    uint256 public constant AMOUNT_TO_ClAIM = 25 * 1e18;
    uint256 public constant AMOUNT_TO_SEND = AMOUNT_TO_ClAIM * 4;
    bytes32 proofOne = 0x0fd7c981d39bece61f7499702bf59b3114a90e66b51ba2c53abdf7b62986c00a;
    bytes32 proofTwo = 0xe5ebd1e1b5a5478a944ecab36a9a954ac3b6b8216875f6524caa7a1d87096576;
    bytes32[] public PROOF = [proofOne, proofTwo];

    address public gasPayer;
    address user;
    uint256 userPrivKey;

    function setUp() public {
        if (!isZkSyncChain()) {
            // deploy with the script
            DeployMerkleAirdrop deployer = new DeployMerkleAirdrop();
            (airdrop, token) = deployer.run();
        } else {
            token = new BagelToken();
            airdrop = new MerkleAirdrop(ROOT, token);
            token.mint(token.owner(), AMOUNT_TO_SEND);
            token.transfer(address(airdrop), AMOUNT_TO_SEND);
        }

        (user, userPrivKey) = makeAddrAndKey("user");
        console.log("User address: ", user);
        gasPayer = makeAddr("gasPayer");
    }

    function testUsersCanClaim() public {
        uint256 startingBalance = token.balanceOf(user);
        bytes32 digest = airdrop.getMessageHash(user, AMOUNT_TO_ClAIM);

        // sign a message

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivKey, digest);
        // console.log("Signature v: ", v);
        // console.log("Signature r: ", uint256(r));
        // console.log("Signature s: ", uint256(s));

        // gasPayer calls claim using the signed message
        vm.prank(gasPayer);
        airdrop.claim(user, AMOUNT_TO_ClAIM, PROOF, v, r, s);
        // vm.prank(user) only pranks the next line and since it is stopped already, we dont need to have vm.stopPrank()

        uint256 endingBalance = token.balanceOf(user);
        console.log("Ending Balance: ", endingBalance);
        assertEq(endingBalance - startingBalance, AMOUNT_TO_ClAIM);
    }
}
