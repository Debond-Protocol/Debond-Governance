const GovStorage = artifacts.require("GovStorage");

module.exports = async function (deployer) {
    deployer.deploy(GovStorage);
};
