import { toastSuccessMessage, toastErrorMessage } from "utils/toast";

import { useAccount, useContracts } from "contexts";

const stakingContractAddr = process.env.NEXT_PUBLIC_STAKING_ADDRESS;

export default function NFT({ imageUrl, tokenId, owner, isStaked, setNfts }) {
  const account = useAccount();
  const { dcWarriorsContract, stakingContract } = useContracts();
  const isOwner = owner.toLowerCase() === account.toLowerCase();

  const stake = async () => {
    try {
      const approveTxn = await dcWarriorsContract.approve(
        stakingContractAddr,
        tokenId
      );
      await approveTxn.wait();

      const txn = await stakingContract.stake(tokenId);
      await txn.wait();
    } catch (e) {
      if (e?.reason) toastErrorMessage(e?.reason);
      return;
    }

    toastSuccessMessage("🦄 NFT was successfully staked!");
    setNfts((nfts) =>
      nfts.map((nft) => {
        if (nft.tokenId === tokenId) {
          return {
            ...nft,
            isStaked: true,
          };
        }
        return nft;
      })
    );
  };

  const unstake = async () => {
    try {
      const txn = await stakingContract.unstake(tokenId);
      await txn.wait();
      toastSuccessMessage("🦄 NFT was successfully unstaked!");
    } catch (e) {
      if (e?.reason) toastErrorMessage(e?.reason);
      return;
    }

    setNfts((nfts) =>
      nfts.map((nft) => {
        if (nft.tokenId === tokenId) {
          return {
            ...nft,
            isStaked: false,
          };
        }
        return nft;
      })
    );
  };

  return (
    <div className="col-span-12 box-border border-0 border-solid border-neutral-200 text-sm leading-5 duration-300 sm:col-span-6 lg:col-span-3">
      <div className="h-full overflow-hidden rounded-lg border-2 border-gray-200 border-opacity-60">
        <img
          className="w-full object-cover object-center md:h-36 lg:h-48"
          src={imageUrl}
          alt="DappCamp Warrior"
          onError={({ currentTarget }) => {
            currentTarget.onerror = null;
            currentTarget.src = "http:///i.imgur.com/hfM1J8s.png";
          }}
        />
        <div className="p-6">
          <h1 className="title-font mb-3 text-lg font-medium text-gray-900">
            WARRIOR #{tokenId}
          </h1>
          <h2 className="title-font mb-1 text-xs font-medium tracking-widest text-gray-900">
            OWNER
          </h2>
          <p
            className="mb-3 leading-relaxed"
            style={{
              maxWidth: "60%",
              wordBreak: "break-word",
            }}
          >
            {owner}
          </p>
          {isOwner && !isStaked && (
            <button
              onClick={stake}
              className="flex rounded border-0 bg-indigo-500 py-2 px-8 text-lg text-white hover:bg-indigo-600 focus:outline-none disabled:opacity-50"
            >
              STAKE
            </button>
          )}
          {isOwner && isStaked && (
            <button
              onClick={unstake}
              className="flex rounded border-0 bg-indigo-500 py-2 px-8 text-lg text-white hover:bg-indigo-600 focus:outline-none disabled:opacity-50"
            >
              UNSTAKE
            </button>
          )}
        </div>
      </div>
    </div>
  );
}
