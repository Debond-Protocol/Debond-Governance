const chai = require("chai");
const chaiAsPromised = require('chai-as-promised');
const { Console } = require("console");
const readline = require('readline');

chai.use(chaiAsPromised);
const expect = chai.expect;

const DBIT = artifacts.require("DBITToken");
const DGOV = artifacts.require("DGOVToken");
const ERC3475 = artifacts.require("ERC3475");
const Bank = artifacts.require("Bank");
const APMTest = artifacts.require("APMTest");
const VoteToken = artifacts.require("VoteToken");
const StakingDGOV = artifacts.require("StakingDGOV");
const GovSettings = artifacts.require("GovSettings");
const Governance = artifacts.require("Governance");
const VoteCounting = artifacts.require("VoteCounting");
const Executable = artifacts.require("Executable");
const GovStorage = artifacts.require("GovStorage");
const ProposalLogic = artifacts.require("ProposalLogic");
const GovernanceMigrator = artifacts.require("GovernanceMigrator");
const ExchangeStorage = artifacts.require("ExchangeStorage");
const BankData = artifacts.require("BankData");
const BankBondManager = artifacts.require("BankBondManager");

contract("Governance", async (accounts) => {
    let gov;
    let apm;
    let bank;
    let dbit;
    let dgov;
    let stak;
    let vote;
    let exec;
    let count;
    let logic;
    let erc3475;
    let storage;
    let settings;
    let amountToMint;
    let amountToStake;
    let migrator;
    let exStorage;
    let bankData;
    let bondManager;

    let balanceUser1BeforeStake;
    let balanceStakingContractBeforeStake;

    let operator = accounts[0];
    let debondTeam = accounts[1];
    let user1 = accounts[2];
    let user2 = accounts[3];
    let user3 = accounts[4];
    let user4 = accounts[5];
    let user5 = accounts[6];
    let user6 = accounts[7];

    let ProposalStatus = {
        Active: '0',
        Canceled: '1',
        Pending: '2',
        Defeated: '3',
        Succeeded: '4',
        Executed: '5'
    }

    beforeEach(async () => {
        count = await VoteCounting.new();
        migrator = await GovernanceMigrator.new();
        vote = await VoteToken.new("Debond Vote Token", "DVT", operator);
        storage = await GovStorage.new(debondTeam, operator);
        settings = await GovSettings.new(storage.address);
        exec = await Executable.new(storage.address);
        gov = await Governance.new(storage.address, count.address);
        exStorage = await ExchangeStorage.new(gov.address, operator, exec.address);
        bondManager = await BankBondManager.new(gov.address, exec.address, operator);
        bank = await Bank.new(gov.address, exec.address, bondManager.address, operator);
        erc3475 = await ERC3475.new(gov.address, exec.address, bank.address, bondManager.address);
        apm = await APMTest.new(gov.address, bank.address, exec.address);
        bankData = await BankData.new(gov.address, bank.address, exec.address);
        dbit = await DBIT.new(gov.address, bank.address, operator, operator, exec.address);
        dgov = await DGOV.new(gov.address, bank.address, operator, operator, exec.address);
        logic = await ProposalLogic.new(operator, storage.address, vote.address, count.address);
        stak = await StakingDGOV.new(dgov.address, vote.address, gov.address, logic.address, storage.address, exec.address);

        // initialize all contracts
        await storage.setUpGoup1(
            gov.address,
            dgov.address,
            dbit.address,
            apm.address,
            operator,
            bondManager.address,
            operator,
            stak.address,
            vote.address,
            count.address,
            {from: operator}
        );

        await storage.setUpGoup2(
            settings.address,
            logic.address,
            exec.address,
            bank.address,
            bankData.address,
            erc3475.address,
            operator,
            exStorage.address,
            operator,
            operator,
            {from: operator}
        );

        // set the stakingDGOV contract address into Vote Token
        await vote.setStakingDGOVContract(stak.address);

        // set the governance contract address in voteToken
        await vote.setGovernanceContract(gov.address);

        // set the proposal logic contract address in voteToken
        await vote.setproposalLogicContract(logic.address);

        // set GovStorage contract address in voteCounting
        await count.setGovStorageContract(storage.address);

        // set the proposal logic address into voteCounting
        await count.setProposalLogicContract(logic.address);

        // set the staking contract address into proposalLogic
        await logic.setStakingContract(stak.address);

        // set the apm address in Bank
        await bank.setAPMAddress(apm.address);

        // set govStorage address in GovernanceMigrator
        await migrator.setGovStorageAddress(gov.address);

        // set Bank in Bank Bond Manager
        await bondManager.setBank(bank.address);

        //let amount = await web3.utils.toWei(web3.utils.toBN(100), 'ether');
        let amount = await web3.utils.toWei(web3.utils.toBN(20000), 'ether');
        let amountToSend = await web3.utils.toWei(web3.utils.toBN(10000), 'ether');
        await bank.mintCollateralisedSupply(dbit.address, debondTeam, amount, { from: operator });
        await dbit.transfer(gov.address, amountToSend, { from: debondTeam });
        await dbit.transfer(apm.address, amountToSend, { from: debondTeam });

        await bank.mintCollateralisedSupply(dgov.address, debondTeam, amountToSend, { from: operator  });
        await dgov.transfer(apm.address, amountToSend, { from: debondTeam });
 
        await bank.update(
            amountToSend,
            amountToSend,
            dbit.address,
            dgov.address,
            { from: operator }
        );

        //amountToMint = await web3.utils.toWei(web3.utils.toBN(200), 'ether');
        amountToMint = await web3.utils.toWei(web3.utils.toBN(200), 'ether');
        amountToStake = await web3.utils.toWei(web3.utils.toBN(50), 'ether');

        await bank.mintCollateralisedSupply(dgov.address, debondTeam, amountToMint, { from: operator });
        await dgov.transfer(user1, amountToStake, { from: debondTeam });
        await dgov.transfer(user2, amountToStake, { from: debondTeam });
        await dgov.transfer(user3, amountToStake, { from: debondTeam });
        await dgov.transfer(operator, amountToStake, { from: debondTeam });
        await dgov.approve(stak.address, amountToStake, { from: user1 });
        await dgov.approve(stak.address, amountToStake, { from: user2 });
        await dgov.approve(stak.address, amountToStake, { from: user3 });
        await dgov.approve(stak.address, amountToStake, { from: operator });
        await dgov.approve(user1, amountToStake, { from: user1 });
        await dgov.approve(user2, amountToStake, { from: user2 });
        await dgov.approve(user3, amountToStake, { from: user3 });
        await dgov.approve(operator, amountToStake, { from: operator });

        await dgov.approve(user4, amountToStake, { from: user1 });

        balanceUser1BeforeStake = await dgov.balanceOf(user1);
        balanceUser2BeforeStake = await dgov.balanceOf(user1);
        balanceUser3BeforeStake = await dgov.balanceOf(user1);
        balanceStakingContractBeforeStake = await dgov.balanceOf(stak.address);

        await gov.stakeDGOV(amountToStake, 10, { from: user1 });
        await gov.stakeDGOV(amountToStake, 10, { from: user2 });
        await gov.stakeDGOV(amountToStake, 10, { from: user3 });
        await gov.stakeDGOV(amountToStake, 10, { from: operator });
    });

    it("Stake DGOV tokens", async () => {
        let balanceUser1AfterStake = await dgov.balanceOf(user1);
        let balanceStakingContractAfterStake = await dgov.balanceOf(stak.address);

        expect(
            balanceUser1AfterStake.toString()
        ).to.equal(
            balanceUser1BeforeStake.sub(amountToStake).toString()
        );

        expect(
            Number(
                balanceStakingContractAfterStake.toString()
            )
        ).to.equal(
            Number(
                balanceStakingContractBeforeStake
                    .add(
                        amountToStake
                    ).toString()
            ) * 4
        );
    });

    it("Unstake DGOV tokens", async () => {
        let balBefore = await dgov.balanceOf(user1);
        let balContractBefore = await dgov.balanceOf(stak.address);

        await wait(12000);

        let unstake = await gov.unstakeDGOV(1, { from: user1 });
        let event = unstake.logs[0].args;
        let duration = event.duration.toString();

        let estimate = await storage.estimateInterestEarned(amountToStake, duration);

        let balanceAfter = await dbit.balanceOf(user1);

        let balAfter = await dgov.balanceOf(user1);
        let balContractAfter = await dgov.balanceOf(stak.address);

        expect(balContractAfter.toString())
            .to.equal(
                balContractBefore.sub(amountToStake).toString()
            );

        expect(balAfter.toString())
            .to.equal(
                balBefore.add(amountToStake).toString()
            );

        expect(
            (Number(balanceAfter.toString()) / 100).toFixed(0)
        ).to.equal(
            (Number(estimate.toString()) / 100).toFixed(0)
        );
    });

    it("Withdraw staking DGOV interest before end of staking", async () => {
        amountToStake = await web3.utils.toWei(web3.utils.toBN(50), 'ether');

        await bank.mintCollateralisedSupply(dgov.address, debondTeam, amountToStake, { from: operator });
        await dgov.transfer(user6, amountToStake, { from: debondTeam });
        await dgov.approve(stak.address, amountToStake, { from: user6 });
        await dgov.approve(user6, amountToStake, { from: user6 });

        await gov.stakeDGOV(amountToStake, 10, { from: user6 });

        await wait(4000);

        await gov.withdrawInterest(1, { from: user6 });

        await wait(8000);

        let unstake = await gov.unstakeDGOV(1, { from: user6 });
        let event = unstake.logs[0].args;
        let duration = event.duration.toString();

        let estimate = await storage.estimateInterestEarned(amountToStake, duration);

        let userBalanceFinal = await dbit.balanceOf(user6);

        expect(
            (Number(userBalanceFinal.toString()) / 1000).toFixed(0)
        ).to.equal(
            (Number(estimate.toString()) / 1000).toFixed(0)
        );
    });

    it("Several inetrest withdraw before end of staking", async () => {
        amountToStake = await web3.utils.toWei(web3.utils.toBN(50), 'ether');

        await bank.mintCollateralisedSupply(dgov.address, debondTeam, amountToStake, { from: operator });
        await dgov.transfer(user6, amountToStake, { from: debondTeam });
        await dgov.approve(stak.address, amountToStake, { from: user6 });
        await dgov.approve(user6, amountToStake, { from: user6 });

        await gov.stakeDGOV(amountToStake, 10, { from: user6 });

        await wait(2000);
        await gov.withdrawInterest(1, { from: user6 });
        await wait(3000);
        await gov.withdrawInterest(1, { from: user6 });

        await wait(6000);

        let unstake = await gov.unstakeDGOV(1, { from: user6 });
        let event = unstake.logs[0].args;
        let duration = event.duration.toString();

        let userBalanceFinal = await dbit.balanceOf(user6);
        let estimate = await storage.estimateInterestEarned(amountToStake, duration);

        expect(
            (Number(userBalanceFinal.toString()) / 1000).toFixed(0)
        ).to.equal(
            (Number(estimate.toString()) / 1000).toFixed(0)
        );
    });

    it('Cannot unstake DGOV before staking ends', async () => {
        amountToStake = await web3.utils.toWei(web3.utils.toBN(50), 'ether');

        await bank.mintCollateralisedSupply(dgov.address, debondTeam, amountToStake, { from: operator });
        await dgov.transfer(user5, amountToStake, { from: debondTeam });
        await dgov.approve(stak.address, amountToStake, { from: user5 });
        await dgov.approve(user5, amountToStake, { from: user5 });

        await gov.stakeDGOV(amountToStake, 10, { from: user5 });

        expect(gov.unstakeDGOV(1, { from: user5 }))
            .to.rejectedWith(
                Error,
                "VM Exception while processing transaction: revert Staking: still staking -- Reason given: Staking: still staking"
            );
    });

    it("Create a proposal", async () => {
        let _class = 0;
        let _nonce = await gov.generateNewNonce(_class);

        let title = "Propsal-1: Update the benchMark interest rate";
        let callData = await gov.contract.methods.updateBenchmarkInterestRate(
            _class,
            _nonce,
            '10'
        ).encodeABI();
        
        let res = await gov.createProposal(
            _class,
            _nonce,
            [gov.address],
            [0],
            [callData],
            title,
            web3.utils.soliditySha3(title),
            { from: operator }
        );

        // fetch data from the emitted event
        let event = res.logs[0].args;

        // fetch data from structure Proposal
        let nonce = res.logs[0].args.nonce;
        let proposal = await storage.getProposalStruct(_class, nonce);

        let approvalMode = await logic.getApprovalMode(_class);
        
        expect(event.class.toString()).to.equal(_class.toString());
        expect(event.nonce.toString()).to.equal(nonce.toString());
        expect(event.targets[0]).to.equal(gov.address);
        expect(event.values[0].toString()).to.equal('0');
        expect(event.calldatas[0].toString()).to.equal(callData.toString())
        
        expect(event.startVoteTime.toString())
            .to.equal(proposal.startTime.toString());

        expect(event.endVoteTime.toString())
            .to.equal(proposal.endTime.toString());

        expect(event.proposer).to.equal(operator);

        expect(proposal.approvalMode.toString())
            .to.equal(approvalMode.toString());

        expect(event.title).to.equal(title);
        expect(event.descriptionHash).to.equal(web3.utils.soliditySha3(title));
    });

    it("Cancel a proposal", async () => {
        let _class = 0;
        let _nonce = await gov.generateNewNonce(_class);

        let title = "Propsal-1: Update the benchMark interest rate";
        let callData = await gov.contract.methods.updateBenchmarkInterestRate(
            _class,
            _nonce,
            '10'
        ).encodeABI();

        let res = await gov.createProposal(
            _class,
            _nonce,
            [gov.address],
            [0],
            [callData],
            title,
            web3.utils.soliditySha3(title),
            { from: operator }
        );

        let event = res.logs[0].args;
        
        await gov.cancelProposal(event.class, event.nonce, { from: operator });
        let status = await storage.getProposalStatus(event.class, event.nonce);

        expect(status.toString()).to.equal(ProposalStatus.Canceled);
    });

    it("Migrate tokens from Governance contract to Bank contract", async () => {
        let amount = await web3.utils.toWei(web3.utils.toBN(20000), 'ether');
        await bank.mintCollateralisedSupply(dbit.address, gov.address, amount, { from: operator });

        // create a proposal
        let _class = 0;
        let _nonce = await gov.generateNewNonce(_class);

        let title = "Propsal-1: Migrate tokens from Governance to Bank";
        let callData = await gov.contract.methods.migrateToken(
            _class,
            _nonce,
            dbit.address,
            gov.address,
            bank.address,
            amount
        ).encodeABI();

        let res = await gov.createProposal(
            _class,
            _nonce,
            [gov.address],
            [0],
            [callData],
            title,
            web3.utils.soliditySha3(title),
            { from: operator }
        );

        let event = res.logs[0].args;

        await gov.vote(event.class, event.nonce, user1, 0, amountToStake, 1, { from: user1 });
        await gov.vote(event.class, event.nonce, user2, 1, amountToStake, 1, { from: user2 });
        await gov.vote(event.class, event.nonce, user3, 0, amountToStake, 1, { from: user3 });
        
        await gov.veto(event.class, event.nonce, true, { from: operator });

        await wait(18000);

        let balanceGovBefore = await dbit.balanceOf(gov.address);
        let balanceBankBefore = await dbit.balanceOf(bank.address);

        // Execute the proposal
        await gov.executeProposal(
            event.class,
            event.nonce,
            { from: operator }
        );

        let balanceGovAfter = await dbit.balanceOf(gov.address);
        let balanceBankAfter = await dbit.balanceOf(bank.address);

        expect(
            balanceGovAfter.toString()
        ).to.equal(
            balanceGovBefore.sub(amount).toString()
        );
        expect(
            balanceBankAfter.toString()
        ).to.equal(
            balanceBankBefore.add(amount).toString()
        );
    });

    it.only("update the bank contract", async () => {
        // create a proposal
        let _class = 0;
        let _nonce = await gov.generateNewNonce(_class);

        let title = "Propsal-1: Update the bank contract";
        let callData = await gov.contract.methods.updateBankAddress(
            _class,
            _nonce,
            user6
        ).encodeABI();

        let res = await gov.createProposal(
            _class,
            _nonce,
            [gov.address],
            [0],
            [callData],
            title,
            web3.utils.soliditySha3(title),
            { from: operator }
        );

        let event = res.logs[0].args;

        await gov.vote(event.class, event.nonce, user1, 0, amountToStake, 1, { from: user1 });
        await gov.vote(event.class, event.nonce, user2, 1, amountToStake, 1, { from: user2 });
        await gov.vote(event.class, event.nonce, user3, 0, amountToStake, 1, { from: user3 });
        
        await gov.veto(event.class, event.nonce, true, { from: operator });

        await wait(18000);

        let bankBefore = await storage.getBankAddress();
        let bankInDBITBefore = await dbit.getBankAddress();
        let bankInDGOVBefore = await dbit.getBankAddress();
        let bankInAPMBefore = await dbit.getBankAddress();
        let bankInERC3475Before = await erc3475.getBankAddress();
        let bankInBankDataBefore = await bankData.getBankAddress();
        let bankInBondManagerBefore = await bondManager.getBankAddress();

        await gov.executeProposal(
            event.class,
            event.nonce,
            { from: operator }
        );

        let bankAfter = await storage.getBankAddress();
        let bankInDBITAfter = await dbit.getBankAddress();
        let bankInDGOVAfter = await dbit.getBankAddress();
        let bankInAPMAfter = await dbit.getBankAddress();
        let bankInERC3475After = await erc3475.getBankAddress();
        let bankInBankDataAfter = await bankData.getBankAddress();
        let bankInBondManagerAfter = await bondManager.getBankAddress();

        expect(bankBefore)
        .to.equal(bankInDBITBefore)
        .to.equal(bankInDGOVBefore)
        .to.equal(bankInAPMBefore)
        .to.equal(bankInERC3475Before)
        .to.equal(bankInBankDataBefore)
        .to.equal(bankInBondManagerBefore)
        .to.equal(bank.address);

        expect(bankAfter)
        .to.equal(bankInDBITAfter)
        .to.equal(bankInDGOVAfter)
        .to.equal(bankInAPMAfter)
        .to.equal(bankInERC3475After)
        .to.equal(bankInBankDataAfter)
        .to.equal(bankInBondManagerAfter)
        .to.equal(user6)
        .not.to.equal(bankBefore);
    });

    it("update the Governance contract", async () => {
        // create a proposal
        let _class = 0;
        let _nonce = await gov.generateNewNonce(_class);

        let title = "Propsal-1: Update the governance contract";
        let callData = await gov.contract.methods.updateGovernanceAddress(
            _class,
            _nonce,
            user6
        ).encodeABI();
        
        let res = await gov.createProposal(
            _class,
            _nonce,
            [gov.address],
            [0],
            [callData],
            title,
            web3.utils.soliditySha3(title),
            { from: operator }
        );

        let event = res.logs[0].args;

        await gov.vote(event.class, event.nonce, user1, 0, amountToStake, 1, { from: user1 });
        await gov.vote(event.class, event.nonce, user2, 1, amountToStake, 1, { from: user2 });
        await gov.vote(event.class, event.nonce, user3, 0, amountToStake, 1, { from: user3 });
        
        await gov.veto(event.class, event.nonce, true, { from: operator });

        await wait(18000);

        let executableBefore = await storage.getGovernanceAddress();

        await gov.executeProposal(
            event.class,
            event.nonce,
            { from: operator }
        );

        let executableAfter = await storage.getGovernanceAddress();
        let inBank = await bank.getGovernanceAddress();
        let inDBIT = await dbit.getGovernanceAddress();
        let inDGOV = await dgov.getGovernanceAddress();
        let inBankData = await bankData.getGovernanceAddress();
        let inAPM = await apm.getGovernanceAddress();
        let inDebondBond = await erc3475.getGovernanceAddress();
        let inExStorage = await exStorage.getGovernanceAddress();
        let inStaking = await stak.getGovernanceAddress();

        expect(executableAfter)
        .to.equal(inBank)
        .to.equal(inDBIT)
        .to.equal(inDGOV)
        .to.equal(inBankData)
        .to.equal(inAPM)
        .to.equal(inDebondBond)
        .to.equal(inExStorage)
        .to.equal(inStaking)
        .to.equal(user6)
        .not.to.equal(executableBefore);
    });

    it("Check updated Governance is out of use", async () => {
        // create a proposal
        let _class = 0;
        let _nonce = await gov.generateNewNonce(_class);

        let title = "Propsal-1: Update the governance contract";
        let callData = await gov.contract.methods.updateGovernanceAddress(
            _class,
            _nonce,
            user6
        ).encodeABI();
        
        let res = await gov.createProposal(
            _class,
            _nonce,
            [gov.address],
            [0],
            [callData],
            title,
            web3.utils.soliditySha3(title),
            { from: operator }
        );

        let event = res.logs[0].args;

        await gov.vote(event.class, event.nonce, user1, 0, amountToStake, 1, { from: user1 });
        await gov.vote(event.class, event.nonce, user2, 1, amountToStake, 1, { from: user2 });
        await gov.vote(event.class, event.nonce, user3, 0, amountToStake, 1, { from: user3 });
        
        await gov.veto(event.class, event.nonce, true, { from: operator });

        await wait(18000);

        await gov.executeProposal(
            event.class,
            event.nonce,
            { from: operator }
        );

        expect(
            gov.createProposal(
                _class,
                [gov.address],
                [0],
                [callData],
                title,
                web3.utils.soliditySha3(title),
                { from: operator }
            )
        ).to.rejectedWith(
            Error,
            "VM Exception while processing transaction: revert Executable: execute proposal reverted -- Reason given: ProposalLogic: Only Gov"
        );
    });

    it("update the executable contract", async () => {
        // create a proposal
        let _class = 0;
        let _nonce = await gov.generateNewNonce(_class);

        let title = "Propsal-1: Update the executable contract";
        let callData = await gov.contract.methods.updateExecutableAddress(
            _class,
            _nonce,
            user6
        ).encodeABI();
        
        let res = await gov.createProposal(
            _class,
            _nonce,
            [gov.address],
            [0],
            [callData],
            title,
            web3.utils.soliditySha3(title),
            { from: operator }
        );

        let event = res.logs[0].args;

        await gov.vote(event.class, event.nonce, user1, 0, amountToStake, 1, { from: user1 });
        await gov.vote(event.class, event.nonce, user2, 1, amountToStake, 1, { from: user2 });
        await gov.vote(event.class, event.nonce, user3, 0, amountToStake, 1, { from: user3 });
        
        await gov.veto(event.class, event.nonce, true, { from: operator });

        await wait(18000);

        let executableBefore = await storage.getExecutableContract();

        await gov.executeProposal(
            event.class,
            event.nonce,
            { from: operator }
        );

        let executableAfter = await storage.getExecutableContract();

        expect(executableAfter)
        .to.equal(user6)
        .not.to.equal(executableBefore);
    });

    it("update the exchange contract", async () => {
        // create a proposal
        let _class = 0;
        let _nonce = await gov.generateNewNonce(_class);

        let title = "Propsal-1: Update the exchange contract";
        let callData = await gov.contract.methods.updateExchangeAddress(
            _class,
            _nonce,
            user6
        ).encodeABI();

        
        let res = await gov.createProposal(
            _class,
            _nonce,
            [gov.address],
            [0],
            [callData],
            title,
            web3.utils.soliditySha3(title),
            { from: operator }
        );

        let event = res.logs[0].args;

        await gov.vote(event.class, event.nonce, user1, 0, amountToStake, 1, { from: user1 });
        await gov.vote(event.class, event.nonce, user2, 1, amountToStake, 1, { from: user2 });
        await gov.vote(event.class, event.nonce, user3, 0, amountToStake, 1, { from: user3 });
        
        await gov.veto(event.class, event.nonce, true, { from: operator });

        await wait(18000);

        let exchangeBefore = await storage.getExchangeAddress();
        let exchangeInStorageBefore = await exStorage.getExchangeAddress();

        await gov.executeProposal(
            event.class,
            event.nonce,
            { from: operator }
        );

        let exchangeAfter = await storage.getExchangeAddress();
        let exchangeInStorageAfter = await exStorage.getExchangeAddress();

        expect(exchangeBefore)
        .to.equal(exchangeInStorageBefore);

        expect(exchangeAfter)
        .to.equal(exchangeInStorageAfter)
        .not.to.equal(exchangeBefore);
    });

    it("update the bank bond manager contract", async () => {
        // create a proposal
        let _class = 0;
        let _nonce = await gov.generateNewNonce(_class);

        let title = "Propsal-1: Update the bank bond manager contract";
        let callData = await gov.contract.methods.updateBankBondManagerAddress(
            _class,
            _nonce,
            user6
        ).encodeABI();
        
        let res = await gov.createProposal(
            _class,
            _nonce,
            [gov.address],
            [0],
            [callData],
            title,
            web3.utils.soliditySha3(title),
            { from: operator }
        );

        let event = res.logs[0].args;

        await gov.vote(event.class, event.nonce, user1, 0, amountToStake, 1, { from: user1 });
        await gov.vote(event.class, event.nonce, user2, 1, amountToStake, 1, { from: user2 });
        await gov.vote(event.class, event.nonce, user3, 0, amountToStake, 1, { from: user3 });
        
        await gov.veto(event.class, event.nonce, true, { from: operator });

        await wait(18000);

        let bankBondManagerBefore = await storage.getBankBondManagerAddress();
        let inBankBefore = await bank.getBankBondManager();
        let inDebondBondBefore = await erc3475.getBankBondManager();

        await gov.executeProposal(
            event.class,
            event.nonce,
            { from: operator }
        );

        let bankBondManagerAfter = await storage.getBankBondManagerAddress();
        let inBankAfter = await bank.getBankBondManager();
        let inDebondBondAfter = await erc3475.getBankBondManager();

        expect(bankBondManagerBefore)
        .to.equal(inDebondBondBefore)
        .to.equal(inBankBefore);

        expect(bankBondManagerAfter)
        .to.equal(inBankAfter)
        .to.equal(inDebondBondAfter)
        .not.to.equal(bankBondManagerBefore);
    });

    it("update the airdrop contract", async () => {
        // create a proposal
        let _class = 0;
        let _nonce = await gov.generateNewNonce(_class);

        let title = "Propsal-1: Update the airdrop contract";
        let callData = await gov.contract.methods.updateAirdropAddress(
            _class,
            _nonce,
            user6
        ).encodeABI();
        
        let res = await gov.createProposal(
            _class,
            _nonce,
            [gov.address],
            [0],
            [callData],
            title,
            web3.utils.soliditySha3(title),
            { from: operator }
        );

        let event = res.logs[0].args;

        await gov.vote(event.class, event.nonce, user1, 0, amountToStake, 1, { from: user1 });
        await gov.vote(event.class, event.nonce, user2, 1, amountToStake, 1, { from: user2 });
        await gov.vote(event.class, event.nonce, user3, 0, amountToStake, 1, { from: user3 });
        
        await gov.veto(event.class, event.nonce, true, { from: operator });

        await wait(18000);

        let airdropBefore = await storage.getAirdropContract();
        let inDBITBefore = await dbit.getAirdropAddress();
        let inDGOVBefore = await dgov.getAirdropAddress();

        await gov.executeProposal(
            event.class,
            event.nonce,
            { from: operator }
        );

        let airdropAfter = await storage.getAirdropContract();
        let inDBITAfter = await dbit.getAirdropAddress();
        let inDGOVAfter = await dgov.getAirdropAddress();

        expect(airdropBefore)
        .to.equal(inDBITBefore)
        .to.equal(inDGOVBefore);

        expect(airdropAfter)
        .to.equal(inDBITAfter)
        .to.equal(inDGOVAfter)
        .not.to.equal(airdropBefore);
    });

    it("update the oracle contract", async () => {
        // create a proposal
        let _class = 0;
        let _nonce = await gov.generateNewNonce(_class);

        let title = "Propsal-1: Update the oracle contract";
        let callData = await gov.contract.methods.updateOracleAddress(
            _class,
            _nonce,
            user6
        ).encodeABI();
        
        let res = await gov.createProposal(
            _class,
            _nonce,
            [gov.address],
            [0],
            [callData],
            title,
            web3.utils.soliditySha3(title),
            { from: operator }
        );

        let event = res.logs[0].args;

        await gov.vote(event.class, event.nonce, user1, 0, amountToStake, 1, { from: user1 });
        await gov.vote(event.class, event.nonce, user2, 1, amountToStake, 1, { from: user2 });
        await gov.vote(event.class, event.nonce, user3, 0, amountToStake, 1, { from: user3 });
        
        await gov.veto(event.class, event.nonce, true, { from: operator });

        await wait(18000);

        let oracleBefore = await storage.getOracleAddress();
        let inBankBefore = await bank.getOracleAddress();
        let inBondManagerBefore = await bondManager.getOracleAddress();

        await gov.executeProposal(
            event.class,
            event.nonce,
            { from: operator }
        );

        let oracleAfter = await storage.getOracleAddress();
        let inBankAfter = await bank.getOracleAddress();
        let inBondManagerAfter = await bondManager.getOracleAddress();

        expect(oracleBefore)
        .to.equal(inBankBefore)
        .to.equal(inBondManagerBefore);

        expect(oracleAfter)
        .to.equal(inBankAfter)
        .to.equal(inBondManagerAfter)
        .not.to.equal(oracleBefore);
    });

    it("Change the benchmark interest rate", async () => {
        // create a proposal
        let _class = 0;
        let _nonce = await gov.generateNewNonce(_class);

        let title = "Propsal-1: Update the benchMark interest rate";
        let callData = await gov.contract.methods.updateBenchmarkInterestRate(
            _class,
            _nonce,
            '10'
        ).encodeABI();
        
        let res = await gov.createProposal(
            _class,
            _nonce,
            [gov.address],
            [0],
            [callData],
            title,
            web3.utils.soliditySha3(title),
            { from: operator }
        );

        let event = res.logs[0].args;

        await gov.vote(event.class, event.nonce, user1, 0, amountToStake, 1, { from: user1 });
        await gov.vote(event.class, event.nonce, user2, 1, amountToStake, 1, { from: user2 });
        await gov.vote(event.class, event.nonce, user3, 0, amountToStake, 1, { from: user3 });
        
        await gov.veto(event.class, event.nonce, true, { from: operator });

        await wait(18000);

        let status = await storage.getProposalStatus(event.class, event.nonce);
        let benchmarkBefore = await storage.getBenchmarkIR();
        let bechmarkBankBefore = await bank.getBenchmarkIR();

        // Execute the proposal
        await gov.executeProposal(
            event.class,
            event.nonce,
            { from: operator }
        );

        let benchmarkAfter = await storage.getBenchmarkIR();
        let bechmarkBankAfter = await bank.getBenchmarkIR();

        let status1 = await storage.getProposalStatus(event.class, event.nonce);

        expect(status.toString()).to.equal(ProposalStatus.Active);
        expect(status1.toString()).to.equal(ProposalStatus.Executed);
        expect(
            benchmarkAfter.toString()
        ).to.equal(
            benchmarkBefore.add(web3.utils.toBN(5)).toString()
        );
        expect(
            bechmarkBankAfter.toString()
        ).to.equal(
            bechmarkBankBefore.add(web3.utils.toBN(5)).toString()
        );
    });

    it("change the budget in Part Per Million", async () => {
        let newDBITBudget = await web3.utils.toWei(web3.utils.toBN(5000000), 'ether');
        let newDGOVBudget = await web3.utils.toWei(web3.utils.toBN(7000000), 'ether');

        // create a proposal
        let _class = 0;
        let _nonce = await gov.generateNewNonce(_class);

        let title = "Propsal-1: Update the budget part per million";
        let callData = await gov.contract.methods.changeCommunityFundSize(
            _class,
            _nonce,
            newDBITBudget,
            newDGOVBudget
        ).encodeABI();
        
        let res = await gov.createProposal(
            _class,
            _nonce,
            [gov.address],
            [0],
            [callData],
            title,
            web3.utils.soliditySha3(title),
            { from: operator }
        );

        let event = res.logs[0].args;

        await gov.vote(event.class, event.nonce, user1, 0, amountToStake, 1, { from: user1 });
        await gov.vote(event.class, event.nonce, user2, 1, amountToStake, 1, { from: user2 });
        await gov.vote(event.class, event.nonce, user3, 0, amountToStake, 1, { from: user3 });

        await gov.veto(event.class, event.nonce, true, { from: operator });

        await wait(18000);

        let oldBudget = await web3.utils.toWei(web3.utils.toBN(100000), 'ether');
        let budget = await storage.getBudget();

        expect(budget[0].toString()).to.equal(oldBudget.toString());
        expect(budget[1].toString()).to.equal(oldBudget.toString());

        await gov.executeProposal(
            event.class,
            event.nonce,
            { from: operator }
        );

        budget = await storage.getBudget();

        expect(budget[0].toString()).to.equal(newDBITBudget.toString());
        expect(budget[1].toString()).to.equal(newDGOVBudget.toString());
    });

    it("mint DBIT allocated token", async () => {
        let amountDBIT = await web3.utils.toWei(web3.utils.toBN(2), 'ether');

        // create a proposal
        let _class = 0;
        let _nonce = await gov.generateNewNonce(_class);

        let title = "Propsal-1: Mint the team allocation token";
        let callData = await gov.contract.methods.mintAllocatedToken(
            _class,
            _nonce,
            dbit.address,
            debondTeam,
            amountDBIT
        ).encodeABI();
        
        let res = await gov.createProposal(
            _class,
            _nonce,
            [gov.address],
            [0],
            [callData],
            title,
            web3.utils.soliditySha3(title),
            {from: operator}
        );

        let event = res.logs[0].args;

        await gov.vote(event.class, event.nonce, user1, 0, amountToStake, 1, {from: user1});
        await gov.vote(event.class, event.nonce, user2, 1, amountToStake, 1, {from: user2});
        await gov.vote(event.class, event.nonce, user3, 0, amountToStake, 1, {from: user3});

        await gov.veto(event.class, event.nonce, true, {from: operator});

        await wait(18000);

        let allocMintedBefore = await storage.getAllocatedTokenMinted(debondTeam);
        let totaAllocDistBefore = await storage.getTotalAllocationDistributed();

        await gov.executeProposal(
            event.class,
            event.nonce,
            {from: operator}
        );

        let allocMintedAfter = await storage.getAllocatedTokenMinted(debondTeam);
        let totaAllocDistAfter = await storage.getTotalAllocationDistributed();

        expect(allocMintedAfter[0].toString()).to.equal(allocMintedBefore[0].add(amountDBIT).toString());
        expect(totaAllocDistAfter[0].toString()).to.equal(totaAllocDistBefore[0].add(amountDBIT).toString());
    });

    it("mint DGOV allocated token", async () => {
        let amountDGOV = await web3.utils.toWei(web3.utils.toBN(1), 'ether');

        // create a proposal
        let _class = 0;
        let _nonce = await gov.generateNewNonce(_class);

        let title = "Propsal-1: Mint the team allocation token";
        let callData = await gov.contract.methods.mintAllocatedToken(
            _class,
            _nonce,
            dgov.address,
            debondTeam,
            amountDGOV
        ).encodeABI();
        
        let res = await gov.createProposal(
            _class,
            _nonce,
            [gov.address],
            [0],
            [callData],
            title,
            web3.utils.soliditySha3(title),
            {from: operator}
        );

        let event = res.logs[0].args;

        await gov.vote(event.class, event.nonce, user1, 0, amountToStake, 1, {from: user1});
        await gov.vote(event.class, event.nonce, user2, 1, amountToStake, 1, {from: user2});
        await gov.vote(event.class, event.nonce, user3, 0, amountToStake, 1, {from: user3});

        await gov.veto(event.class, event.nonce, true, {from: operator});

        await wait(18000);

        let allocMintedBefore = await storage.getAllocatedTokenMinted(debondTeam);
        let totaAllocDistBefore = await storage.getTotalAllocationDistributed();

        await gov.executeProposal(
            event.class,
            event.nonce,
            {from: operator}
        );

        let allocMintedAfter = await storage.getAllocatedTokenMinted(debondTeam);
        let totaAllocDistAfter = await storage.getTotalAllocationDistributed();

        expect(allocMintedAfter[1].toString()).to.equal(allocMintedBefore[1].add(amountDGOV).toString());
        expect(totaAllocDistAfter[1].toString()).to.equal(totaAllocDistBefore[1].add(amountDGOV).toString());
    });

    it("change team allocation", async () =>  {
        let toStake = await web3.utils.toWei(web3.utils.toBN(25), 'ether');
        let newDBITAmount = await web3.utils.toWei(web3.utils.toBN(60000), 'ether');
        let newDGOVAmount = await web3.utils.toWei(web3.utils.toBN(90000), 'ether');

        let _class = 0;
        let _nonce = await gov.generateNewNonce(_class);

        let title = "Propsal-1: Change the team allocation token amount";
        callData = await gov.contract.methods.changeTeamAllocation(
            _class,
            _nonce,
            debondTeam,
            newDBITAmount,
            newDGOVAmount
        ).encodeABI();
        
        let res = await gov.createProposal(
            _class,
            _nonce,
            [gov.address],
            [0],
            [callData],
            title,
            web3.utils.soliditySha3(title),
            {from: operator}
        );

        let event = res.logs[0].args;

        await gov.vote(event.class, event.nonce, user1, 0, toStake, 1, {from: user1});
        await gov.vote(event.class, event.nonce, user2, 1, toStake, 1, {from: user2});
        await gov.vote(event.class, event.nonce, user3, 0, toStake, 1, {from: user3});

        await gov.veto(event.class, event.nonce, true, {from: operator});

        await wait(18000);

        await gov.executeProposal(
            event.class,
            event.nonce,
            {from: operator}
        );
    });

    it("check a proposal didn't pass", async () => {
        // create a proposal
        let _class = 2;
        let _nonce = await gov.generateNewNonce(_class);

        let title = "Propsal-1: Update the benchMark interest rate";
        let callData = await gov.contract.methods.updateBenchmarkInterestRate(
            _class,
            _nonce,
            '10'
        ).encodeABI();
        
        let res = await gov.createProposal(
            _class,
            _nonce,
            [gov.address],
            [0],
            [callData],
            title,
            web3.utils.soliditySha3(title),
            { from: operator }
        );

        let event = res.logs[0].args;

        await gov.vote(event.class, event.nonce, user1, 0, amountToStake, 1, { from: user1 });
        await gov.vote(event.class, event.nonce, user2, 1, amountToStake, 1, { from: user2 });
        await gov.vote(event.class, event.nonce, user3, 1, amountToStake, 1, { from: user3 });

        await wait(18000);

        expect(
            gov.executeProposal(
                event.class,
                event.nonce,
                {from: operator}
            )
        ).to.rejectedWith(
            Error,
            "VM Exception while processing transaction: revert Gov: proposal not successful -- Reason given: Gov: proposal not successful"
        );

    });

    it("check the delegate vote", async () => {
        // create a proposal
        let _class = 0;
        let _nonce = await gov.generateNewNonce(_class);

        let title = "Propsal-1: Update the benchMark interest rate";
        let callData = await gov.contract.methods.updateBenchmarkInterestRate(
            _class,
            _nonce,
            '10'
        ).encodeABI();
        
        let res = await gov.createProposal(
            _class,
            _nonce,
            [gov.address],
            [0],
            [callData],
            title,
            web3.utils.soliditySha3(title),
            { from: operator }
        );

        let event = res.logs[0].args;

        await gov.vote(event.class, event.nonce, user1, 0, amountToStake, 1, { from: user4 });
        await gov.vote(event.class, event.nonce, user2, 1, amountToStake, 1, { from: user2 });
        await gov.vote(event.class, event.nonce, user3, 0, amountToStake, 1, { from: user3 });

        let v1 = await count.hasVoted(event.class, event.nonce, user1);
        let v4 = await count.hasVoted(event.class, event.nonce, user4);
        let v2 = await count.hasVoted(event.class, event.nonce, user2);
        let v3 = await count.hasVoted(event.class, event.nonce, user3);

        expect(v1).to.be.false;
        expect(v4).to.be.true;
        expect(v2).to.be.true;
        expect(v3).to.be.true;
    });

    it('check proposal of class 2 passes', async () => {
        let _class = 2;
        let _nonce = await gov.generateNewNonce(_class);

        let title = "Propsal-1: Update the benchMark interest rate";
        let callData = await gov.contract.methods.updateBenchmarkInterestRate(
            _class,
            _nonce,
            '10'
        ).encodeABI();
        
        let res = await gov.createProposal(
            _class,
            _nonce,
            [gov.address],
            [0],
            [callData],
            title,
            web3.utils.soliditySha3(title),
            { from: operator }
        );

        let event = res.logs[0].args;

        await gov.vote(event.class, event.nonce, user1, 0, amountToStake, 1, { from: user1 });
        await gov.vote(event.class, event.nonce, user2, 1, amountToStake, 1, { from: user2 });
        await gov.vote(event.class, event.nonce, user3, 0, amountToStake, 1, { from: user3 });

        await wait(18000);

        let benchmarkBefore = await storage.getBenchmarkIR();

        // Execute the proposal
        await gov.executeProposal(
            event.class,
            event.nonce,
            { from: operator }
        );

        let status = await storage.getProposalStatus(event.class, event.nonce);

        let benchmarkAfter = await storage.getBenchmarkIR();

        expect(status.toString()).to.equal(ProposalStatus.Executed);
        expect(
            benchmarkAfter.toString()
        )
            .to.equal(
                benchmarkBefore.add(web3.utils.toBN(5)).toString()
            );
    });

    it('Check DBIT earned by voting', async () => {
        let _class = 2;
        let _nonce = await gov.generateNewNonce(_class);

        let title = "Propsal-1: Update the benchMark interest rate";
        let desc = await web3.utils.soliditySha3(title);
        let callData = await gov.contract.methods.updateBenchmarkInterestRate(
            _class,
            _nonce,
            '10'
        ).encodeABI();
        
        let res = await gov.createProposal(
            _class,
            _nonce,
            [gov.address],
            [0],
            [callData],
            title,
            desc,
            { from: operator }
        );

        let event = res.logs[0].args;

        await gov.vote(event.class, event.nonce, user1, 0, amountToStake, 1, { from: user1 });
        await gov.vote(event.class, event.nonce, user2, 1, amountToStake, 1, { from: user2 });
        await gov.vote(event.class, event.nonce, user3, 0, amountToStake, 1, { from: user3 });
        await gov.vote(event.class, event.nonce, operator, 0, amountToStake, 1, { from: operator });

        await wait(18000);

        await gov.unlockVoteTokens(event.class, event.nonce, { from: user1 });
        await gov.unlockVoteTokens(event.class, event.nonce, { from: operator });

        let balanceVoteAfter = await dbit.balanceOf(user1);
        balanceVoteAfter = Number(balanceVoteAfter.toString()) / 1e18;
        balanceVoteAfter = balanceVoteAfter.toFixed(15);

        let balanceProposer = await dbit.balanceOf(operator);
        balanceProposer = Number(balanceProposer.toString()) / 1e18;
        balanceProposer = balanceProposer.toFixed(15);

        let dbitPerDay = await storage.dbitDistributedPerDay();
        dbitPerDay = Number(dbitPerDay.toString()) / 1e18;
        let reward = amountToStake * dbitPerDay / (4 * amountToStake);
        reward = reward.toFixed(15);

        expect(balanceVoteAfter).to.equal(reward);
        expect(balanceProposer).to.equal(reward);
    });

    it('Check proposer can unstake their vote tokens', async () => {
        let _class = 2;
        let _nonce = await gov.generateNewNonce(_class);

        let title = "Propsal-1: Update the benchMark interest rate";
        let callData = await gov.contract.methods.updateBenchmarkInterestRate(
            _class,
            _nonce,
            '10'
        ).encodeABI();
        
        let res = await gov.createProposal(
            _class,
            _nonce,
            [gov.address],
            [0],
            [callData],
            title,
            web3.utils.soliditySha3(title),
            { from: operator }
        );

        let event = res.logs[0].args;

        await gov.vote(event.class, event.nonce, user1, 0, amountToStake, 1, { from: user1 });
        await gov.vote(event.class, event.nonce, user2, 1, amountToStake, 1, { from: user2 });
        await gov.vote(event.class, event.nonce, user3, 0, amountToStake, 1, { from: user3 });

        await wait(18000);

        let thresold = await web3.utils.toWei(web3.utils.toBN(10), 'ether');
        let balanceBefore = await vote.availableBalance(operator);

        await gov.unlockVoteTokens(event.class, event.nonce, { from: operator });

        let balanceAfter = await vote.availableBalance(operator);

        expect(balanceAfter.toString()).to.equal(balanceBefore.add(thresold).toString())
    });

    it('update DGOV max supply', async () => {
        let toAdd = await web3.utils.toWei(web3.utils.toBN(4000000), 'ether');
        let maxSupplyBefore = await dgov.getMaxSupply();
        let newMax = maxSupplyBefore.add(toAdd);

        let _class = 0;
        let _nonce = await gov.generateNewNonce(_class);

        await gov.updateDGOVMaxSupply(_class, _nonce, newMax);
        let maxSupplyAfter = await dgov.getMaxSupply();

        expect(maxSupplyAfter.toString()).to.equal(maxSupplyBefore.add(toAdd).toString());
    });

    it("set DGOV max allocation percentage", async () => {
        let _class = 0;
        let _nonce = await gov.generateNewNonce(_class);

        await gov.setMaxAllocationPercentage(
            _class,
            _nonce,
            "800",
            dgov.address,
            { from: operator }
        );
        let maxAlloc = await dgov.getMaxAllocatedPercentage();

        expect(maxAlloc.toString()).to.equal("800");
    });

    it("set DGOV max airdrop supply", async () => {
        let toAdd = await web3.utils.toWei(web3.utils.toBN(250000), 'ether');
        let maxAirdropBefore = await dgov.getMaxAirdropSupply();
        let newMax = maxAirdropBefore.add(toAdd);

        let _class = 0;
        let _nonce = await gov.generateNewNonce(_class);

        await gov.updateMaxAirdropSupply(
            _class,
            _nonce,
            newMax,
            dgov.address,
            { from: operator }
        );
        let maxAirdropAfter = await dgov.getMaxAirdropSupply();

        expect(maxAirdropAfter.toString()).to.equal(maxAirdropBefore.add(toAdd).toString());
    });

    it("set DBIT max airdrop supply", async () => {
        let toAdd = await web3.utils.toWei(web3.utils.toBN(250000), 'ether');
        let maxAirdropBefore = await dbit.getMaxAirdropSupply();
        let newMax = maxAirdropBefore.add(toAdd);

        let _class = 0;
        let _nonce = await gov.generateNewNonce(_class);

        await gov.updateMaxAirdropSupply(
            _class,
            _nonce,
            newMax,
            dbit.address,
            { from: operator }
        );
        let maxAirdropAfter = await dbit.getMaxAirdropSupply();

        expect(maxAirdropAfter.toString()).to.equal(maxAirdropBefore.add(toAdd).toString());
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