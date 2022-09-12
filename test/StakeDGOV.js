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

contract("Governance", async (accounts) => {
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

    it("Check DGOV have been staked", async () => {
        // A -> After staking
        let user1A = await dgov.balanceOf(user1);
        let user2A = await dgov.balanceOf(user2);
        let user3A = await dgov.balanceOf(user3);
        let user4A = await dgov.balanceOf(user4);
        let user5A = await dgov.balanceOf(user5);
        let userOA = await dgov.balanceOf(operator);
        let contrA = await dgov.balanceOf(stak.address);

        expect(user1A.toString()).to.equal(user1B.sub(toStake1).toString());
        expect(user2A.toString()).to.equal(user2B.sub(toStake2).toString());
        expect(user3A.toString()).to.equal(user3B.sub(toStake3).toString());
        expect(user4A.toString()).to.equal(user4B.sub(toStake4).toString());
        expect(user5A.toString()).to.equal(user5B.sub(toStake5).toString());
        expect(userOA.toString()).to.equal(userOB.sub(opStake).toString());
        expect(contrA.toString()).to.equal(
            contrB.add(user1B.add(user2B.add(user3B.add(user4B.add(user5B.add(userOB)))))
        ).toString());
    });

    it("Unstake DGOV tokens", async () => {
        let balContractBefore = await dgov.balanceOf(stak.address);

        await wait(5000);
        await nextTime.increment();

        let unstake = await stak.unstakeDgovToken(1, { from: user1 });
        let event = unstake.logs[0].args;
        let duration = event.duration.toString();

        let estimate = await stak.estimateInterestEarned(toStake1, duration);
        let balanceAfter = await dbit.balanceOf(user1);
        let balContractAfter = await dgov.balanceOf(stak.address);

        expect(
            (Number(balanceAfter.toString()) / 100).toFixed(0)
        ).to.equal(
            (Number(estimate.toString()) / 100).toFixed(0)
        );

        expect(balContractAfter.toString())
        .to.equal(
            balContractBefore.sub(toStake1).toString()
        );
    });

    it("Withdraw staking DGOV interest before end of staking", async () => {
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

    it("Cannot unstake DGOV before staking ends", async () => {
        expect(stak.unstakeDgovToken(1, { from: user1 }))
        .to.rejectedWith(
            Error,
            "VM Exception while processing transaction: revert Staking: still staking -- Reason given: Staking: still staking"
        );
    });

    it("stakes DGOV several times", async () => {
        amount1 = await web3.utils.toWei(web3.utils.toBN(30), 'ether');
        amount2 = await web3.utils.toWei(web3.utils.toBN(20), 'ether');
        amount3 = await web3.utils.toWei(web3.utils.toBN(100), 'ether');
        amountToMint = await web3.utils.toWei(web3.utils.toBN(150), 'ether');

        await bank.mintCollateralisedSupply(dgov.address, debondTeam, amountToMint, { from: operator });
        await dgov.transfer(user7, amountToMint, { from: debondTeam });
        await dgov.approve(stak.address, amountToMint, { from: user7 });
        await dgov.approve(user7, amountToMint, { from: user7 });

        // first staking
        await stak.stakeDgovToken(amount1, 0, { from: user7 });
        await wait(1000);
        await nextTime.increment();

        // second staking
        await stak.stakeDgovToken(amount2, 0, { from: user7 });
        await wait(1000);
        await nextTime.increment();

        // third staking
        await stak.stakeDgovToken(amount3, 0, { from: user7 });

        let stake = await storage.getStakedDOVOf(user7);
    
        expect(stake[0].amountDGOV.toString()).ordered.equal(amount1.toString());
        expect(stake[1].amountDGOV.toString()).ordered.equal(amount2.toString());
        expect(stake[2].amountDGOV.toString()).ordered.equal(amount3.toString());

        expect(
            Number(stake[1].startTime.toString()) - Number(stake[0].startTime.toString())
        ).to.equal(1);

        expect(
            Number(stake[2].startTime.toString()) - Number(stake[1].startTime.toString())
        ).to.equal(1);
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