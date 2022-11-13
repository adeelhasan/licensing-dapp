import React, { useEffect, useState } from "react";
import Head from "next/head";

import Layout from "components/Layout";
import Spinner from "components/Spinner";
import { ethers } from "ethers";

import { useAccount, useContracts } from "contexts";
import LicenseItem from "../components/License";

const EthInWei = 1000000000000000000;

export default function Home() {
  const [isLoading, setIsLoading] = useState(false);
  const [licenses, setLicenses] = useState([]);
  const [licensees, setLicensees] = useState([]);
  const [isOwner, setIsOwner] = useState(false);

  const account = useAccount();
  const { licensingContract } = useContracts();

  const loadLicenses = async () => {
    setIsLoading(true);
    const licensesRes = await licensingContract.currentLicences();
    const licenseesRes = await licensingContract.myLicenses();
    setLicenses(licensesRes);
    setLicensees(licenseesRes.filter((_) => _.tokenId.toString() !== "0"));
    setIsLoading(false);
  }

  const addLicense = async (event) => {
    event.preventDefault();
    const name = event.target.name.value;
    const maxCycles = event.target.maxCycles.value;
    const cycleLength = event.target.cycleLength.value;
    const price = event.target.price.value;
    setIsLoading(true);
    const txnHash = await licensingContract.addLicense(ethers.utils.formatBytes32String(name), maxCycles, cycleLength, ethers.utils.parseUnits(price.toString(), "ether"));
    await txnHash.wait();
    const licensesRes = await licensingContract.currentLicences();
    setLicenses(licensesRes);
    setIsLoading(false);
  }

  const checkOwner = async () => {
    const owner = await licensingContract.owner();
    setIsOwner(String(owner).toLowerCase() === String(account));
  }

  const buyLicense = async (tokenId, licenseIndex, license) => {
    setIsLoading(true);
    const txnHash = await licensingContract.buyLicense(tokenId, licenseIndex, 0, { value: ethers.utils.parseEther(String(license.price / EthInWei)) });
    await txnHash.wait();
    const licenseesRes = await licensingContract.myLicenses();
    setLicensees(licenseesRes.filter((_) => _.tokenId.toString() !== "0"));
    setIsLoading(false);
  }

  useEffect(() => {
    loadLicenses();
    checkOwner();
  }, [account]);


  const getExpiration = (cycles) => {
    return cycles[cycles.length - 1].endTime;
  }

  return (
    <div className="mx-auto max-w-7xl p-4">
      <section className="body-font text-gray-600">
        <div className="container mx-auto px-5 pt-12 pb-24">
          {!isLoading && (
            <>
              {isOwner && <form onSubmit={addLicense} className="grid">
                <div>
                  <label htmlFor="name">Name</label>
                  <input
                    type="text"
                    id="name"
                    name="name"
                    className="mb-4 ml-2 border-2"
                    required
                  />
                </div>
                <div>
                  <label htmlFor="maxCycles">Max Cycles</label>
                  <input
                    type="number"
                    id="maxCycles"
                    name="maxCycles"
                    className="mb-4 ml-2 border-2"
                    required
                  /></div>
                <div>
                  <label htmlFor="cycleLength">Cycle Length (seconds)</label>
                  <input
                    type="number"
                    id="cycleLength"
                    name="cycleLength"
                    className="mb-4 ml-2 border-2"
                    required
                  />
                </div>
                <div>
                  <label htmlFor="price">Price (ethers)</label>
                  <input
                    type="number"
                    id="price"
                    name="price"
                    step={0.00001}
                    className="mb-4 ml-2 border-2"
                    required
                  />
                </div>
                <div>
                  <button
                    type="submit"
                    className="flex rounded border-0 bg-indigo-500 mb-16 py-2 px-8 text-lg text-white hover:bg-indigo-600 focus:outline-none disabled:opacity-50"
                  >
                    Add License
                  </button>
                </div>
              </form>}
              <h2 className="title-font mb-5 text-xl font-medium tracking-widest text-gray-900">
                License Catalogue
              </h2>
              <div className="grid grid-cols-12 gap-8">
                {licenses.map((license, index) => <LicenseItem
                  license={license}
                  isOwner={isOwner}
                  buyLicense={() => buyLicense(0, index, license)}
                  key={index}
                />
                )}
              </div>
              {Boolean(licensees.length) && <h2 className="title-font mb-5 mt-5 text-xl font-medium tracking-widest text-gray-900">
                My licenses
              </h2>}
              <div className="grid grid-cols-12 gap-8">
                {licensees.map((licenseInfo, index) => <LicenseItem
                  license={licenseInfo.licenseinfo}
                  expiration={getExpiration(licenseInfo.licenseeInfo.cycles)}
                  tokenId={licenseInfo.tokenId}
                  isOwner={isOwner}
                  buyLicense={() => buyLicense(licenseInfo.tokenId, licenseInfo.licenseeInfo.licenseIndex, licenseInfo.licenseinfo)}
                  key={index} />
                )}
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
        <title>Home | Licensing Project</title>
      </Head>
      {page}
    </Layout>
  );
};
