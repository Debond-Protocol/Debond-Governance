const VoteToken = artifacts.require("VoteToken");
const DBIT = artifacts.require("DBIT");
const DGOV = artifacts.require("DGOV");
const GovStorage = artifacts.require("GovStorage");
const StakingDGOV = artifacts.require("StakingDGOV");
const Governance = artifacts.require("Governance");

contract("governance storage", async (deployer,accounts,network) => {
    let dbit;
    let dgov;
    let storage;
    let voteToken;
    let stakingDGOV;
    let gov;

    let [debondOperator , user1 , user2 , user3]  = accounts;
    
    beforeEach(async () => {
        
        storage = await GovStorage.deployed();
        dbit = await DBIT.deployed();
        dgov = await DGOV.deployed();
        voteToken = await VoteToken.deployed();
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
        await voteToken.setGovernanceContract(debondOperator);

        let balanceBefore = await voteToken.balanceOf(user1);

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