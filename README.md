BPI-R4 - Openwrt + Kernel 6.6.94 + MTK-Feeds

For other build platforms please see openwrt documentation at: https://openwrt.org/docs/guide-developer/toolchain/install-buildsystem

Ubuntu Server 24.04.2 LTS

git clone https://github.com/slarkyy/bpi-r4-build-6.6.94.git

sudo chmod 776 -R bpi-r4

cd bpi-r4

sudo chmod +x ./build.sh

./build.sh

Script will automatically install needed packages for your build host