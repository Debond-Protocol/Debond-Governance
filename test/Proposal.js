const chai = require("chai");
const chaiAsPromised = require('chai-as-promised');
const { Console } = require("console");
const readline = require('readline');

chai.use(chaiAsPromised);
const expect = chai.expect;

const DBIT = artifacts.require("DBITTest");
const DGOV = artifacts.require("DGOVTest");
const ERC3475 = artifacts.require("DebondERC3475Test");
const BankTest = artifacts.require("BankTest");
const APMTest = artifacts.require("APMTest");
const VoteToken = artifacts.require("VoteToken");
const StakingDGOV = artifacts.require("StakingDGOV");
const Governance = artifacts.require("Governance");
const Executable = artifacts.require("Executable");
const GovStorage = artifacts.require("GovStorage");
const GovernanceMigrator = artifacts.require("GovernanceMigrator");
const Exchange = artifacts.require("ExchangeTest");
const ExchangeStorage = artifacts.require("ExchangeStorageTest");
const BankData = artifacts.require("BankStorageTest");
const BankBondManager = artifacts.require("BankBondManager");
const AdvanceBlockTimeStamp = artifacts.require("AdvanceBlockTimeStamp");

contract("Proposal: Governance", async (accounts) => {
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

    beforeEach(async (accounts) => {
        migrator = await GovernanceMigrator.new();
        storage = await GovStorage.new(debondTeam, operator);
        exec = await Executable.new(storage.address);
        oracle = accounts[10];
        gov = await Governance.new(storage.address);
        vote = await VoteToken.new("Debond Vote Token", "DVT", storage.address);
        exStorage = await ExchangeStorage.new(exec.address);
        exchange = await Exchange.new(exStorage.address, exec.address);
        bondManager = await BankBondManager.new(
            exec.address,
            "0x0000000000000000000000000000000000000000",
            "0x0000000000000000000000000000000000000000",
            "0x0000000000000000000000000000000000000000",
            "0x0000000000000000000000000000000000000000",
            "0x0000000000000000000000000000000000000000",
        );
        bank = await BankTest.new(
            exec.address,
            "0x0000000000000000000000000000000000000000",
            "0x0000000000000000000000000000000000000000",
            "0x0000000000000000000000000000000000000000",
            "0x0000000000000000000000000000000000000000",
            "0x0000000000000000000000000000000000000000",
            "0x0000000000000000000000000000000000000000",
            "0x0000000000000000000000000000000000000000",
            "0x0000000000000000000000000000000000000000",
            "0x0000000000000000000000000000000000000000"
            );
        erc3475 = await ERC3475.new(exec.address, bank.address, bondManager.address);
        apm = await APMTest.new(bank.address, exec.address);
        bankData = await BankData.new(exec.address, bank.address, 0);
        dbit = await DBIT.new(exec.address, bank.address, operator);
        dgov = await DGOV.new(exec.address, bank.address, operator);
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

        // set the apm address in BankTest
        await bank.setApmAddress(apm.address);

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

    it("create a proposal", async () => {
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
        let proposal = await storage.getProposalStruct(event.class, event.nonce);
        let nonce = await storage.getProposaLastNonce(_class);

        expect(event.class.toString()).to.equal(_class.toString());
        expect(event.nonce.toString()).to.equal(nonce.toString());
        expect(proposal.targets).to.equal(exec.address);
        expect(proposal.ethValue.toString()).to.equal('0');
        expect(proposal.calldatas.toString()).to.equal(callData.toString())
        expect(proposal.startTime.toString()).not.to.equal('0');
        expect(proposal.endTime.toString()).not.to.equal('0');
        expect(proposal.proposer).to.equal(operator);
        expect(proposal.title).to.equal(title);
        expect(proposal.descriptionHash).to.equal(web3.utils.soliditySha3(title));
    });

    it("create several proposals", async () => {
        // first proposal
        let _class1 = 0;
        let title1 = "Propsal-1: Update the benchMark interest rate";
        let callData1 = await exec.contract.methods.updateBenchmarkInterestRate(
            _class1,
            '100000000000000000'
        ).encodeABI();

        let res1 = await gov.createProposal(
            _class1,
            exec.address,
            0,
            callData1,
            title1,
            web3.utils.soliditySha3(title1),
            { from: operator }
        );

        // second proposal
        let _class2 = 1;
        let title2 = "Propsal-1: Update the bank contract";
        let callData2 = await exec.contract.methods.updateBankAddress(
            _class2,
            user6
        ).encodeABI();
        
        let res2 = await gov.createProposal(
            _class2,
            exec.address,
            0,
            callData2,
            title2,
            web3.utils.soliditySha3(title2),
            { from: operator }
        );

        // third proposal
        let toAdd = await web3.utils.toWei(web3.utils.toBN(4000000), 'ether');
        let maxSupplyBefore = await dgov.getMaxSupply();
        let newMax = maxSupplyBefore.add(toAdd);
        let _class3 = 0;
        let title3 = "Propsal-1: Update the DGOV max";
        let callData3 = await gov.contract.methods.updateDGOVMaxSupply(
            _class3,
            newMax
        ).encodeABI();
        
        let res3 = await gov.createProposal(
            _class3,
            gov.address,
            0,
            callData3,
            title3,
            web3.utils.soliditySha3(title3),
            { from: operator }
        );

        let proposals = await storage.getAllProposals();

        expect(proposals).to.not.be.empty;
        expect(proposals).to.have.lengthOf(3);

        expect(proposals[0].proposer).to.equal(operator);
        expect(proposals[0].calldatas).to.equal(callData1);
        expect(proposals[0].descriptionHash).to.equal(web3.utils.soliditySha3(title1));
        expect(proposals[0].title).to.equal("Propsal-1: Update the benchMark interest rate");

        expect(proposals[1].proposer).to.equal(operator);
        expect(proposals[1].calldatas).to.equal(callData2);
        expect(proposals[1].descriptionHash).to.equal(web3.utils.soliditySha3(title2));
        expect(proposals[1].title).to.equal("Propsal-1: Update the bank contract");

        expect(proposals[2].proposer).to.equal(operator);
        expect(proposals[2].calldatas).to.equal(callData3);
        expect(proposals[2].descriptionHash).to.equal(web3.utils.soliditySha3(title3));
        expect(proposals[2].title).to.equal("Propsal-1: Update the DGOV max");
    });

    it("Cancel a proposal", async () => {
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
        let proposal = await storage.getProposalStruct(event.class, event.nonce);
        let statusBef = proposal.status;
        
        await gov.cancelProposal(event.class, event.nonce);
        proposal = await storage.getProposalStruct(event.class, event.nonce);
        let statusAft = proposal.status;

        expect(statusBef.toString()).to.equal(ProposalStatus.Active);
        expect(statusAft.toString()).to.equal(ProposalStatus.Canceled);
    });

    it("cannot execute an active proposal", async () => {
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

        expect(gov.executeProposal(event.class, event.nonce)).to.rejectedWith(
            Error,
            "VM Exception while processing transaction: revert Gov: only succeded proposals -- Reason given: Gov: only succeded proposals"
        );
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
