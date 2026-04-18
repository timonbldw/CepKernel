#!/bin/bash

#set -e

KERNEL_DEFCONFIG=cepheus_defconfig
ANYKERNEL3_DIR=$PWD/AnyKernel3/
FINAL_KERNEL_ZIP=Asuna_cepheus_DLN.zip
KERNEL_OUT_DIR=$PWD/kernel_out

# Colors
GREEN='\033[01;32m'
YELLOW='\033[01;33m'
RED='\033[01;31m'
BOLD='\033[1m'
RESET='\033[0m'

status() {
    echo -e "${GREEN}[*]${RESET} ${BOLD}$1${RESET}"
}

warn() {
    echo -e "${YELLOW}[!]${RESET} $1"
}

error() {
    echo -e "${RED}[x]${RESET} $1"
}

# paths
TC="$PWD"
#注意 你需要下载17.0.2版本的clang并自行加入环境变量
#Attention! You should download ver17.0.2 clang for compiling.
# Download Url: https://github.com/llvm/llvm-project/releases/tag/llvmorg-17.0.2
# PATH=${TC}/clang+llvm-17.0.2-x86_64-linux-gnu-ubuntu-22.04/bin:${TC}/aarch64/bin:${TC}/arm/bin:$PATH

export KBUILD_OUTPUT=$PWD/out
export CC=clang
#请按照需求修改下方指令并解除注释
#Edit the code below according to what you need,its up to U!
#export CROSS_COMPILE=aarch64-linux-gnu-
export ARCH=arm64
export SUBARCH=arm64
export USE_CCACHE=1

# Speed up build process
MAKE="./makeparallel"

echo ""
status "Configuring kernel with ${KERNEL_DEFCONFIG}..."
make O=out ARCH=arm64 $KERNEL_DEFCONFIG

START=$(date +"%s")

echo ""
status "Compiling kernel ($(nproc --all) threads)..."
make ARCH=arm64 \
        O=out \
        CC=clang \
	AR=llvm-ar \
        LD=ld.lld \
        HOSTLD=ld \
        NM=llvm-nm \
        OBJCOPY=llvm-objcopy \
        OBJDUMP=llvm-objdump \
        STRIP=llvm-strip \
        -j$(nproc --all)

echo ""
status "Verifying kernel image..."
if [ ! -f "$PWD/out/arch/arm64/boot/Image.gz-dtb" ]; then
    error "Image.gz-dtb not found! Kernel compilation failed."
    exit 1
fi
ls -lh $PWD/out/arch/arm64/boot/Image.gz-dtb

status "Preparing AnyKernel3 package..."
mkdir -p $KERNEL_OUT_DIR
cp cepheus_anykernel.sh $ANYKERNEL3_DIR/anykernel.sh
#rm -rf $ANYKERNEL3_DIR/Image.gz-dtb
#rm -rf $ANYKERNEL3_DIR/$FINAL_KERNEL_ZIP

status "Copying Image.gz-dtb into AnyKernel3..."
cp $PWD/out/arch/arm64/boot/Image.gz-dtb $ANYKERNEL3_DIR/

status "Creating flashable ZIP with AnyKernel3..."
cd $ANYKERNEL3_DIR/
zip -r9 $FINAL_KERNEL_ZIP * -x README $FINAL_KERNEL_ZIP

status "Copying ZIP to output directory..."
cp $ANYKERNEL3_DIR/$FINAL_KERNEL_ZIP $KERNEL_OUT_DIR/$FINAL_KERNEL_ZIP
cd ..

#rm -rf $ANYKERNEL3_DIR/$FINAL_KERNEL_ZIP
#rm -rf $ANYKERNEL3_DIR/Image.gz-dtb
#rm -rf out/

END=$(date +"%s")
DIFF=$((END - START))

echo ""
echo -e "${GREEN}============================================${RESET}"
echo -e "${GREEN}  Kernel build finished successfully!${RESET}"
echo -e "${GREEN}============================================${RESET}"
echo -e "  Duration : $((DIFF / 60))m $((DIFF % 60))s"
echo -e "  ZIP      : ${BOLD}${KERNEL_OUT_DIR}/${FINAL_KERNEL_ZIP}${RESET}"
echo -e "  SHA1     : $(sha1sum ${KERNEL_OUT_DIR}/${FINAL_KERNEL_ZIP} | awk '{print $1}')"
echo -e "${GREEN}============================================${RESET}"
echo ""
