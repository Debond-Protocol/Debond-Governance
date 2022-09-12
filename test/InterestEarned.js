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

        await dgov.approve(user6, toStake1, { from: user1 });

        await stak.stakeDgovToken(toStake1, 0, { from: user1 });
        await stak.stakeDgovToken(toStake2, 0, { from: user2 });
        await stak.stakeDgovToken(toStake3, 0, { from: user3 });
        await stak.stakeDgovToken(toStake4, 0, { from: user4 });
        await stak.stakeDgovToken(toStake5, 0, { from: user5 });
        await stak.stakeDgovToken(opStake, 0, { from: operator });
    });

    it("check DBIT earned by staking DGOV", async () => {
        await wait(2000);
        await nextTime.increment();
        let balAPMBef = await dbit.balanceOf(apm.address);
        let balUserBef = await dbit.balanceOf(user1);

        await stak.withdrawDbitInterest(1, { from: user1 });

        let balAPMAft = await dbit.balanceOf(apm.address);
        let balUserAft = await dbit.balanceOf(user1);

        let diff = balAPMBef.sub(balAPMAft);

        expect(balUserAft.toString()).to.equal(balUserBef.add(diff).toString());
    });

    it("Several inetrest withdraw before end of staking", async () => {
        await wait(2000);
        await nextTime.increment();
        let balAPMBef = await dbit.balanceOf(apm.address);
        let balUserBef = await dbit.balanceOf(user1);

        // first withdraw
        await stak.withdrawDbitInterest(1, { from: user1 });
        let bal1 = await dbit.balanceOf(apm.address);
        let dif1 = balAPMBef.sub(bal1);

        // second withdraw
        await stak.withdrawDbitInterest(1, { from: user1 });
        let bal2 = await dbit.balanceOf(apm.address);
        let dif2 = bal1.sub(bal2);

        // third withdraw
        await stak.withdrawDbitInterest(1, { from: user1 });
        let bal3 = await dbit.balanceOf(apm.address);
        let dif3 = bal2.sub(bal3);

        let balAPMAft = await dbit.balanceOf(apm.address);
        let balUserAft = await dbit.balanceOf(user1);

        let dif = balAPMBef.sub(balAPMAft);
        let del = dif1.add(dif2.add(dif3));

        expect(dif.toString()).to.equal(del.toString());
        expect(balUserAft.toString()).to.equal(balUserBef.add(dif).toString());
    });

    it("Check DBIT earned by voting", async () => {
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

        await wait(17000);
        await nextTime.increment();

        let apmBalBef1 = await dbit.balanceOf(apm.address);
        let balUser1Bef = await dbit.balanceOf(user1);
        let balUser2Bef = await dbit.balanceOf(user2);

        await stak.unlockVotes(event.class, event.nonce, { from: user1 });
        let apmBalBef2 = await dbit.balanceOf(apm.address);
        let balUser1Aft = await dbit.balanceOf(user1);
        let dif1 = apmBalBef1.sub(apmBalBef2);

        await stak.unlockVotes(event.class, event.nonce, { from: user2 });
        let apmBalBef3 = await dbit.balanceOf(apm.address);
        let balUser2Aft = await dbit.balanceOf(user2);
        let dif2 = apmBalBef2.sub(apmBalBef3);

        expect(balUser1Aft.toString()).to.equal(balUser1Bef.add(dif1).toString());
        expect(balUser2Aft.toString()).to.equal(balUser2Bef.add(dif2).toString());
        expect(apmBalBef1.toString()).to.equal(apmBalBef3.add(dif1.add(dif2)).toString());
    });

    it("check DBIT earned by voting for several proposals", async () => {
        amount1 = await web3.utils.toWei(web3.utils.toBN(30), 'ether');
        amount2 = await web3.utils.toWei(web3.utils.toBN(20), 'ether');
        amount3 = await web3.utils.toWei(web3.utils.toBN(100), 'ether');
        amountToMint = await web3.utils.toWei(web3.utils.toBN(150), 'ether');

        await bank.mintCollateralisedSupply(dgov.address, debondTeam, amountToMint, { from: operator });
        await dgov.transfer(user7, amountToMint, { from: debondTeam });
        await dgov.approve(stak.address, amountToMint, { from: user7 });
        await dgov.approve(user7, amountToMint, { from: user7 });

        // staking
        await stak.stakeDgovToken(amount1, 0, { from: user7 });
        await stak.stakeDgovToken(amount2, 1, { from: user7 });
        await stak.stakeDgovToken(amount3, 2, { from: user7 });

        let amountVote1 = await storage.getAvailableVoteTokens(user7, 1);
        let amountVote2 = await storage.getAvailableVoteTokens(user7, 2);
        let amountVote3 = await storage.getAvailableVoteTokens(user7, 3);
        let totalVote = await vote.availableBalance(user7);

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

        let e1 = res1.logs[0].args;

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

        let e2 = res2.logs[0].args;

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
        
        let e3 = res3.logs[0].args;

        await gov.vote(e1.class, e1.nonce, user7, 0, amountVote1, 1, { from: user7 });
        await gov.vote(e2.class, e2.nonce, user7, 0, amountVote2, 2, { from: user7 });
        await gov.vote(e3.class, e3.nonce, user7, 0, amountVote3, 3, { from: user7 });

        await wait(17000);
        await nextTime.increment();

        let apmBalBef1 = await dbit.balanceOf(apm.address);
        let balUser1 = await dbit.balanceOf(user7);

        await stak.unlockVotes(e1.class, e1.nonce, { from: user7 }); 
        let apmBalBef2 = await dbit.balanceOf(apm.address);
        let balUser2 = await dbit.balanceOf(user7);
        let dif1 = apmBalBef1.sub(apmBalBef2);

        await stak.unlockVotes(e2.class, e2.nonce, { from: user7 }); 
        let apmBalBef3 = await dbit.balanceOf(apm.address);
        let balUser3 = await dbit.balanceOf(user7);
        let dif2 = apmBalBef2.sub(apmBalBef3);

        await stak.unlockVotes(e3.class, e3.nonce, { from: user7 }); 
        let apmBalBef4 = await dbit.balanceOf(apm.address);
        let balUser4 = await dbit.balanceOf(user7);
        let dif3 = apmBalBef3.sub(apmBalBef4);

        expect(balUser4.toString()).to.equal(balUser1.add(dif1.add(dif2.add(dif3))).toString());
        expect(apmBalBef1.toString()).to.equal(apmBalBef4.add(dif1.add(dif2.add(dif3))).toString());
    });

    it("check token owner get rewarded with DBIT after the delagated user has voted", async () => {
        let _class = 0;
        let title = "Propsal-1: Update the benchMark interest rate";
        let callData = await exec.contract.methods.updateBenchmarkInterestRate(
            _class,
            '10'
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

        await gov.vote(event.class, event.nonce, user1, 0, amountVote1, 1, { from: user6 });

        await wait(17000);
        await nextTime.increment();

        let apmBalBef = await dbit.balanceOf(apm.address);
        let balUser1Bef = await dbit.balanceOf(user1);
        let balUser6Bef = await dbit.balanceOf(user6);

        await stak.unlockVotes(event.class, event.nonce, { from: user1 });

        let apmBalAft = await dbit.balanceOf(apm.address);
        let balUser1Aft = await dbit.balanceOf(user1);
        let balUser6Aft = await dbit.balanceOf(user6);
        let dif = apmBalBef.sub(apmBalAft);

        expect(balUser6Bef.toString()).to.equal(balUser6Aft.toString());
        expect(apmBalBef.toString()).to.equal(apmBalAft.add(dif).toString());
        expect(balUser1Aft.toString()).to.equal(balUser1Bef.add(dif).toString());
    });

    it("check the delegated user cannot unlock delegator's vote tokens", async () => {
        let _class = 0;
        let title = "Propsal-1: Update the benchMark interest rate";
        let callData = await exec.contract.methods.updateBenchmarkInterestRate(
            _class,
            '10'
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

        await gov.vote(event.class, event.nonce, user1, 0, amountVote1, 1, { from: user6 });

        await wait(17000);
        await nextTime.increment();

        expect(stak.unlockVotes(event.class, event.nonce, { from: user6 }))
        .to.rejectedWith(
            Error,
            "VM Exception while processing transaction: revert Staking: no DGOV staked or haven't voted -- Reason given: Staking: no DGOV staked or haven't voted"
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