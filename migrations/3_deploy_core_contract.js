const GovStorage = artifacts.require("GovStorage");
const Governance = artifacts.require("Governance");
const ProposalWrapper = artifacts.require("ProposalWrapper");
const FakeProposal = artifacts.require("FakeProposal");
const StakingContract = artifacts.require("StakingContract");
const GovernanceOwnable = artifacts.require("GovernanceOwnable");
const governance
const dgov = artifacts.require("DBIT");
const dbit = artifacts.require("DGOV");
const vote = artifacts.require("VoteToken");
module.exports = async function (deployer,networks,accounts) {
    const[debondOperator , debondTeam] = accounts;

    const _dgov = await dgov.deployed();
    const _dbit = await dbit.deployed();
    const _vote = await vote.deployed();
    const interestRate  = 10;

    deployer.deploy(StakingContract,_dgov.address,_dbit.address, debondOperator,interestRate);
    const stakingDGOV = StakingContract.deployed();
    
    deployer.deploy(GovStorage,debondOperator);

    const govStorage = await GovStorage.deployed();

    deployer.deploy(Governance, _dbit.address, _dgov.address, stakingDGOV.address ,_vote.address , debondOperator, debondTeam, govStorage.address);

    const governance =  Governance.deployed();

    await govStorage.setGovernanceAddress(governance.address);


  //  deployer.deploy(ProposalWrapper,  );
    
    
    
    deploy.deploy()

};
