# QuakeSAVER

Decentralized multi-agent UAV/UGV system for earthquake disaster response.
ME 366 (Electro-Mechanical System Design), BUET.

## Setup (Ubuntu 22.04)

```bash
git clone git@github.com:<user>/quakesaver.git ~/quakesaver_ws
cd ~/quakesaver_ws
./scripts/bootstrap.sh
source ~/.bashrc
./scripts/launch_all.sh
```

## Packages

| Package | Role |
|---|---|
| qs_msgs | Shared message interfaces (build first) |
| qs_uav | Mission manager, ortho camera, entry-point detector |
| qs_comms | LoRa bridge + link simulator |
| qs_ugv | CNP auction, Bully election, Nav2 executor |
| qs_base | Passive dashboard + ABORT publisher |
| qs_bringup | Launch files and tmux orchestration |

## Architecture notes

- Base station is passive — observer plus human ABORT only.
- CNP auction allocates tasks among UGVs only. UAVs are not bidders.
- Bully election selects the auctioneer within the UGV pool.
- UAV1 = SYSID 1, UAV2 (relay) = SYSID 2. Distinct namespaces /uav1, /uav2.
