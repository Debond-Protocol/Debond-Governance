const GovStorage = artifacts.require("GovStorage");
const Governance = artifacts.require("Governance");
const Executable = artifacts.require("Executable");
const StakingDGOV = artifacts.require("StakingDGOV");
const VoteToken = artifacts.require("VoteToken");



module.exports = async function (deployer, network, accounts) {
  const operator = accounts[0];
  const debondTeam = accounts[1];
  await deployer.deploy(GovStorage, debondTeam, operator);
  const govStorage = await GovStorage.deployed()

  await deployer.deploy(Governance, govStorage.address)
  await deployer.deploy(Executable, govStorage.address)
  await deployer.deploy(StakingDGOV, govStorage.address)
  await deployer.deploy(VoteToken, govStorage.address)

};
