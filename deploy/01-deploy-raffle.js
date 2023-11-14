const {
  networkConfig,
  developmentChains,
  VERIFICATION_BLOCK_CONFIRMATIONS,
} = require("../helper-hardhat-config")
const { verify } = require("../utils/verify")

const VRF_SUB_FUND_AMOUNT = ethers.parseEther("2")

module.exports = async ({ getNamedAccounts, deployments, getChainId }) => {
  const { deploy, log, get } = deployments
  const { deployer } = await getNamedAccounts()

  let vrfCoordinatorV2Address, subscriptionId
  const chainId = await getChainId()

  const isDevNetwork = developmentChains.includes(network.name)

  if (isDevNetwork) {
    const vrfCoordinatorV2Mock = await ethers.getContract(
      "VRFCoordinatorV2Mock",
    )
    vrfCoordinatorV2Address = vrfCoordinatorV2Mock.target
    const transactionResponse = await vrfCoordinatorV2Mock.createSubscription()
    const transactionReceipt = await transactionResponse.wait(1)
    subscriptionId = 1
    // Fund the subscription
    // Usually you'd need the link token on a real network
    await vrfCoordinatorV2Mock.fundSubscription(
      subscriptionId,
      VRF_SUB_FUND_AMOUNT,
    )
  } else {
    vrfCoordinatorV2Address = networkConfig[chainId]["vrfCoordinatorV2"]
    subscriptionId = networkConfig[chainId]["subscriptionId"]
  }

  const entranceFee = networkConfig[chainId]["entranceFee"]
  const gasLane = networkConfig[chainId]["gasLane"]
  const callbackGasLimit = networkConfig[chainId]["callbackGasLimit"]
  const interval = networkConfig[chainId]["interval"]
  const args = [
    vrfCoordinatorV2Address,
    entranceFee,
    gasLane,
    subscriptionId,
    callbackGasLimit,
    interval,
  ]

  // the following will only deploy  "GenericMetaTxProcessor" if the contract was never deployed or if the code changed since last deployment
  const raffle = await deploy("Raffle", {
    from: deployer,
    // gasLimit: 4000000,
    log: true,
    args,
    waitConfirmations: isDevNetwork ? 1 : VERIFICATION_BLOCK_CONFIRMATIONS,
  })

  if (!isDevNetwork && process.env.ETHERSCAN_API_KEY) {
    await verify(raffle.address, args)
  }

  log("--------------------------------------")
}

module.exports.tags = ["all", "raffle"]
