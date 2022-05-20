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


function mintGOVAllocation(address _to , uint256 _amount, uint proposal_class, uint proposal_nonce ) external ;



}