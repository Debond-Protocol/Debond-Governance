const GovStorage = artifacts.require("GovStorage");
const Governance = artifacts.require("Governance");
const Executable = artifacts.require("Executable");
const StakingDGOV = artifacts.require("StakingDGOV");
const VoteToken = artifacts.require("VoteToken");



const DGOV = artifacts.require("DGOVTest");
const DBIT = artifacts.require("DBITTest");
const APM = artifacts.require("APMTest");
const BankBondManager = artifacts.require("BankBondManagerTest");
const BankStorage = artifacts.require("BankStorageTest");
const Bank = artifacts.require("BankTest");
const DebondERC3475 = artifacts.require("DebondERC3475Test");
const ExchangeStorage = artifacts.require("ExchangeStorageTest");
const Exchange = artifacts.require("ExchangeTest");
const AdvanceBlockTimeStamp = artifacts.require("AdvanceBlockTimeStamp");

module.exports = async function (deployer, network, accounts) {

  const executable = await Executable.deployed()


  await deployer.deploy(DGOV, executable.address)
  await deployer.deploy(DBIT, executable.address)
  await deployer.deploy(APM, executable.address)
  await deployer.deploy(BankBondManager, executable.address)
  await deployer.deploy(BankStorage, executable.address)
  await deployer.deploy(Bank, executable.address)
  await deployer.deploy(DebondERC3475, executable.address)
  await deployer.deploy(ExchangeStorage, executable.address)
  await deployer.deploy(Exchange, executable.address)
  await deployer.deploy(AdvanceBlockTimeStamp)

  const governance = await Governance.deployed();
  const voteToken = await VoteToken.deployed();
  const stakingDGOV = await StakingDGOV.deployed();

  const dgov = await DGOV.deployed();
  const dbit = await DBIT.deployed();
  const apm = await APM.deployed();
  const bankBondManager = await BankBondManager.deployed();
  const bankStorage = await BankStorage.deployed();
  const bank = await Bank.deployed();
  const debondERC3475 = await DebondERC3475.deployed();
  const exchangeStorage = await ExchangeStorage.deployed();
  const exchange = await Exchange.deployed();


  const govStorage = await GovStorage.deployed()
  await govStorage.setUpGroup1(
      governance.address,
      dgov.address,
      dbit.address,
      apm.address,
      bankBondManager.address,
      stakingDGOV.address,
      voteToken.address
  );

  await govStorage.setUpGroup2(
      executable.address,
      bank.address,
      bankStorage.address,
      debondERC3475.address,
      exchange.address,
      exchangeStorage.address
  )




};
