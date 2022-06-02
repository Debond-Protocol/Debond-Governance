const { VoteTokenInstance, StakingDGOVInstance, DGOVInstance } = require('../../types/truffle');

const VoteToken = artifacts.require("VoteToken");
const DGOV = artifacts.require("DGOV");
const Staking = artifacts.require("StakingDGOV");
const DBIT

var Vote: VoteTokenInstance;
var StakingContract: StakingDGOVInstance;
var dgov: DGOVInstance;


let amount = await web3.utils.toWei(web3.utils.toBN(1000), 'ether');
let amountVote = await web3.utils.toWei(web3.utils.toBN(60), 'ether');
let stakeAmtVoter1 = await web3.utils.toWei(web3.utils.toBN(10), 'ether');
let stakeAmtVoter2 = await web3.utils.toWei(web3.utils.toBN(20), 'ether');

contract("Vote Token Instance", async (accounts: String[]) => {

    let [deployer, voter1, voter2, debondOperator] = accounts;

    before("initialization", async () => {


        await dgov.mintCollateralisedSupply(voter1, amount, { from: deployer });
        await dgov.mintCollateralisedSupply(voter2, amount, { from: deployer });

        await Vote.mintVoteToken(voter1, amountVote, { from: voter1 });
        await Vote.mintVoteToken(voter2, amountVote, { from: voter2 });
    });
    it("is able to mint vote token ", async () => {
        expect(Vote.balanceOf(voter1)).toEqual(amountVote);
        expect(Vote.balanceOf(voter2)).toEqual(amountVote);
    })


    it("burning Vote tokens ", async () => {
        await Vote.burnVoteToken(voter1, stakeAmtVoter1, { from: voter1 });
        expect(Vote.balanceOf(voter1)).toEqual(amountVote - stakeAmtVoter1);
    });

    it("transfer from allows transfer of token only to staking contract and dGOV and fails for others ", async () => {
        await Vote.transferFrom(voter1, StakingContract.address, stakeAmtVoter1, { from: voter1 });
        expect(Vote.balanceOf(voter1)).toEqual(amountVote - stakeAmtVoter1);
        expect(Vote.transferFrom(voter2, debondOperator, stakeAmtVoter2, { from: voter2 })).to.revertWith("VoteToken: can't transfer vote tokens");
        await Vote.transfer(StakingContract.address, stakeAmtVoter2, { from: voter2 });
        expect(Vote.balanceOf(voter2)).toEqual(amountVote - stakeAmtVoter1);
        expect(Vote.transferFrom(voter2, debondOperator, 20, { from: voter2 })).to.revertWith("VoteToken: can't transfer vote tokens");

    });


});


function increaseTime(timeDelay: number) {
    const date = Date.now();
    let currentDate = null;
    do {
        currentDate = Date.now();
    } while (currentDate - date < timeDelay);

}



contract("Staking contract", async (accounts: String[]) => {
    let [deployer, voter1, voter2, debondOperator] = accounts;
    const day = 86400;

    before("initialization", async () => {
        StakingContract = Staking.deployed();
        Vote = await VoteToken.deployed();
        dgov = DGOV.deployed();
        // adding some of the initial params (similar to the previous contracts).

        await dgov.mintCollateralisedSupply(voter1, amount, { from: deployer });
        await dgov.mintCollateralisedSupply(voter2, amount, { from: deployer });
        await StakingContract.stakeDgovToken(voter1, stakeAmtVoter1, day, { from: voter1 });

    });

    it("Staking dGOV tokens works", async () => {

        expect(Vote.balanceOf(voter1)).toEqual(stakeAmtVoter1);
        except(StakingContract.getStakedDGOV(voter1)).toEqual(stakeAmtVoter1);

    });


    it("unstaking dGOV token works", async () => {
        await StakingContract.unstakeDgovToken(voter1, stakeAmtVoter1, { from: voter1 });
        expect(Vote.balanceOf(voter1)).toEqual(0);
        expect(StakingContract.getStakedDGOV(voter1)).toEqual(0);
    });

    it("calculate interest earned by the  voters   ", async () => {
        // increasing time to considerable amount in getting APY
        //increaseTime(100000000000); 
        expect(StakingContract.estimateInterestEarned(stakeAmtVoter2, 1000000000)).to.be.above(1);
    });




});