import React, { useEffect, useState } from "react";
import Head from "next/head";

import Layout from "components/Layout";
import Spinner from "components/Spinner";
import { ethers } from "ethers";

import { useAccount, useContracts } from "contexts";
import LicenseItem from "../components/License";

const zeroAddress = "0x0000000000000000000000000000000000000000";

export default function Home() {
  const [isLoading, setIsLoading] = useState(false);
  const [licenses, setLicenses] = useState([]);

  const account = useAccount();
  const { licensingContract } = useContracts();

  const loadLicenses = async () => {
    setIsLoading(true);
    const licensesRes = await licensingContract.currentLicences();
    setLicenses(licensesRes);
    setIsLoading(false);
  }

  const addLicense = async () => {
    setIsLoading(true);
    await licensingContract.addLicense(ethers.utils.formatBytes32String("Free 2"), 1, 3600, 0);
    const licensesRes = await licensingContract.currentLicences();
    setLicenses(licensesRes);
    setIsLoading(false);
  }

  useEffect(() => {
    loadLicenses();
  }, [account]);

  return (
    <div className="mx-auto max-w-7xl p-4">
      <section className="body-font text-gray-600">
        <div className="container mx-auto px-5 pt-12 pb-24">
          {!isLoading && (
            <>
              <button
                onClick={addLicense}
                className="flex rounded border-0 bg-indigo-500 mb-16 py-2 px-8 text-lg text-white hover:bg-indigo-600 focus:outline-none disabled:opacity-50"
              >
                Add License
              </button>
              <div className="grid grid-cols-12 gap-8">
                {licenses.map((license) => <LicenseItem license={license} />)}
              </div>
            </>
          )}
          {isLoading && (
            <div className="w-full text-center">
              <div className="mx-auto mt-32 w-min">
                <Spinner />
              </div>
            </div>
          )}
        </div>
      </section>
    </div>
  );
}

Home.getLayout = function getLayout(page) {
  return (
    <Layout>
      <Head>
        <title>Home | DappCamp Warriors</title>
      </Head>
      {page}
    </Layout>
  );
};
