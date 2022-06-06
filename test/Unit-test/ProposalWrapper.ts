import {GovernanceInstance, GovStorageInstance , FakeProposalInstance , DebondDataInstance , ProposalWrapperInstance, BankInstance} from "../types/truffle-contracts";
const Governance = artifacts.require('Governance');
const GovStorage = artifacts.require('GovStorage') ;
const ProposalWrapper = artifacts.require('ProposalWrapper');
const 
const Bank = artifacts.require('Bank');
const data = artifacts.require('DebondData');




contract('Proposal Wrapper', async() => {

let gov : GovernanceInstance;
let proposalWrapper : ProposalWrapperInstance;
let data : DebondDataInstance;
let  bank : BankInstance;
const proposalClass = 2;
const proposalNonce = 0;




before("initialize", async () => {


gov = await Governance.deployed();
proposalWrapper = await ProposalWrapper.deployed(); 
bank = await Bank.deployed();

})


it("calls bank functions to set new params ", async() => {


const purchaseClassId : number[] = [0,1];
const purchaseable : bool[] = [true, true];

expect(proposalWrapper.setBenchmarkInterestRate('6', {from: gov.address})).toEqual(true);

const newBondClass = 2; 

await proposalWrapper.updatePurchesableClasses(newBondClass,proposalClass,  proposalNonce,  purchaseClassId , purchaseable));

//expect(bank.get)








});










});
