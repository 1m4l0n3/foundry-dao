// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test,console} from "../lib/forge-std/src/Test.sol";
import {Timelock} from "../src/TimeLock.sol";
import {GovToken} from "../src/GovToken.sol";
import {MyGovernor} from "../src/MyGovernor.sol";
import {Box} from "../src/Box.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

contract MyGovernorTest is Test {
    MyGovernor internal myGovernor;
    Box internal box;
    Timelock internal timeLock;
    GovToken internal govToken;
    address internal user;

    uint256 public constant INITIAL_SUPPLY = 100 ether;
    uint48 public constant INITIAL_VOTING_DELAY = 7200;
    uint32 public constant INITIAL_VOTING_PERIOD = 50400;
    uint256 public constant INITIAL_VOTING_THRESHOLD = 0;
    uint256 public constant QUORUM_PERCENTAGE = 4;
    uint256 public constant EXECUTION_DELAY = 3600;
    uint8 public constant WAY_OF_VOTING = 1;

    address[] internal proposers;
    address[] internal executors;
    address[] internal targets;
    uint256[] internal values;
    bytes[] internal calldatas;



    function setUp() external {
        user = makeAddr("user");
        govToken = new GovToken();
        govToken.mint(user,INITIAL_SUPPLY);

        vm.prank(user);
        govToken.delegate(user);

        timeLock = new Timelock(EXECUTION_DELAY,proposers,executors);
        myGovernor = new MyGovernor(govToken,timeLock,INITIAL_VOTING_DELAY,INITIAL_VOTING_PERIOD,INITIAL_VOTING_THRESHOLD,QUORUM_PERCENTAGE);

        bytes32 proposerRole = timeLock.PROPOSER_ROLE();
        bytes32 executorRole = timeLock.EXECUTOR_ROLE();
        bytes32 adminRole = timeLock.DEFAULT_ADMIN_ROLE();

        timeLock.grantRole(proposerRole,address(myGovernor));
        timeLock.grantRole(executorRole,address(0));
        timeLock.revokeRole(adminRole,msg.sender);

        box = new Box(msg.sender);
        vm.prank(msg.sender);
        box.transferOwnership(address(timeLock));
    }

    function testCantUpdateBoxWithoutGovernance() public {
        vm.expectRevert();
        box.store(1);
    }

    function testGovernanceUpdatesBox() public {
        uint256 valueToUpdate = 123;
        string memory reason = "I love voting";

        string memory description;
        bytes memory functionSignature = abi.encodeWithSignature("store(uint256)",valueToUpdate);

        targets.push(address(box));
        values.push(0);
        calldatas.push(functionSignature);
        description = "Update the box value to 123";

        uint256 proposeId = myGovernor.propose(targets,values,calldatas,description);
        console.log("proposal status",uint256(myGovernor.state(proposeId)));


        vm.warp(block.timestamp + INITIAL_VOTING_DELAY + 1);
        vm.roll(block.number + INITIAL_VOTING_DELAY + 1);
        console.log("proposal status",uint256(myGovernor.state(proposeId)));

        vm.prank(user);
        myGovernor.castVoteWithReason(proposeId,WAY_OF_VOTING,reason);

        vm.warp(block.timestamp + INITIAL_VOTING_PERIOD + 1);
        vm.roll(block.number + INITIAL_VOTING_PERIOD + 1);
        console.log("proposal status",uint256(myGovernor.state(proposeId)));


        bytes32 descriptionHash = keccak256(abi.encodePacked(description));
        myGovernor.queue(targets,values,calldatas,descriptionHash);
        console.log("proposal status",uint256(myGovernor.state(proposeId)));

        vm.roll(block.timestamp + EXECUTION_DELAY + 1);
        vm.warp(block.timestamp + EXECUTION_DELAY + 1);

        myGovernor.execute(targets,values,calldatas,descriptionHash);

        assertEq(valueToUpdate, box.getNumber());
    }
}

/**

enum ProposalState {
    Pending,
    Active,
    Canceled,
    Defeated,
    Succeeded,
    Queued,
    Expired,
    Executed
}

**/