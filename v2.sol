// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

contract LunchVenue {

    /*
        Weakness.2: Uses enum to create states for the contract. This will help fix 2, as the stages
        are much more clearer and modifiers on the state can be used to enforce which function can be
        executed.
        0   VoteClose       Used at beginning, where manager can add friends and venues
        1   VoteOpen        Used when voting is open, manager cannot add friends and venues
        2   VoteTimeOut     Used when voting has reach timeout
        3   VoteComplete    Used when contract has determined a reault
                     0           1         2              3
    */
    enum VoteState { VoteClose , VoteOpen, VoteTimeOut, VoteComplete }
    VoteState public voteState = VoteState.VoteClose; // Initalised as opened

    /*
        Weakness 5: To address the gas consumption.
        I implemented the structure so it would, comply to the
        32 bytes chunks that EVM uses. Variable Packing in forms of 32 bytes spaces.

        Also note that most of the variables are not Initalised. From what I
        read online, it says 'Every variable assignment in Solidity costs gas'.
        So by default I let the compiler defaults the values of the variable.

        (Not implemented) I maybe would change name type (string) to bytes32,
        as it is more reasonable and gas efficienct. But I didn't want to change
        the interfaces of the functions since they take in type string. Also,
        it was risky as name or venue can be > 32 bytes.
    */
    struct Friend {
        uint venue;
        string name;
        bool voted;
    }

    struct Venue {
        uint16 nVotes;
        string name;
    }

    uint16 public numVenues;
    uint16 public numFriends;
    uint16 public numVotes;
    uint16 private highestVotes;
    string public votedVenue;

    mapping (uint => Venue) public venues;
    mapping (address => Friend) public friends;
    address public manager;

    /*
        Weakness 3: Uses `block.number` as a source of time.
        Timeout is considered by 2 hours after the contract deployment.
        The @variable blockCountToExpire is calculated using avg block time mine
        from https://ycharts.com/indicators/ethereum_average_block_time
        (13.10 sec @ 17/06/21). We can determine that 2 hours (7200 sec) worth is
        7200/13.10 = 549.618 =~ 520 blocks mined. So after 520 blocks has mined
        (approx 2 hrs) the contract will timeout.
    */
    uint startBlock;
    uint expireBlockNum;

    function setTimeout(uint16 blockCountToExpire) private {
        startBlock = block.number;
        expireBlockNum = block.number + blockCountToExpire;
    }

    constructor () {
        manager = msg.sender;
        setTimeout(520);        // Initalised timeout
    }

    function addVenue(string memory name) public restricted votingClose returns (uint) {
        numVenues++;
        Venue memory v;
        v.name = name;
        v.nVotes = 0;
        venues[numVenues] = v;
        return numVenues;
    }

    function addFriend(address friendAddress, string memory name) public restricted votingClose returns (uint) {
        Friend memory f;
        f.name = name;
        f.voted = false;
        friends[friendAddress] = f;
        numFriends++;
        return numFriends;
    }

    function openForVoting() public restricted returns (bool) {
        voteState = VoteState.VoteOpen;
        return true;
    }

    function doVote(uint venue) public votingOpen returns (bool validVote) {
        /*
            Weakness 3: If timeout is reached then the vote state is set
            to Vote... Any remaining votes in the ballet will be
            used to calculate the venue. This current vote will be
            excluded since it has passed the contract lifespan.

            Note that this vote doesn't count.
        */
        // if(block.number > expireBlockNum) {
        //     voteState = VoteState.VoteTimeOut;
        //     finalResult();
        //     return false;
        // }

        validVote = false;
        /*
            Weakness 1: To solve the restriction of friends voting once.
            The Friend struct contains a bool voted that determines if they
            have voted or not. The preconditions here are designed to
            the ensure that the contract caller is indeed a friend and
            that that friend has not voted inorder to process.
        */
        // For some reason requires is very buggy. so I resorted to the code below.

        // require(bytes(friends[msg.sender].name).length == 0, "Can't vote. Not a friend.");
        // require(friends[msg.sender].voted, "Can't vote. Already voted.");
        if (bytes(friends[msg.sender].name).length == 0) {
            require(false, "Can't vote. Not a friend.");
        }
        if (friends[msg.sender].voted) {
            require(false, "Can't vote. Already voted.");
        }

        if(bytes(venues[venue].name).length != 0) {
            validVote = true;
            friends[msg.sender].voted = true;
            friends[msg.sender].venue = venue;
            numVotes++;
            venues[venue].nVotes++;
            if(venues[venue].nVotes > highestVotes) {
               highestVotes = venues[venue].nVotes;
            }
        }

        if(numVotes >= numFriends/2 + 1) {
            // voteState = VoteState.VoteClose;
            finalResult();
        }

        return validVote;
    }

    function getVenues() public view returns (uint[] memory, string[] memory) {
        string[] memory names = new string[](numVenues);
        uint[] memory ids = new uint[](numVenues);

         for(uint i=0; i<numVenues; i++) {
            names[i] = venues[i].name;
            ids[i] = i;
        }
        return (ids, names);
    }


    /*
        Can only be executed when voting is closed,
        so they there is no more incoming votes. This functions
        can also handle venues that have tied results.
    */
    function finalResult() private {
        for(uint i=1; i<=numVenues; i++) {
            if(venues[i].nVotes >= highestVotes) {
                votedVenue = venues[i].name;
                break;
            }
        }

        voteState = VoteState.VoteComplete;    // Meaning that voting has ended and cannot be reopened
    }

    /*
        Weakness 4: The contract can be disabled. Since the disabling of
        the contract is manual. It is a public function that can only be
        executed by the contract owner, using the selfdestruct. Any ETH
        that may exist is also sent to that owner's Ethereum addr.
    */
    function endContractLife() restricted public {
        selfdestruct(payable(manager));
    }

    /*
        Weakness 5: Again in 32 bytes packing. I made sure that the requires
        messages are <= 32 bytes.
    */
    modifier restricted() {
        require(msg.sender == manager, "Restricted to manager only.");
        _;
    }

    modifier votingOpen() {
        require(voteState == VoteState.VoteOpen, "Voting has not open yet.");
        _;
    }

    modifier votingClose() {
        require(voteState == VoteState.VoteClose, "Voting is not closed.");
        _;
    }

    /*
        For some reason accessing voteState in testing doesn't work. So I
        created a custom getter function for voteState.
    */
    function getVoteState() public view returns (uint) {
        return uint(voteState);
    }
}
