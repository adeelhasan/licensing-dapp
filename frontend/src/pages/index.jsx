import React, { useEffect, useState } from "react";
import Head from "next/head";

import Layout from "components/Layout";
import Spinner from "components/Spinner";
import { ethers } from "ethers";

import { useAccount, useContracts } from "contexts";
import LicenseItem from "../components/License";

const zeroAddress = "0x0000000000000000000000000000000000000000";
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

  const addLicense = async () => {
    setIsLoading(true);
    await licensingContract.addLicense(ethers.utils.formatBytes32String("Free 2"), 1, 3600, 0);
    const licensesRes = await licensingContract.currentLicences();
    setLicenses(licensesRes);
    setIsLoading(false);
  }

  const checkOwner = async () => {
    const owner = await licensingContract.owner();
    setIsOwner(String(owner).toLowerCase() === String(account));
  }

  const buyLicense = async (tokenId, licenseIndex, license) => {
    const token = licensingContract.buyLicense(tokenId, licenseIndex, 0, {value: ethers.utils.parseEther(String(license.price/EthInWei))});
    if (token) {
      const licenseesRes = await licensingContract.myLicenses();
      setLicensees(licenseesRes.filter((_) => _.tokenId.toString() !== "0"));
    }
  }

  useEffect(() => {
    loadLicenses();
    checkOwner();
  }, [account]);


  const getExpiration = (cycles) => {
    return cycles[cycles.length-1].endTime;
  }
  
  console.log(licensees)

  return (
    <div className="mx-auto max-w-7xl p-4">
      <section className="body-font text-gray-600">
        <div className="container mx-auto px-5 pt-12 pb-24">
          {!isLoading && (
            <>
              {isOwner && <button
                onClick={addLicense}
                className="flex rounded border-0 bg-indigo-500 mb-16 py-2 px-8 text-lg text-white hover:bg-indigo-600 focus:outline-none disabled:opacity-50"
              >
                Add License
              </button>}
              <h2 className="title-font mb-5 text-xl font-medium tracking-widest text-gray-900">
                License Catalogue
              </h2>
              <div className="grid grid-cols-12 gap-8">
                {licenses.map((license, index) => <LicenseItem license={license} isOwner={isOwner} buyLicense={() => buyLicense(0, index, license)} />)}
              </div>
              {Boolean(licensees.length) && <h2 className="title-font mb-5 mt-5 text-xl font-medium tracking-widest text-gray-900">
                My licenses
              </h2>}
              <div className="grid grid-cols-12 gap-8">
                {licensees.map((licenseInfo) => <LicenseItem license={licenseInfo.licenseinfo} isOwner={isOwner} buyLicense={() => buyLicense(licenseInfo.tokenId, licenseInfo.licenseeInfo.licenseIndex, licenseInfo.licenseinfo)} />)}
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
