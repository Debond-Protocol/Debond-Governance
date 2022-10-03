const chai = require("chai");
const chaiAsPromised = require('chai-as-promised');
const { Console } = require("console");
const readline = require('readline');

chai.use(chaiAsPromised);
const expect = chai.expect;

const Governance = artifacts.require("Governance");
const Executable = artifacts.require("Executable");
const GovStorage = artifacts.require("GovStorage");
const DGOV = artifacts.require("DGOVTest");
const StakingContract = artifacts.require("StakingDGOV");
const AdvanceBlockTimeStamp = artifacts.require("AdvanceBlockTimeStamp");

contract("Proposal: Governance", async (accounts) => {
    let gov;
    let exec;
    let storage;
    let dgov;
    let stakingContract;
    let nextTime;

    let operator = accounts[0];
    let debondTeam = accounts[1];
    let bank = accounts[3];

    let dgovToStake;

    let ProposalStatus = {
        Active: '0',
        Canceled: '1',
        Pending: '2',
        Defeated: '3',
        Succeeded: '4',
        Executed: '5'
    }

    beforeEach(async () => {
        gov = await Governance.deployed();
        exec = await Executable.deployed();
        storage = await GovStorage.deployed();
        dgov = await DGOV.deployed();
        stakingContract = await StakingContract.deployed();
        nextTime = await AdvanceBlockTimeStamp.deployed();

        dgovToStake = await web3.utils.toWei(web3.utils.toBN(500), 'ether');

        await dgov.mint(operator, dgovToStake);
        await dgov.mint(debondTeam, dgovToStake);
        await dgov.approve(stakingContract.address, dgovToStake, { from: operator });
        await dgov.approve(stakingContract.address, dgovToStake, { from: debondTeam });

        await stakingContract.stakeDgovToken(dgovToStake, 0, { from: operator });
        await stakingContract.stakeDgovToken(dgovToStake, 0, { from: debondTeam });
    });

    it("create a proposal", async () => {
        let _class = 0;
        let title = "Propsal-1: Update the benchMark interest rate";
        let callData = await exec.contract.methods.updateBenchmarkInterestRate(
            _class,
            '100000000000000000'
        ).encodeABI();

        let bal = await dgov.balanceOf(operator);
     
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
        let proposal = await storage.getProposalStruct(event.class, event.nonce);
        let nonce = await storage.getProposaLastNonce(_class);

        expect(event.class.toString()).to.equal(_class.toString());
        expect(event.nonce.toString()).to.equal(nonce.toString());
        expect(proposal.targets[0]).to.equal(exec.address);
        expect(proposal.ethValues[0]).to.equal('0');
        expect(proposal.calldatas[0].toString()).to.equal(callData.toString())
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
            [exec.address],
            [0],
            [callData1],
            title1,
            web3.utils.soliditySha3(title1),
            { from: operator }
        );

        // second proposal
        let _class2 = 1;
        let title2 = "Propsal-1: Update the bank contract";
        let callData2 = await exec.contract.methods.updateBankAddress(
            _class2,
            bank
        ).encodeABI();
        
        let res2 = await gov.createProposal(
            _class2,
            [exec.address],
            [50],
            [callData2],
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

        let proposals = await storage.getAllProposals();

        expect(proposals).to.not.be.empty;
        expect(proposals).to.have.lengthOf(4);

        expect(proposals[1].proposer).to.equal(operator);
        expect(proposals[1].calldatas[0]).to.equal(callData1);
        expect(proposals[1].descriptionHash).to.equal(web3.utils.soliditySha3(title1));
        expect(proposals[1].title).to.equal("Propsal-1: Update the benchMark interest rate");

        expect(proposals[2].proposer).to.equal(operator);
        expect(proposals[2].calldatas[0]).to.equal(callData2);
        expect(proposals[2].descriptionHash).to.equal(web3.utils.soliditySha3(title2));
        expect(proposals[2].title).to.equal("Propsal-1: Update the bank contract");

        expect(proposals[3].proposer).to.equal(operator);
        expect(proposals[3].calldatas[0]).to.equal(callData3);
        expect(proposals[3].descriptionHash).to.equal(web3.utils.soliditySha3(title3));
        expect(proposals[3].title).to.equal("Propsal-1: Update the DGOV max");
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
            [exec.address],
            [0],
            [callData],
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
            [exec.address],
            [0],
            [callData],
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
