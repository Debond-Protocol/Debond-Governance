const chai = require("chai");
const chaiAsPromised = require('chai-as-promised');
const { Console } = require("console");
const readline = require('readline');

chai.use(chaiAsPromised);
const expect = chai.expect;

const DBIT = artifacts.require("DBIT");
const DGOV = artifacts.require("DGOV");
const VoteToken = artifacts.require("VoteToken");
const NewStakingDGOV = artifacts.require("NewStakingDGOV");
const GovSettings = artifacts.require("GovSettings");
const NewGovernance = artifacts.require("NewGovernance");
const VoteCounting = artifacts.require("VoteCounting");

contract("Governance", async (accounts) => {
    let dbit;
    let dgov;
    let stak;
    let vote;
    let settings;
    let gov;
    let amountToMint;
    let amountToStake;

    let balanceUser1BeforeStake;
    let balanceStakingContractBeforeStake;

    let operator = accounts[0];
    let debondTeam = accounts[1];
    let user1 = accounts[2];
    let user2 = accounts[3];
    let user3 = accounts[4];
    let user4 = accounts[5];
    let user5 = accounts[6];

    let ProposalStatus = {
        Active: '0',
        Canceled: '1',
        Pending: '2',
        Defeated: '3',
        Succeeded: '4',
        Executed: '5'
    }

    beforeEach(async () => {
        dbit = await DBIT.new();
        dgov = await DGOV.new();
        count = await VoteCounting.new();
        vote = await VoteToken.new("Debond Vote Token", "DVT", operator);
        stak = await NewStakingDGOV.new(dgov.address, vote.address);
        settings = await GovSettings.new(2, 3);
        gov = await NewGovernance.new(operator, operator);

        // set the stakingDGOV contract address in Vote Token
        await vote.setStakingDGOVContract(stak.address);

        // set the governance contract address in voteToken
        await vote.setGovernanceContract(gov.address);

        // set the governance contract address in DBIT
        await dbit.setGovernanceContract(gov.address);

        // set the bank contract address in DBIT
        await dbit.setBankContract(operator);

        // set the governance contract address in DGOV
        await dgov.setGovernanceContract(gov.address);

        // set the bank contract address in DGOV
        await dgov.setBankContract(operator);

        // initialize all contracts
        await gov.firstSetUp(
            gov.address,
            dgov.address,
            dbit.address,
            stak.address,
            vote.address,
            settings.address,
            operator,
            operator,
            {from: operator}
        );

        let amount = await web3.utils.toWei(web3.utils.toBN(100), 'ether');
        await dbit.mintCollateralisedSupply(debondTeam, amount, {from: operator});
        await dbit.transfer(gov.address, amount, {from: debondTeam});

        amountToMint = await web3.utils.toWei(web3.utils.toBN(200), 'ether');
        amountToStake = await web3.utils.toWei(web3.utils.toBN(50), 'ether');

        await dgov.mintCollateralisedSupply(debondTeam, amountToMint, {from: operator});
        await dgov.transfer(user1, amountToStake, {from: debondTeam});
        await dgov.transfer(user2, amountToStake, {from: debondTeam});
        await dgov.transfer(user3, amountToStake, {from: debondTeam});
        await dgov.transfer(operator, amountToStake, {from: debondTeam});
        await dgov.approve(stak.address, amountToStake, {from: user1});
        await dgov.approve(stak.address, amountToStake, {from: user2});
        await dgov.approve(stak.address, amountToStake, {from: user3});
        await dgov.approve(stak.address, amountToStake, {from: operator});
        await dgov.approve(user1, amountToStake, {from: user1});
        await dgov.approve(user2, amountToStake, {from: user2});
        await dgov.approve(user3, amountToStake, {from: user3});
        await dgov.approve(operator, amountToStake, {from: operator});

        await dgov.approve(user4, amountToStake, {from: user1});

        balanceUser1BeforeStake = await dgov.balanceOf(user1);
        balanceUser2BeforeStake = await dgov.balanceOf(user1);
        balanceUser3BeforeStake = await dgov.balanceOf(user1);
        balanceStakingContractBeforeStake = await dgov.balanceOf(stak.address);

        await gov.stakeDGOV(amountToStake, 10, {from: user1});
        await gov.stakeDGOV(amountToStake, 10, {from: user2});
        await gov.stakeDGOV(amountToStake, 10, {from: user3});
        await gov.stakeDGOV(amountToStake, 10, {from: operator});
    });

    it("Create a proposal", async () => {
        let _class = 0;
        let desc = "Propsal-1: Update the benchMark interest rate";
        let callData = await gov.contract.methods.updateBenchmarkInterestRate(
            '10',
            operator
        ).encodeABI();

        let res = await gov.createProposal(
            _class,
            [gov.address],
            [0],
            [callData],
            desc
        );

        // fetch data from the emitted event
        let event = res.logs[0].args;

        // fetch data from structure Proposal
        let nonce = res.logs[0].args.nonce;
        let proposal = await gov.getProposal(_class, nonce);

        let approvalMode = await gov.getApprovalMode(_class);

        expect(event.class.toString()).to.equal(_class.toString());
        expect(event.nonce.toString()).to.equal(nonce.toString());
        expect(event.targets[0]).to.equal(gov.address);
        expect(event.values[0].toString()).to.equal('0');
        expect(event.calldatas[0].toString()).to.equal(callData.toString())

        expect(event.startVoteTime.toString())
            .to.equal(proposal.startTime.toString());

        expect(event.endVoteTime.toString())
            .to.equal(proposal.endTime.toString());

        expect(event.proposer).to.equal(operator);

        expect(proposal.approvalMode.toString())
            .to.equal(approvalMode.toString());

        expect(event.description).to.equal(desc);
    });

    it("Stake DGOV tokens", async () => {
        let balanceUser1AfterStake = await dgov.balanceOf(user1);
        let balanceStakingContractAfterStake = await dgov.balanceOf(stak.address);

        expect(
            balanceUser1AfterStake.toString()
        ).to.equal(
            balanceUser1BeforeStake.sub(amountToStake).toString()
        );
            
        expect(
            Number(
                balanceStakingContractAfterStake.toString()
            )
        ).to.equal(
            Number(
                balanceStakingContractBeforeStake
                .add(
                    amountToStake
                ).toString()
            ) * 4  
        );
    });

    it("Ustake DGOV tokens", async () => {
        let balBefore = await dgov.balanceOf(user1);
        let balContractBefore = await dgov.balanceOf(stak.address);

        await wait(12000);

        await gov.unstakeDGOV(1, {from: user1});
        let estimate = await gov.estimateInterestEarned(amountToStake, 10);


        let balanceAfter = await dbit.balanceOf(user1);

        let balAfter = await dgov.balanceOf(user1);
        let balContractAfter = await dgov.balanceOf(stak.address);

        expect(balContractAfter.toString())
            .to.equal(
                balContractBefore.sub(amountToStake).toString()
            );

        expect(balAfter.toString())
            .to.equal(
                balBefore.add(amountToStake).toString()
            );

        expect(
            (Number(balanceAfter.toString()) / 100).toFixed(0)
        ).to.equal(
            (Number(estimate.toString()) / 100).toFixed(0)
        );
    });

    it('Cannot unstake DGOV before staking ends', async () => {
        expect(gov.unstakeDGOV(1, {from: user1}))
            .to.rejectedWith(
                Error,
                "VM Exception while processing transaction: revert Staking: still staking -- Reason given: Staking: still staking"
            );
    });

    it("Chenge the benchmark interest rate", async () => {
        // create a proposal
        let _class = 0;
        let desc = "Propsal-1: Update the benchMark interest rate";
        let callData = await gov.contract.methods.updateBenchmarkInterestRate(
            '10',
            operator
        ).encodeABI();

        let res = await gov.createProposal(
            _class,
            [gov.address],
            [0],
            [callData],
            desc,
            {from: operator}
        );

        let event = res.logs[0].args;

        await gov.test();
        await wait(3000);
        await gov.test();

        await gov.vote(event.class, event.nonce, user1, 0, amountToStake, 1, {from: user1});
        await gov.vote(event.class, event.nonce, user2, 1, amountToStake, 1, {from: user2});
        await gov.vote(event.class, event.nonce, user3, 0, amountToStake, 1, {from: user3});

        await gov.veto(event.class, event.nonce, true, {from: operator});
        
        await wait(3000);
        await gov.test();
        
        let status = await gov.getProposalStatus(event.class, event.nonce);
        let benchmarkBefore = await gov.getBenchmarkIR();
       
        // Execute the proposal
        await gov.executeProposal(
            event.class,
            event.nonce,
            {from: operator}
        );
       
        let status1 = await gov.getProposalStatus(event.class, event.nonce);

        let benchmarkAfter = await gov.getBenchmarkIR();

        expect(status.toString()).to.equal(ProposalStatus.Succeeded);
        expect(status1.toString()).to.equal(ProposalStatus.Executed);
        expect(
            benchmarkAfter.toString()
        )
        .to.equal(
            benchmarkBefore.add(web3.utils.toBN(5)).toString()
        );
    });

    it("change the budget in Part Per Million", async () => {
        let newDBITBudget = await web3.utils.toWei(web3.utils.toBN(5000000), 'ether');
        let newDGOVBudget = await web3.utils.toWei(web3.utils.toBN(7000000), 'ether');

        // create a proposal
        let _class = 0;
        let desc = "Propsal-1: Update the budget part per million";
        let callData = await gov.contract.methods.changeCommunityFundSize(
            newDBITBudget,
            newDGOVBudget,
            operator
        ).encodeABI();

        let res = await gov.createProposal(
            _class,
            [gov.address],
            [0],
            [callData],
            desc,
            {from: operator}
        );

        let event = res.logs[0].args;

        await gov.test();
        await wait(3000);
        await gov.test();

        await gov.vote(event.class, event.nonce, user1, 0, amountToStake, 1, {from: user1});
        await gov.vote(event.class, event.nonce, user2, 1, amountToStake, 1, {from: user2});
        await gov.vote(event.class, event.nonce, user3, 0, amountToStake, 1, {from: user3});

        await gov.veto(event.class, event.nonce, true, {from: operator});

        await wait(3000);
        await gov.test();

        let oldBudget = await web3.utils.toWei(web3.utils.toBN(100000), 'ether');
        let budget = await gov.getBudget();

        expect(budget[0].toString()).to.equal(oldBudget.toString());
        expect(budget[1].toString()).to.equal(oldBudget.toString());

        await gov.executeProposal(
            event.class,
            event.nonce,
            {from: operator}
        );

        budget = await gov.getBudget();

        expect(budget[0].toString()).to.equal(newDBITBudget.toString());
        expect(budget[1].toString()).to.equal(newDGOVBudget.toString());
    });

    it("check a proposal didn't pass", async () => {
        // create a proposal
        let _class = 0;
        let desc = "Propsal-1: Update the benchMark interest rate";
        let callData = await gov.contract.methods.updateBenchmarkInterestRate(
            '10',
            operator
        ).encodeABI();

        let res = await gov.createProposal(
            _class,
            [gov.address],
            [0],
            [callData],
            desc,
            {from: operator}
        );

        let event = res.logs[0].args;

        await gov.test();
        await wait(3000);
        await gov.test();

        await gov.vote(event.class, event.nonce, user1, 0, amountToStake, 1, {from: user1});
        await gov.vote(event.class, event.nonce, user2, 1, amountToStake, 1, {from: user2});
        await gov.vote(event.class, event.nonce, user3, 1, amountToStake, 1, {from: user3});

        await wait(3000);
        await gov.test();

        let status = await gov.getProposalStatus(event.class, event.nonce);
        
        expect(status.toString()).to.equal(ProposalStatus.Defeated);
    });

    it("check the delegate vote", async () => {
        // create a proposal
        let _class = 0;
        let desc = "Propsal-1: Update the benchMark interest rate";
        let callData = await gov.contract.methods.updateBenchmarkInterestRate(
            '10',
            operator
        ).encodeABI();

        let res = await gov.createProposal(
            _class,
            [gov.address],
            [0],
            [callData],
            desc,
            {from: operator}
        );

        let event = res.logs[0].args;

        await gov.test();
        await wait(3000);
        await gov.test();

        await gov.vote(event.class, event.nonce, user1, 0, amountToStake, 1, {from: user4});
        await gov.vote(event.class, event.nonce, user2, 1, amountToStake, 1, {from: user2});
        await gov.vote(event.class, event.nonce, user3, 0, amountToStake, 1, {from: user3});

        let v1 = await gov.hasVoted(event.class, event.nonce, user1);
        let v4 = await gov.hasVoted(event.class, event.nonce, user4);
        let v2 = await gov.hasVoted(event.class, event.nonce, user2);
        let v3 = await gov.hasVoted(event.class, event.nonce, user3);

        expect(v1).to.be.false;
        expect(v4).to.be.true;
        expect(v2).to.be.true;
        expect(v3).to.be.true;
    });

    it('check proposal of class 2 passes', async () => {
        let _class = 2;
        let desc = "Propsal-1: Update the benchMark interest rate";
        let callData = await gov.contract.methods.updateBenchmarkInterestRate(
            '10',
            operator
        ).encodeABI();

        let res = await gov.createProposal(
            _class,
            [gov.address],
            [0],
            [callData],
            desc,
            {from: operator}
        );

        let event = res.logs[0].args;

        await gov.test();
        await wait(3000);
        await gov.test();

        await gov.vote(event.class, event.nonce, user1, 0, amountToStake, 1, {from: user1});
        await gov.vote(event.class, event.nonce, user2, 1, amountToStake, 1, {from: user2});
        await gov.vote(event.class, event.nonce, user3, 0, amountToStake, 1, {from: user3});
        
        await wait(3000);
        await gov.test();
        
        let status = await gov.getProposalStatus(event.class, event.nonce);
        let benchmarkBefore = await gov.getBenchmarkIR();
       
        // Execute the proposal
        await gov.executeProposal(
            event.class,
            event.nonce,
            {from: operator}
        );
       
        let status1 = await gov.getProposalStatus(event.class, event.nonce);

        let benchmarkAfter = await gov.getBenchmarkIR();

        expect(status.toString()).to.equal(ProposalStatus.Succeeded);
        expect(status1.toString()).to.equal(ProposalStatus.Executed);
        expect(
            benchmarkAfter.toString()
        )
        .to.equal(
            benchmarkBefore.add(web3.utils.toBN(5)).toString()
        );
    });

    it('Check DBIT earned by voting', async () => {
        let _class = 2;
        let desc = "Propsal-1: Update the benchMark interest rate";
        let callData = await gov.contract.methods.updateBenchmarkInterestRate(
            '10',
            operator
        ).encodeABI();

        let res = await gov.createProposal(
            _class,
            [gov.address],
            [0],
            [callData],
            desc,
            {from: operator}
        );

        let event = res.logs[0].args;

        await gov.test();
        await wait(3000);
        await gov.test();

        await gov.vote(event.class, event.nonce, user1, 0, amountToStake, 1, {from: user1});
        await gov.vote(event.class, event.nonce, user2, 1, amountToStake, 1, {from: user2});
        await gov.vote(event.class, event.nonce, user3, 0, amountToStake, 1, {from: user3});
        
        await wait(3000);
        await gov.test();
 
        await gov.unlockVoteTokens(event.class, event.nonce, {from: user1});
    
        let balanceVoteAfter = await dbit.balanceOf(user1);
        balanceVoteAfter = Number(balanceVoteAfter.toString()) / 1e18;
        balanceVoteAfter = balanceVoteAfter.toFixed(15)

        let reward = amountToStake * 5 / (3 * amountToStake);
        reward = reward.toFixed(15);

        expect(balanceVoteAfter).to.equal(reward);
    })
})


// Functions
async function wait(milliseconds) {
    const date = Date.now();
    let currentDate = null;
    do {
      currentDate = Date.now();
    } while (currentDate - date < milliseconds);
}