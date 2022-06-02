import {GovernanceInstance , ProposalWrapperInstance, GovStorageInstance} from "../types/truffle-contracts";

const Governance = artifacts.require("Governance");
const ProposalWrapper = artifacts.require("ProposalWrapper");

contract("Proposal Factory", async(account) => {

let  govInstance : GovernanceInstance;
let proposalWrapper : ProposalWrapperInstance;
let gs : GovStorageInstance;
let [deployer,proposer] = account;



before("initialization", async () => {
govInstance = await Governance.deployed();
proposalWrapper = await proposalWrapper.deployed();

govInstance.registerProposal()

})







})
