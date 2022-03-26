echo -e '\e[40m\e[91m'
echo -e '  ____                  _                    '
echo -e ' / ___|_ __ _   _ _ __ | |_ ___  _ __        '
echo -e '| |   |  __| | | |  _ \| __/ _ \|  _ \       '
echo -e '| |___| |  | |_| | |_) | || (_) | | | |      '
echo -e ' \____|_|   \__  |  __/ \__\___/|_| |_|      '
echo -e '            |___/|_|                         '
echo -e '\e[0m'

sleep 2

echo -e '\n\e[42mWireguard Installation\e[0m\n' && sleep 2

apt update && apt upgrade -y
apt install wireguard -y 

wg genkey | tee /etc/wireguard/privatekey | wg pubkey | tee /etc/wireguard/publickey
chmod 600 /etc/wireguard/privatekey

IP=$(wget -qO- eth0.me)
NETWORK_INTERFACE=$(ip a | grep -oP '(?<=2: ).*' | grep -o '^....')
echo 'export IP='$IP >> $HOME/.bash_profile
echo 'export NETWORK_INTERFACE='${NETWORK_INTERFACE} >> $HOME/.bash_profile
source $HOME/.bash_profile

sudo tee /etc/wireguard/wg0.conf > /dev/null <<EOF
[Interface]
PrivateKey = $(cat /etc/wireguard/privatekey)
Address = 10.0.0.1/24
ListenPort = 51800
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -t nat -A POSTROUTING -o $NETWORK_INTERFACE -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -t nat -D POSTROUTING -o $NETWORK_INTERFACE -j MASQUERADE
EOF

echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

sudo systemctl daemon-reload
sudo systemctl enable wg-quick@wg0.service
sudo systemctl start wg-quick@wg0.service

echo -e '\n\e[42mGenerating keys for confs\e[0m\n' && sleep 2

for ACC_NUM in {1..10} 
do
wg genkey | tee /etc/wireguard/$ACC_NUM'_private' | wg pubkey | tee /etc/wireguard/$ACC_NUM'_public'
sudo tee -a /etc/wireguard/wg0.conf > /dev/null <<EOF

[Peer]
PublicKey = $(cat /etc/wireguard/$ACC_NUM'_public')
AllowedIPs = 10.0.0.$ACC_NUM/32
EOF

sudo systemctl daemon-reload
systemctl restart wg-quick@wg0.service 
done

echo -e '\n\e[42m==================================================\e[0m\n'
echo -e '\n\e[42mSAVE ALL DATA BELOW\e[0m\n' && sleep 2
echo -e '\n\e[42m==================================================\e[0m\n'

for ACC_NUM in {1..10} 
do 
echo "
[Interface]
PrivateKey = $(cat /etc/wireguard/$ACC_NUM'_private')
Address = 10.0.0.'$ACC_NUM'/32
DNS = 8.8.8.8

[Peer]
PublicKey = $(cat /etc/wireguard/publickey)
Endpoint = $IP:51800
AllowedIPs = 0.0.0.0/0  
PersistentKeepalive = 20" 
echo -e "\n\e[42m###################################\e[0m\n"
done

echo -e '\n\e[42m==================================================\e[0m\n'
echo -e '\n\e[42mSAVE ALL DATA ABOVE\e[0m\n' && sleep 2
echo -e '\n\e[42m==================================================\e[0m\n'