pragma solidity ^0.8.9;

interface IProposalFactory {

enum InterestRateType {FixedRate, FloatingRate}

function revokeProposal(
        uint128 _class,
        uint128 _nonce,
        uint128 revoke_proposal_class,
        uint128 revoke_proposal_nonce
    ) external  ;


function addProposalClass(uint _newProposalClass, uint proposal_class, uint proposal_nonce) external   returns(bool);



function addBondClass(uint newBondClass , uint proposal_class, uint proposal_nonce, string calldata symbol , InterestRateType interestRateType , address tokenAddress , uint periodTimestamp)  external  ;



function setDBITAmountForOneVote(uint256 _dbitAmount, uint proposal_class , uint proposal_nonce) external;



function transferDBITAllocation(address _from , address _to, uint256 _amount , uint proposal_class , uint proposal_nonce) external ;


function pauseAll(uint proposal_class , uint proposal_nonce, bool setState) external; 


function mintAllocationToken(uint proposal_class, uint proposal_nonce, uint amount)   external returns(bool);


function mintGOVAllocation(uint proposal_class, uint proposal_nonce, address _to , uint256 _amount, uint proposal_class, uint proposal_nonce ) external ;


function changeCommunityFundSize(
        uint128 _proposalClass,
        uint128 _proposalNonce,
        uint256 _newDBITBudget,
        uint256 _newDGOVBudget
    ) external returns(bool);



function updateDebondBondContract(uint proposal_class, uint proposal_nonce, address newBondAddress ) external;

function updateDBITContract(uint proposal_class,uint proposal_nonce, address newDBITAddress ) external;

function updateDGOVContract(uint proposal_class,uint proposal_nonce, address newDBITAddress) external;

function updateExchangeContract(uint proposal_class,uint proposal_nonce, address newExchangeAddress) external;


}