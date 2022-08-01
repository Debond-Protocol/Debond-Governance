const chai = require("chai");
const chaiAsPromised = require('chai-as-promised');
const { Console } = require("console");
const readline = require('readline');

chai.use(chaiAsPromised);
const expect = chai.expect;

const DBIT = artifacts.require("DBITToken");
const DGOV = artifacts.require("DGOVToken");
const VoteToken = artifacts.require("VoteToken");
const StakingDGOV = artifacts.require("StakingDGOV");
const GovSettings = artifacts.require("GovSettings");
const Governance = artifacts.require("Governance");
const VoteCounting = artifacts.require("VoteCounting");
const Executable = artifacts.require("Executable");
const GovStorage = artifacts.require("GovStorage");
const ProposalLogic = artifacts.require("ProposalLogic");

contract("Governance", async (accounts) => {
    let dbit;
    let dgov;
    let stak;
    let vote;
    let settings;
    let gov;
    let amountToMint;
    let amountToStake;
    let exec;
    let storage;
    let count;
    let logic;

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
        count = await VoteCounting.new();
        vote = await VoteToken.new("Debond Vote Token", "DVT", operator);
        storage = await GovStorage.new(debondTeam, operator);
        settings = await GovSettings.new(17, 17, storage.address);
        gov = await Governance.new(storage.address, count.address);
        dbit = await DBIT.new(gov.address, operator, operator, operator);
        dgov = await DGOV.new(gov.address, operator, operator, operator);
        exec = await Executable.new(storage.address, count.address);
        logic = await ProposalLogic.new(operator, storage.address, vote.address, count.address);
        stak = await StakingDGOV.new(dgov.address, vote.address, gov.address, logic.address);

        // initialize all contracts
        await storage.setUpGoup1(
            gov.address,
            dgov.address,
            dbit.address,
            stak.address,
            vote.address,
            count.address,
            {from: operator}
        );

        await storage.setUpGoup2(
            settings.address,
            logic.address,
            exec.address,
            operator,
            operator,
            operator,
            operator,
            {from: operator}
        );

        // set the stakingDGOV contract address into Vote Token
        await vote.setStakingDGOVContract(stak.address);

        // set the governance contract address in voteToken
        await vote.setGovernanceContract(gov.address);

        // set the proposal logic contract address in voteToken
        await vote.setproposalLogicContract(logic.address);

        // set GovStorage contract address in voteCounting
        await count.setGovStorageContract(storage.address);

        // set the proposal logic address into voteCounting
        await count.setProposalLogicContract(logic.address);

        // set the staking contract address into proposalLogic
        await logic.setStakingContract(stak.address);

        let amount = await web3.utils.toWei(web3.utils.toBN(100), 'ether');
        await dbit.mintCollateralisedSupply(debondTeam, amount, { from: operator });
        await dbit.transfer(gov.address, amount, { from: debondTeam });

        amountToMint = await web3.utils.toWei(web3.utils.toBN(200), 'ether');
        amountToStake = await web3.utils.toWei(web3.utils.toBN(50), 'ether');

        await dgov.mintCollateralisedSupply(debondTeam, amountToMint, { from: operator });
        await dgov.transfer(user1, amountToStake, { from: debondTeam });
        await dgov.transfer(user2, amountToStake, { from: debondTeam });
        await dgov.transfer(user3, amountToStake, { from: debondTeam });
        await dgov.transfer(operator, amountToStake, { from: debondTeam });
        await dgov.approve(stak.address, amountToStake, { from: user1 });
        await dgov.approve(stak.address, amountToStake, { from: user2 });
        await dgov.approve(stak.address, amountToStake, { from: user3 });
        await dgov.approve(stak.address, amountToStake, { from: operator });
        await dgov.approve(user1, amountToStake, { from: user1 });
        await dgov.approve(user2, amountToStake, { from: user2 });
        await dgov.approve(user3, amountToStake, { from: user3 });
        await dgov.approve(operator, amountToStake, { from: operator });

        await dgov.approve(user4, amountToStake, { from: user1 });

        balanceUser1BeforeStake = await dgov.balanceOf(user1);
        balanceUser2BeforeStake = await dgov.balanceOf(user1);
        balanceUser3BeforeStake = await dgov.balanceOf(user1);
        balanceStakingContractBeforeStake = await dgov.balanceOf(stak.address);

        await gov.stakeDGOV(amountToStake, 10, { from: user1 });
        await gov.stakeDGOV(amountToStake, 10, { from: user2 });
        await gov.stakeDGOV(amountToStake, 10, { from: user3 });
        await gov.stakeDGOV(amountToStake, 10, { from: operator });
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

    it("Unstake DGOV tokens", async () => {
        let balBefore = await dgov.balanceOf(user1);
        let balContractBefore = await dgov.balanceOf(stak.address);

        await wait(12000);

        await gov.unstakeDGOV(1, { from: user1 });
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
        amountToStake = await web3.utils.toWei(web3.utils.toBN(50), 'ether');

        await dgov.mintCollateralisedSupply(debondTeam, amountToStake, { from: operator });
        await dgov.transfer(user5, amountToStake, { from: debondTeam });
        await dgov.approve(stak.address, amountToStake, { from: user5 });
        await dgov.approve(user5, amountToStake, { from: user5 });

        await gov.stakeDGOV(amountToStake, 10, { from: user5 });

        expect(gov.unstakeDGOV(1, { from: user5 }))
            .to.rejectedWith(
                Error,
                "VM Exception while processing transaction: revert Staking: still staking -- Reason given: Staking: still staking"
            );
    });

    it("Create a proposal", async () => {
        let _class = 0;
        let desc = "Propsal-1: Update the benchMark interest rate";
        let callData = await exec.contract.methods.updateBenchmarkInterestRate(
            '10',
            operator
        ).encodeABI();
        
        let res = await gov.createProposal(
            _class,
            [exec.address],
            [0],
            [callData],
            desc
        );

        // fetch data from the emitted event
        let event = res.logs[0].args;

        // fetch data from structure Proposal
        let nonce = res.logs[0].args.nonce;
        let proposal = await storage.getProposalStruct(_class, nonce);

        let approvalMode = await gov.getApprovalMode(_class);
        
        expect(event.class.toString()).to.equal(_class.toString());
        expect(event.nonce.toString()).to.equal(nonce.toString());
        expect(event.targets[0]).to.equal(exec.address);
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

    it("Cancel a proposal", async () => {
        let _class = 0;
        let desc = "Propsal-1: Update the benchMark interest rate";
        let callData = await exec.contract.methods.updateBenchmarkInterestRate(
            '10',
            operator
        ).encodeABI();
      
        let res = await gov.createProposal(
            _class,
            [exec.address],
            [0],
            [callData],
            desc,
            { from: operator }
        );

        let event = res.logs[0].args;
        
        await gov.cancelProposal(event.class, event.nonce, { from: operator });
        let status = await storage.getProposalStatus(event.class, event.nonce);

        expect(status.toString()).to.equal(ProposalStatus.Canceled);

    });

    it("Change the benchmark interest rate", async () => {
        // create a proposal
        let _class = 0;
        let desc = "Propsal-1: Update the benchMark interest rate";
        let callData = await exec.contract.methods.updateBenchmarkInterestRate(
            '10'
        ).encodeABI();

        let res = await gov.createProposal(
            _class,
            [exec.address],
            [0],
            [callData],
            desc,
            { from: operator }
        );

        let event = res.logs[0].args;

        await wait(18000);

        await gov.vote(event.class, event.nonce, user1, 0, amountToStake, 1, { from: user1 });
        await gov.vote(event.class, event.nonce, user2, 1, amountToStake, 1, { from: user2 });
        await gov.vote(event.class, event.nonce, user3, 0, amountToStake, 1, { from: user3 });
        
        await gov.veto(event.class, event.nonce, true, { from: operator });

        await wait(18000);

        let status = await storage.getProposalStatus(event.class, event.nonce);
        let benchmarkBefore = await storage.getBenchmarkIR();

        // Execute the proposal
        await gov.executeProposal(
            event.class,
            event.nonce,
            { from: operator }
        );

        let benchmarkAfter = await storage.getBenchmarkIR();        
        let status1 = await storage.getProposalStatus(event.class, event.nonce);

        expect(status.toString()).to.equal(ProposalStatus.Active);
        expect(status1.toString()).to.equal(ProposalStatus.Executed);
        expect(
            benchmarkAfter.toString()
        ).to.equal(
            benchmarkBefore.add(web3.utils.toBN(5)).toString()
        );
    });

    it("change the budget in Part Per Million", async () => {
        let newDBITBudget = await web3.utils.toWei(web3.utils.toBN(5000000), 'ether');
        let newDGOVBudget = await web3.utils.toWei(web3.utils.toBN(7000000), 'ether');

        // create a proposal
        let _class = 0;
        let desc = "Propsal-1: Update the budget part per million";
        let callData = await exec.contract.methods.changeCommunityFundSize(
            _class,
            newDBITBudget,
            newDGOVBudget
        ).encodeABI();

        let res = await gov.createProposal(
            _class,
            [exec.address],
            [0],
            [callData],
            desc,
            { from: operator }
        );

        let event = res.logs[0].args;

        await wait(18000);

        await gov.vote(event.class, event.nonce, user1, 0, amountToStake, 1, { from: user1 });
        await gov.vote(event.class, event.nonce, user2, 1, amountToStake, 1, { from: user2 });
        await gov.vote(event.class, event.nonce, user3, 0, amountToStake, 1, { from: user3 });

        await gov.veto(event.class, event.nonce, true, { from: operator });

        await wait(18000);

        let oldBudget = await web3.utils.toWei(web3.utils.toBN(100000), 'ether');
        let budget = await storage.getBudget();

        expect(budget[0].toString()).to.equal(oldBudget.toString());
        expect(budget[1].toString()).to.equal(oldBudget.toString());

        await gov.executeProposal(
            event.class,
            event.nonce,
            { from: operator }
        );

        budget = await storage.getBudget();

        expect(budget[0].toString()).to.equal(newDBITBudget.toString());
        expect(budget[1].toString()).to.equal(newDGOVBudget.toString());
    });

    it("mint allocated token", async () => {
        let amountDBIT = await web3.utils.toWei(web3.utils.toBN(2), 'ether');
        let amountDGOV = await web3.utils.toWei(web3.utils.toBN(1), 'ether');

        // create a proposal
        let _class = 0;
        let desc = "Propsal-1: Mint the team allocation token";
        let callData = await exec.contract.methods.mintAllocatedToken(
            debondTeam,
            amountDBIT,
            amountDGOV
        ).encodeABI();

        let res = await gov.createProposal(
            _class,
            [exec.address],
            [0],
            [callData],
            desc,
            {from: operator}
        );

        let event = res.logs[0].args;

        await wait(18000);

        await gov.vote(event.class, event.nonce, user1, 0, amountToStake, 1, {from: user1});
        await gov.vote(event.class, event.nonce, user2, 1, amountToStake, 1, {from: user2});
        await gov.vote(event.class, event.nonce, user3, 0, amountToStake, 1, {from: user3});

        await gov.veto(event.class, event.nonce, true, {from: operator});

        await wait(18000);

        let allocMintedBefore = await storage.getAllocatedTokenMinted(debondTeam);
        let totaAllocDistBefore = await storage.getTotalAllocationDistributed();

        await gov.executeProposal(
            event.class,
            event.nonce,
            {from: operator}
        );

        let allocMintedAfter = await storage.getAllocatedTokenMinted(debondTeam);
        let totaAllocDistAfter = await storage.getTotalAllocationDistributed();

        expect(allocMintedAfter[0].toString()).to.equal(allocMintedBefore[0].add(amountDBIT).toString());
        expect(allocMintedAfter[1].toString()).to.equal(allocMintedBefore[1].add(amountDGOV).toString());
        expect(totaAllocDistAfter[0].toString()).to.equal(totaAllocDistBefore[0].add(amountDBIT).toString());
        expect(totaAllocDistAfter[1].toString()).to.equal(totaAllocDistBefore[1].add(amountDGOV).toString());
    });

    it("change team allocation", async () =>  {
        let toStake = await web3.utils.toWei(web3.utils.toBN(25), 'ether');
        let newDBITAmount = await web3.utils.toWei(web3.utils.toBN(60000), 'ether');
        let newDGOVAmount = await web3.utils.toWei(web3.utils.toBN(90000), 'ether');

        let _class = 0;
        let desc = "Propsal-1: Change the team allocation token amount";
        callData = await exec.contract.methods.changeTeamAllocation(
            debondTeam,
            newDBITAmount,
            newDGOVAmount
        ).encodeABI();      

        let res = await gov.createProposal(
            _class,
            [exec.address],
            [0],
            [callData],
            desc,
            {from: operator}
        );

        let event = res.logs[0].args;

        await wait(18000);

        await gov.vote(event.class, event.nonce, user1, 0, toStake, 1, {from: user1});
        await gov.vote(event.class, event.nonce, user2, 1, toStake, 1, {from: user2});
        await gov.vote(event.class, event.nonce, user3, 0, toStake, 1, {from: user3});

        await gov.veto(event.class, event.nonce, true, {from: operator});

        await wait(18000);

        await gov.executeProposal(
            event.class,
            event.nonce,
            {from: operator}
        );
    });






    it("claim fund for proposal", async () => {
        let amountDBIT = await web3.utils.toWei(web3.utils.toBN(2), 'ether');
        let amountDGOV = await web3.utils.toWei(web3.utils.toBN(1), 'ether');

        // create a proposal
        let _class = 0;
        let desc = "Propsal-1: Claim Funds for a proposal";
        let callData = await exec.contract.methods.claimFundForProposal(
            _class,
            debondTeam,
            amountDBIT,
            amountDGOV
        ).encodeABI();

        let res = await gov.createProposal(
            _class,
            [exec.address],
            [0],
            [callData],
            desc,
            {from: operator}
        );

        let event = res.logs[0].args;

        await wait(18000);

        await gov.vote(event.class, event.nonce, user1, 0, amountToStake, 1, {from: user1});
        await gov.vote(event.class, event.nonce, user2, 1, amountToStake, 1, {from: user2});
        await gov.vote(event.class, event.nonce, user3, 0, amountToStake, 1, {from: user3});

        await gov.veto(event.class, event.nonce, true, {from: operator});

        await wait(18000);

        let allocMintedBefore = await storage.getAllocatedTokenMinted(debondTeam);
        let totaAllocDistBefore = await storage.getTotalAllocationDistributed();

        await gov.executeProposal(
            event.class,
            event.nonce,
            {from: operator}
        );

        let allocMintedAfter = await storage.getAllocatedTokenMinted(debondTeam);
        let totaAllocDistAfter = await storage.getTotalAllocationDistributed();

        expect(allocMintedAfter[0].toString()).to.equal(allocMintedBefore[0].add(amountDBIT).toString());
        expect(allocMintedAfter[1].toString()).to.equal(allocMintedBefore[1].add(amountDGOV).toString());
        expect(totaAllocDistAfter[0].toString()).to.equal(totaAllocDistBefore[0].add(amountDBIT).toString());
        expect(totaAllocDistAfter[1].toString()).to.equal(totaAllocDistBefore[1].add(amountDGOV).toString());
    });

    it("check a proposal didn't pass", async () => {
        // create a proposal
        let _class = 2;
        let desc = "Propsal-1: Update the benchMark interest rate";
        let callData = await exec.contract.methods.updateBenchmarkInterestRate(
            '10'
        ).encodeABI();

        let res = await gov.createProposal(
            _class,
            [exec.address],
            [0],
            [callData],
            desc,
            { from: operator }
        );

        let event = res.logs[0].args;

        await wait(18000);

        await gov.vote(event.class, event.nonce, user1, 0, amountToStake, 1, { from: user1 });
        await gov.vote(event.class, event.nonce, user2, 1, amountToStake, 1, { from: user2 });
        await gov.vote(event.class, event.nonce, user3, 1, amountToStake, 1, { from: user3 });

        await wait(18000);

        expect(
            gov.executeProposal(
                event.class,
                event.nonce,
                {from: operator}
            )
        ).to.rejectedWith(
            Error,
            "VM Exception while processing transaction: revert Gov: proposal not successful -- Reason given: Gov: proposal not successful"
        );
    });

    it("check the delegate vote", async () => {
        // create a proposal
        let _class = 0;
        let desc = "Propsal-1: Update the benchMark interest rate";
        let callData = await exec.contract.methods.updateBenchmarkInterestRate(
            '10'
        ).encodeABI();

        let res = await gov.createProposal(
            _class,
            [exec.address],
            [0],
            [callData],
            desc,
            { from: operator }
        );

        let event = res.logs[0].args;

        await wait(18000);

        await gov.vote(event.class, event.nonce, user1, 0, amountToStake, 1, { from: user4 });
        await gov.vote(event.class, event.nonce, user2, 1, amountToStake, 1, { from: user2 });
        await gov.vote(event.class, event.nonce, user3, 0, amountToStake, 1, { from: user3 });

        let v1 = await count.hasVoted(event.class, event.nonce, user1);
        let v4 = await count.hasVoted(event.class, event.nonce, user4);
        let v2 = await count.hasVoted(event.class, event.nonce, user2);
        let v3 = await count.hasVoted(event.class, event.nonce, user3);

        expect(v1).to.be.false;
        expect(v4).to.be.true;
        expect(v2).to.be.true;
        expect(v3).to.be.true;
    });

    it('check proposal of class 2 passes', async () => {
        let _class = 2;
        let desc = "Propsal-1: Update the benchMark interest rate";
        let callData = await exec.contract.methods.updateBenchmarkInterestRate(
            '10'
        ).encodeABI();

        let res = await gov.createProposal(
            _class,
            [exec.address],
            [0],
            [callData],
            desc,
            { from: operator }
        );

        let event = res.logs[0].args;

        await wait(18000);

        await gov.vote(event.class, event.nonce, user1, 0, amountToStake, 1, { from: user1 });
        await gov.vote(event.class, event.nonce, user2, 1, amountToStake, 1, { from: user2 });
        await gov.vote(event.class, event.nonce, user3, 0, amountToStake, 1, { from: user3 });

        await wait(18000);

        let benchmarkBefore = await storage.getBenchmarkIR();

        // Execute the proposal
        await gov.executeProposal(
            event.class,
            event.nonce,
            { from: operator }
        );

        let status = await storage.getProposalStatus(event.class, event.nonce);

        let benchmarkAfter = await storage.getBenchmarkIR();

        expect(status.toString()).to.equal(ProposalStatus.Executed);
        expect(
            benchmarkAfter.toString()
        )
            .to.equal(
                benchmarkBefore.add(web3.utils.toBN(5)).toString()
            );
    });

    it.only('Check DBIT earned by voting', async () => {
        let _class = 2;
        let desc = "Propsal-1: Update the benchMark interest rate";
        let callData = await exec.contract.methods.updateBenchmarkInterestRate(
            '10'
        ).encodeABI();

        let res = await gov.createProposal(
            _class,
            [exec.address],
            [0],
            [callData],
            desc,
            { from: operator }
        );

        let event = res.logs[0].args;

        await wait(18000);

        await gov.vote(event.class, event.nonce, user1, 0, amountToStake, 1, { from: user1 });
        await gov.vote(event.class, event.nonce, user2, 1, amountToStake, 1, { from: user2 });
        await gov.vote(event.class, event.nonce, user3, 0, amountToStake, 1, { from: user3 });

        await wait(18000);

        await gov.unlockVoteTokens(event.class, event.nonce, { from: user1 });
        await gov.unlockVoteTokens(event.class, event.nonce, { from: operator });

        let balanceVoteAfter = await dbit.balanceOf(user1);
        balanceVoteAfter = Number(balanceVoteAfter.toString()) / 1e18;
        balanceVoteAfter = balanceVoteAfter.toFixed(15)

        let reward = amountToStake * 5 / (3 * amountToStake);
        reward = reward.toFixed(15);

        expect(balanceVoteAfter).to.equal(reward);
    });


    it.only('Check proposer can unstake their vote tokens', async () => {
        let _class = 2;
        let title = "Propsal-1: Update the benchMark interest rate";
        let desc = "Lorem ipsum dolor sit amet, consectetur adipiscing elit";
        let callData = await exec.contract.methods.updateBenchmarkInterestRate(
            '10'
        ).encodeABI();

        let res = await gov.createProposal(
            _class,
            [exec.address],
            [0],
            [callData],
            desc,
            { from: operator }
        );

        let event = res.logs[0].args;

        await wait(18000);

        await gov.vote(event.class, event.nonce, user1, 0, amountToStake, 1, { from: user1 });
        await gov.vote(event.class, event.nonce, user2, 1, amountToStake, 1, { from: user2 });
        await gov.vote(event.class, event.nonce, user3, 0, amountToStake, 1, { from: user3 });

        await wait(18000);

        let thresold = await web3.utils.toWei(web3.utils.toBN(10), 'ether');
        let balanceBefore = await vote.availableBalance(operator);

        await gov.unlockVoteTokens(event.class, event.nonce, { from: operator });

        let balanceAfter = await vote.availableBalance(operator);

        expect(balanceAfter.toString()).to.equal(balanceBefore.add(thresold).toString())
    });







    it('update DGOV max supply', async () => {
        let toAdd = await web3.utils.toWei(web3.utils.toBN(4000000), 'ether');
        let maxSupplyBefore = await dgov.getMaxSupply();
        let newMax = maxSupplyBefore.add(toAdd);

        await gov.setMaxSupply(newMax, { from: operator });
        let maxSupplyAfter = await dgov.getMaxSupply();

        expect(maxSupplyAfter.toString()).to.equal(maxSupplyBefore.add(toAdd).toString());
    });

    it("set DGOV max airdrop supply", async () => {
        let toAdd = await web3.utils.toWei(web3.utils.toBN(250000), 'ether');
        let maxAirdropBefore = await dgov.getMaxAirdropSupply();
        let newMax = maxAirdropBefore.add(toAdd);

        await gov.setMaxAirdropSupply(newMax, dgov.address, { from: operator });
        let maxAirdropAfter = await dgov.getMaxAirdropSupply();

        expect(maxAirdropAfter.toString()).to.equal(maxAirdropBefore.add(toAdd).toString());
    });

    it("set DBIT max airdrop supply", async () => {
        let toAdd = await web3.utils.toWei(web3.utils.toBN(250000), 'ether');
        let maxAirdropBefore = await dbit.getMaxAirdropSupply();
        let newMax = maxAirdropBefore.add(toAdd);

        await gov.setMaxAirdropSupply(newMax, dbit.address, { from: operator });
        let maxAirdropAfter = await dbit.getMaxAirdropSupply();

        expect(maxAirdropAfter.toString()).to.equal(maxAirdropBefore.add(toAdd).toString());
    });

    it("set DGOV max allocation percentage", async () => {
        await gov.setMaxAllocationPercentage("800", dgov.address, { from: operator });
        let maxAlloc = await dgov.getMaxAllocatedPercentage();

        expect(maxAlloc.toString()).to.equal("800");
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