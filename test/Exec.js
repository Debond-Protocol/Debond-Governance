const chai = require("chai");
const chaiAsPromised = require('chai-as-promised');
const { Console } = require("console");
const readline = require('readline');

chai.use(chaiAsPromised);
const expect = chai.expect;

const DBIT = artifacts.require("DBITToken");
const DGOV = artifacts.require("DGOVToken");
const ERC3475 = artifacts.require("ERC3475");
const Bank = artifacts.require("Bank");
const APMTest = artifacts.require("APMTest");
const VoteToken = artifacts.require("VoteToken");
const StakingDGOV = artifacts.require("StakingDGOV");
const Governance = artifacts.require("Governance");
const Executable = artifacts.require("Executable");
const GovStorage = artifacts.require("GovStorage");
const GovernanceMigrator = artifacts.require("GovernanceMigrator");
const Exchange = artifacts.require("ExchangeTest");
const ExchangeStorage = artifacts.require("ExchangeStorageTest");
const BankData = artifacts.require("BankData");
const BankBondManager = artifacts.require("BankBondManager");
const Oracle = artifacts.require("Oracle");
const AdvanceBlockTimeStamp = artifacts.require("AdvanceBlockTimeStamp");

contract("Executable: Governance", async (accounts) => {
    let gov;
    let apm;
    let bank;
    let dbit;
    let dgov;
    let stak;
    let vote;
    let exec;
    let erc3475;
    let storage;
    let amountToMint;
    let amountToStake;
    let migrator;
    let exchange;
    let exStorage;
    let bankData;
    let bondManager;
    let oracle;
    let nextTime;

    let user1B;
    let user2B;
    let user3B;
    let user4B;
    let user5B;
    let userOB;
    let contrB;

    let toStake1;
    let toStake2;
    let toStake3;
    let toStake4;
    let toStake5;
    let toStake6;
    let opStake;

    let operator = accounts[0];
    let debondTeam = accounts[1];
    let user1 = accounts[2];
    let user2 = accounts[3];
    let user3 = accounts[4];
    let user4 = accounts[5];
    let user5 = accounts[6];
    let user6 = accounts[7];
    let user7 = accounts[8];

    let ProposalStatus = {
        Active: '0',
        Canceled: '1',
        Pending: '2',
        Defeated: '3',
        Succeeded: '4',
        Executed: '5'
    }

    beforeEach(async () => {
        migrator = await GovernanceMigrator.new();
        storage = await GovStorage.new(debondTeam, operator);
        exec = await Executable.new(storage.address);
        oracle = await Oracle.new(exec.address);
        gov = await Governance.new(storage.address);
        vote = await VoteToken.new("Debond Vote Token", "DVT", storage.address);
        exStorage = await ExchangeStorage.new(gov.address, exec.address);
        exchange = await Exchange.new(exStorage.address, gov.address, exec.address);
        bondManager = await BankBondManager.new(gov.address, exec.address, oracle.address);
        bank = await Bank.new(gov.address, exec.address, bondManager.address, oracle.address);
        erc3475 = await ERC3475.new(gov.address, exec.address, bank.address, bondManager.address);
        apm = await APMTest.new(gov.address, bank.address, exec.address);
        bankData = await BankData.new(gov.address, bank.address, exec.address);
        dbit = await DBIT.new(gov.address, bank.address, operator, exchange.address, exec.address);
        dgov = await DGOV.new(gov.address, bank.address, operator, exchange.address, exec.address);
        stak = await StakingDGOV.new(storage.address);

        nextTime = await AdvanceBlockTimeStamp.new();

        // initialize all contracts
        await storage.setUpGoup1(
            gov.address,
            dgov.address,
            dbit.address,
            apm.address,
            bondManager.address,
            oracle.address,
            stak.address,
            vote.address,
            {from: operator}
        );

        await storage.setUpGoup2(
            exec.address,
            bank.address,
            bankData.address,
            erc3475.address,
            exchange.address,
            exStorage.address,
            operator,
            operator,
            {from: operator}
        );

        // set the apm address in Bank
        await bank.setAPMAddress(apm.address);

        //let amount = await web3.utils.toWei(web3.utils.toBN(100), 'ether');
        let amount = await web3.utils.toWei(web3.utils.toBN(20000), 'ether');
        let amountToSend = await web3.utils.toWei(web3.utils.toBN(10000), 'ether');
        await bank.mintCollateralisedSupply(dbit.address, debondTeam, amount, { from: operator });
        await dbit.transfer(gov.address, amountToSend, { from: debondTeam });
        await dbit.transfer(apm.address, amountToSend, { from: debondTeam });

        await bank.mintCollateralisedSupply(dgov.address, debondTeam, amountToSend, { from: operator  });
        await dgov.transfer(apm.address, amountToSend, { from: debondTeam });
 
        await bank.update(
            amountToSend,
            amountToSend,
            dbit.address,
            dgov.address,
            { from: operator }
        );

        //amountToMint = await web3.utils.toWei(web3.utils.toBN(200), 'ether');
        amountToMint = await web3.utils.toWei(web3.utils.toBN(2500), 'ether');

        toStake1 = await web3.utils.toWei(web3.utils.toBN(50), 'ether');
        toStake2 = await web3.utils.toWei(web3.utils.toBN(85), 'ether');
        toStake3 = await web3.utils.toWei(web3.utils.toBN(300), 'ether');
        toStake4 = await web3.utils.toWei(web3.utils.toBN(20), 'ether');
        toStake5 = await web3.utils.toWei(web3.utils.toBN(750), 'ether');
        toStake6 = await web3.utils.toWei(web3.utils.toBN(810), 'ether');
        opStake = await web3.utils.toWei(web3.utils.toBN(430), 'ether');

        await bank.mintCollateralisedSupply(dgov.address, debondTeam, amountToMint, { from: operator });
        await dgov.transfer(user1, toStake1, { from: debondTeam });
        await dgov.transfer(user2, toStake2, { from: debondTeam });
        await dgov.transfer(user3, toStake3, { from: debondTeam });
        await dgov.transfer(user4, toStake4, { from: debondTeam });
        await dgov.transfer(user5, toStake5, { from: debondTeam });
        await dgov.transfer(operator, opStake, { from: debondTeam });
        await dgov.approve(stak.address, toStake1, { from: user1 });
        await dgov.approve(stak.address, toStake2, { from: user2 });
        await dgov.approve(stak.address, toStake3, { from: user3 });
        await dgov.approve(stak.address, toStake4, { from: user4});
        await dgov.approve(stak.address, toStake5, { from: user5 });
        await dgov.approve(stak.address, opStake, { from: operator });
        await dgov.approve(user1, toStake1, { from: user1 });
        await dgov.approve(user2, toStake2, { from: user2 });
        await dgov.approve(user3, toStake3, { from: user3 });
        await dgov.approve(user4, toStake4, { from: user4 });
        await dgov.approve(user5, toStake5, { from: user5 });
        await dgov.approve(operator, opStake, { from: operator });

        user1B = await dgov.balanceOf(user1);
        user2B = await dgov.balanceOf(user2);
        user3B = await dgov.balanceOf(user3);
        user4B = await dgov.balanceOf(user4);
        user5B = await dgov.balanceOf(user5);
        userOB = await dgov.balanceOf(operator);
        contrB = await dgov.balanceOf(stak.address);

        await stak.stakeDgovToken(toStake1, 0, { from: user1 });
        await stak.stakeDgovToken(toStake2, 0, { from: user2 });
        await stak.stakeDgovToken(toStake3, 0, { from: user3 });
        await stak.stakeDgovToken(toStake4, 0, { from: user4 });
        await stak.stakeDgovToken(toStake5, 0, { from: user5 });
        await stak.stakeDgovToken(opStake, 0, { from: operator });
    });

    it("update the benchmark interest rate", async () => {
        let _class = 0;
        let title = "Propsal-1: Update the benchMark interest rate";
        let callData = await exec.contract.methods.updateBenchmarkInterestRate(
            _class,
            '100000000000000000'
        ).encodeABI();

        let res = await gov.createProposal(
            _class,
            exec.address,
            0,
            callData,
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

        let benchmarkBefore = await storage.getBenchmarkIR();
        let benchmarkBankBefore = await bank.getBenchmarkIR();
        let status = await storage.getProposalStatus(event.class, event.nonce);

        await wait(17000);
        await nextTime.increment();

        await gov.executeProposal(
            event.class,
            event.nonce,
            { from: operator }
        );

        let benchmarkAfter = await storage.getBenchmarkIR();
        let benchmarkBankAfter = await bank.getBenchmarkIR();
        await nextTime.increment();
        let status1 = await storage.getProposalStatus(event.class, event.nonce);

        expect(status.toString()).to.equal(ProposalStatus.Active);
        expect(status1.toString()).to.equal(ProposalStatus.Executed);

        expect(
            benchmarkBefore.toString()
        ).to.equal(
            benchmarkBankBefore.toString()
        ).to.equal(
            "50000000000000000"
        );

        expect(
            benchmarkAfter.toString()
        ).to.equal(
            benchmarkBankAfter.toString()
        ).to.equal(
            "100000000000000000"
        );
    });

    it("cannot update a proposal if it's vetoed", async () => {
        // first proposal
        let _class = 0;
        let title = "Propsal-1: Update the benchMark interest rate";
        let callData = await exec.contract.methods.updateBenchmarkInterestRate(
            _class,
            '100000000000000000'
        ).encodeABI();

        let res = await gov.createProposal(
            _class,
            exec.address,
            0,
            callData,
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

        await gov.veto(event.class, event.nonce, true, { from: operator });

        await wait(17000);
        await nextTime.increment();

        expect(gov.executeProposal(event.class, event.nonce, { from: operator }))
        .to.rejectedWith(
            Error,
            "VM Exception while processing transaction: revert Gov: only succeded proposals -- Reason given: Gov: only succeded proposals"
        );
    });

    it("update the proposal threshold", async () => {
        let oldTherehold = await web3.utils.toWei(web3.utils.toBN(10), 'ether');
        let newTherehold = await web3.utils.toWei(web3.utils.toBN(50), 'ether');
        let _class = 0;
        let title = "Propsal-1: Update the proposal threshold";

        let callData = await exec.contract.methods.updateProposalThreshold(
            _class,
            newTherehold
        ).encodeABI();
        
        let res = await gov.createProposal(
            _class,
            exec.address,
            0,
            callData,
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
        await gov.vote(event.class, event.nonce, user2, 0, amountVote2, 1, { from: user2 });
        await gov.vote(event.class, event.nonce, user3, 0, amountVote3, 1, { from: user3 });
        await gov.vote(event.class, event.nonce, user4, 0, amountVote4, 1, { from: user4 });

        let thresholdBefore = await storage.getProposalThreshold();

        await wait(17000);
        await nextTime.increment();

        await gov.executeProposal(
            event.class,
            event.nonce,
            { from: operator }
        );

        let thresholdAfter = await storage.getProposalThreshold();

        expect(thresholdBefore.toString()).to.equal(oldTherehold.toString());
        expect(thresholdAfter.toString()).to.equal(newTherehold.toString());
    });

    it("change the budget in Part Per Million", async () => {
        let newDBITBudget = await web3.utils.toWei(web3.utils.toBN(5000000), 'ether');
        let newDGOVBudget = await web3.utils.toWei(web3.utils.toBN(7000000), 'ether');
        let _class = 0;
        let title = "Propsal-1: Update the budget part per million";
        let callData = await exec.contract.methods.changeCommunityFundSize(
            _class,
            newDBITBudget,
            newDGOVBudget
        ).encodeABI();
        
        let res = await gov.createProposal(
            _class,
            exec.address,
            0,
            callData,
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
        await gov.vote(event.class, event.nonce, user2, 0, amountVote2, 1, { from: user2 });
        await gov.vote(event.class, event.nonce, user3, 0, amountVote3, 1, { from: user3 });
        await gov.vote(event.class, event.nonce, user4, 1, amountVote4, 1, { from: user4 });

        await wait(17000);
        await nextTime.increment();

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

    it("mint DBIT allocated token", async () => {
        let amountDBIT = await web3.utils.toWei(web3.utils.toBN(2), 'ether');
        let _class = 0;
        let title = "Propsal-1: Mint the team allocation token";
        let callData = await gov.contract.methods.mintAllocatedToken(
            _class,
            dbit.address,
            debondTeam,
            amountDBIT
        ).encodeABI();
        
        let res = await gov.createProposal(
            _class,
            gov.address,
            0,
            callData,
            title,
            web3.utils.soliditySha3(title),
            {from: operator}
        );

        let event = res.logs[0].args;

        let amountVote1 = await storage.getAvailableVoteTokens(user1, 1);
        let amountVote2 = await storage.getAvailableVoteTokens(user2, 1);
        let amountVote3 = await storage.getAvailableVoteTokens(user3, 1);
        let amountVote4 = await storage.getAvailableVoteTokens(user4, 1);

        await gov.vote(event.class, event.nonce, user1, 0, amountVote1, 1, { from: user1 });
        await gov.vote(event.class, event.nonce, user2, 0, amountVote2, 1, { from: user2 });
        await gov.vote(event.class, event.nonce, user3, 0, amountVote3, 1, { from: user3 });
        await gov.vote(event.class, event.nonce, user4, 1, amountVote4, 1, { from: user4 });

        await wait(17000);
        await nextTime.increment();

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
        expect(totaAllocDistAfter[0].toString()).to.equal(totaAllocDistBefore[0].add(amountDBIT).toString());
    });

    it("mint DGOV allocated token", async () => {
        let amountDGOV = await web3.utils.toWei(web3.utils.toBN(1), 'ether');
        let _class = 0;
        let title = "Propsal-1: Mint the team allocation token";
        let callData = await gov.contract.methods.mintAllocatedToken(
            _class,
            dgov.address,
            debondTeam,
            amountDGOV
        ).encodeABI();
        
        let res = await gov.createProposal(
            _class,
            gov.address,
            0,
            callData,
            title,
            web3.utils.soliditySha3(title),
            {from: operator}
        );

        let event = res.logs[0].args;

        let amountVote1 = await storage.getAvailableVoteTokens(user1, 1);
        let amountVote2 = await storage.getAvailableVoteTokens(user2, 1);
        let amountVote3 = await storage.getAvailableVoteTokens(user3, 1);
        let amountVote4 = await storage.getAvailableVoteTokens(user4, 1);

        await gov.vote(event.class, event.nonce, user1, 0, amountVote1, 1, { from: user1 });
        await gov.vote(event.class, event.nonce, user2, 0, amountVote2, 1, { from: user2 });
        await gov.vote(event.class, event.nonce, user3, 0, amountVote3, 1, { from: user3 });
        await gov.vote(event.class, event.nonce, user4, 1, amountVote4, 1, { from: user4 });

        await wait(17000);
        await nextTime.increment();

        let allocMintedBefore = await storage.getAllocatedTokenMinted(debondTeam);
        let totaAllocDistBefore = await storage.getTotalAllocationDistributed();

        await gov.executeProposal(
            event.class,
            event.nonce,
            {from: operator}
        );

        let allocMintedAfter = await storage.getAllocatedTokenMinted(debondTeam);
        let totaAllocDistAfter = await storage.getTotalAllocationDistributed();

        expect(allocMintedAfter[1].toString()).to.equal(allocMintedBefore[1].add(amountDGOV).toString());
        expect(totaAllocDistAfter[1].toString()).to.equal(totaAllocDistBefore[1].add(amountDGOV).toString());
    });

    it("cannot execute a proposal without calling the callData", async () => {
        let amountDGOV = await web3.utils.toWei(web3.utils.toBN(1), 'ether');
        let _class = 0;
        let title = "Propsal-1: Mint the team allocation token";
        let callData = await gov.contract.methods.mintAllocatedToken(
            _class,
            dgov.address,
            debondTeam,
            amountDGOV
        ).encodeABI();
        
        let res = await gov.createProposal(
            _class,
            gov.address,
            0,
            callData,
            title,
            web3.utils.soliditySha3(title),
            {from: operator}
        );

        let event = res.logs[0].args;

        let amountVote1 = await storage.getAvailableVoteTokens(user1, 1);
        let amountVote2 = await storage.getAvailableVoteTokens(user2, 1);
        let amountVote3 = await storage.getAvailableVoteTokens(user3, 1);
        let amountVote4 = await storage.getAvailableVoteTokens(user4, 1);

        await gov.vote(event.class, event.nonce, user1, 0, amountVote1, 1, { from: user1 });
        await gov.vote(event.class, event.nonce, user2, 0, amountVote2, 1, { from: user2 });
        await gov.vote(event.class, event.nonce, user3, 0, amountVote3, 1, { from: user3 });
        await gov.vote(event.class, event.nonce, user4, 1, amountVote4, 1, { from: user4 });

        await wait(17000);
        await nextTime.increment();

        expect(
            gov.mintAllocatedToken(
                event.class,
                dgov.address,
                debondTeam,
                amountDGOV
            )
        ).to.rejectedWith(
            Error,
            "VM Exception while processing transaction: revert Executable: Only Gov -- Reason given: Executable: Only Gov"
        );
    });

    it("change the team allocation", async () => {
        let newDBITAmount = await web3.utils.toWei(web3.utils.toBN(60000), 'ether');
        let newDGOVAmount = await web3.utils.toWei(web3.utils.toBN(90000), 'ether');
        let _class = 0;
        let title = "Propsal-1: Change the team allocation token amount";
        callData = await exec.contract.methods.changeTeamAllocation(
            _class,
            debondTeam,
            newDBITAmount,
            newDGOVAmount
        ).encodeABI();
        
        let res = await gov.createProposal(
            _class,
            exec.address,
            0,
            callData,
            title,
            web3.utils.soliditySha3(title),
            {from: operator}
        );

        let event = res.logs[0].args;

        let amountVote1 = await storage.getAvailableVoteTokens(user1, 1);
        let amountVote2 = await storage.getAvailableVoteTokens(user2, 1);
        let amountVote3 = await storage.getAvailableVoteTokens(user3, 1);
        let amountVote4 = await storage.getAvailableVoteTokens(user4, 1);

        await gov.vote(event.class, event.nonce, user1, 0, amountVote1, 1, { from: user1 });
        await gov.vote(event.class, event.nonce, user2, 0, amountVote2, 1, { from: user2 });
        await gov.vote(event.class, event.nonce, user3, 0, amountVote3, 1, { from: user3 });
        await gov.vote(event.class, event.nonce, user4, 1, amountVote4, 1, { from: user4 });

        await wait(17000);
        await nextTime.increment();

        await gov.executeProposal(
            event.class,
            event.nonce,
            {from: operator}
        );

        let alloc = await storage.getAllocatedToken(debondTeam);

        expect(alloc.dbitAllocPPM.toString()).to.equal(newDBITAmount.toString());
        expect(alloc.dgovAllocPPM.toString()).to.equal(newDGOVAmount.toString());
    });

    it("update DGOV max supply", async () => {
        let toAdd = await web3.utils.toWei(web3.utils.toBN(4000000), 'ether');
        let maxSupplyBefore = await dgov.getMaxSupply();
        let newMax = maxSupplyBefore.add(toAdd);
        let _class = 0;
        let title = "Propsal-1: Update the DGOV max";
        let callData = await gov.contract.methods.updateDGOVMaxSupply(
            _class,
            newMax
        ).encodeABI();
        
        let res = await gov.createProposal(
            _class,
            gov.address,
            0,
            callData,
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
        await gov.vote(event.class, event.nonce, user2, 0, amountVote2, 1, { from: user2 });
        await gov.vote(event.class, event.nonce, user3, 0, amountVote3, 1, { from: user3 });
        await gov.vote(event.class, event.nonce, user4, 1, amountVote4, 1, { from: user4 });

        await wait(17000);
        await nextTime.increment();

        await gov.executeProposal(
            event.class,
            event.nonce,
            {from: operator}
        );

        let maxSupplyAfter = await dgov.getMaxSupply();

        expect(maxSupplyAfter.toString()).to.equal(maxSupplyBefore.add(toAdd).toString());
    });

    it("update DGOV max allocation percentage", async () => {
        let _class = 0;
        let title = "Propsal-1: Update the benchMark interest rate";
        let callData = await gov.contract.methods.setMaxAllocationPercentage(
            _class,
            "800",
            dgov.address
        ).encodeABI();
        
        let res = await gov.createProposal(
            _class,
            gov.address,
            0,
            callData,
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
        await gov.vote(event.class, event.nonce, user2, 0, amountVote2, 1, { from: user2 });
        await gov.vote(event.class, event.nonce, user3, 0, amountVote3, 1, { from: user3 });
        await gov.vote(event.class, event.nonce, user4, 1, amountVote4, 1, { from: user4 });

        await wait(17000);
        await nextTime.increment();

        await gov.executeProposal(
            event.class,
            event.nonce,
            {from: operator}
        );

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