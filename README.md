### Deployments

FarcasterLauncher: 0xa8a3E70c029CE2F53a90D7a6819b1cF40DfADCB4\
Launcher: 0xdbb1f02483B49E813D717Afe4dadF6D76eAF2F8f\
TokenFactory: 0x015f0fA4a62752E40152791855527edaBbbA77b9\
Funder Template: 0xE99fDF05d518a483aC7a5dbc2888aCC70E86b4Ff\
Locker Template: 0x00d7d2449cc28094f832f379d957acd07bca9bf0\
Staker Template: 0xea50d9c4a4cc68f3ef575749ec1d0cf62bc4745b\
Pool Template: 0xab3488542122eadc677301b37d79ea69c1e0ec28\

### Setup

```
forge install foundry-rs/forge-std
forge install OpenZeppelin/openzeppelin-foundry-upgrades
forge install OpenZeppelin/openzeppelin-contracts@v4.9.6
forge install OpenZeppelin/openzeppelin-contracts-upgradeable@v4.9.6
```

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
