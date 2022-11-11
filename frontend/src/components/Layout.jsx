import Header from "components/Header";
import { useAccount } from "contexts";

export default function Layout({ children }) {
  const account = useAccount();

  return (
    <div>
      <Header />
      {account && children}
    </div>
  );
}
