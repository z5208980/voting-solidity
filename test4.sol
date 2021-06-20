// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.00 <0.9.0;
import "remix_tests.sol";
import "remix_accounts.sol";
import "../contracts/LunchVenue.sol";
import "https://github.com/GNSPS/solidity-bytes-utils/blob/5d251ad816e804d55ac39fa146b4622f55708579/contracts/BytesLib.sol";

contract LunchVenueTestEdgeCases is LunchVenue {
    using BytesLib for bytes;

    address acc0;
    address acc1;
    address acc2;
    address acc3;
    address acc4;
    address acc5;


    function beforeAll() public {
        acc0 = TestsAccounts.getAccount(0);
        acc1 = TestsAccounts.getAccount(1);
        acc2 = TestsAccounts.getAccount(2);
        acc3 = TestsAccounts.getAccount(3);
        acc4 = TestsAccounts.getAccount(4);
        acc5 = TestsAccounts.getAccount(5);

    }

    /// Account at zero index (account-0) is default account, so manager will be set to acc0
    function managerTest() public {
        Assert.equal(manager, acc0, 'Manager should be acc0');
    }

    /// Add lunch venue as manager
    /// When msg.sender isn’t specified , default account (i.e., account-0) is considered as the sender
    function setLunchVenue() public {
        Assert.equal(addVenue('Courtyard Cafe'), 1, 'Should be equal to 1');
        Assert.equal(addVenue('Uni Cafe'), 2, 'Should be equal to 2');
    }

    /// Try to add lunch venue as a user other than manager. This should fail
    /// #sender: account-1
    function setLunchVenueFailure() public {
        try this.addVenue('Atomic Cafe') returns (uint v) {
            Assert.ok(false, 'Method execution should fail');
        } catch Error(string memory reason) {
            Assert.equal(reason, 'Restricted to manager only.', 'Failed with unexpected reason');
        } catch (bytes memory) {
            Assert.ok(false, 'Failed unexpected');
        }
    }

    function setFriend() public {
        Assert.equal(addFriend(acc0, 'Alice'), 1, 'Should be equal to 1');
        Assert.equal(addFriend(acc1, 'Bob'), 2, 'Should be equal to 2');
        Assert.equal(addFriend(acc2, 'Charlie'), 3, 'Should be equal to 3');
        Assert.equal(addFriend(acc3, 'Eve'), 4, 'Should be equal to 4');
        Assert.equal(addFriend(acc5, 'Fred'), 5, 'Should be equal to 4');

    }

    /// Try adding friend as a user other than manager. This should fail
    /// #sender: account-2
    function setFriendFailure() public {
        try this.addFriend(acc4, 'Daniels') returns (uint f) {
            Assert.ok(false, 'Method execution should fail');
        } catch Error(string memory reason) {
            Assert.equal(reason, 'Restricted to manager only.', 'Failed with unexpected reason');
        } catch (bytes memory) {
            Assert.ok(false, 'Failed unexpected');
        }
    }

    function setOpenVote() public {
        Assert.equal(getVoteState(), 0, 'Vote should be closed (0)');
        Assert.ok(openForVoting(), 'Voting open now.');
        Assert.equal(getVoteState(), 1, 'Vote should be open (1)');
    }

    /// Vote as Bob (acc1)
    /// #sender: account-1
    function vote() public {
        Assert.ok(doVote(2), 'Voting result should be true');
    }

    /// Trying to vote again after already voted with different venue
    /// #sender: account-1
    function voteAgainFailure() public {
        // Assert.equal(doVote(1), false, 'Voting result should be false');
        (bool success, bytes memory result) = address(this).delegatecall(abi.encodeWithSignature("doVote(uint256)", 1));
        if (success == false) {
            string memory reason = abi.decode(result.slice(4, result.length - 4), (string));
            Assert.equal(reason, 'Can\'t vote. Already voted.', 'Failed with unexpected reason');
        } else {
            Assert.ok(false, 'Method Execution should fail');
        }
    }


    /// Vote for a venue number that is not on list
    /// #sender: account-5
    function voteNonExistVenueFailure() public {
        Assert.equal(doVote(100), false, 'Voting result should be false');
    }


    /// Vote as Charlie
    /// #sender: account-2
    function vote2() public {
        Assert.ok(doVote(1), 'Voting result should be true');
    }

    /// Try Voting again with for the same venue
    /// #sender: account-2
    function voteSameFailure() public {
        (bool success, bytes memory result) = address(this).delegatecall(abi.encodeWithSignature("doVote(uint256)", 1));
        if (success == false) {
            string memory reason = abi.decode(result.slice(4, result.length - 4), (string));
            Assert.equal(reason, 'Can\'t vote. Already voted.', 'Failed with unexpected reason');
        } else {
            Assert.ok(false, 'Method Execution should fail');
        }
    }

    /// Try voting as a user not in the friends list. This should fail
    /// #sender: account-4
    function voteFailure() public {
                (bool success, bytes memory result) = address(this).delegatecall(abi.encodeWithSignature("doVote(uint256)", 2));
        if (success == false) {
            string memory reason = abi.decode(result.slice(4, result.length - 4), (string));
            Assert.equal(reason, 'Can\'t vote. Not a friend.', 'Failed with unexpected reason');
        } else {
            Assert.ok(false, 'Method Execution should fail');
        }
    }

    /// Vote as Eve
    /// #sender: account-3
    function vote3() public {
        Assert.ok(doVote(2), 'Voting result should be true');
    }

    function lunchVenueTest() public {
        Assert.equal(votedVenue, 'Uni Cafe', 'Selected venue should be Uni Cafe');
    }

    // // After successfully voting, Vote should be Finalised (Not Closed)
    // function voteOpenTest() public {
    //     Assert.equal(getVoteState(), 3, 'Voting should be closed');
    // }

    /// Verify voting after vote closed. This should fail
    /// #sender: account-2
    function voteAfterClosedFialure() public {
        try this.doVote(1) returns (bool validVote) {
            Assert.ok(false, 'Method execution should fail');
        } catch Error(string memory reason) {
            Assert.equal(reason, 'Can vote only while voting is open', 'Failed with unexpected reason');
        } catch (bytes memory) {
            Assert.ok(false, 'Failed unexpectedly');
        }
    }
}


