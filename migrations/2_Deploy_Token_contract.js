const DBIT = artifacts.require("DBIT");
const voteToken = artifacts.require("VoteToken");
const DGOV = artifacts.require("DGOV");

module.exports = async function (deployer,networks,accounts) {
const debondOperator = accounts[0];

const zeroAddress = web3.utils.toChecksumAddress('0x0000000000000000000000000000000000000000');
deployer.deploy(VoteToken,"Debond Vote Token", "DVT", debondOperator);
deployer.deploy(DGOV, debondOperator);
deployer.deploy(DBIT,debondOperator);



const dvtAddress = (await voteToken.deployed()).address;
const dbitAddr = (await DBIT.deployed()).address;
const dgovAddr = (await DGOV.deployed()).address;

console.log(dvtAddress, dbitAddr , dgovAddr);

}