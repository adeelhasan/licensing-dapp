import { useEffect, useState } from "react";
import Head from "next/head";

import { ToastContainer } from "react-toastify";
import "react-toastify/dist/ReactToastify.css";

import { AccountContext, ContractsContext } from "contexts.js";
import {
  networkName,
  getEthereumObject,
  setupEthereumEventListeners,
  getSignedContract,
  getCurrentAccount,
} from "utils/common";

import campContractMetadata from "data/abis/Camp.metadata.json";
import warriorsContractMetadata from "data/abis/DappCampWarriors.metadata.json";
import stakingContractMetdata from "data/abis/Staking.metadata.json";
import licenseProjectMetadata from "data/abis/LicenseProject.metadata.json";

import "../styles/globals.css";

// const campContractAddr = process.env.NEXT_PUBLIC_CAMP_ADDRESS;
// const dappCampWarriorsContractAddr = process.env.NEXT_PUBLIC_WARRIORS_ADDRESS;
const stakingContractAddr = process.env.NEXT_PUBLIC_STAKING_ADDRESS;
const licensingContractAddr = process.env.NEXT_PUBLIC_LICENSE_PROJECT;

function MyApp({ Component, pageProps }) {
  const getLayout = Component.getLayout || ((page) => page);

  const [account, setAccount] = useState(null);
  const [contracts, setContracts] = useState({
    // campContract: null,
    // dcWarriorsContract: null,
    // stakingContract: null,
    licensingContract: null,
  });

  const load = async () => {
    const ethereum = getEthereumObject();
    if (!ethereum) return;

    setupEthereumEventListeners(ethereum);

    // const campContract = getSignedContract(
    //   campContractAddr,
    //   campContractMetadata.output.abi
    // );
    // const dcWarriorsContract = getSignedContract(
    //   dappCampWarriorsContractAddr,
    //   warriorsContractMetadata.output.abi
    // );
    // const stakingContract = getSignedContract(
    //   stakingContractAddr,
    //   stakingContractMetdata.output.abi
    // );
    const licensingContract = getSignedContract(
      licensingContractAddr,
      licenseProjectMetadata.output.abi
    );

    if (!licensingContract) return;

    const currentAccount = await getCurrentAccount();
    // setContracts({ campContract, dcWarriorsContract, stakingContract });
    setContracts({ licensingContract });
    setAccount(currentAccount);
  };

  useEffect(() => {
    load();
  }, []);

  return (
    <>
      <Head>
        <title>Word Star Licensing</title>
        <meta name="viewport" content="initial-scale=1.0, width=device-width" />
      </Head>
      <AccountContext.Provider value={account}>
        <ContractsContext.Provider value={contracts}>
          <ToastContainer
            position="bottom-center"
            autoClose={5000}
            closeOnClick
            pauseOnFocusLoss
            draggable
            pauseOnHover
          />
          {getLayout(<Component {...pageProps} />)}
        </ContractsContext.Provider>
      </AccountContext.Provider>
    </>
  );
}

export default MyApp;
