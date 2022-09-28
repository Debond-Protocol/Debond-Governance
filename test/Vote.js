const chai = require("chai");
const chaiAsPromised = require('chai-as-promised');
const { Console } = require("console");
const readline = require('readline');
const { isTypedArray } = require("util/types");

chai.use(chaiAsPromised);
const expect = chai.expect;

const DGOV = artifacts.require("DGOVTest");
const VoteToken = artifacts.require("VoteToken");
const StakingDGOV = artifacts.require("StakingDGOV");
const Governance = artifacts.require("Governance");
const Executable = artifacts.require("Executable");
const GovStorage = artifacts.require("GovStorage");
const AdvanceBlockTimeStamp = artifacts.require("AdvanceBlockTimeStamp");

contract("Vote: Governance", async (accounts) => {
    let gov;
    let dgov;
    let exec;
    let stakingContract;
    let vote;
    let storage;
    let nextTime;

    let proposerDGOV;

    let operator = accounts[0];
    let debondTeam = accounts[1];
    let user1 = accounts[2];
    let user2 = accounts[3];
    let user3 = accounts[4];
    let user4 = accounts[5];
    let user5 = accounts[6];
    let user6 = accounts[7];
    let user7 = accounts[8];

    let amount1;
    let amount2;
    let amount3;
    let amountToMint;

    let ProposalStatus = {
        Active: '0',
        Canceled: '1',
        Pending: '2',
        Defeated: '3',
        Succeeded: '4',
        Executed: '5'
    }

    beforeEach(async () => {
        storage = await GovStorage.deployed();
        gov = await Governance.deployed();
        exec = await Executable.deployed();
        vote = await VoteToken.deployed();
        dgov = await DGOV.deployed();
        stakingContract = await StakingDGOV.deployed();
        nextTime = await AdvanceBlockTimeStamp.new();

        proposerDGOV = await web3.utils.toWei(web3.utils.toBN(25000), 'ether');

        await dgov.mint(operator, proposerDGOV);
        await dgov.approve(stakingContract.address, proposerDGOV, { from: operator });
        await stakingContract.stakeDgovToken(proposerDGOV, 0, { from: operator });
    });
    
    it("check users can vote", async () => {
        let toStake1 = await web3.utils.toWei(web3.utils.toBN(50), 'ether');
        let toStake2 = await web3.utils.toWei(web3.utils.toBN(85), 'ether');
        let toStake3 = await web3.utils.toWei(web3.utils.toBN(30), 'ether');
        let toStake4 = await web3.utils.toWei(web3.utils.toBN(20), 'ether');

        await dgov.mint(user1, toStake1);
        await dgov.mint(user2, toStake2);
        await dgov.mint(user3, toStake3);
        await dgov.mint(user4, toStake4);

        await dgov.approve(stakingContract.address, toStake1, { from: user1 });
        await dgov.approve(stakingContract.address, toStake2, { from: user2 });
        await dgov.approve(stakingContract.address, toStake3, { from: user3 });
        await dgov.approve(stakingContract.address, toStake4, { from: user4});

        await stakingContract.stakeDgovToken(toStake1, 0, { from: user1 });
        await stakingContract.stakeDgovToken(toStake2, 0, { from: user2 });
        await stakingContract.stakeDgovToken(toStake3, 0, { from: user3 });
        await stakingContract.stakeDgovToken(toStake4, 0, { from: user4 });

        let _class = 0;
        let title = "Propsal-1: Update the benchMark interest rate";
        let callData = await exec.contract.methods.updateBenchmarkInterestRate(
            _class,
            '100000000000000000'
        ).encodeABI();
        
        let res = await gov.createProposal(
            _class,
            [exec.address],
            [0],
            [callData],
            title,
            web3.utils.soliditySha3(title),
            { from: operator }
        );

        let event = res.logs[0].args;

        let amountVote1 = await storage.getAvailableVoteTokens(user1, 1);
        let amountVote2 = await storage.getAvailableVoteTokens(user2, 1);
        let amountVote3 = await storage.getAvailableVoteTokens(user3, 1);
        let amountVote4 = await storage.getAvailableVoteTokens(user4, 1);

        await gov.vote(event.class, event.nonce, user1, 0, amountVote1, 1, { from: user1 });
        await gov.vote(event.class, event.nonce, user2, 1, amountVote2, 1, { from: user2 });
        await gov.vote(event.class, event.nonce, user3, 0, amountVote3, 1, { from: user3 });
        await gov.vote(event.class, event.nonce, user4, 0, amountVote4, 1, { from: user4 });

        let hasVoted1 = await storage.hasVoted(event.class, event.nonce, user1);
        let hasVoted2 = await storage.hasVoted(event.class, event.nonce, user2);
        let hasVoted3 = await storage.hasVoted(event.class, event.nonce, user3);
        let hasVoted4 = await storage.hasVoted(event.class, event.nonce, user4);
        let hasVoted5 = await storage.hasVoted(event.class, event.nonce, user5);

        expect(hasVoted1).to.be.true;
        expect(hasVoted2).to.be.true;
        expect(hasVoted3).to.be.true;
        expect(hasVoted4).to.be.true;
        expect(hasVoted5).to.be.false;
    });

    it("check users cannot vote more than once for a proposal", async () => {
        amount1 = await web3.utils.toWei(web3.utils.toBN(30), 'ether');
        amount2 = await web3.utils.toWei(web3.utils.toBN(20), 'ether');
        amount3 = await web3.utils.toWei(web3.utils.toBN(100), 'ether');
        amountToMint = await web3.utils.toWei(web3.utils.toBN(150), 'ether');

        await dgov.mint(user7, amountToMint);
        await dgov.approve(stakingContract.address, amountToMint, { from: user7});

        // stake DGOV
        await stakingContract.stakeDgovToken(amount1, 0, { from: user7 });
        await stakingContract.stakeDgovToken(amount2, 1, { from: user7 });

        // get the amount of vote tokens for the two staking objects
        let amountVote1 = await storage.getAvailableVoteTokens(user7, 1);
        let amountVote2 = await storage.getAvailableVoteTokens(user7, 2);

        // create a proposal
        let _class = 0;
        let title = "Propsal-1: Update the benchMark interest rate";
        let callData = await exec.contract.methods.updateBenchmarkInterestRate(
            _class,
            '100000000000000000'
        ).encodeABI();
        
        let res = await gov.createProposal(
            _class,
            [exec.address],
            [0],
            [callData],
            title,
            web3.utils.soliditySha3(title),
            { from: operator }
        );

        let event = res.logs[0].args;

        // try to vote two times
        await gov.vote(event.class, event.nonce, user7, 0, amountVote1, 1, { from: user7 });

        expect(gov.vote(event.class, event.nonce, user7, 0, amountVote2, 1, { from: user7 }))
        .to.rejectedWith(
            Error,
            "VM Exception while processing transaction: revert VoteCounting: already voted -- Reason given: VoteCounting: already voted"
        );
    });

    it("check users cannot vote for a canceled proposal", async () => {
        amountToMint = await web3.utils.toWei(web3.utils.toBN(150), 'ether');

        await dgov.mint(user7, amountToMint);
        await dgov.approve(stakingContract.address, amountToMint, { from: user7});

        let amountVote = await storage.getAvailableVoteTokens(user7, 2);

        let _class = 0;
        let title = "Propsal-1: Update the benchMark interest rate";
        let callData = await exec.contract.methods.updateBenchmarkInterestRate(
            _class,
            '100000000000000000'
        ).encodeABI();
        
        let res = await gov.createProposal(
            _class,
            [exec.address],
            [0],
            [callData],
            title,
            web3.utils.soliditySha3(title),
            { from: operator }
        );

        let event = res.logs[0].args;
        
        await gov.cancelProposal(event.class, event.nonce);

        expect(gov.vote(event.class, event.nonce, user7, 0, amountVote, 2, { from: user7 }))
        .to.rejectedWith(
            Error,
            "VM Exception while processing transaction: revert Gov: vote not active -- Reason given: Gov: vote not active"
        );
    });

    it("check a user can vote for multiple proposals", async () => {
        amount1 = await web3.utils.toWei(web3.utils.toBN(30), 'ether');
        amount2 = await web3.utils.toWei(web3.utils.toBN(20), 'ether');
        amount3 = await web3.utils.toWei(web3.utils.toBN(100), 'ether');
        amountToMint = await web3.utils.toWei(web3.utils.toBN(150), 'ether');

        await dgov.mint(user7, amountToMint);
        await dgov.approve(stakingContract.address, amountToMint, { from: user7});

        // staking
        await stakingContract.stakeDgovToken(amount1, 0, { from: user7 });
        await stakingContract.stakeDgovToken(amount2, 1, { from: user7 });
        await stakingContract.stakeDgovToken(amount3, 2, { from: user7 });

        let amountVote1 = await storage.getAvailableVoteTokens(user7, 1);
        let amountVote2 = await storage.getAvailableVoteTokens(user7, 2);
        let amountVote3 = await storage.getAvailableVoteTokens(user7, 3);

        // first proposal
        let _class1 = 0;
        let title1 = "Propsal-1: Update the benchMark interest rate";
        let callData1 = await exec.contract.methods.updateBenchmarkInterestRate(
            _class1,
            '100000000000000000'
        ).encodeABI();

        let res1 = await gov.createProposal(
            _class1,
            [exec.address],
            [0],
            [callData1],
            title1,
            web3.utils.soliditySha3(title1),
            { from: operator }
        );

        let e1 = res1.logs[0].args;

        // second proposal
        let _class2 = 1;
        let title2 = "Propsal-1: Update the bank contract";
        let callData2 = await exec.contract.methods.updateBankAddress(
            _class2,
            user6
        ).encodeABI();
        
        let res2 = await gov.createProposal(
            _class2,
            [exec.address],
            [0],
            [callData2],
            title2,
            web3.utils.soliditySha3(title2),
            { from: operator }
        );

        let e2 = res2.logs[0].args;

        // third proposal
        let toAdd = await web3.utils.toWei(web3.utils.toBN(4000000), 'ether');
        let maxSupplyBefore = await dgov.getMaxSupply();
        let newMax = maxSupplyBefore.add(toAdd);
        let _class3 = 0;
        let title3 = "Propsal-1: Update the DGOV max";
        let callData3 = await exec.contract.methods.updateDGOVMaxSupply(
            _class3,
            newMax
        ).encodeABI();
        
        let res3 = await gov.createProposal(
            _class3,
            [exec.address],
            [0],
            [callData3],
            title3,
            web3.utils.soliditySha3(title3),
            { from: operator }
        );
        
        let e3 = res3.logs[0].args;

        await gov.vote(e1.class, e1.nonce, user7, 0, amountVote1, 3, { from: user7 });
        await gov.vote(e2.class, e2.nonce, user7, 0, amountVote2, 4, { from: user7 });
        await gov.vote(e3.class, e3.nonce, user7, 0, amountVote3, 5, { from: user7 });
        
        let hasVoted1 = await storage.hasVoted(e1.class, e1.nonce, user7);
        let hasVoted2 = await storage.hasVoted(e2.class, e2.nonce, user7);
        let hasVoted3 = await storage.hasVoted(e2.class, e2.nonce, user7);

        let hasVoted4 = await storage.hasVoted(e1.class, e1.nonce, user1);
        let hasVoted5 = await storage.hasVoted(e2.class, e2.nonce, user1);
        let hasVoted6 = await storage.hasVoted(e2.class, e2.nonce, user1);

        expect(hasVoted1).to.be.true;
        expect(hasVoted2).to.be.true;
        expect(hasVoted3).to.be.true;
        expect(hasVoted4).to.be.false;
        expect(hasVoted5).to.be.false;
        expect(hasVoted6).to.be.false;
    });

    it("check the delegate vote", async () => {
        let toStake1 = await web3.utils.toWei(web3.utils.toBN(50), 'ether');
        let toStake2 = await web3.utils.toWei(web3.utils.toBN(85), 'ether');
        let toStake3 = await web3.utils.toWei(web3.utils.toBN(30), 'ether');
        let toStake4 = await web3.utils.toWei(web3.utils.toBN(20), 'ether');

        await dgov.mint(user1, toStake1);
        await dgov.mint(user2, toStake2);
        await dgov.mint(user3, toStake3);
        await dgov.mint(user4, toStake4);

        await dgov.approve(stakingContract.address, toStake1, { from: user1 });
        await dgov.approve(stakingContract.address, toStake2, { from: user2 });
        await dgov.approve(stakingContract.address, toStake3, { from: user3 });
        await dgov.approve(stakingContract.address, toStake4, { from: user4});

        await stakingContract.stakeDgovToken(toStake1, 0, { from: user1 });
        await stakingContract.stakeDgovToken(toStake2, 0, { from: user2 });
        await stakingContract.stakeDgovToken(toStake3, 0, { from: user3 });
        await stakingContract.stakeDgovToken(toStake4, 0, { from: user4 });

        let amountVote1 = await storage.getAvailableVoteTokens(user1, 2);
        let amountVote2 = await storage.getAvailableVoteTokens(user2, 2);
        let amountVote3 = await storage.getAvailableVoteTokens(user3, 2);
        let amountVote4 = await storage.getAvailableVoteTokens(user4, 2);

        await vote.approve(user6, amountVote1, { from: user1 });

        let _class = 0;
        let title = "Propsal-1: Update the benchMark interest rate";
        let callData = await exec.contract.methods.updateBenchmarkInterestRate(
            _class,
            '10'
        ).encodeABI();
        
        let res = await gov.createProposal(
            _class,
            [exec.address],
            [0],
            [callData],
            title,
            web3.utils.soliditySha3(title),
            { from: operator }
        );

        let event = res.logs[0].args;

        await gov.vote(event.class, event.nonce, user1, 0, amountVote1, 2, { from: user6 });
        await gov.vote(event.class, event.nonce, user2, 0, amountVote2, 2, { from: user2 });
        await gov.vote(event.class, event.nonce, user3, 0, amountVote3, 2, { from: user3 });
        await gov.vote(event.class, event.nonce, user4, 1, amountVote4, 2, { from: user4 });

        let v1 = await storage.hasVoted(event.class, event.nonce, user1);
        let v6 = await storage.hasVoted(event.class, event.nonce, user6);
        let v4 = await storage.hasVoted(event.class, event.nonce, user4);
        let v2 = await storage.hasVoted(event.class, event.nonce, user2);
        let v3 = await storage.hasVoted(event.class, event.nonce, user3);

        expect(v1).to.be.false;
        expect(v6).to.be.true;
        expect(v4).to.be.true;
        expect(v2).to.be.true;
        expect(v3).to.be.true;
    });
})


// Functions
async function wait(milliseconds) {
    const date = Date.now();
    let currentDate = null;
    do {
        currentDate = Date.now();
    } while (currentDate - date < milliseconds);
}