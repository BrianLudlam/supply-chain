/**
 * Use this file to configure your truffle project. It's seeded with some
 * common settings for different networks and features like migrations,
 * compilation and testing. Uncomment the ones you need or modify
 * them to suit your project as necessary.
 *
 * More information about configuration can be found at:
 *
 * truffleframework.com/docs/advanced/configuration
 *
 * To deploy via Infura you'll need a wallet provider (like truffle-hdwallet-provider)
 * to sign your transactions before they're sent to a remote public node. Infura accounts
 * are available for free at: infura.io/register.
 *
 * You'll also need a mnemonic - the twelve word phrase the wallet uses to generate
 * public/private key pairs. If you're publishing your code to GitHub make sure you load this
 * phrase from a file you've .gitignored so it doesn't accidentally become public.
 *
 */
const HDWalletProvider = require('truffle-hdwallet-provider');
const fs = require('fs');
const devAccount = fs.readFileSync(".account").toString().trim();
const devMnemonic = fs.readFileSync(".mnemonic").toString().trim();
const infuraKey = fs.readFileSync(".infura").toString().trim();

module.exports = {
  /**
   * Networks define how you connect to your ethereum client and let you set the
   * defaults web3 uses to send transactions. If you don't specify one truffle
   * will spin up a development blockchain for you on port 9545 when you
   * run `develop` or `test`. You can ask a truffle command to use a specific
   * network from the command line, e.g
   *
   * $ truffle test --network <network-name>
   */
  networks: {
    // Useful for testing. The `development` name is special - truffle uses it by default
    // if it's defined here and no other network is specified at the command line.
    // You should run a client (like ganache-cli, geth or parity) in a separate terminal
    // tab if you use this network and you must also set the `host`, `port` and `network_id`
    // options below to some value.
    
    //Local testing Ganache settings
    development: {
        host: "127.0.0.1",     // Localhost (default: none)
        port: 8545,            // Standard Ethereum port (default: none)
        network_id: "*",       // Any network (default: none)
        gas: 6000000,
        gasPrice: 5000000000,  // 5 gwei 
    },
    //Remote testing Ropsten settings
    ropsten: {
      provider: () => new HDWalletProvider(devMnemonic, `https://ropsten.infura.io/v3/${infuraKey}`),
      from: devAccount,
      network_id: 3,       // Ropsten's id
      gas: 4000000,        // Ropsten has a lower block limit than mainnet
      confirmations: 5,    // # of confs to wait between deployments. (default: 0)
      timeoutBlocks: 200,  // # of blocks before a deployment times out  (minimum/default: 50)
      //skipDryRun: true     // Skip dry run before migrations? (default: false for public nets )
    },
  },
  //Complier settings
  compilers: {
    solc: {
      version: "0.5.10",    
      settings: {         
        optimizer: {
          enabled: true,
          runs: 10000
        }
      }
    }
  }
}
