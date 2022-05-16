

const VoteToken = artifacts.require("VoteToken");
const ERC20Token = artifacts.require("ERC20Token");
const GovStorage = artifacts.require("GovStorage");
const StakingDGOV = artifacts.require("StakingDGOV");
const Governance = artifacts.require("Governance");

contract("governance storage", async (accounts,deployer) => {
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
        
        storage = await GovStorage.new();
        dbit = await ERC20Token.new("Debond Index Token", "DBIT");
        dgov = await ERC20Token.new("Debond Governance Token", "DGOV");
        voteToken = await VoteToken.new("Debond Vote Token", "DVT", debondOperator);
        stakingDGOV = await StakingDGOV.new(
            dbit.address,
            dgov.address,
            voteToken.address,
            debondOperator,
            10
        );
        gov = await Governance.new(
            dgov.address,
            voteToken.address,
            stakingDGOV.address,
            voteToken.address,
            accounts[0],
            1
        );
    
        // set the governance contract address in stakingDGOV
        await stakingDGOV.setGovernanceContract(gov.address);
    });

    it("check contrats have deployed", async () => {
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

        expect(dbitName).to.equal("Debond Index Token");
        expect(dbitsymbol).to.equal("DBIT");
        expect(dgovName).to.equal("Debond Governance Token");
        expect(dgovsymbol).to.equal("DGOV");
        expect(voteName).to.equal("Debond Vote Token");
        expect(votesymbol).to.equal("DVT");

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
        let amountAfter = balanceBefore.add(web3.utils.toBN(amount));

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
        expect(interest.toString()).to.equal(web3.utils.toBN(10).toString());
    });


});