#!/bin/sh
# Build selftest.bit with the open-source openXC7 toolchain in Docker.
# First run downloads the Artix-7 bitstream database (~80 MB) and generates
# the nextpnr chip database (a few minutes); both are cached.
set -eu

PART=xc7a35tcpg236-1
IMAGE=regymm/openxc7
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/openxc7"
HERE="$(cd "$(dirname "$0")" && pwd)"

mkdir -p "$CACHE/chipdb"

if [ ! -d "$CACHE/prjxray-db/artix7" ]; then
    git clone --depth 1 --filter=blob:none --sparse \
        https://github.com/openXC7/prjxray-db.git "$CACHE/prjxray-db"
    git -C "$CACHE/prjxray-db" sparse-checkout set --no-cone \
        '/artix7/*.json' '/artix7/*.yaml' '/artix7/*.db' '/artix7/*.sh' \
        "/artix7/$PART/" '/artix7/xc7a50t/' '/artix7/mapping/'
fi

run() {
    docker run --rm -u "$(id -u):$(id -g)" \
        -v "$CACHE/prjxray-db:/db:ro" -v "$CACHE/chipdb:/chipdb" -v "$HERE:/w" -w /w \
        "$IMAGE" "$@"
}

if [ ! -f "$CACHE/chipdb/$PART.bin" ]; then
    echo ">> generating chip database for $PART (one-time)"
    run sh -c "python3 /nextpnr-xilinx/xilinx/python/bbaexport.py \
                 --device $PART --xray /db/artix7 --bba /chipdb/$PART.bba &&
               bbasm -l /chipdb/$PART.bba /chipdb/$PART.bin && rm /chipdb/$PART.bba"
fi

mkdir -p build
run sh -c "
  yosys -q -l build/yosys.log -p 'synth_xilinx -flatten -abc9 -arch xc7 -top top; write_json build/top.json' selftest.v &&
  nextpnr-xilinx -q -l build/nextpnr.log --chipdb /chipdb/$PART.bin --xdc basys3.xdc \
      --json build/top.json --fasm build/top.fasm --freq 100 &&
  fasm2frames --part $PART --db-root /db/artix7 build/top.fasm > build/top.frames &&
  xc7frames2bit --part_file /db/artix7/$PART/part.yaml --part_name $PART \
      --frm_file build/top.frames --output_file build/top.bit &&
  python3 fix_header.py build/top.bit selftest.bit
"
echo ">> built $HERE/selftest.bit"
