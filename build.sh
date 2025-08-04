#!/bin/bash

# --- Helper Functions ---
print_step() {
    echo "================================================================="
    echo "=> $1"
    echo "================================================================="
}

# --- Build Step Functions ---

step_01_install_dependencies() {
    print_step "STEP 1: Installing Build System Dependencies (requires sudo)"
    echo "This will use apt to install necessary packages."
    echo "You may be prompted for your password."

    # De-duplicated and cleaned package list
    PACKAGES="build-essential clang flex bison g++ gawk gcc-multilib g++-multilib gettext git libncurses-dev libssl-dev python3-setuptools rsync swig unzip zlib1g-dev file wget libtraceevent-dev systemtap-sdt-dev libslang-dev"

    sudo apt-get update || { echo "apt update failed"; return 1; }
    sudo apt-get install -y $PACKAGES || { echo "apt install failed"; return 1; }

    echo "Dependency installation complete."
}


step_02_cleanup() {
    print_step "STEP 2: Cleaning up old build directories"
    read -p "This will delete './openwrt' and './mtk-openwrt-feeds'. Are you sure? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cleanup cancelled."
        return 1
    fi
    rm -rf openwrt
    rm -rf mtk-openwrt-feeds
    echo "Cleanup complete."
}

step_03_clone_repos() {
    print_step "STEP 3: Cloning OpenWrt and MediaTek Feeds"
    
    echo "Cloning OpenWrt repository..."
    git clone --branch openwrt-24.10 https://git.openwrt.org/openwrt/openwrt.git openwrt || true
    cd openwrt; git checkout 4a18bb1056c78e1224ae3444f5862f6265f9d91c; cd -;
    
    echo "Cloning MediaTek feeds repository..."
    git clone --branch master https://git01.mediatek.com/openwrt/feeds/mtk-openwrt-feeds || true
    cd mtk-openwrt-feeds; git checkout 05615a80ed680b93c3c8337c209d42a2e00db99b; cd -;
    
    echo "Repositories cloned and checked out to specific commits."
}

