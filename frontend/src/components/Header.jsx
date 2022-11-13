import React, { useState, useEffect } from "react";
import Link from "next/link";

import Address from "components/Address";

import { connectWallet } from "utils/common";
import { useAccount, useContracts } from "contexts";

export default function Header() {
  const account = useAccount();
  const isMetamaskConnected = !!account;
  const { licensingContract } = useContracts();
  const [contractName, setContractName] = useState("");

  useEffect(() => {
    if (licensingContract && account) {
      getContractName();
    }
  }, [licensingContract, account]);

  const getContractName = async () => {
    const contractNameRes = await licensingContract.name();
    setContractName(contractNameRes);
  }

  return (
    <header className="body-font mx-auto max-w-7xl p-4 text-gray-600">
      <div className="container mx-auto flex flex-col flex-wrap items-center gap-4 p-5 md:flex-row lg:gap-0">
        <span className="ml-3 text-xl">{contractName} Licensing</span>
        <nav className="flex flex-wrap items-center justify-center text-base md:mr-auto	md:ml-4 md:border-l md:border-gray-400 md:py-1 md:pl-4">
          <Link href="/">
            <a className="mr-5 hover:text-gray-900">Home</a>
          </Link>
        </nav>
        {!isMetamaskConnected && (
          <button
            className="mt-4 inline-flex items-center rounded border-0 bg-gray-100 py-1 px-3 text-base hover:bg-gray-200 focus:outline-none md:mt-0"
            onClick={connectWallet}
          >
            Connect Wallet
          </button>
        )}
        {isMetamaskConnected && (
          <div className="flex gap-2">
            <Address address={account} />
            {/* <Balance /> */}
          </div>
        )}
      </div>
    </header>
  );
}
