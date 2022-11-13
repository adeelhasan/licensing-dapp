import { useEffect, useState } from "react";
import Head from "next/head";

import { ToastContainer } from "react-toastify";
import "react-toastify/dist/ReactToastify.css";

import { AccountContext, ContractsContext } from "contexts.js";
import {
  getEthereumObject,
  setupEthereumEventListeners,
  getSignedContract,
  getCurrentAccount,
} from "utils/common";

import licenseProjectMetadata from "data/abis/LicenseProject.metadata.json";

import "../styles/globals.css";

const licensingContractAddr = process.env.NEXT_PUBLIC_LICENSE_PROJECT;

function MyApp({ Component, pageProps }) {
  const getLayout = Component.getLayout || ((page) => page);

  const [account, setAccount] = useState(null);
  const [contracts, setContracts] = useState({
    licensingContract: null,
  });

  const load = async () => {
    const ethereum = getEthereumObject();
    if (!ethereum) return;

    setupEthereumEventListeners(ethereum);

    const licensingContract = getSignedContract(
      licensingContractAddr,
      licenseProjectMetadata.output.abi
    );

    if (!licensingContract) return;

    const currentAccount = await getCurrentAccount();
    setContracts({ licensingContract });
    setAccount(currentAccount);
  };

  useEffect(() => {
    load();
  }, []);

  return (
    <>
      <Head>
        <title>License Project</title>
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
