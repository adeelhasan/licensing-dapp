import React, { useEffect, useState } from "react";
import Head from "next/head";

import NFT from "components/NFT";
import Layout from "components/Layout";
import Spinner from "components/Spinner";

import { useAccount, useContracts } from "contexts";

const zeroAddress = "0x0000000000000000000000000000000000000000";
const fallbackImage = "http:///i.imgur.com/hfM1J8s.png";

export default function Home() {
  const [isLoading, setIsLoading] = useState(false);
  const [nfts, setNfts] = useState([]);
  const [licenses, setLicenses] = useState([]);

  const account = useAccount();
  const { licensingContract } = useContracts();

  const fetchNftDetails = async (nftURL) => {
    try {
      const response = await (await fetch(nftURL)).json();
      const { image } = response;
      return { image };
    } catch (e) {
      return { image: fallbackImage };
    }
  };

  const loadNfts = async () => {
    setIsLoading(true);
    const baseUri = await dcWarriorsContract.baseURI();

    let nfts = [];
    for (let i = 0; i < 1000; i++) {
      try {
        const tokenId = i;
        const owner = await dcWarriorsContract.ownerOf(tokenId);
        const staked = await stakingContract.staked(tokenId);
        const isStaked = staked.owner !== zeroAddress;

        const nftURL = `${baseUri}/${tokenId}.json`;
        const { image } = await fetchNftDetails(nftURL);

        const nft = {
          imageUrl: image,
          tokenId,
          owner: isStaked ? staked.owner : owner,
          isStaked,
        };
        nfts.push(nft);
      } catch (e) {
        break;
      }
    }

    setNfts(nfts);
    setIsLoading(false);
  };

  const loadLicenses = async () => {
    setIsLoading(true);
    const licensesRes = await licensingContract.currentLicences();
    setLicenses(licensesRes);
    setIsLoading(false);
  }

  useEffect(() => {
    loadLicenses();
  }, [account]);

  console.log("Licenses", licenses);

  return (
    <div className="mx-auto max-w-7xl p-4">
      <section className="body-font text-gray-600">
        <div className="container mx-auto px-5 pt-12 pb-24">
          {!isLoading && (
            <div className="grid grid-cols-12 gap-8">
              {/* {nfts.map((nft) => {
                return (
                  <NFT
                    key={nft.tokenId}
                    imageUrl={nft.imageUrl}
                    tokenId={nft.tokenId}
                    owner={nft.owner}
                    isStaked={nft.isStaked}
                    setNfts={setNfts}
                  />
                );
              })} */}
            </div>
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
