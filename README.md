# Minima

This repo contains the contract for Minima, a DeFi router created by Node Finance.  Documentation for Minima can be found at https://docs.router.nodefinance.org/

## Dependencies
This project requries Forge / Foundry to build and test.  Find instructions on installing Foundry here https://github.com/foundry-rs/foundry

For individual pair tests, the mainnet of the concerned network must be forked with Ganache and ran locally. Find some tips on how to do that here: https://www.quicknode.com/guides/ethereum-development/how-to-fork-ethereum-blockchain-with-ganache

# Setup Repo
```
yarn
forge install
```

# Run tests for Router
```
sh shell/router.test.sh
```

# Run test with foundry

```
forge test
```

# Run test with hardhat

``` 
 npx hardhat compile
 npm run test 
 ```

