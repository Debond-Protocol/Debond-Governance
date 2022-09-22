const chai = require("chai");
const chaiAsPromised = require('chai-as-promised');

chai.use(chaiAsPromised);
const expect = chai.expect;

const DBIT = artifacts.require("DBITTest");
const DGOV = artifacts.require("DGOVTest");
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
const BankStorageTest = artifacts.require("BankStorageTest");
const BankBondManager = artifacts.require("BankBondManager");
const Oracle = artifacts.require("Oracle");
const AdvanceBlockTimeStamp = artifacts.require("AdvanceBlockTimeStamp");

contract("Executable: Governance", async (accounts) => {

    const ProposalStatus = {
        Active: '0',
        Canceled: '1',
        Pending: '2',
        Defeated: '3',
        Succeeded: '4',
        Executed: '5'
    }

    let gov;
    let exec;
    let storage;
    let bankStorage;
    let dgov;
    let dbit;
    let stakingContract;
    let nextTime;

    const [operator, debondTeam, user1, user2, user3, user4, user5] = accounts;

    const approvalAmount = web3.utils.toWei(web3.utils.toBN(2500000), 'ether');

    before(async () => {
        gov = await Governance.deployed();
        exec = await Executable.deployed();
        storage = await GovStorage.deployed();
        bankStorage = await BankStorageTest.deployed();
        dgov = await DGOV.deployed();
        dbit = await DBIT.deployed();
        stakingContract = await StakingDGOV.deployed();
        nextTime = await AdvanceBlockTimeStamp.deployed();

        const amountToMint = await web3.utils.toWei(web3.utils.toBN(2500000), 'ether');

        await dgov.mint(operator, amountToMint);
        await dgov.mint(user1, amountToMint);
        await dgov.mint(user2, amountToMint);
        await dgov.mint(user3, amountToMint);
        await dgov.mint(user4, amountToMint);
        await dgov.mint(user5, amountToMint);
        await dbit.mintCollateralisedSupply(user5, amountToMint);

        await dgov.approve(stakingContract.address, approvalAmount, { from: operator });
        await dgov.approve(stakingContract.address, approvalAmount, { from: user1 });
        await dgov.approve(stakingContract.address, approvalAmount, { from: user2 });
        await dgov.approve(stakingContract.address, approvalAmount, { from: user3 });
        await dgov.approve(stakingContract.address, approvalAmount, { from: user4});
        await dgov.approve(stakingContract.address, approvalAmount, { from: user5});

        await stakingContract.stakeDgovToken(approvalAmount, 0, { from: operator });
        await stakingContract.stakeDgovToken(approvalAmount, 0, { from: user1 });
        await stakingContract.stakeDgovToken(approvalAmount, 0, { from: user2 });
        await stakingContract.stakeDgovToken(approvalAmount, 0, { from: user3 });
        await stakingContract.stakeDgovToken(approvalAmount, 0, { from: user4 });
        await stakingContract.stakeDgovToken(approvalAmount, 0, { from: user5 });

    })

    it("update the benchmark interest rate", async () => {
        let _class = 0;
        let title = "Propsal-1: Update the benchMark interest rate";
        let callData = await exec.contract.methods.updateBenchmarkInterestRate(
            '100000000000000000'
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

        let amountVote1 = web3.utils.toWei(web3.utils.toBN(10), 'ether')
        let amountVote2 = web3.utils.toWei(web3.utils.toBN(10), 'ether')
        let amountVote3 = web3.utils.toWei(web3.utils.toBN(10), 'ether')
        let amountVote4 = web3.utils.toWei(web3.utils.toBN(10), 'ether')

        await gov.vote(event.class, event.nonce, user1, 0, amountVote1, 1, { from: user1 });
        await gov.vote(event.class, event.nonce, user2, 1, amountVote2, 1, { from: user2 });
        await gov.vote(event.class, event.nonce, user3, 0, amountVote3, 1, { from: user3 });
        await gov.vote(event.class, event.nonce, user4, 0, amountVote4, 1, { from: user4 });

        let benchmarkBefore = await storage.getBenchmarkIR();
        let benchmarkBankBefore = await bankStorage.getBenchmarkIR();
        let status = await storage.getProposalStatus(event.class, event.nonce);

        await wait(4000);
        await nextTime.increment();

        await gov.executeProposal(
            event.class,
            event.nonce,
            { from: operator }
        );

        let benchmarkAfter = await storage.getBenchmarkIR();
        let benchmarkBankAfter = await bankStorage.getBenchmarkIR();
        await nextTime.increment();
        let status1 = await storage.getProposalStatus(event.class, event.nonce);

        expect(status.toString()).to.equal(ProposalStatus.Active);
        expect(status1.toString()).to.equal(ProposalStatus.Executed);

        expect(
            benchmarkAfter.toString()
        ).to.equal(
            "100000000000000000"
        );

        expect(
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

        let amountVote1 = web3.utils.toWei(web3.utils.toBN(10), 'ether')
        let amountVote2 = web3.utils.toWei(web3.utils.toBN(10), 'ether')
        let amountVote3 = web3.utils.toWei(web3.utils.toBN(10), 'ether')
        let amountVote4 = web3.utils.toWei(web3.utils.toBN(10), 'ether')

        await gov.vote(event.class, event.nonce, user1, 0, amountVote1, 1, { from: user1 });
        await gov.vote(event.class, event.nonce, user2, 1, amountVote2, 1, { from: user2 });
        await gov.vote(event.class, event.nonce, user3, 0, amountVote3, 1, { from: user3 });
        await gov.vote(event.class, event.nonce, user4, 0, amountVote4, 1, { from: user4 });

        await gov.veto(event.class, event.nonce, true, { from: operator });

        await wait(3000);
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

        let amountVote1 = web3.utils.toWei(web3.utils.toBN(10), 'ether')
        let amountVote2 = web3.utils.toWei(web3.utils.toBN(10), 'ether')
        let amountVote3 = web3.utils.toWei(web3.utils.toBN(10), 'ether')
        let amountVote4 = web3.utils.toWei(web3.utils.toBN(10), 'ether')

        await gov.vote(event.class, event.nonce, user1, 0, amountVote1, 1, { from: user1 });
        await gov.vote(event.class, event.nonce, user2, 0, amountVote2, 1, { from: user2 });
        await gov.vote(event.class, event.nonce, user3, 0, amountVote3, 1, { from: user3 });
        await gov.vote(event.class, event.nonce, user4, 0, amountVote4, 1, { from: user4 });

        let thresholdBefore = await storage.getProposalThreshold();

        await wait(3000);
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

        let amountVote1 = web3.utils.toWei(web3.utils.toBN(10), 'ether')
        let amountVote2 = web3.utils.toWei(web3.utils.toBN(10), 'ether')
        let amountVote3 = web3.utils.toWei(web3.utils.toBN(10), 'ether')
        let amountVote4 = web3.utils.toWei(web3.utils.toBN(10), 'ether')

        await gov.vote(event.class, event.nonce, user1, 0, amountVote1, 1, { from: user1 });
        await gov.vote(event.class, event.nonce, user2, 0, amountVote2, 1, { from: user2 });
        await gov.vote(event.class, event.nonce, user3, 0, amountVote3, 1, { from: user3 });
        await gov.vote(event.class, event.nonce, user4, 1, amountVote4, 1, { from: user4 });

        await wait(3000);
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
        let callData = await exec.contract.methods.mintAllocatedToken(
            dbit.address,
            debondTeam,
            amountDBIT
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

        let amountVote1 = web3.utils.toWei(web3.utils.toBN(10), 'ether')
        let amountVote2 = web3.utils.toWei(web3.utils.toBN(10), 'ether')
        let amountVote3 = web3.utils.toWei(web3.utils.toBN(10), 'ether')
        let amountVote4 = web3.utils.toWei(web3.utils.toBN(10), 'ether')

        await gov.vote(event.class, event.nonce, user1, 0, amountVote1, 1, { from: user1 });
        await gov.vote(event.class, event.nonce, user2, 0, amountVote2, 1, { from: user2 });
        await gov.vote(event.class, event.nonce, user3, 0, amountVote3, 1, { from: user3 });
        await gov.vote(event.class, event.nonce, user4, 1, amountVote4, 1, { from: user4 });

        await wait(3000);
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
        let callData = await exec.contract.methods.mintAllocatedToken(
            dgov.address,
            debondTeam,
            amountDGOV
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

        let amountVote1 = web3.utils.toWei(web3.utils.toBN(10), 'ether')
        let amountVote2 = web3.utils.toWei(web3.utils.toBN(10), 'ether')
        let amountVote3 = web3.utils.toWei(web3.utils.toBN(10), 'ether')
        let amountVote4 = web3.utils.toWei(web3.utils.toBN(10), 'ether')

        await gov.vote(event.class, event.nonce, user1, 0, amountVote1, 1, { from: user1 });
        await gov.vote(event.class, event.nonce, user2, 0, amountVote2, 1, { from: user2 });
        await gov.vote(event.class, event.nonce, user3, 0, amountVote3, 1, { from: user3 });
        await gov.vote(event.class, event.nonce, user4, 1, amountVote4, 1, { from: user4 });

        await wait(3000);
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

    it("change the team allocation", async () => {
        let newDBITAmount = await web3.utils.toWei(web3.utils.toBN(60000), 'ether');
        let newDGOVAmount = await web3.utils.toWei(web3.utils.toBN(90000), 'ether');
        let _class = 0;
        let title = "Propsal-1: Change the team allocation token amount";
        callData = await exec.contract.methods.changeTeamAllocation(
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

        let amountVote1 = web3.utils.toWei(web3.utils.toBN(10), 'ether')
        let amountVote2 = web3.utils.toWei(web3.utils.toBN(10), 'ether')
        let amountVote3 = web3.utils.toWei(web3.utils.toBN(10), 'ether')
        let amountVote4 = web3.utils.toWei(web3.utils.toBN(10), 'ether')

        await gov.vote(event.class, event.nonce, user1, 0, amountVote1, 1, { from: user1 });
        await gov.vote(event.class, event.nonce, user2, 0, amountVote2, 1, { from: user2 });
        await gov.vote(event.class, event.nonce, user3, 0, amountVote3, 1, { from: user3 });
        await gov.vote(event.class, event.nonce, user4, 1, amountVote4, 1, { from: user4 });

        await wait(3000);
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
        let callData = await exec.contract.methods.updateDGOVMaxSupply(
            newMax
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

        let amountVote1 = web3.utils.toWei(web3.utils.toBN(10), 'ether')
        let amountVote2 = web3.utils.toWei(web3.utils.toBN(10), 'ether')
        let amountVote3 = web3.utils.toWei(web3.utils.toBN(10), 'ether')
        let amountVote4 = web3.utils.toWei(web3.utils.toBN(10), 'ether')

        await gov.vote(event.class, event.nonce, user1, 0, amountVote1, 1, { from: user1 });
        await gov.vote(event.class, event.nonce, user2, 0, amountVote2, 1, { from: user2 });
        await gov.vote(event.class, event.nonce, user3, 0, amountVote3, 1, { from: user3 });
        await gov.vote(event.class, event.nonce, user4, 1, amountVote4, 1, { from: user4 });

        await wait(3000);
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
        let callData = await exec.contract.methods.setMaxAllocationPercentage(
            "800",
            dgov.address
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

        let amountVote1 = web3.utils.toWei(web3.utils.toBN(10), 'ether')
        let amountVote2 = web3.utils.toWei(web3.utils.toBN(10), 'ether')
        let amountVote3 = web3.utils.toWei(web3.utils.toBN(10), 'ether')
        let amountVote4 = web3.utils.toWei(web3.utils.toBN(10), 'ether')

        await gov.vote(event.class, event.nonce, user1, 0, amountVote1, 1, { from: user1 });
        await gov.vote(event.class, event.nonce, user2, 0, amountVote2, 1, { from: user2 });
        await gov.vote(event.class, event.nonce, user3, 0, amountVote3, 1, { from: user3 });
        await gov.vote(event.class, event.nonce, user4, 1, amountVote4, 1, { from: user4 });

        await wait(3000);
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