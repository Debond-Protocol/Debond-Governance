const ProposalFactory = artifacts.require("ProposalFactory");
const FakeProposal = artifacts.require("FakePropsoal");
const Governance = artifacts.require("Governance");
const stakingDGOV = artifacts.require("StakingDGOV");
const GovStorage = artifacts.require("GovStorage");
const VoteToken = artifacts.require("VoteToken");
const dGOV = artifacts.require("dGOV");
import {ProposalFactoryInstance, FakeProposalInstance, GovernanceInstance, stakingDGOVInstance,GovStorageInstance, VoteTokenInstance, dGOVInstance } from "../../types/truffle-contracts";
 const date = require("Date");


 function increaseTime(timeDelay: number) {
    const date = Date.now();
    let currentDate = null;
    do {
        currentDate = Date.now();
    } while (currentDate - date < timeDelay);

}

 contract("FakeProposal", async(deployer : String,accounts : String[], network  :number) =>{


let _FakeProposal : FakeProposalInstance;
let _ProposalFactory : ProposalFactoryInstance;
let governance : GovernanceInstance;
let GovStorage : GovStorageInstance;
let voteToken : VoteTokenInstance;
let stakingContract : stakingDGOVInstance;
let dgov : dGOVInstance;


const [debondOperator,Proposer,Voter1 , Voter2] = accounts;

beforeEach("initialization and passing of proposal", async () => {

_ProposalFactory = await ProposalFactory.deployed();
governance = await Governance.deployed();
GovStorage = await GovStorage.deployed();
voteToken = await voteToken.deployed();
dgov = await dgov.deployed();
stakingContract = await stakingDGOV.deployed();
// this will be deployed on the fly
_FakeProposal = await FakeProposal.new(debondOperator,governance.address,GovStorage.address, {from:Proposer});

const addressProposalFactory  = await _ProposalFactory.address;  
const _fakeProposalAddress = await  _FakeProposal.address;

await dgov.mintCollateralisedSupply(Proposer, web3.utils.toWei('1000', 'ether'), { from: Proposer});
await dgov.mintCollateralisedSupply(Voter1, web3.utils.toWei('1000', 'ether'), { from: Proposer});

await StakingContract.stakeDgovToken(Voter1, web3.utils.toWei('500', 'ether'), web3.utils.toBN(50), {from: Voter1});
await StakingContract.stakeDgovToken(Proposer, web3.utils.toWei('500', 'ether'), web3.utils.toBN(50), {from: Voter1});

// getting proposalHash (hashing the ABI)
const proposalhash = web3.utils.keccak256((_FakeProposal.deployed()).hash); //TODO: get the bytecode from the compiled information , the given method is not correct.

// Proposal details
const _class = 0;
const _nonce = 1;
 
// here check for proposal class / nonce  already initialized and what are the criterias (in the constructor of the governance).
await governance.registerProposal(0,1,Proposer,date.now() + web3.utils.toBN(10) ,/**dbitrewards */ 10 , _fakeProposalAddress, proposalhash, Date.now() , web3.utils.toBN(5), 1 /** converting the enum to the value ShouldApprove*/,[30, 10, 10] /**DBIT to be supplied during day s before proposal finished */);
// 1 is for "support" in enum.
await governance.vote(Voter1, 0 , 1 , _fakeProposalAddress, 1, 60, {from: Voter1});
increaseTime(10);

});
it("proposal execution  of the function passes ", async () => {

    expect(await governance.checkProposal(0,1)).toEqual(true);
   // expect(await _FakeProposal.create(0)).toEqual



});






})

