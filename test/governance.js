const chai = require("chai");
const chaiAsPromised = require('chai-as-promised');

chai.use(chaiAsPromised);
const expect = chai.expect;

const VoteToken = artifacts.require("VoteToken");
const ERC20Token = artifacts.require("ERC20Token");
const GovStorage = artifacts.require("GovStorage");
const StakingDGOV = artifacts.require("StakingDGOV");
const Governance = artifacts.require("Governance");

contract("governance storage", async (accounts) => {
    let dbit;
    let dgov;
    let storage;
    let voteToken;
    let stakingDGOV;
    let gov;

    let debondOperator = accounts[0];
    let user1 = accounts[1];
    let user2 = accounts[2];
    let user3 = accounts[3];

    beforeEach(async () => {
        storage = await GovStorage.deployed();
        dbit = await ERC20Token.new("Debond Index Token", "DBIT");
        dgov = await ERC20Token.new("Debond Governance Token", "DGOV");
        voteToken = await VoteToken.new("Debond Vote Token", "DVT", debondOperator);
        stakingDGOV = await StakingDGOV.new(
            dbit.address,
            dgov.address,
            voteToken.address,
            debondOperator,
            10000000
        );
        gov = await Governance.new(
            dbit.address,
            dgov.address,
            stakingDGOV.address,
            voteToken.address,
            debondOperator,
            1
        );
    
        // set the governance contract address in stakingDGOV
        await stakingDGOV.setGovernanceContract(gov.address);

        // set the stakingDGOV contract address in Vote Token
        await voteToken.setStakingDGOVContract(stakingDGOV.address);

        // set the governance contract address in voteToken
        await voteToken.setGovernanceContract(gov.address);
    });

    it("check contrats have been deployed", async () => {
        expect(storage.address).not.to.equal("");
        expect(dbit.address).not.to.equal("");
        expect(dgov.address).not.to.equal("");
        expect(voteToken.address).not.to.equal("");
        expect(stakingDGOV.address).not.to.equal("");

        let dbitName = await dbit.name();
        let dbitsymbol = await dbit.symbol();
        let dgovName = await dgov.name();
        let dgovsymbol = await dgov.symbol();
        let voteName = await voteToken.name();
        let votesymbol = await voteToken.symbol();

        let govAddress = await stakingDGOV.getGovernanceContract();

        expect(dbitName).to.equal("Debond Index Token");
        expect(dbitsymbol).to.equal("DBIT");
        expect(dgovName).to.equal("Debond Governance Token");
        expect(dgovsymbol).to.equal("DGOV");
        expect(voteName).to.equal("Debond Vote Token");
        expect(votesymbol).to.equal("DVT");
        expect(govAddress).to.equal(gov.address);

        let days = await storage.NUMBER_OF_SECONDS_IN_DAY();
        expect(days.toString()).to.equal('86400');

    });

    it("Mint some vote tokens", async () => {
        await voteToken.setGovernanceContract(accounts[0]); 

        let user = accounts[1];
        let balanceBefore = await voteToken.balanceOf(user);

        let amount = await web3.utils.toWei(web3.utils.toBN(10), 'ether');
        await voteToken.mintVoteToken(user, amount);
        let balanceAfter = await voteToken.balanceOf(user);

        expect(balanceAfter.toString())
            .to.equal(balanceBefore.add(web3.utils.toBN(amount)).toString());
    });

    it("Check inputs in stakingDGOV constructor", async () => {
        let dbitAddress = await stakingDGOV.dbit();
        let dgovAddress = await stakingDGOV.dGov();
        let voteTokenAddress = await stakingDGOV.voteToken();
        let operator = await stakingDGOV.debondOperator();
        let interest = await stakingDGOV.getInterestRate();

        expect(dbitAddress).to.equal(dbit.address);
        expect(dgovAddress).to.equal(dgov.address);
        expect(voteTokenAddress).to.equal(voteToken.address);
        expect(operator).to.equal(debondOperator);
        expect(interest.toString()).to.equal(web3.utils.toBN(10000000).toString());
    });

    it("check the dbit interest earned per vote token", async () => {
        let interest = await gov.getDBITAmountForOneVote();

        expect(interest.toString()).to.equal('1');
    });

    it("Register a proposal", async () => {
        let startTime = Date.now()
        let endTime = startTime + 120;

        let proposalHash = '0x321';

        await gov.registerProposal(
            1,
            user1,
            endTime,
            10,
            storage.address,
            proposalHash,
            [30, 10, 10]
        );

        let proposal = await gov.getProposal(1, 1);
        let dbitRewards = proposal.dbitDistributedPerDay;

        expect(proposal.owner).to.equal(user1);
        expect(proposal.contractAddress).to.equal(storage.address);
        expect(proposal.dbitRewards.toString()).to.equal('10');
        expect(proposal.status.toString()).to.equal('0');
        expect(dbitRewards).to.be.an('array');
        expect(dbitRewards).to.not.be.empty;
        expect(dbitRewards).to.include('10');
        expect(dbitRewards).to.include('30');
        expect(dbitRewards).to.have.lengthOf(3);
    });

    it("Register two proposals to check nonce generation", async () => {
        let startTime = Date.now()
        let endTime = startTime + 100;

        let proposalHash1 = '0x321';
        await gov.registerProposal(
            1,
            user1,
            endTime,
            20,
            storage.address,
            proposalHash1,
            [30, 10, 10]
        );

        let proposal1 = await gov.getProposal(1, 1);
        let dbitRewards1 = proposal1.dbitDistributedPerDay;

        startTime = Date.now()
        endTime = startTime + 120;

        let proposalHash2 = '0x310';
        await gov.registerProposal(
            1,
            user2,
            endTime,
            10,
            storage.address,
            proposalHash2,
            [20, 10, 5]
        );

        let proposal2 = await gov.getProposal(1, 2);
        let dbitRewards2 = proposal2.dbitDistributedPerDay;

        expect(proposal1.owner).to.equal(user1);
        expect(proposal1.contractAddress).to.equal(storage.address);
        expect(proposal1.dbitRewards.toString()).to.equal('20');
        expect(proposal1.status.toString()).to.equal('0');
        expect(dbitRewards1).to.be.an('array');
        expect(dbitRewards1).to.not.be.empty;
        expect(dbitRewards1).to.include('10');
        expect(dbitRewards1).to.include('30');
        expect(dbitRewards1).to.have.lengthOf(3);
        
        expect(proposal2.owner).to.equal(user2);
        expect(proposal2.contractAddress).to.equal(storage.address);
        expect(proposal2.dbitRewards.toString()).to.equal('10');
        expect(proposal2.status.toString()).to.equal('0');
        expect(dbitRewards2).to.be.an('array');
        expect(dbitRewards1).to.not.be.empty;
        expect(dbitRewards2).to.include('20');
        expect(dbitRewards2).to.include('10');
        expect(dbitRewards2).to.include('5');
        expect(dbitRewards2).to.have.lengthOf(3);
    });

    it("Stak DGOV tokens", async () => {
        let amount = await web3.utils.toWei(web3.utils.toBN(100), 'ether');
        let amountToSend = await web3.utils.toWei(web3.utils.toBN(50), 'ether');
        
        await dgov.mint(user1, amount, {from: user1});
        await dgov.approve(stakingDGOV.address, amountToSend, {from: user1});

        let balanceUserBefore = await dgov.balanceOf(user1);
        let balanceContractBefore = await dgov.balanceOf(stakingDGOV.address);

        await gov.stakeDGOV(
            user1,
            amountToSend,
            60
        );

        let balanceUserAfter = await dgov.balanceOf(user1);
        let balanceContractAfter = await dgov.balanceOf(stakingDGOV.address);

        let staked = await stakingDGOV.stackedDGOV(user1);

        expect(staked.amountDGOV.toString()).to.equal(amountToSend.toString());
        expect(staked.duration.toString()).to.equal('60');
        expect(balanceUserAfter.toString())
            .to.equal(
                balanceUserBefore
                .sub(
                    web3.utils.toBN(amountToSend)
                )
                .toString()
            );
        expect(balanceContractAfter.toString())
            .to.equal(
                balanceContractBefore
                .add(
                    web3.utils.toBN(amountToSend)
                )
                .toString()
            );        
    });

    it("Prevent user to transfer vote tokens", async () => {
        let amount = await web3.utils.toWei(web3.utils.toBN(100), 'ether');
        let amountToSend = await web3.utils.toWei(web3.utils.toBN(50), 'ether');
        
        await dgov.mint(user1, amount, {from: user1});
        await dgov.approve(stakingDGOV.address, amountToSend, {from: user1});

        await gov.stakeDGOV(
            user1,
            amountToSend,
            60
        );
        
        await voteToken.approve(voteToken.address, amountToSend, {from: user1});

        expect(voteToken.transferFrom(user1, user2, amountToSend))
            .to.rejectedWith(
                Error,
                "VM Exception while processing transaction: revert VoteToken: can't transfer vote tokens -- Reason given: VoteToken: can't transfer vote tokens"
            );
    });

    it("Unstak DGOV tokens", async () => {
        let amount = await web3.utils.toWei(web3.utils.toBN(100), 'ether');
        let amountToSend = await web3.utils.toWei(web3.utils.toBN(50), 'ether');
        
        await dgov.mint(user1, amount, {from: user1});
        await dgov.approve(stakingDGOV.address, amountToSend, {from: user1});

        // mint DBIT tokens to the governance contract to reward dGoV staker
        await dbit.mint(gov.address, amount, {from: user1});

        await gov.stakeDGOV(
            user1,
            amountToSend,
            2
        );

        // give allowance to the stakingDGOV contract to burn vote tokens
        await voteToken.approve(stakingDGOV.address, amountToSend, {from: user1});

        await wait(3000);

        let balanceBefore = await dgov.balanceOf(user1);

        await gov.unstakeDGOV(
            user1,
            user1,
            amountToSend
        );
        
        let balanceAfter = await dgov.balanceOf(user1);

        expect(balanceAfter.toString())
            .to.equal(
                balanceBefore
                .add(
                    web3.utils.toBN(amountToSend)
                )
                .toString()
            );
    });

    it("Check dGoV staker receives vote tokens", async () => {
        let amount = await web3.utils.toWei(web3.utils.toBN(100), 'ether');
        let amountToSend = await web3.utils.toWei(web3.utils.toBN(50), 'ether');
        
        await dgov.mint(user1, amount, {from: user1});
        await dgov.approve(stakingDGOV.address, amountToSend, {from: user1});

        let balanceUserBefore = await voteToken.balanceOf(user1);

        await gov.stakeDGOV(
            user1,
            amountToSend,
            60
        );

        let balanceUserAfter = await voteToken.balanceOf(user1);

        expect(balanceUserAfter.toString())
            .to.equal(
                balanceUserBefore
                .add(web3.utils.toBN(amountToSend))
                .toString()
            );
    });

    it("Check vote tokens are burned after unstaking dGoV tokens", async () => {
        let amount = await web3.utils.toWei(web3.utils.toBN(100), 'ether');
        let amountToSend = await web3.utils.toWei(web3.utils.toBN(50), 'ether');
        
        await dgov.mint(user1, amount, {from: user1});
        await dgov.approve(stakingDGOV.address, amountToSend, {from: user1});

        let balanceUserBefore = await voteToken.balanceOf(user1);

        await gov.stakeDGOV(
            user1,
            amountToSend,
            2
        );

        let balanceUserAfter = await voteToken.balanceOf(user1);

        expect(balanceUserAfter.toString())
            .to.equal(
                balanceUserBefore
                .add(web3.utils.toBN(amountToSend))
                .toString()
            );
        
        // Reedem vote Token => unstake dGoV
        await voteToken.approve(stakingDGOV.address, amountToSend, {from: user1});
        await wait(3000);
        await gov.unstakeDGOV(
            user1,
            user1,
            amountToSend
        );

        let balanceNow = await voteToken.balanceOf(user1);

        expect(balanceNow.toString())
            .to.equal(
                balanceUserAfter
                .sub(web3.utils.toBN(amountToSend))
                .toString()
            );
    });

    it("Vote for a proposal", async () => {
        let amount = await web3.utils.toWei(web3.utils.toBN(100), 'ether');
        let amountToSend = await web3.utils.toWei(web3.utils.toBN(50), 'ether');
        
        await dgov.mint(user1, amount, {from: user1});
        await dgov.approve(stakingDGOV.address, amountToSend, {from: user1});

        await dgov.mint(user2, amount, {from: user2});
        await dgov.approve(stakingDGOV.address, amountToSend, {from: user2});

        let endTime = Date.now() + 120;

        let proposalHash = '0x310';
        await gov.registerProposal(
            1,
            user1,
            endTime,
            10,
            storage.address,
            proposalHash,
            [30, 10, 10, 70]
        );

        await gov.stakeDGOV(
            user1,
            amountToSend,
            200
        );

        await gov.stakeDGOV(
            user2,
            amountToSend,
            200
        );

        let proposal = await gov.getProposal(1, 1);

        // approve the governance to transfer vote tokens
        await voteToken.approve(gov.address, amountToSend, {from: user1});
        await gov.vote(user1, 1, 1, storage.address, 0, amountToSend, {from: user1});

        await voteToken.approve(gov.address, amountToSend, {from: user2});
        await gov.vote(user2, 1, 1, storage.address, 1, amountToSend, {from: user2});

        proposal = await gov.getProposal(1, 1);

        let nbrOfVotes = await gov.getNumberOfVotePerDay(1, 1);
        let user1Stak = await stakingDGOV.stackedDGOV(user1);
        let user2Stak = await stakingDGOV.stackedDGOV(user2);

        expect(nbrOfVotes[0].toString()).to.equal(
            amountToSend.add(amountToSend).toString()
        );

        expect(nbrOfVotes[1].toString())
        .to.equal(nbrOfVotes[2].toString())
        .to.equal('0');

        expect(user1Stak.amountDGOV.toString()).to.equal(amountToSend.toString());
        expect(user2Stak.amountDGOV.toString()).to.equal(amountToSend.toString());
    });

    it("Check DBIT interest is trasfered to dGoV stakeer after unstaking", async () => {
        let amount = await web3.utils.toWei(web3.utils.toBN(100), 'ether');
        let amountToSend = await web3.utils.toWei(web3.utils.toBN(50), 'ether');
        
        await dgov.mint(user1, amount, {from: user1});
        await dgov.approve(stakingDGOV.address, amountToSend, {from: user1});

        // mint DBIT tokens to the governance contract to reward dGoV staker
        await dbit.mint(gov.address, amount, {from: user1});

        await gov.stakeDGOV(
            user1,
            amountToSend,
            7
        );

        // give allowance to the stakingDGOV contract to burn vote tokens
        await voteToken.approve(stakingDGOV.address, amountToSend, {from: user1});

        await wait(13000);
        await stakingDGOV.stackedDGOV(user1);

        let balanceBefore = await dbit.balanceOf(user1);

        await gov.unstakeDGOV(
            user1,
            user1,
            amountToSend
        );
        
        let balanceAfter = await dbit.balanceOf(user1);

        // estimate interest earned
        let interest = await stakingDGOV.estimateInterestEarned(
            amountToSend,
            7
        );

        console.log(balanceBefore.toString());
        console.log(balanceAfter.toString());
        console.log(interest.toString());
    });
});




async function wait(milliseconds) {
    const date = Date.now();
    let currentDate = null;
    do {
      currentDate = Date.now();
    } while (currentDate - date < milliseconds);
}