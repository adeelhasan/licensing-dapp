import { ethers } from "ethers";

import { toastErrorMessage } from "utils/toast";

const networkId = process.env.NEXT_PUBLIC_NETWORK_ID || "31337";
const networks = {
  1: "Mainnet",
  3: "Ropsten",
  4: "Rinkeby",
  5: "Goerli",
  42: "Kovan",
  1337: "localhost",
  31337: "localhost",
  11155111: "Sepolia",
};
const networkName = networks[networkId];

export const getEthereumObject = () => {
  const { ethereum } = window;
  if (!ethereum) return null;

  if (ethereum.networkVersion != networkId) {
    toastErrorMessage(`Please switch to the ${networkName} network`);
    return null;
  }

  return ethereum;
};

export const setupEthereumEventListeners = (ethereum) => {
  const provider = new ethers.providers.Web3Provider(ethereum, "any");
  provider.on("network", (newNetwork, oldNetwork) => {
    if (oldNetwork) {
      window.location.reload();
    }
  });

  window.ethereum.on("accountsChanged", async (accounts) => {
    window.location.reload();
  });

  return ethereum;
};

export const connectWallet = async () => {
  const { ethereum } = window;
  if (!ethereum) return null;

  await ethereum.request({ method: "eth_requestAccounts" });
  location.reload();
};

export const getCurrentAccount = async () => {
  const { ethereum } = window;

  const accounts = await ethereum.request({ method: "eth_accounts" });

  if (!accounts || accounts?.length === 0) {
    return null;
  }
  const account = accounts[0];
  return account;
};

export const getSignedContract = (address, abi) => {
  const { ethereum } = window;

  const provider = new ethers.providers.Web3Provider(ethereum, "any");

  const signer = provider.getSigner();
  return new ethers.Contract(address, abi, signer);
};
