const chai = require("chai");
const chaiAsPromised = require('chai-as-promised');

chai.use(chaiAsPromised);
const expect = chai.expect;

const DBIT = artifacts.require("DBIT");
const DGOV = artifacts.require("DGOV");
const VoteToken = artifacts.require("VoteToken");
const NewStakingDGOV = artifacts.require("NewStakingDGOV");
const GovSettings = artifacts.require("GovSettings");
const NewGovernance = artifacts.require("NewGovernance");

contract("Governance", async (accounts) => {
    let dbit;
    let dgov;
    let stak;
    let vote;
    let settings;
    let gov;
    let proposal;

    let operator = accounts[0];
    let debondTeam = accounts[1];
    let user1 = accounts[2];
    let user2 = accounts[3];
    let user3 = accounts[4];
    let user4 = accounts[5];

    beforeEach(async () => {
        dbit = await DBIT.new();
        dgov = await DGOV.new();
        vote = await VoteToken.new("Debond Vote Token", "DVT", operator);
        stak = await NewStakingDGOV.new(dgov.address, vote.address);
        settings = await GovSettings.new(2, 3);
        gov = await NewGovernance.new(
            dgov.address,
            dbit.address,
            stak.address,
            vote.address,
            settings.address
        );

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
    });

    it("Create a proposal", async () => {
        let _class = 0;
        let desc = "Propsal-1: Update the benchMark interest rate";
        let callData = await gov.contract.methods.updateBenchmarkInterestRate(
            '10'
        ).encodeABI();

        await gov.initialize(gov.address);

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

        expect(event.proposalId.toString())
            .to.equal(proposal.id.toString());

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
        let amount = await web3.utils.toWei(web3.utils.toBN(100), 'ether');
        let amountToStake = await web3.utils.toWei(web3.utils.toBN(50), 'ether');

        await dgov.mintCollateralisedSupply(debondTeam, amount, {from: operator});
        await dgov.transfer(user1, amount, {from: debondTeam});
        await dgov.approve(stak.address, amountToStake, {from: user1});

        let balanceBefore = await dgov.balanceOf(user1);
        let balBefore = await dgov.balanceOf(stak.address);

        await gov.stakeDGOV(amountToStake, 5, {from: user1});

        let balanceAfter = await dgov.balanceOf(user1);
        let balAfter = await dgov.balanceOf(stak.address);

        expect(balanceAfter.toString())
            .to.equal(
                balanceBefore.sub(amountToStake).toString()
            );

        expect(balAfter.toString())
            .to.equal(
                balBefore.add(amountToStake).toString()
            );
    });

    it("Ustake DGOV tokens", async () => {
        let amount = await web3.utils.toWei(web3.utils.toBN(100), 'ether');
        let amountToStake = await web3.utils.toWei(web3.utils.toBN(50), 'ether');

        await dgov.mintCollateralisedSupply(debondTeam, amount, {from: operator});
        await dgov.transfer(user1, amount, {from: debondTeam});
        await dgov.approve(stak.address, amountToStake, {from: user1});

        await dbit.mintCollateralisedSupply(debondTeam, amount, {from: operator});
        await dbit.transfer(gov.address, amount, {from: debondTeam});

        await gov.stakeDGOV(amountToStake, 2, {from: user1});

        await wait(3000);

        let balanceBefore = await dbit.balanceOf(user1);
        let balBefore = await dgov.balanceOf(user1);
        let balContractBefore = await dgov.balanceOf(stak.address);

        await gov.unstakeDGOV(1, {from: user1});
        let estimate = await gov.estimateInterestEarned(amountToStake, 2);

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
        let amount = await web3.utils.toWei(web3.utils.toBN(100), 'ether');
        let amountToStake = await web3.utils.toWei(web3.utils.toBN(50), 'ether');

        await dgov.mintCollateralisedSupply(debondTeam, amount, {from: operator});
        await dgov.transfer(user1, amount, {from: debondTeam});
        await dgov.approve(stak.address, amountToStake, {from: user1});

        await dbit.mintCollateralisedSupply(debondTeam, amount, {from: operator});
        await dbit.transfer(gov.address, amount, {from: debondTeam});

        await gov.stakeDGOV(amountToStake, 2, {from: user1});

        expect(gov.unstakeDGOV(1, {from: user1}))
            .to.rejectedWith(
                Error,
                "VM Exception while processing transaction: revert Staking: still staking -- Reason given: Staking: still staking"
            );
    });

    it.only("let users vote for a proposal", async () => {
        let amountToMint = await web3.utils.toWei(web3.utils.toBN(200), 'ether');
        let amountToStake = await web3.utils.toWei(web3.utils.toBN(50), 'ether');

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

        await gov.stakeDGOV(amountToStake, 10, {from: user1});
        await gov.stakeDGOV(amountToStake, 10, {from: user2});
        await gov.stakeDGOV(amountToStake, 10, {from: user3});
        await gov.stakeDGOV(amountToStake, 10, {from: operator});

        // create a proposal
        let _class = 0;
        let desc = "Propsal-1: Update the benchMark interest rate";
        let callData = await gov.contract.methods.updateBenchmarkInterestRate(
            '10'
        ).encodeABI();

        await gov.initialize(gov.address);

        let res = await gov.createProposal(
            _class,
            [gov.address],
            [0],
            [callData],
            desc,
            {from: operator}
        );

        let event = res.logs[0].args;
        let nonce = res.logs[0].args.nonce;
        let proposal = await gov.getProposal(_class, nonce);

        console.log('t1', proposal.startTime.toString());
        console.log('t2', proposal.endTime.toString());

        //await wait(3000);
        //let status = await gov.getProposalStatus(_class, event.nonce, event.proposalId);

        await wait(3000);
        await gov.test();
        await gov.vote(event.proposalId, user1, 0, amountToStake, 1, {from: user1});
        await gov.vote(event.proposalId, user2, 1, amountToStake, 1, {from: user2});
        await gov.vote(event.proposalId, user3, 0, amountToStake, 1, {from: user3});
        await wait(4000);
        await gov.test();
        let status = await gov.getProposalStatus(_class, event.nonce, event.proposalId);

        console.log(status.toString());
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