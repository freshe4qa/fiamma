#!/bin/bash

while true
do

# Logo

echo -e '\e[40m\e[91m'
echo -e '  ____                  _                    '
echo -e ' / ___|_ __ _   _ _ __ | |_ ___  _ __        '
echo -e '| |   |  __| | | |  _ \| __/ _ \|  _ \       '
echo -e '| |___| |  | |_| | |_) | || (_) | | | |      '
echo -e ' \____|_|   \__  |  __/ \__\___/|_| |_|      '
echo -e '            |___/|_|                         '
echo -e '\e[0m'

sleep 2

# Menu

PS3='Select an action: '
options=(
"Install"
"Create Wallet"
"Create Validator"
"Exit")
select opt in "${options[@]}"
do
case $opt in

"Install")
echo "============================================================"
echo "Install start"
echo "============================================================"

# set vars
if [ ! $NODENAME ]; then
	read -p "Enter node name: " NODENAME
	echo 'export NODENAME='$NODENAME >> $HOME/.bash_profile
fi
if [ ! $WALLET ]; then
	echo "export WALLET=wallet" >> $HOME/.bash_profile
fi
echo "export FIAMMA_CHAIN_ID=fiamma-testnet-1" >> $HOME/.bash_profile
source $HOME/.bash_profile

# update
sudo apt update && sudo apt upgrade -y

# packages
apt install curl iptables build-essential git wget jq make gcc nano tmux htop nvme-cli pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip libleveldb-dev lz4 -y

# install go
VER="1.22.3"
wget "https://golang.org/dl/go$VER.linux-amd64.tar.gz"
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf "go$VER.linux-amd64.tar.gz"
rm "go$VER.linux-amd64.tar.gz"
[ ! -f ~/.bash_profile ] && touch ~/.bash_profile
echo "export PATH=$PATH:/usr/local/go/bin:~/go/bin" >> ~/.bash_profile
source $HOME/.bash_profile
[ ! -d ~/go/bin ] && mkdir -p ~/go/bin

# download binary
cd $HOME && rm -rf fiamma
git clone https://github.com/fiamma-chain/fiamma.git
cd fiamma
git checkout v1.0.0
make install

# config
fiammad config chain-id $FIAMMA_CHAIN_ID
fiammad config keyring-backend test

# init
fiammad init $NODENAME --chain-id $FIAMMA_CHAIN_ID

# download genesis and addrbook
wget -O $HOME/.fiamma/config/genesis.json https://server-5.itrocket.net/testnet/fiamma/genesis.json
wget -O $HOME/.fiamma/config/addrbook.json  https://server-5.itrocket.net/testnet/fiamma/addrbook.json

# set minimum gas price
sed -i -e "s|^minimum-gas-prices *=.*|minimum-gas-prices = \"0.00001ufia\"|" $HOME/.fiamma/config/app.toml

# set peers and seeds
SEEDS="1e8777199f1edb3a35937e653b0bb68422f3c931@fiamma-testnet-seed.itrocket.net:50656"
PEERS="16b7389e724cc440b2f8a2a0f6b4c495851934ff@fiamma-testnet-peer.itrocket.net:49656,5ead2fb9ef45dd786cc9bb805400e0a75037f7f8@135.125.97.162:30256,cd574a3d8c022e8a6f19b010230069ba9987d905@164.132.247.253:56396,b0335d1c77fa96c27458390e6c48d2bf74c1533b@176.9.24.46:50656,a12e8531f345ccff39f47847aabf12e73e216ee3@144.76.97.251:26796,13455fb8dcc64ea42ba3b20d58bd5b3b2f4f4991@84.247.141.40:50656,2f1f3bee3f9c946d1f91f078de09e313956a618e@161.97.167.196:20656,48cc8b28f2b7d07263936e5e2a7130bb01df1872@84.247.187.77:37656,1c9def41279dfc0fe2cc7c8de683d852f70bb2fc@195.26.241.17:26656,3ee17aaa7235a7e0c121b5dff396ea937d11e5fe@[2a01:4f8:202:54ec::2]:26656,fd8af2419e8a1cd9198066809465cb11c63b5428@148.251.128.49:29656"
sed -i -e "s/^seeds *=.*/seeds = \"$SEEDS\"/; s/^persistent_peers *=.*/persistent_peers = \"$PEERS\"/" $HOME/.fiamma/config/config.toml

# disable indexing
indexer="null"
sed -i -e "s/^indexer *=.*/indexer = \"$indexer\"/" $HOME/.fiamma/config/config.toml

# config pruning
pruning="custom"
pruning_keep_recent="100"
pruning_keep_every="0"
pruning_interval="10"
sed -i -e "s/^pruning *=.*/pruning = \"$pruning\"/" $HOME/.fiamma/config/app.toml
sed -i -e "s/^pruning-keep-recent *=.*/pruning-keep-recent = \"$pruning_keep_recent\"/" $HOME/.fiamma/config/app.toml
sed -i -e "s/^pruning-keep-every *=.*/pruning-keep-every = \"$pruning_keep_every\"/" $HOME/.fiamma/config/app.toml
sed -i -e "s/^pruning-interval *=.*/pruning-interval = \"$pruning_interval\"/" $HOME/.fiamma/config/app.toml
sed -i "s/snapshot-interval *=.*/snapshot-interval = 0/g" $HOME/.fiamma/config/app.toml

# enable prometheus
sed -i -e "s/prometheus = false/prometheus = true/" $HOME/.fiamma/config/config.toml

# create service
sudo tee /etc/systemd/system/fiammad.service > /dev/null << EOF
[Unit]
Description=Fiamma node service
After=network-online.target
[Service]
User=$USER
ExecStart=$(which fiammad) start
Restart=on-failure
RestartSec=10
LimitNOFILE=65535
[Install]
WantedBy=multi-user.target
EOF

# reset
fiammad tendermint unsafe-reset-all --home $HOME/.fiamma --keep-addr-book
curl https://server-5.itrocket.net/testnet/fiamma/fiamma_2024-11-26_310597_snap.tar.lz4 | lz4 -dc - | tar -xf - -C $HOME/.fiamma

# start service
sudo systemctl daemon-reload
sudo systemctl enable fiammad
sudo systemctl restart fiammad

break
;;

"Create Wallet")
fiammad keys add $WALLET
echo "============================================================"
echo "Save address and mnemonic"
echo "============================================================"
FIAMMA_WALLET_ADDRESS=$(fiammad keys show $WALLET -a)
FIAMMA_VALOPER_ADDRESS=$(fiammad keys show $WALLET --bech val -a)
echo 'export FIAMMA_WALLET_ADDRESS='${FIAMMA_WALLET_ADDRESS} >> $HOME/.bash_profile
echo 'export FIAMMA_VALOPER_ADDRESS='${FIAMMA_VALOPER_ADDRESS} >> $HOME/.bash_profile
source $HOME/.bash_profile

break
;;

"Create Validator")
fiammad tx staking create-validator \
--amount=1000000ufia \
--pubkey=$(fiammad tendermint show-validator) \
--moniker=$NODENAME \
--chain-id=fiamma-testnet-1 \
--commission-rate=0.10 \
--commission-max-rate=0.20 \
--commission-max-change-rate=0.01 \
--min-self-delegation=1 \
--from=wallet \
--gas-adjustment=1.5 \
--gas=300000 \
-y 
  
break
;;

"Exit")
exit
;;
*) echo "invalid option $REPLY";;
esac
done
done