contract LunchVenueTestTie is LunchVenue {
    using BytesLib for bytes;

    /*
        No. friends: 6
        Quorum: (6/2)+1 = 4
    */

    address acc0;
    address acc1;
    address acc2;
    address acc3;
    address acc4;
    address acc5;
    address acc6;

    function beforeAll() public {
        acc0 = TestsAccounts.getAccount(0);
        acc1 = TestsAccounts.getAccount(1);
        acc2 = TestsAccounts.getAccount(2);
        acc3 = TestsAccounts.getAccount(3);
        acc4 = TestsAccounts.getAccount(4);
        acc5 = TestsAccounts.getAccount(5);
        acc6 = TestsAccounts.getAccount(6);
    }

    /// Account at zero index (account-0) is default account, so manager will be set to acc0
    function managerTest() public {
        Assert.equal(manager, acc0, 'Manager should be acc0');
    }

    /// Add lunch venue as manager
    /// When msg.sender isn’t specified , default account (i.e., account-0) is considered as the sender
    function setLunchVenue() public {
        Assert.equal(addVenue('Courtyard Cafe'), 1, 'Should be equal to 1');
        Assert.equal(addVenue('Uni Cafe'), 2, 'Should be equal to 2');
    }

    /// Try to add lunch venue as a user other than manager. This should fail
    /// #sender: account-1
    function setLunchVenueFailure() public {
        try this.addVenue('Atomic Cafe') returns (uint v) {
            Assert.ok(false, 'Method execution should fail');
        } catch Error(string memory reason) {
            Assert.equal(reason, 'Restricted to manager only.', 'Failed with unexpected reason');
        } catch (bytes memory) {
            Assert.ok(false, 'Failed unexpected');
        }
    }

    function setFriend() public {
        Assert.equal(addFriend(acc1, 'Alice'), 1, 'Should be equal to 1');
        Assert.equal(addFriend(acc2, 'Bob'), 2, 'Should be equal to 2');
        Assert.equal(addFriend(acc3, 'Char'), 3, 'Should be equal to 3');
        Assert.equal(addFriend(acc4, 'Dav'), 4, 'Should be equal to 4');
        Assert.equal(addFriend(acc5, 'Eve'), 5, 'Should be equal to 5');
        Assert.equal(addFriend(acc6, 'Fred'), 6, 'Should be equal to 6');
    }

    function setOpenVote() public {
        Assert.equal(getVoteState(), 0, 'Vote should be closed (0)');
        Assert.ok(openForVoting(), 'Voting open now.');
        Assert.equal(getVoteState(), 1, 'Vote should be open (1)');
    }

    /// Vote as Bob (acc1)
    /// #sender: account-1
    function vote() public {
        Assert.ok(doVote(1), 'Voting result should be true');
    }

    /// Vote as Charlie
    /// #sender: account-2
    function vote2() public {
        Assert.ok(doVote(1), 'Voting result should be true');
    }

    /// Vote as Dav
    /// #sender: account-3
    function vote3() public {
        Assert.ok(doVote(2), 'Voting result should be true');
    }

    /// Vote as Eve
    /// #sender: account-4
    function vote4() public {
        Assert.ok(doVote(2), 'Voting result should be true');
    }

    function lunchVenueTest() public {
        Assert.equal(votedVenue, 'Courtyard Cafe', 'Selected venue should be Uni Cafe');
    }

    // After successfully voting, Vote should be Finalised (Not Closed)
    function voteOpenTest() public {
        Assert.equal(getVoteState(), 3, 'Voting should be closed');
    }

    /// Verify voting after vote closed. This should fail
    /// #sender: account-2
    function voteAfterClosedFailure() public {
        try this.doVote(1) returns (bool validVote) {
            Assert.ok(false, 'Method execution should fail');
        } catch Error(string memory reason) {
            Assert.equal(reason, 'Voting has not open yet.', 'Failed with unexpected reason');
        } catch (bytes memory) {
            Assert.ok(false, 'Failed unexpectedly');
        }
    }
}

