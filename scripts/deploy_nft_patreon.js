const { ethers, upgrades, run } = require("hardhat");

async function main() {
  const maxUsed = 3

  const Referral = await ethers.getContractFactory('ReferralRegistry')
  const referral = await Referral.deploy(maxUsed)
  await referral.deploymentTransaction().wait(5);
  const referralAddress = await referral.getAddress()
  await verify(referralAddress, [maxUsed])

  const nftAddress = "0xecf138865d780e03d60B7Ab98B0c6081330780A0"
  const protocolWallet = "0x666d0bb670b0A241a33C4e60dFd33907F224D9f3"
  const protocolFeePercentage = ethers.parseEther("0.05")
  const nftFeePercentage = ethers.parseEther("0.03")
  const referralFeePercentage = ethers.parseEther("0.05")
  
  const Patreon = await ethers.getContractFactory("NFTPatreonV1")
  const patreon = await Patreon.deploy(protocolWallet, nftAddress, protocolFeePercentage, nftFeePercentage, referralFeePercentage, referralAddress)

  await patreon.deploymentTransaction().wait(5);

  const patreonAddress = await patreon.getAddress()
  await verify(patreonAddress, [protocolWallet, nftAddress, protocolFeePercentage, nftFeePercentage, referralFeePercentage, referralAddress])

  await referral.addAllowAddress(patreonAddress)
  
  console.log("Referral Address: ", referralAddress)
  console.log("Patreon Address: ", patreonAddress)
}

async function verify(contractAddress, args) {
  console.log("Verifying contract...");
  try {
      await run("verify:verify", {
          address: contractAddress,
          constructorArguments: args,
      });
  } catch (e) {
      if (e.message.toLowerCase().includes("already verified")) {
          console.log("Already verified!");
      } else {
          console.log(e);
      }
  }
}

main();