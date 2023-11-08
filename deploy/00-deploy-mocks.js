const { network } = require("hardhat")
const { developmentChains } = require("../helper-hardhat-config")

const BASE_FEE = ethers.parseEther("0.25") // 0.25 is the premium. It costs 0.25 LINK per request
const GAS_PRICE_LINK = 1e9 // Link per gas Calculated value based on the gas price of the chain

module.exports = async ({
  getNamedAccounts,
  deployments,
  getChainId,
  // getUnnamedAccounts,
}) => {
  const { deploy, log } = deployments
  const { deployer } = await getNamedAccounts()

  log("network.name", network.name)

  if (developmentChains.includes(network.name)) {
    log("Local network detected! Deploying Mocks...")

    await deploy("VRFCoordinatorV2Mock", {
      from: deployer,
      log: true,
      args: [BASE_FEE, GAS_PRICE_LINK],
    })

    log("Mocks deployed!")
    log("-----------------------------------")
  }
}

module.exports.tags = ["all", "mocks"]
