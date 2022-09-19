const GovStorage = artifacts.require("GovStorage");
const Governance = artifacts.require("Governance");
const Executable = artifacts.require("Executable");

module.exports = async function (deployer, network, accounts) {
  let operator = accounts[0];
  let debondTeam = accounts[1];
  await deployer.deploy(GovStorage, debondTeam, operator);
  const govStorageAddress = (await GovStorage.deployed()).address

  await deployer.deploy(Governance, govStorageAddress)
  await deployer.deploy(Executable, govStorageAddress)
};
