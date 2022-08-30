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
const GovSettings = artifacts.require("GovSettings");
const Governance = artifacts.require("Governance");
const VoteCounting = artifacts.require("VoteCounting");
const Executable = artifacts.require("Executable");
const GovStorage = artifacts.require("GovStorage");
const ProposalLogic = artifacts.require("ProposalLogic");
const GovernanceMigrator = artifacts.require("GovernanceMigrator");
const Exchange = artifacts.require("ExchangeTest");
const ExchangeStorage = artifacts.require("ExchangeStorageTest");
const BankData = artifacts.require("BankData");
const BankBondManager = artifacts.require("BankBondManager");
const Oracle = artifacts.require("Oracle");
const AdvanceBlockTimeStamp = artifacts.require("AdvanceBlockTimeStamp");

contract("Governance", async (accounts) => {
    let gov;
    let apm;
    let bank;
    let dbit;
    let dgov;
    let stak;
    let vote;
    let exec;
    let count;
    let logic;
    let erc3475;
    let storage;
    let settings;
    let amountToMint;
    let migrator;
    let exchange;
    let exStorage;
    let bankData;
    let bondManager;
    let oracle;
    let nextTime;

    let amountToStake1;
    let amountToStake2;
    let amountToStake3;
    let amountToStake4;
    let amountToStake5;
    let amountToStake6;
    let amountToStake7;

    let amountUser1;
    let amountUser8;

    let balanceUser1BeforeStake;
    let balanceUser2BeforeStake;
    let balanceUser3BeforeStake;
    let balanceUser4BeforeStake;
    let balanceUser5BeforeStake;
    let balanceUser6BeforeStake;
    let balanceUser7BeforeStake;
    let balanceOperator;
    let balanceStakingContractBeforeStake;

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
        count = await VoteCounting.new();
        migrator = await GovernanceMigrator.new();
        vote = await VoteToken.new("Debond Vote Token", "DVT", operator);
        storage = await GovStorage.new(debondTeam, operator);
        settings = await GovSettings.new(storage.address);
        exec = await Executable.new(storage.address);
        oracle = await Oracle.new(exec.address);
        gov = await Governance.new(storage.address, count.address);
        exStorage = await ExchangeStorage.new(gov.address, exec.address);
        exchange = await Exchange.new(exStorage.address, gov.address, exec.address);
        bondManager = await BankBondManager.new(gov.address, exec.address, oracle.address);
        bank = await Bank.new(gov.address, exec.address, bondManager.address, oracle.address);
        erc3475 = await ERC3475.new(gov.address, exec.address, bank.address, bondManager.address);
        apm = await APMTest.new(gov.address, bank.address, exec.address);
        bankData = await BankData.new(gov.address, bank.address, exec.address);
        dbit = await DBIT.new(gov.address, bank.address, operator, exchange.address, exec.address);
        dgov = await DGOV.new(gov.address, bank.address, operator, exchange.address, exec.address);
        logic = await ProposalLogic.new(operator, storage.address, vote.address, count.address);
        stak = await StakingDGOV.new(dgov.address, vote.address, gov.address, logic.address, storage.address, exec.address);

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
            count.address,
            {from: operator}
        );

        await storage.setUpGoup2(
            settings.address,
            logic.address,
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

        // set the apm address in Bank
        await bank.setAPMAddress(apm.address);

        // set govStorage address in GovernanceMigrator
        await migrator.setGovStorageAddress(gov.address);

        // set Bank in Bank Bond Manager
        await bondManager.setBank(bank.address);

        // set echange address in exchange storage contract
        await exStorage.setExchange(exchange.address);

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
        amountToMint = await web3.utils.toWei(web3.utils.toBN(1000), 'ether');

        amountToStake1 = await web3.utils.toWei(web3.utils.toBN(350), 'ether');
        amountToStake2 = await web3.utils.toWei(web3.utils.toBN(20), 'ether');
        amountToStake3 = await web3.utils.toWei(web3.utils.toBN(25), 'ether');
        amountToStake4 = await web3.utils.toWei(web3.utils.toBN(5), 'ether');
        amountToStake5 = await web3.utils.toWei(web3.utils.toBN(200), 'ether');
        amountToStake6 = await web3.utils.toWei(web3.utils.toBN(100), 'ether');
        amountToStake7 = await web3.utils.toWei(web3.utils.toBN(75), 'ether');
        amountOperator = await web3.utils.toWei(web3.utils.toBN(55), 'ether');

        amountUser1 = await web3.utils.toWei(web3.utils.toBN(175), 'ether');
        amountUser8 = await web3.utils.toWei(web3.utils.toBN(175), 'ether');

        await bank.mintCollateralisedSupply(dgov.address, debondTeam, amountToMint, { from: operator });
        await dgov.transfer(user1, amountToStake1, { from: debondTeam });
        await dgov.transfer(user2, amountToStake2, { from: debondTeam });
        await dgov.transfer(user3, amountToStake3, { from: debondTeam });
        await dgov.transfer(user4, amountToStake4, { from: debondTeam });
        await dgov.transfer(user5, amountToStake5, { from: debondTeam });
        await dgov.transfer(user6, amountToStake6, { from: debondTeam });
        await dgov.transfer(user7, amountToStake7, { from: debondTeam });
        await dgov.transfer(operator, amountOperator, { from: debondTeam });
        await dgov.approve(stak.address, amountToStake1, { from: user1 });
        await dgov.approve(stak.address, amountToStake2, { from: user2 });
        await dgov.approve(stak.address, amountToStake3, { from: user3 });
        await dgov.approve(stak.address, amountToStake4, { from: user4});
        await dgov.approve(stak.address, amountToStake5, { from: user5 });
        await dgov.approve(stak.address, amountToStake6, { from: user6 });
        await dgov.approve(stak.address, amountToStake7, { from: user7 });
        await dgov.approve(stak.address, amountOperator, { from: operator });
        await dgov.approve(user1, amountToStake1, { from: user1 });
        await dgov.approve(user2, amountToStake2, { from: user2 });
        await dgov.approve(user3, amountToStake3, { from: user3 });
        await dgov.approve(user4, amountToStake4, { from: user4 });
        await dgov.approve(user5, amountToStake5, { from: user5 });
        await dgov.approve(user6, amountToStake6, { from: user6 });
        await dgov.approve(user7, amountToStake7, { from: user7 });
        await dgov.approve(operator, amountOperator, { from: operator });

        await dgov.approve(user8, amountUser8, { from: user1 });

        balanceUser1BeforeStake = await dgov.balanceOf(user1);
        balanceUser2BeforeStake = await dgov.balanceOf(user2);
        balanceUser3BeforeStake = await dgov.balanceOf(user3);
        balanceUser4BeforeStake = await dgov.balanceOf(user4);
        balanceUser5BeforeStake = await dgov.balanceOf(user5);
        balanceUser6BeforeStake = await dgov.balanceOf(user6);
        balanceUser7BeforeStake = await dgov.balanceOf(user7);
        balanceOperator = await dgov.balanceOf(operator);
        balanceStakingContractBeforeStake = await dgov.balanceOf(stak.address);

        await gov.stakeDGOV(amountToStake1, { from: user1 });
        await gov.stakeDGOV(amountToStake2, { from: user2 });
        await gov.stakeDGOV(amountToStake3, { from: user3 });
        await gov.stakeDGOV(amountToStake4, { from: user4 });
        await gov.stakeDGOV(amountToStake5, { from: user5 });
        await gov.stakeDGOV(amountToStake6, { from: user6 });
        await gov.stakeDGOV(amountToStake7, { from: user7 });
        await gov.stakeDGOV(amountOperator, { from: operator });
    });

    it("update the benchmark interest rate", async () => {
        /*************************************************************************
        *   create the proposal that will trigger the update benchmark function  *
        *************************************************************************/
        let _class = 0;
        let newBenchmark = "7";

        let title = "Proposal: Update the benchmark interest rate";
        let callData = await exec.contract.methods.updateBenchmarkInterestRate( 
            _class,
            newBenchmark
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

        let e = res.logs[0].args;

        expect(e.class.toString()).to.equal(_class + "");
        expect(e.nonce.toString()).to.equal("1");
        expect(e.proposer).to.equal(operator);
        expect(e.targets).to.equal(exec.address);
        expect(e.calldatas).to.equal(callData);
        expect(e.values.toString()).to.equal("0");
        expect(e.title).to.equal(title);

        /*************************************************************************
        *                      Let users vote for the proposal                   *
        *************************************************************************/
        // check that an approved user cannot vote more than the amount of tokens
        // he's approved 
        expect(
            gov.vote(e.class, e.nonce, user8, 0, amountUser8, 1, { from: user8 })
        ).to.rejectedWith(
            Error,
            "VM Exception while processing transaction: revert ProposalLogic: not approved or not enough dGoV staked -- Reason given: ProposalLogic: not approved or not enough dGoV staked"
        );

        // check that a user cannot vote for more than he's staked DGOV
        expect(
            gov.vote(e.class, e.nonce, user1, 0, amountToMint, 1, { from: user1 })
        ).to.rejectedWith(
            Error,
            "VM Exception while processing transaction: revert ProposalLogic: not approved or not enough dGoV staked -- Reason given: ProposalLogic: not approved or not enough dGoV staked"
        );

        await gov.vote(e.class, e.nonce, user1, 0, amountUser1, 1, { from: user1 });
        await gov.vote(e.class, e.nonce, user2, 0, amountToStake2, 1, { from: user2 });
        await gov.vote(e.class, e.nonce, user3, 1, amountToStake3, 1, { from: user3 });
        await gov.vote(e.class, e.nonce, user4, 0, amountToStake4, 1, { from: user4 });
        await gov.vote(e.class, e.nonce, user5, 0, amountToStake5, 1, { from: user5 });
        await gov.vote(e.class, e.nonce, user6, 1, amountToStake6, 1, { from: user6 });
        await gov.vote(e.class, e.nonce, user7, 1, amountToStake7, 1, { from: user7 });
        await gov.vote(e.class, e.nonce, user1, 0, amountUser8, 1, { from: user8 });

        await gov.veto(e.class, e.nonce, false, { from: operator });

        let status = await storage.getProposalStatus(e.class, e.nonce);
        expect(status.toString()).to.equal(ProposalStatus.Active);

        await wait(18000);
        await nextTime.increment();

        status = await storage.getProposalStatus(e.class, e.nonce);
        expect(status.toString()).to.equal(ProposalStatus.Succeeded);

        let benchmarkBefore = await storage.getBenchmarkIR();
        let benchmarkBankBefore = await bank.getBenchmarkIR();

        /*************************************************************************
        *                            Execute a proposal                          *
        *************************************************************************/
        await gov.executeProposal(
            e.class,
            e.nonce,
            { from: operator }
        );

        let benchmarkAfter = await storage.getBenchmarkIR();
        let benchmarkBankAfter = await bank.getBenchmarkIR();

        await nextTime.increment();

        status = await storage.getProposalStatus(e.class, e.nonce);
        expect(status.toString()).to.equal(ProposalStatus.Executed);

        expect(
            benchmarkAfter.toString()
        ).to.equal(
            benchmarkBefore.add(web3.utils.toBN(2)).toString()
        );
        expect(
            benchmarkBankAfter.toString()
        ).to.equal(
            benchmarkBankBefore.add(web3.utils.toBN(2)).toString()
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