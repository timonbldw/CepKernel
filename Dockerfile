FROM ubuntu:22.04

ARG CLANG_VERSION=17.0.2
ARG REPO_URL=https://github.com/Separatee/CepKernel.git
ARG REPO_BRANCH=13.0-lxc-docker-nethunter

# Install build dependencies
RUN apt-get update -qq && \
    apt-get install -y -qq --no-install-recommends \
        build-essential bc bison flex libssl-dev libelf-dev \
        libyaml-dev ccache zip python3 git curl wget xz-utils ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Download and install Clang toolchain
# Use --retry for transient GitHub 502s; encode '+' as %2B in the URL
RUN curl -fsSL --retry 3 --retry-delay 5 \
        "https://github.com/llvm/llvm-project/releases/download/llvmorg-${CLANG_VERSION}/clang%2Bllvm-${CLANG_VERSION}-aarch64-linux-gnu.tar.xz" \
        -o /tmp/clang.tar.xz && \
    mkdir -p /opt/clang && \
    tar xf /tmp/clang.tar.xz -C /opt/clang --strip-components=1 && \
    rm /tmp/clang.tar.xz

# Add clang to PATH
ENV PATH="/opt/clang/bin:${PATH}"

# Verify clang installation
RUN clang --version | head -1

# Shallow-clone kernel source from GitHub (no host mount needed).
# This avoids macOS case-insensitivity issues (xt_MARK.h vs xt_mark.h)
# and makes the build fully self-contained.
WORKDIR /kernel
RUN git clone --depth=1 --branch=${REPO_BRANCH} ${REPO_URL} . && \
    git submodule update --init KernelSU && \
    git clone --depth=1 https://github.com/osm0sis/AnyKernel3.git AnyKernel3

# ---------------------------------------------------------------------------
# Overwrite upstream files with patched versions:
#   - cepheus_defconfig — Docker/LXC support (namespaces, cgroups, networking)
#   - Makefile.lib       — python2→python3 invocation fix
#   - mkdtboimg.py       — Python 3 syntax (xrange→range, 'is 0'→'== 0')
# ---------------------------------------------------------------------------
COPY arch/arm64/configs/cepheus_defconfig          arch/arm64/configs/cepheus_defconfig
COPY scripts/Makefile.lib                          scripts/Makefile.lib
COPY cepheus_anykernel.sh                          cepheus_anykernel.sh
COPY scripts/dtc/mkdtboimg.py                      scripts/dtc/mkdtboimg.py
COPY tools/perf/scripts/python/sched-migration.py  tools/perf/scripts/python/sched-migration.py
COPY build.sh                                      build.sh
COPY kernel/cgroup/cpuset.c                        kernel/cgroup/cpuset.c