step_04_apply_patches() {
    print_step "STEP 4: Applying all custom pre-build patches"
    
    if [ ! -d "openwrt" ] || [ ! -d "mtk-openwrt-feeds" ]; then
        echo "Error: 'openwrt' or 'mtk-openwrt-feeds' directory not found. Please run Step 3 first."
        return 1
    fi

    echo "Applying MediaTek feed revisions and various fixes..."
    echo "05615a8" > mtk-openwrt-feeds/autobuild/unified/feed_revision

    ### wireless-regdb modification
    rm -rf openwrt/package/firmware/wireless-regdb/patches/*.*
    rm -rf mtk-openwrt-feeds/autobuild/unified/filogic/mac80211/24.10/files/package/firmware/wireless-regdb/patches/*.*
    cp -v my_files/500-tx_power.patch mtk-openwrt-feeds/autobuild/unified/filogic/mac80211/24.10/files/package/firmware/wireless-regdb/patches/
    cp -v my_files/regdb.Makefile openwrt/package/firmware/wireless-regdb/Makefile

    ### Misc Patches
    rm -f mtk-openwrt-feeds/24.10/patches-feeds/108-strongswan-add-uci-support.patch
    cp -v my_files/200-v.kosikhin-libiwinfo-fix_noise_reading_for_radios.patch openwrt/package/network/utils/iwinfo/patches/
    cp -v my_files/99999_tx_power_check.patch mtk-openwrt-feeds/autobuild/unified/filogic/mac80211/24.10/files/package/kernel/mt76/patches/
    cp -v my_files/9997-use-tx_power-from-default-fw-if-EEPROM-contains-0s.patch mtk-openwrt-feeds/autobuild/unified/filogic/mac80211/24.10/files/package/kernel/mt76/patches/

    ### MTK_Patches - Build fixes & Enhancements (grouped for clarity)
    PATCH_DIR_6_6="mtk-openwrt-feeds/autobuild/unified/filogic/mac80211/24.10/files/target/linux/mediatek/patches-6.6"
    
    rm -f mtk-openwrt-feeds/autobuild/unified/filogic/24.10/patches-feeds/cryptsetup-*.patch
    cp -v my_files/cryptsetup-01-add-host-build.patch mtk-openwrt-feeds/autobuild/unified/filogic/24.10/patches-feeds/

    rm -f ${PATCH_DIR_6_6}/999-30{02,03,10,19}-*.patch
    cp -v my_files/999-30{02,03,10,19}-*.patch "${PATCH_DIR_6_6}/"

    rm -f ${PATCH_DIR_6_6}/999-30{2,3}*.patch
    cp -v my_files/QoSMT7988/*.patch "${PATCH_DIR_6_6}/"

    rm -f mtk-openwrt-feeds/24.10/files/target/linux/mediatek/files-6.6/arch/arm64/boot/dts/mediatek/mt7988a-rfb-4pcie.dtso
    rm -f mtk-openwrt-feeds/24.10/patches-base/1120-image-mediatek-filogic-mt7988a-rfb-05-add-4pcie-overlays.patch
    cp -v my_files/mt7988a-rfb-4pcie.dtso mtk-openwrt-feeds/24.10/files/target/linux/mediatek/files-6.6/arch/arm64/boot/dts/mediatek/
    cp -v my_files/1120-image-mediatek-filogic-mt7988a-rfb-05-add-4pcie-overlays.patch mtk-openwrt-feeds/24.10/patches-base/

    rm -f mtk-openwrt-feeds/autobuild/unified/filogic/24.10/files/scripts/make-squashfs-hashed.sh
    cp -v my_files/make-squashfs-hashed.sh mtk-openwrt-feeds/autobuild/unified/filogic/24.10/files/scripts/

    rm -f mtk-openwrt-feeds/autobuild/unified/filogic/24.10/files/target/linux/mediatek/files-6.6/drivers/net/ethernet/mediatek/mtk_eth_reset.*
    cp -v my_files/mtk_eth_reset.* mtk-openwrt-feeds/autobuild/unified/filogic/24.10/files/target/linux/mediatek/files-6.6/drivers/net/ethernet/mediatek/

    cp -v my_files/999-2702-crypto-avoid-rcu-stall.patch mtk-openwrt-feeds/24.10/files/target/linux/mediatek/patches-6.6/

    rm -f mtk-openwrt-feeds/24.10/files/target/linux/mediatek/patches-6.6/999-cpufreq-02-*.patch
    cp -v my_files/999-cpufreq-*.patch mtk-openwrt-feeds/24.10/files/target/linux/mediatek/patches-6.6/
    
    rm -f ${PATCH_DIR_6_6}/999-3004-*.patch ${PATCH_DIR_6_6}/999-3016-*.patch
    cp -v my_files/999-3004-netfilter-add-DSCP-learning-flow-to-xt_FLOWOFFLOAD.patch "${PATCH_DIR_6_6}/"
    cp -v my_files/999-3016-netfilter-add-DSCP-learning-flow-to-nft_flow_offload.patch "${PATCH_DIR_6_6}/"

    rm -f mtk-openwrt-feeds/feed/kernel/crypto-eip/src/ddk-wrapper.c
    cp -v my_files/ddk-wrapper.c mtk-openwrt-feeds/feed/kernel/crypto-eip/src/

    rm -f mtk-openwrt-feeds/autobuild/unified/filogic/24.10/files/target/linux/mediatek/files-6.6/arch/arm64/boot/dts/mediatek/mt7987-emmc.dtso
    cp -v my_files/mt7987-emmc.dtso mtk-openwrt-feeds/autobuild/unified/filogic/24.10/files/target/linux/mediatek/files-6.6/arch/arm64/boot/dts/mediatek/

    rm -f mtk-openwrt-feeds/feed/app/regs/src/regs.c
    cp -v my_files/regs.c mtk-openwrt-feeds/feed/app/regs/src/

    rm -f openwrt/scripts/ipkg-remove
    cp -v my_files/ipkg-remove openwrt/scripts/

    rm -f mtk-openwrt-feeds/autobuild/unified/filogic/mac80211/24.10/remove_list.txt
    cp -v my_files/remove_list.txt mtk-openwrt-feeds/autobuild/unified/filogic/mac80211/24.10/

    echo "All patches applied successfully."
}

step_05_configure_build() {
    print_step "STEP 5: Setting up build configuration"
    
    if [ ! -d "mtk-openwrt-feeds" ]; then
        echo "Error: 'mtk-openwrt-feeds' directory not found. Please run Step 3 first."
        return 1
    fi
    
    echo "Copying custom defconfig..."
    rm -f mtk-openwrt-feeds/autobuild/unified/filogic/24.10/defconfig
    cp -v my_files/defconfig mtk-openwrt-feeds/autobuild/unified/filogic/24.10/
    
    echo "Disabling 'perf' package in various configs..."
    sed -i 's/CONFIG_PACKAGE_perf=y/# CONFIG_PACKAGE_perf is not set/' mtk-openwrt-feeds/autobuild/unified/filogic/mac80211/24.10/defconfig
    sed -i 's/CONFIG_PACKAGE_perf=y/# CONFIG_PACKAGE_perf is not set/' mtk-openwrt-feeds/autobuild/autobuild_5.4_mac80211_release/mt7988_wifi7_mac80211_mlo/.config
    sed -i 's/CONFIG_PACKAGE_perf=y/# CONFIG_PACKAGE_perf is not set/' mtk-openwrt-feeds/autobuild/autobuild_5.4_mac80211_release/mt7986_mac80211/.config

    echo "Configuration complete."
}

step_06_run_autobuild() {
    print_step "STEP 6: Running the MediaTek autobuild script"
    
    if [ ! -d "openwrt" ] || [ ! -f "mtk-openwrt-feeds/autobuild/unified/autobuild.sh" ]; then
        echo "Error: 'openwrt' directory or autobuild script not found. Please run previous steps."
        return 1
    fi

    echo "This step will start the full build process and may take a long time."
    read -p "Do you want to proceed? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Build cancelled."
        return 1
    fi
    
    cd openwrt || return
    bash ../mtk-openwrt-feeds/autobuild/unified/autobuild.sh filogic-mac80211-mt7988_rfb-mt7996 log_file=make
    BUILD_RESULT=$?
    cd - || return
    
    if [ $BUILD_RESULT -eq 0 ]; then
        echo "Build completed successfully."
    else
        echo "Build failed. Check the log file in the 'openwrt' directory."
        return 1
    fi
}

step_07_post_build_injection() {
    print_step "STEP 7: Injecting post-build files"

    if [ ! -d "openwrt" ]; then
        echo "Error: 'openwrt' directory not found. Build must be run first."
        return 1
    fi
    
    if [ ! -d "post_build_files" ]; then
        echo "Error: 'post_build_files' directory not found. Cannot inject files."
        return 1
    fi
    
    echo "Injecting 'files' directory into 'openwrt/files'..."
    cp -rv post_build_files/files openwrt/
    
    echo "Injecting custom mt76 patch..."
    cp -v post_build_files/001-Add-tx_power-check-Yukariin.patch openwrt/package/kernel/mt76/patches/

    echo "Post-build injection complete. You may need to rebuild for changes to take effect."
    echo "Hint: cd openwrt && make -j\$(nproc)"
}


run_all_steps() {
    print_step "Running ALL build steps autonomously"
    step_01_install_dependencies && \
    step_02_cleanup && \
    step_03_clone_repos && \
    step_04_apply_patches && \
    step_05_configure_build && \
    step_06_run_autobuild && \
    step_07_post_build_injection
}

# --- Main Menu Logic ---
main_menu() {
    while true; do
        echo
        print_step "OpenWrt Custom Build Menu"
        echo " 1) Step 1: Install Build Dependencies"
        echo " 2) Step 2: Clean Up Old Builds"
        echo " 3) Step 3: Clone Repositories"
        echo " 4) Step 4: Apply Pre-Build Patches"
        echo " 5) Step 5: Configure Build (.config)"
        echo " 6) Step 6: Run MediaTek Autobuild"
        echo " 7) Step 7: Inject Post-Build Files"
        echo "-----------------------------------------------------------------"
        echo " a) Run ALL Steps (1-7)"
        echo " q) Quit"
        echo
        read -p "Enter your choice: " choice

        case $choice in
            1) step_01_install_dependencies ;;
            2) step_02_cleanup ;;
            3) step_03_clone_repos ;;
            4) step_04_apply_patches ;;
            5) step_05_configure_build ;;
            6) step_06_run_autobuild ;;
            7) step_07_post_build_injection ;;
            a|A) run_all_steps ;;
            q|Q) echo "Exiting script."; exit 0 ;;
            *) echo "Invalid option. Please try again." ;;
        esac
    done
}

# --- Script Entry Point ---
main_menu