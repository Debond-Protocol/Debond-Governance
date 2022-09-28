const chai = require("chai");
const chaiAsPromised = require('chai-as-promised');
const { Console } = require("console");
const readline = require('readline');

chai.use(chaiAsPromised);
const expect = chai.expect;

const DBIT = artifacts.require("DBITTest");
const DGOV = artifacts.require("DGOVTest");
const ERC3475 = artifacts.require("DebondERC3475Test");
const APM = artifacts.require("APMTest");
const VoteToken = artifacts.require("VoteToken");
const StakingDGOV = artifacts.require("StakingDGOV");
const Governance = artifacts.require("Governance");
const Executable = artifacts.require("Executable");
const Bank = artifacts.require("BankTest");
const GovStorage = artifacts.require("GovStorage");
const Exchange = artifacts.require("ExchangeTest");
const ExchangeStorage = artifacts.require("ExchangeStorageTest");
const BankStorage = artifacts.require("BankStorageTest");
const BankBondManager = artifacts.require("BankBondManagerTest");
const AdvanceBlockTimeStamp = artifacts.require("AdvanceBlockTimeStamp");

contract("Executable: Governance", async (accounts) => {
    let gov;
    let apm;
    let bank;
    let dbit;
    let dgov;
    let stakingContract;
    let vote;
    let exec;
    let erc3475;
    let storage;
    let exchange;
    let exStorage;
    let bankStorage;
    let bondManager;
    let nextTime;

    let proposerDGOV;
    let amountDGOV;

    let operator = accounts[0];
    let debondTeam = accounts[1];
    let user1 = accounts[2];
    let user2 = accounts[3];
    let user3 = accounts[4];
    let user4 = accounts[5];
    let user5 = accounts[6];
    let user6 = accounts[7];
    let user7 = accounts[8];
    let user8 = accounts[9];

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
        exec = await Executable.deployed();
        gov = await Governance.deployed();
        vote = await VoteToken.deployed();
        exStorage = await ExchangeStorage.deployed();
        exchange = await Exchange.deployed();
        bondManager = await BankBondManager.deployed();
        bank = await Bank.deployed();
        erc3475 = await ERC3475.deployed();
        apm = await APM.deployed();
        bankStorage = await BankStorage.deployed();
        dbit = await DBIT.deployed();
        dgov = await DGOV.deployed();
        stakingContract = await StakingDGOV.deployed();
        nextTime = await AdvanceBlockTimeStamp.new();

        proposerDGOV = await web3.utils.toWei(web3.utils.toBN(2500), 'ether');
        amountDGOV = await web3.utils.toWei(web3.utils.toBN(150), 'ether');

        await dgov.mint(operator, proposerDGOV);
        await dgov.approve(stakingContract.address, proposerDGOV, { from: operator });
        await stakingContract.stakeDgovToken(proposerDGOV, 0, { from: operator });
    });

    /**
    * Execute tests one by one using "it.only", since when a contract is updated it is replaced
    * by an address which is not a contract, all the logic of setting and getting data
    * contained in the previous contract cannot be used anymore
    */
    it.only("update the bank contract", async () => {
        await dgov.mint(user1, amountDGOV);
        await dgov.approve(stakingContract.address, amountDGOV, { from: user1 });
        await stakingContract.stakeDgovToken(amountDGOV, 0, { from: user1 });

        let _class = 1;
        let title = "Propsal-1: Update the bank contract";
        let callData = await exec.contract.methods.updateBankAddress(
            _class,
            user6
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

        let amountVote = await storage.getAvailableVoteTokens(user1, 1);

        await gov.vote(event.class, event.nonce, user1, 0, amountVote, 1, { from: user1 });
        await gov.veto(event.class, event.nonce, true, { from: operator });

        await wait(17000);
        await nextTime.increment();

        let bankBefore = await storage.getBankAddress();

        await gov.executeProposal(
            event.class,
            event.nonce,
            { from: operator }
        );

        let bankAfter = await storage.getBankAddress();
        let bankInDBITAfter = await dbit.getBankAddress();
        let bankInDGOVAfter = await dgov.getBankAddress();
        let bankInAPMAfter = await apm.getBankAddress();
        let bankInERC3475After = await erc3475.getBankAddress();
        let bankInBankStorageAfter = await bankStorage.getBankAddress();
        let bankInBondManagerAfter = await bondManager.getBankAddress();

        expect(bankAfter)
        .to.equal(bankInDBITAfter)
        .to.equal(bankInDGOVAfter)
        .to.equal(bankInAPMAfter)
        .to.equal(bankInERC3475After)
        .to.equal(bankInBankStorageAfter)
        .to.equal(bankInBondManagerAfter)
        .to.equal(user6)
        .not.to.equal(bankBefore);
    });

    it("update the exchange address", async () => {
        await dgov.mint(user5, amountDGOV);
        await dgov.approve(stakingContract.address, amountDGOV, { from: user5 });
        await stakingContract.stakeDgovToken(amountDGOV, 0, { from: user5 });

        let _class = 0;
        let title = "Propsal-1: Update the exchange contract";
        let callData = await exec.contract.methods.updateExchangeAddress(
            _class,
            user6
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

        let amountVote = await storage.getAvailableVoteTokens(user5, 1);

        await gov.vote(event.class, event.nonce, user5, 0, amountVote, 1, { from: user5 });
        await gov.veto(event.class, event.nonce, true, { from: operator });

        await wait(17000);
        await nextTime.increment();

        let exchangeBefore = await storage.getExchangeAddress();

        await gov.executeProposal(
            event.class,
            event.nonce,
            { from: operator }
        );

        let exchangeAfter = await storage.getExchangeAddress();
        let inExchangeStorage = await exStorage.getExchangeAddress();

        expect(exchangeAfter)
        .to.equal(inExchangeStorage)
        .to.equal(user6)
        .not.to.equal(exchangeBefore);
    });

    it("update the bank bond manager contract", async () => {
        await dgov.mint(user6, amountDGOV);
        await dgov.approve(stakingContract.address, amountDGOV, { from: user6 });
        await stakingContract.stakeDgovToken(amountDGOV, 0, { from: user6 });

        let _class = 0;
        let title = "Propsal-1: Update the bank bond manager contract";
        let callData = await exec.contract.methods.updateBankBondManagerAddress(
            _class,
            user6
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

        let amountVote = await storage.getAvailableVoteTokens(user6, 1);

        await gov.vote(event.class, event.nonce, user6, 0, amountVote, 1, { from: user6 });
        await gov.veto(event.class, event.nonce, true, { from: operator });

        await wait(17000);
        await nextTime.increment();

        let bankBondManagerBefore = await storage.getBankBondManagerAddress();

        await gov.executeProposal(
            event.class,
            event.nonce,
            { from: operator }
        );

        let bankBondManagerAfter = await storage.getBankBondManagerAddress();
        let inBankAfter = await bank.getBankBondManager();
        let inDebondBondAfter = await erc3475.getBankBondManager();

        expect(bankBondManagerAfter)
        .to.equal(inBankAfter)
        .to.equal(inDebondBondAfter)
        .not.to.equal(bankBondManagerBefore);
    });

    it("update the oracle contract", async () => {
        await dgov.mint(user7, amountDGOV);
        await dgov.approve(stakingContract.address, amountDGOV, { from: user7 });
        await stakingContract.stakeDgovToken(amountDGOV, 0, { from: user7 });

        let _class = 0;
        let title = "Propsal-1: Update the oracle contract";
        let callData = await exec.contract.methods.updateOracleAddress(
            _class,
            user6
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

        let amountVote = await storage.getAvailableVoteTokens(user7, 1);

        await gov.vote(event.class, event.nonce, user7, 0, amountVote, 1, { from: user7 });
        await gov.veto(event.class, event.nonce, true, { from: operator });

        await wait(17000);
        await nextTime.increment();

        await gov.executeProposal(
            event.class,
            event.nonce,
            { from: operator }
        );

        let inBankAfter = await bank.getOracleAddress();
        let inBondManagerAfter = await bondManager.getOracleAddress();

        expect(inBankAfter).to.equal(inBondManagerAfter);
    });

    it("update the Governance contract", async () => {
        await dgov.mint(user2, amountDGOV);
        await dgov.approve(stakingContract.address, amountDGOV, { from: user2 });
        await stakingContract.stakeDgovToken(amountDGOV, 0, { from: user2 });

        let _class = 0;
        let title = "Propsal-1: Update the governance contract";
        let callData = await exec.contract.methods.updateGovernanceAddress(
            _class,
            user6
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

        let amountVote = await storage.getAvailableVoteTokens(user2, 1);

        await gov.vote(event.class, event.nonce, user2, 0, amountVote, 1, { from: user2 });
        await gov.veto(event.class, event.nonce, true, { from: operator });

        await wait(17000);
        await nextTime.increment();

        let governanceBefore = await storage.getGovernanceAddress();

        await gov.executeProposal(
            event.class,
            event.nonce,
            { from: operator }
        );

        let governanceAfter = await storage.getGovernanceAddress();

        expect(governanceAfter)
        .to.equal(user6)
        .not.to.equal(governanceBefore);
    });

    it("check that the old Governance is out of use after update", async () => {
        await dgov.mint(user3, amountDGOV);
        await dgov.approve(stakingContract.address, amountDGOV, { from: user3 });
        await stakingContract.stakeDgovToken(amountDGOV, 0, { from: user3 });

        let _class = 0;
        let title = "Propsal-1: Update the governance contract";
        let callData = await exec.contract.methods.updateGovernanceAddress(
            _class,
            user6
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

        let amountVote = await storage.getAvailableVoteTokens(user3, 1);

        await gov.vote(event.class, event.nonce, user3, 0, amountVote, 1, { from: user3 });
        await gov.veto(event.class, event.nonce, true, { from: operator });

        await wait(17000);
        await nextTime.increment();

        await gov.executeProposal(
            event.class,
            event.nonce,
            { from: operator }
        );

        expect(
            gov.createProposal(
                _class,
                [gov.address],
                [0],
                [callData],
                title,
                web3.utils.soliditySha3(title),
                { from: operator }
            )
        ).to.rejectedWith(
            Error,
            "param.substring is not a function"
        );
    });

    it("update the executable contract", async () => {
        await dgov.mint(user4, amountDGOV);
        await dgov.approve(stakingContract.address, amountDGOV, { from: user4 });
        await stakingContract.stakeDgovToken(amountDGOV, 0, { from: user4 });

        let _class = 1;
        let title = "Propsal-1: Update the executable contract";
        let callData = await exec.contract.methods.updateExecutableAddress(
            _class,
            user6
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

        let amountVote = await storage.getAvailableVoteTokens(user4, 1);

        await gov.vote(event.class, event.nonce, user4, 0, amountVote, 1, { from: user4 });
        await gov.veto(event.class, event.nonce, true, { from: operator });

        await wait(17000);
        await nextTime.increment();

        let executableBefore = await storage.getExecutableContract();

        await gov.executeProposal(
            event.class,
            event.nonce,
            { from: operator }
        );

        let executableAfter = await storage.getExecutableContract();
        let inDBITAfter = await dbit.getExecutableAddress();
        let inDGOVAfter = await dgov.getExecutableAddress();
        let inBankAfter = await bank.getExecutableAddress();
        let inAPMAfter = await apm.getExecutableAddress();
        let inExchangeAfter = await exchange.getExecutableAddress();
        let inERC3475After = await erc3475.getExecutableAddress();
        let inExStorageAfter = await exStorage.getExecutableAddress();
        let inBondManager = await bondManager.getExecutableAddress();
        let inBankStorageAfter = await bankStorage.getExecutableAddress();

        expect(executableAfter)
        .to.equal(inBankAfter)
        .to.equal(inDBITAfter)
        .to.equal(inDGOVAfter)
        .to.equal(inAPMAfter)
        .to.equal(inExchangeAfter)
        .to.equal(inERC3475After)
        .to.equal(inExStorageAfter)
        .to.equal(inBondManager)
        .to.equal(inBankStorageAfter)
        .to.equal(user6)
        .not.to.equal(executableBefore);
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