import NextDocument, { Head, Html, Main, NextScript } from "next/document";

export default class Document extends NextDocument {
  render() {
    return (
      <Html>
        <Head>
          <meta
            name="description"
            content="DappCamp Warriors is a tutorial project from DappCamp"
          ></meta>

          <link
            rel="shortcut icon"
            href="https://www.dappcamp.xyz/favicon.png"
          />
        </Head>
        <body>
          <Main />
          <NextScript />
        </body>
      </Html>
    );
  }
}
