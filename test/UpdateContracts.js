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

        // set Bank in Bank Bond Manager
        await bondManager.setBank(bank.address);

        // set exchange address in exchange storage contract
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

    it("update the bank contract", async () => {
        let _class = 1;
        let title = "Propsal-1: Update the bank contract";
        let callData = await exec.contract.methods.updateBankAddress(
            _class,
            user6
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

        await wait(17000);
        await nextTime.increment();

        let bankBefore = await storage.getBankAddress();
        let bankInDBITBefore = await dbit.getBankAddress();
        let bankInDGOVBefore = await dbit.getBankAddress();
        let bankInAPMBefore = await dbit.getBankAddress();
        let bankInERC3475Before = await erc3475.getBankAddress();
        let bankInBankDataBefore = await bankData.getBankAddress();
        let bankInBondManagerBefore = await bondManager.getBankAddress();

        await gov.executeProposal(
            event.class,
            event.nonce,
            { from: operator }
        );

        let bankAfter = await storage.getBankAddress();
        let bankInDBITAfter = await dbit.getBankAddress();
        let bankInDGOVAfter = await dbit.getBankAddress();
        let bankInAPMAfter = await dbit.getBankAddress();
        let bankInERC3475After = await erc3475.getBankAddress();
        let bankInBankDataAfter = await bankData.getBankAddress();
        let bankInBondManagerAfter = await bondManager.getBankAddress();

        expect(bankBefore)
        .to.equal(bankInDBITBefore)
        .to.equal(bankInDGOVBefore)
        .to.equal(bankInAPMBefore)
        .to.equal(bankInERC3475Before)
        .to.equal(bankInBankDataBefore)
        .to.equal(bankInBondManagerBefore)
        .to.equal(bank.address);

        expect(bankAfter)
        .to.equal(bankInDBITAfter)
        .to.equal(bankInDGOVAfter)
        .to.equal(bankInAPMAfter)
        .to.equal(bankInERC3475After)
        .to.equal(bankInBankDataAfter)
        .to.equal(bankInBondManagerAfter)
        .to.equal(user6)
        .not.to.equal(bankBefore);
    });

    it("update the Governance contract", async () => {
        let _class = 0;
        let title = "Propsal-1: Update the governance contract";
        let callData = await exec.contract.methods.updateGovernanceAddress(
            _class,
            user6
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

        await wait(17000);
        await nextTime.increment();

        let executableBefore = await storage.getGovernanceAddress();

        await gov.executeProposal(
            event.class,
            event.nonce,
            { from: operator }
        );

        let executableAfter = await storage.getGovernanceAddress();
        let inBank = await bank.getGovernanceAddress();
        let inDBIT = await dbit.getGovernanceAddress();
        let inDGOV = await dgov.getGovernanceAddress();
        let inBankData = await bankData.getGovernanceAddress();
        let inAPM = await apm.getGovernanceAddress();
        let inDebondBond = await erc3475.getGovernanceAddress();
        let inExchange = await exchange.getGovernanceAddress();
        let inExStorage = await exStorage.getGovernanceAddress();

        expect(executableAfter)
        .to.equal(inBank)
        .to.equal(inDBIT)
        .to.equal(inDGOV)
        .to.equal(inBankData)
        .to.equal(inAPM)
        .to.equal(inDebondBond)
        .to.equal(inExchange)
        .to.equal(inExStorage)
        .to.equal(user6)
        .not.to.equal(executableBefore);
    });

    it("check that the old Governance is out of use after update", async () => {
        let _class = 0;
        let title = "Propsal-1: Update the governance contract";
        let callData = await exec.contract.methods.updateGovernanceAddress(
            _class,
            user6
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
        let _class = 1;
        let title = "Propsal-1: Update the executable contract";
        let callData = await exec.contract.methods.updateExecutableAddress(
            _class,
            user6
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

        await wait(17000);
        await nextTime.increment();

        let executableBefore = await storage.getExecutableContract();
        let inDBITBefore = await dbit.getExecutableAddress();
        let inDGOVBefore = await dgov.getExecutableAddress();
        let inBankBefore = await bank.getExecutableAddress();
        let inBankDataBefore = await bankData.getExecutableAddress();
        let inAPMBefore = await apm.getExecutableAddress();
        let inERC3475Before = await erc3475.getExecutableAddress();
        let inExStorageBefore = await exStorage.getExecutableAddress();
        let inExchangeBefore = await exchange.getExecutableAddress();

        await gov.executeProposal(
            event.class,
            event.nonce,
            { from: operator }
        );

        let executableAfter = await storage.getExecutableContract();
        let inDBITAfter = await dbit.getExecutableAddress();
        let inDGOVAfter = await dgov.getExecutableAddress();
        let inBankAfter = await bank.getExecutableAddress();
        let inBankDataAfter = await bankData.getExecutableAddress();
        let inAPMAfter = await apm.getExecutableAddress();
        let inERC3475After = await erc3475.getExecutableAddress();
        let inExStorageAfter = await exStorage.getExecutableAddress();
        let inExchangeAfter = await exchange.getExecutableAddress();

        expect(executableBefore)
        .to.equal(inBankBefore)
        .to.equal(inDBITBefore)
        .to.equal(inDGOVBefore)
        .to.equal(inBankDataBefore)
        .to.equal(inAPMBefore)
        .to.equal(inERC3475Before)
        .to.equal(inExStorageBefore)
        .to.equal(inExchangeBefore)

        expect(executableAfter)
        .to.equal(inBankAfter)
        .to.equal(inDBITAfter)
        .to.equal(inDGOVAfter)
        .to.equal(inBankDataAfter)
        .to.equal(inAPMAfter)
        .to.equal(inERC3475After)
        .to.equal(inExStorageAfter)
        .to.equal(inExchangeAfter)
        .to.equal(user6)
        .not.to.equal(executableBefore);
    });

    it("update the exchange address", async () => {
        let _class = 0;
        let title = "Propsal-1: Update the exchange contract";
        let callData = await exec.contract.methods.updateExchangeAddress(
            _class,
            user6
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

        await wait(17000);
        await nextTime.increment();

        let exchangeBefore = await storage.getExchangeAddress();
        let exchangeInStorageBefore = await exStorage.getExchangeAddress();

        await gov.executeProposal(
            event.class,
            event.nonce,
            { from: operator }
        );

        let exchangeAfter = await storage.getExchangeAddress();
        let exchangeInStorageAfter = await exStorage.getExchangeAddress();

        expect(exchangeBefore)
        .to.equal(exchangeInStorageBefore);

        expect(exchangeAfter)
        .to.equal(exchangeInStorageAfter)
        .not.to.equal(exchangeBefore);
    });

    it("update the bank bond manager contract", async () => {
        let _class = 0;
        let title = "Propsal-1: Update the bank bond manager contract";
        let callData = await exec.contract.methods.updateBankBondManagerAddress(
            _class,
            user6
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

        await wait(17000);
        await nextTime.increment();

        let bankBondManagerBefore = await storage.getBankBondManagerAddress();
        let inBankBefore = await bank.getBankBondManager();
        let inDebondBondBefore = await erc3475.getBankBondManager();

        await gov.executeProposal(
            event.class,
            event.nonce,
            { from: operator }
        );

        let bankBondManagerAfter = await storage.getBankBondManagerAddress();
        let inBankAfter = await bank.getBankBondManager();
        let inDebondBondAfter = await erc3475.getBankBondManager();

        expect(bankBondManagerBefore)
        .to.equal(inDebondBondBefore)
        .to.equal(inBankBefore);

        expect(bankBondManagerAfter)
        .to.equal(inBankAfter)
        .to.equal(inDebondBondAfter)
        .not.to.equal(bankBondManagerBefore);
    });

    it("update the oracle contract", async () => {
        let _class = 0;
        let title = "Propsal-1: Update the oracle contract";
        let callData = await exec.contract.methods.updateOracleAddress(
            _class,
            user6
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

        await wait(17000);
        await nextTime.increment();

        let oracleBefore = await storage.getOracleAddress();
        let inBankBefore = await bank.getOracleAddress();
        let inBondManagerBefore = await bondManager.getOracleAddress();

        await gov.executeProposal(
            event.class,
            event.nonce,
            { from: operator }
        );

        let oracleAfter = await storage.getOracleAddress();
        let inBankAfter = await bank.getOracleAddress();
        let inBondManagerAfter = await bondManager.getOracleAddress();

        expect(oracleBefore)
        .to.equal(inBankBefore)
        .to.equal(inBondManagerBefore);

        expect(oracleAfter)
        .to.equal(inBankAfter)
        .to.equal(inBondManagerAfter)
        .not.to.equal(oracleBefore);
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