contract LunchVenueTestSuccess is LunchVenue {
    using BytesLib for bytes;
    /*
        No. friends: 4
        Quorum: (4/2)+1 = 3
    */

    address acc0;
    address acc1;
    address acc2;
    address acc3;
    address acc4;
    address acc5;
    address acc6;

    function beforeAll() public {
        acc0 = TestsAccounts.getAccount(0);
        acc1 = TestsAccounts.getAccount(1);
        acc2 = TestsAccounts.getAccount(2);
        acc3 = TestsAccounts.getAccount(3);
        acc4 = TestsAccounts.getAccount(4);
        acc5 = TestsAccounts.getAccount(5);
        acc6 = TestsAccounts.getAccount(6);
    }

    /// Account at zero index (account-0) is default account, so manager will be set to acc0
    function managerTest() public {
        Assert.equal(manager, acc0, 'Manager should be acc0');
    }

    /// Add lunch venue as manager
    /// When msg.sender isn’t specified , default account (i.e., account-0) is considered as the sender
    function setLunchVenue() public {
        Assert.equal(addVenue('Courtyard Cafe'), 1, 'Should be equal to 1');
        Assert.equal(addVenue('Uni Cafe'), 2, 'Should be equal to 2');
    }

    function setFriend() public {
        Assert.equal(addFriend(acc0, 'Alice'), 1, 'Should be equal to 6');
        Assert.equal(addFriend(acc3, 'Char'), 2, 'Should be equal to 3');
        Assert.equal(addFriend(acc4, 'Dav'), 3, 'Should be equal to 4');
        Assert.equal(addFriend(acc5, 'Eve'), 4, 'Should be equal to 5');
        // Assert.equal(addFriend(acc6, 'Fred'), 5, 'Should be equal to 5');
    }

    /// #sender: account-3
    function testVoteBeforeOpen() public {
        (bool success, bytes memory result) = address(this).delegatecall(abi.encodeWithSignature("doVote(uint256)", 1));
        if (success == false) {
            string memory reason = abi.decode(result.slice(4, result.length - 4), (string));
            Assert.equal(reason, 'Voting has not open yet.', 'Failed with unexpected reason');
        } else {
            Assert.ok(false, 'Method Execution should fail');
        }
    }

    function setOpenVote() public {
        Assert.equal(getVoteState(), 0, 'Vote should be closed (0)');
        Assert.ok(openForVoting(), 'Voting open now.');
        Assert.equal(getVoteState(), 1, 'Vote should be open (1)');
    }

    /*  Test adding a venue after open for voting. This should fail and trigger
        the votingClose modifer message
    */
    /// #sender: account-0
    function testAddVenue() public {
        (bool success, bytes memory result) = address(this).delegatecall(abi.encodeWithSignature("addVenue(string)", 'Cafe2'));
        if (success == false) {
            string memory reason = abi.decode(result.slice(4, result.length - 4), (string));
            Assert.equal(reason, 'Voting is not closed.', 'Failed with unexpected reason');
        } else {
            Assert.ok(false, 'Method Execution should fail');
        }
    }

    /// #sender: account-0
    function testAddFriend() public {
        (bool success, bytes memory result) = address(this).delegatecall(abi.encodeWithSignature("addFriend(address, string)", TestsAccounts.getAccount(6), 'Fred'));
        if (success == false) {
            string memory reason = abi.decode(result.slice(4, result.length - 4), (string));
            Assert.equal(reason, 'Voting is not closed.', 'Failed with unexpected reason');
        } else {
            Assert.ok(false, 'Method Execution should fail');
        }
    }

    /// Vote success 1
    /// #sender: account-3
    function vote1AfterOpen() public {
        Assert.ok(doVote(1), 'Should be false. Voting has not open yet.');
    }

    /// Not a friend, so returns false.
    /// #sender: account-2
    function testUnknownVoteFail() public {
        // Assert.equal(doVote(1), false, 'Should not false. Sender is not a friend.');
        (bool success, bytes memory result) = address(this).delegatecall(abi.encodeWithSignature("doVote(uint256)", 1));
        if (success == false) {
            string memory reason = abi.decode(result.slice(4, result.length - 4), (string));
            Assert.equal(reason, 'Can\'t vote. Not a friend.', 'Failed with unexpected reason');
        } else {
            Assert.ok(false, 'Method Execution should fail');
        }
    }

    /// Vote success 2
    /// #sender: account-4
    function vote2() public {
        Assert.ok(doVote(1), 'Vote should be true.');
    }

    /// Vote success 3. Quorum reached.
    /// #sender: account-5
    function vote3() public {
        Assert.ok(doVote(2), 'Vote hould be true.');
    }

    /// Votes After would fail.
    /// #sender: account-0
    function vote4() public {
        (bool success, bytes memory result) = address(this).delegatecall(abi.encodeWithSignature("doVote(uint256)", 1));
        if (success == false) {
            string memory reason = abi.decode(result.slice(4, result.length - 4), (string));
            Assert.equal(reason, 'Voting has not open yet.', 'Failed with unexpected reason');
        } else {
            Assert.ok(false, 'Method Execution should fail');
        }
    }

    function lunchVenueTest() public {
        Assert.equal(votedVenue, 'Courtyard Cafe', 'Selected venue should be Courtyard Cafe');
    }

    function testVoteStateComplete() public {
        Assert.equal(getVoteState(), 3, 'Vote should be complete (3)');
    }

    /// Tries to add and execute contract again
    function setLunchVenueAgain() public {
        endContractLife();
        Assert.equal(addVenue('Courtyard Cafe'), 3, 'Should be equal to 1');
        Assert.equal(addVenue('Uni Cafe'), 4, 'Should be equal to 2');
    }
}
