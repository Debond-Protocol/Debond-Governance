const chai = require("chai");
const chaiAsPromised = require('chai-as-promised');
const { Console } = require("console");
const readline = require('readline');

chai.use(chaiAsPromised);
const expect = chai.expect;

const DGOV = artifacts.require("DGOVTest");
const DBIT = artifacts.require("DBITTest");
const APM = artifacts.require("APMTest");
const StakingDGOV = artifacts.require("StakingDGOV");
const GovStorage = artifacts.require("GovStorage");
const AdvanceBlockTimeStamp = artifacts.require("AdvanceBlockTimeStamp");

contract("Staking: Governance", async (accounts) => {
    let dgov;
    let dbit;
    let apm;
    let stakingContract;
    let storage;
    let nextTime;

    let user5B;
    let user6B;
    let user7B;
    let user8B;
    let userOB;
    let userTB;
    let contrB;

    let toStake3;
    let toStake4;
    let toStake5;
    let toStake6;
    let toStake7;
    let toStake8;
    let opStake;


    let operator = accounts[0];
    let debondTeam = accounts[1];
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
        dgov = await DGOV.deployed();
        dbit = await DBIT.deployed();
        apm = await APM.deployed();
        stakingContract = await StakingDGOV.deployed();
        nextTime = await AdvanceBlockTimeStamp.new();

        toStake5 = await web3.utils.toWei(web3.utils.toBN(750), 'ether');
        toStake6 = await web3.utils.toWei(web3.utils.toBN(810), 'ether');
        toStake7 = await web3.utils.toWei(web3.utils.toBN(45), 'ether');
        toStake8 = await web3.utils.toWei(web3.utils.toBN(130), 'ether');
        opStake = await web3.utils.toWei(web3.utils.toBN(430), 'ether');

        const amountToMint = await web3.utils.toWei(web3.utils.toBN(2500000), 'ether');
        await dbit.mintCollateralisedSupply(apm.address, amountToMint);

        await dgov.mint(user5, toStake5);
        await dgov.mint(user6, toStake6);
        await dgov.mint(user7, toStake7);
        await dgov.mint(user8, toStake8);
        await dgov.mint(operator, opStake);
        await dgov.mint(debondTeam, opStake);

        await dgov.approve(stakingContract.address, toStake5, { from: user5 });
        await dgov.approve(stakingContract.address, toStake6, { from: user6 });
        await dgov.approve(stakingContract.address, toStake7, { from: user7 });
        await dgov.approve(stakingContract.address, toStake8, { from: user8 });
        await dgov.approve(stakingContract.address, opStake, { from: operator });
        await dgov.approve(stakingContract.address, opStake, { from: debondTeam });

        user5B = await dgov.balanceOf(user5);
        user6B = await dgov.balanceOf(user6);
        user7B = await dgov.balanceOf(user7);
        user8B = await dgov.balanceOf(user8);
        userOB = await dgov.balanceOf(operator);
        userTB = await dgov.balanceOf(debondTeam);
        contrB = await dgov.balanceOf(stakingContract.address);

        await stakingContract.stakeDgovToken(toStake5, 0, { from: user5 });
        await stakingContract.stakeDgovToken(toStake6, 0, { from: user6 });
        await stakingContract.stakeDgovToken(toStake7, 0, { from: user7 });
        await stakingContract.stakeDgovToken(toStake8, 0, { from: user8 });
        await stakingContract.stakeDgovToken(opStake, 0, { from: operator });
        await stakingContract.stakeDgovToken(opStake, 0, { from: debondTeam });
    });

    it("Cannot unstake DGOV before staking ends", async () => {
        expect(stakingContract.unstakeDgovToken(1, { from: debondTeam }))
        .to.rejectedWith(
            Error,
            "VM Exception while processing transaction: revert Staking: still staking -- Reason given: Staking: still staking"
        );
    });

    it("Check DGOV have been staked", async () => {
        // A -> After staking
        let user5A = await dgov.balanceOf(user5);
        let user6A = await dgov.balanceOf(user6);
        let user7A = await dgov.balanceOf(user7);
        let user8A = await dgov.balanceOf(user8);
        let userOA = await dgov.balanceOf(operator);
        let userTA = await dgov.balanceOf(operator);
        let contrA = await dgov.balanceOf(stakingContract.address);

        expect(user5A.toString()).to.equal(user5B.sub(toStake5).toString());
        expect(user6A.toString()).to.equal(user6B.sub(toStake6).toString());
        expect(user7A.toString()).to.equal(user7B.sub(toStake7).toString());
        expect(user8A.toString()).to.equal(user8B.sub(toStake8).toString());
        expect(userOA.toString()).to.equal(userOB.sub(opStake).toString());
        expect(userTA.toString()).to.equal(userTB.sub(opStake).toString());
        expect(contrA.toString()).to.equal(
            contrB.add(user5B.add(user6B.add(user7B.add(user8B.add(userOB.add(userTB)))))
        ).toString());
    });

    it("Several inetrest withdraw before end of staking", async () => {
        toStake3 = await web3.utils.toWei(web3.utils.toBN(1200), 'ether');
        await dgov.mint(user3, toStake3);
        await dgov.approve(stakingContract.address, toStake3, { from: user3 });
        await stakingContract.stakeDgovToken(toStake3, 0, { from: user3 });

        let balAPMBef = await dbit.balanceOf(apm.address);
        let balUserBef = await dbit.balanceOf(user3);

        await wait(350);
        await nextTime.increment();

        // first withdraw
        await stakingContract.withdrawDbitInterest(1, { from: user3 });
        let bal1 = await dbit.balanceOf(apm.address);
        let dif1 = balAPMBef.sub(bal1);

        await wait(350);
        await nextTime.increment();

        // second withdraw
        await stakingContract.withdrawDbitInterest(1, { from: user3 });
        let bal2 = await dbit.balanceOf(apm.address);
        let dif2 = bal1.sub(bal2);

        await wait(150);
        await nextTime.increment();

        // third withdraw
        await stakingContract.withdrawDbitInterest(1, { from: user3 });
        let bal3 = await dbit.balanceOf(apm.address);
        let dif3 = bal2.sub(bal3);

        await wait(150);
        await nextTime.increment();

        let balAPMAft = await dbit.balanceOf(apm.address);
        let balUserAft = await dbit.balanceOf(user3);

        let dif = balAPMBef.sub(balAPMAft);
        let del = dif1.add(dif2.add(dif3));
        
        expect(dif.toString()).to.equal(del.toString());
        expect(balUserAft.toString()).to.equal(balUserBef.add(dif).toString());
    });

    it("Withdraw staking DGOV interest before end of staking", async () => {
        toStake4 = await web3.utils.toWei(web3.utils.toBN(50), 'ether');

        await dgov.mint(user4, toStake4);
        await dgov.approve(stakingContract.address, toStake4, { from: user4 });
        await stakingContract.stakeDgovToken(toStake4, 0, { from: user4 });

        let balAPMBef = await dbit.balanceOf(apm.address);
        let balUserBef = await dbit.balanceOf(user4);

        await stakingContract.withdrawDbitInterest(1, { from: user4 });

        let balAPMAft = await dbit.balanceOf(apm.address);
        let balUserAft = await dbit.balanceOf(user4);

        let diff = balAPMBef.sub(balAPMAft);

        expect(balUserAft.toString()).to.equal(balUserBef.add(diff).toString());
    });

    it("Unstake DGOV tokens", async () => {
        let balContractBefore = await dgov.balanceOf(stakingContract.address);

        await wait(5000);
        await nextTime.increment();

        let unstake = await stakingContract.unstakeDgovToken(1, { from: debondTeam });
        let event = unstake.logs[0].args;
        let duration = event.duration.toString();

        let estimate = await stakingContract.estimateInterestEarned(opStake, duration);
        let balanceAfter = await dbit.balanceOf(debondTeam);
        let balContractAfter = await dgov.balanceOf(stakingContract.address);

        expect(
            (Number(balanceAfter.toString()) / 100).toFixed(0)
        ).to.equal(
            (Number(estimate.toString()) / 100).toFixed(0)
        );

        expect(balContractAfter.toString())
        .to.equal(
            balContractBefore.sub(opStake).toString()
        );
    });

    it("stake DGOV several times", async () => {
        amount1 = await web3.utils.toWei(web3.utils.toBN(30), 'ether');
        amount2 = await web3.utils.toWei(web3.utils.toBN(20), 'ether');
        amount3 = await web3.utils.toWei(web3.utils.toBN(100), 'ether');
        amountToMint = await web3.utils.toWei(web3.utils.toBN(150), 'ether');

        await dgov.mint(user2, amountToMint);
        await dgov.approve(stakingContract.address, amountToMint, { from: user2 });

        // first staking
        await stakingContract.stakeDgovToken(amount1, 0, { from: user2 });
        await wait(1000);
        await nextTime.increment();

        // second staking
        await stakingContract.stakeDgovToken(amount2, 0, { from: user2 });
        await wait(1000);

        // third staking
        await stakingContract.stakeDgovToken(amount3, 0, { from: user2 });

        let stake = await storage.getStakedDGOVOf(user2);
    
        expect(stake[0].amountDGOV.toString()).ordered.equal(amount1.toString());
        expect(stake[1].amountDGOV.toString()).ordered.equal(amount2.toString());
        expect(stake[2].amountDGOV.toString()).ordered.equal(amount3.toString());
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