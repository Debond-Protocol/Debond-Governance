## Debond Governance:

Contracts that handle the upgradation of the protocol parameters and capital allocation  by allowing the DGOV holders to participate in the process either via adding the proposal to be considered for voting or voting itself for the already existing proposal. the contracts  definition are inspired  from  the modified version of[openzeppelin governance]() that is efficient in storing 

there are two main  types of contracts present in the  debond governance:
    - Core governance contract : it consist of the main governance contract, GovernanceSharedStorage and Executable contract that holds the logic for the lifecycle of proposals for debond protocol (explained further in contracts section). 

    - Vote token/staking contract: these contracts provide mechanism for DGOV holders to stake  their tokens into Vote tokens (for voting purpose as well as getting interest on their staking).



## structures: 

- the proposals are divided into several classes, each class stores information about the proposal lifecycle: 
    - timelock: Is the time period after issuance proposal, during which vote are to be locked. 
    - minimum_approval_percentage_needed: Is the minimum quorum needed to approve the proposal.
    - Architect approval: bool for checking whether the given proposal is to be approved by the Architect(ie the Veto address). 
    - maximum execution time: Is the max time after the finishing of the voting period for approved proposal, before which the proposal should be executed. 
    
    ```solidity
        mapping(uint128 => uint256[6]) public proposalClassInfo;
        // with the mapping starting from  proposalClassInfo[_proposalClass][0] = timelock, proposalClassInfo[_proposalClass][0] = min_approval_percent and so on .... 
    ```
    -  proposal class 1 and 2 have the proposals with highest priority to be checked by the veto address (ie multisig address being the deployer of all the contract) and it has  higher timelock and approval percentage needed. 

- each proposal stores the following information: 
    ```solidity
    struct  Proposal {
        uint256 id;
        uint256 startTime;
        uint256 endTime;
        address proposer;
        ProposalStatus status;
        ProposalApproval approvalMode;
    }    
    ```
    where most of the information is self explanatory, and ProposalStatus is an enum that represents the state of the proposal (Active,Canceled,Pending,Defeated,Succeeded,Executed) and ProposalApproval enum determines the nature of the evaluation of the proposal. this is defined by the following conditions: 
        1. NoVote : for the proposal by  core address of debond 
        2. Approve: the proposal is approved the moment it gets sufficient pro votes.
        3. ApproveAndVeto: the veto condition (explained in **Working process**)




## Contracts:

1. GovSharedStorage: this stores the structures and mappings referred by  vote token for referring to the votes calculation process (explained in voteCounting contract)

2. GovSettings : and util contracts for 






## Working process:

1. Proposal creator (with DGOV tokens) adds all the values  for his proposal in the frontend .
    - Proposal contract it inherits only the functions by inheriting from the interface of the governance contract. Example of the contract :[here](./contracts/Proposal/Proposal.sol). Then the Proposal time period starts and then voting starts  after the delay period (defined in govSettings by the   deployer/ governance) and rests till the `endTime`. 

    ```solidity
    function createProposal(
        uint128 _class,
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas,
        string memory _description
    )
    ```

2. On the voter side, they stake their tokens in the StakingDGOV contract, which then mints equivalent number of vote tokens for him and puts his DGOV tokens on timelock. Voters are also incentivised by providing them intererst in DBIT once the timelock passes, and their interest depends upon the number of days the user has voted on any proposal. 

3. Once the proposal endtime passes, the frontend checks for the proposal votes (pro,con) and if it satisfies both conditions (pro > con along with the votes being greater than minimum approval votes in the given proposal class). 
    - then we check if veto is required (specially for proposal nonces in class 1 or 2), if yes then veto address will finally determine the fate of proposal status (Accepted/ rejected).
    - else the accepted proposal can be executed by the proposer

4. And then eventually voters can redeem their unused VOTE token back to DGOV, and recovering the DBIT interest.  







## Security Considerations:





## Contracts dependence  diagram:




