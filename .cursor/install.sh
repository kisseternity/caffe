#!/usr/bin/env bash
# Cloud Agent install script for Caffe (CPU-only build).
# Idempotent: safe to run multiple times. Builds the C++ library, CLI tools
# and the Python (pycaffe) bindings against the checked-out source.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_DIR"

# ---[ System dependencies ]---------------------------------------------------
sudo apt-get update
sudo apt-get install -y --no-install-recommends \
  build-essential cmake git wget curl pkg-config ca-certificates \
  libboost-all-dev \
  libgflags-dev libgoogle-glog-dev \
  libhdf5-dev \
  libatlas-base-dev \
  libleveldb-dev liblmdb-dev libsnappy-dev \
  libopencv-dev \
  libprotobuf-dev protobuf-compiler \
  python3-dev python3-numpy python3-pip

# ---[ Python dependencies for pycaffe ]---------------------------------------
# Modern replacements for the (Python 2 era) pins in python/requirements.txt.
pip install --break-system-packages \
  scikit-image protobuf pyyaml Pillow six scipy \
  matplotlib networkx pandas python-dateutil

# ---[ Build Caffe (CPU-only) ]------------------------------------------------
# Force GCC (the default image's /usr/bin/c++ resolves to clang, which cannot
# find libstdc++ here). Provide OpenCV 2/3 -> OpenCV 4 constant shims via
# compiler defines so the source builds unmodified against OpenCV 4.
rm -rf build
mkdir -p build
cd build
cmake .. \
  -DCMAKE_C_COMPILER=/usr/bin/gcc \
  -DCMAKE_CXX_COMPILER=/usr/bin/g++ \
  -DCMAKE_CXX_FLAGS="-DCV_LOAD_IMAGE_COLOR=cv::IMREAD_COLOR -DCV_LOAD_IMAGE_GRAYSCALE=cv::IMREAD_GRAYSCALE" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCPU_ONLY=On \
  -DUSE_CUDNN=Off \
  -DBLAS=Atlas \
  -Dpython_version=3 \
  -DBUILD_matlab=Off \
  -DBUILD_docs=Off \
  -DUSE_OPENCV=On -DUSE_LMDB=On -DUSE_LEVELDB=On
make -j"$(nproc)"
make pycaffe

# ---[ Make `import caffe` work for future agents ]----------------------------
# Add the pycaffe package dir to the user site via a .pth file (idempotent).
USER_SITE="$(python3 -m site --user-site)"
mkdir -p "$USER_SITE"
echo "${REPO_DIR}/python" > "$USER_SITE/caffe.pth"

echo "Caffe install complete. Binary: ${REPO_DIR}/build/tools/caffe"
