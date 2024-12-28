// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test} from "../lib/forge-std/src/Test.sol";
import {Timelock} from "../src/TimeLock.sol";
import {GovToken} from "../src/GovToken.sol";
import {MyGovernor} from "../src/MyGoverner.sol";
import {Box} from "../src/Box.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

contract MyGovernorTest is Test {
    MyGovernor internal myGovernor;
    Box internal box;
    Timelock internal timeLock;
    GovToken internal govToken;
    address internal user;

    uint256 internal constant INITIAL_SUPPLY = 100 ether;
    uint256 internal constant VOTING_DELAY = 60 * 60;

    address[] internal proposers;
    address[] internal executors;

    function setUp() external {
        govToken = new GovToken();
        govToken.mint(user,INITIAL_SUPPLY);

        vm.prank(user);
        govToken.delegate(user);

        timeLock = new Timelock(VOTING_DELAY,proposers,executors);
        myGovernor = new MyGovernor(govToken,timeLock);

        bytes32 proposerRole = timeLock.PROPOSER_ROLE();
        bytes32 executorRole = timeLock.EXECUTOR_ROLE();
        bytes32 adminRole = timeLock.DEFAULT_ADMIN_ROLE();

        timeLock.grantRole(proposerRole,address(myGovernor));
        timeLock.grantRole(executorRole,address(0));
        timeLock.revokeRole(adminRole,msg.sender);

        box = new Box(msg.sender);
        box.transferOwnership(address(timeLock));
    }
}