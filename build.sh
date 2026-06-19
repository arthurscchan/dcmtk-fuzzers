#!/bin/bash -eux
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# DCMTK is already built and installed under this prefix by the OSS-Fuzz build.sh.
DCMTK_INSTALL="$WORK/dcmtk-install"
DCMTK_LIBS="-Wl,--start-group -ldcmimage -ldcmimgle -ldcmjpeg -ldcmjpls -lijg8 -lijg12 -lijg16 -ldcmtkcharls -ldcmdata -loflog -lofstd -loficonv -lz -Wl,--end-group"

FUZZERS=("$HERE"/*_fuzzer.cc)

# Build all fuzzers.
for src in "${FUZZERS[@]}"; do
  name="$(basename "$src" .cc)"
  $CXX $CXXFLAGS -std=c++17 -I"$DCMTK_INSTALL/include" "$src" \
    -o "$OUT/$name" $LIB_FUZZING_ENGINE -L"$DCMTK_INSTALL/lib" $DCMTK_LIBS
done

# Prepare corpus for all (the seed corpus is shared).
python3 "$HERE/make_seed_corpus.py"
for src in "${FUZZERS[@]}"; do
  name="$(basename "$src" .cc)"
  [ "$OUT/${name}_seed_corpus.zip" = "$OUT/dcmtk_dicom_fuzzer_seed_corpus.zip" ] || \
    cp "$OUT/dcmtk_dicom_fuzzer_seed_corpus.zip" "$OUT/${name}_seed_corpus.zip"
done
