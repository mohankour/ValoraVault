const { ethers } = require("hardhat");

async function main() {
  const ValoraVault = await ethers.getContractFactory("ValoraVault");
  const valoraVault = await ValoraVault.deploy();

  await valoraVault.deployed();

  console.log("ValoraVault contract deployed to:", valoraVault.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
