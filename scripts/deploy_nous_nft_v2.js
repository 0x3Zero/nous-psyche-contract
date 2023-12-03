const { ethers, upgrades, run } = require("hardhat");

async function main() {
  const mintPrice = ethers.parseEther("0")
  const maxTokens = 10000
  const NFT = await ethers.getContractFactory("NousPsycheNFTV2")
  const nft = await NFT.deploy(mintPrice, maxTokens)

  await nft.deploymentTransaction().wait(5);

  const nftAddress = await nft.getAddress()
  await verify(nftAddress, [mintPrice, maxTokens])

  console.log("NFT Address: ", nftAddress)
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