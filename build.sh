#!/bin/bash -eux
cd "$SRC"

git clone --depth 1 https://github.com/DCMTK/dcmtk.git
cmake -S dcmtk -B dcmtk-build   -DBUILD_SHARED_LIBS=OFF   -DDCMTK_WITH_OPENSSL=OFF   -DDCMTK_WITH_PNG=OFF   -DDCMTK_WITH_TIFF=OFF   -DDCMTK_WITH_XML=OFF   -DDCMTK_WITH_ICONV=OFF   -DDCMTK_WITH_ZLIB=ON   -DCMAKE_BUILD_TYPE=Release   -DCMAKE_INSTALL_PREFIX="$WORK/dcmtk-install"
cmake --build dcmtk-build -j"$(nproc)"
cmake --install dcmtk-build

DICT_SRC=$(ls "$WORK"/dcmtk-install/share/dcmtk-*/dicom.dic 2>/dev/null || true)
if [ -n "$DICT_SRC" ]; then
  cp "$DICT_SRC" "$OUT/dicom.dic" || true
fi

$CXX $CXXFLAGS -std=c++17 -I"$WORK/dcmtk-install/include"   "$SRC/dcmtk_dicom_fuzzer.cc" -o "$OUT/dcmtk_dicom_fuzzer_bin"   $LIB_FUZZING_ENGINE -L"$WORK/dcmtk-install/lib"   -Wl,--start-group -ldcmdata -loflog -lofstd -loficonv -lz -Wl,--end-group

$CXX $CXXFLAGS -std=c++17 -I"$WORK/dcmtk-install/include"   "$SRC/dcmtk_meta_fuzzer.cc" -o "$OUT/dcmtk_meta_fuzzer_bin"   $LIB_FUZZING_ENGINE -L"$WORK/dcmtk-install/lib"   -Wl,--start-group -ldcmdata -loflog -lofstd -loficonv -lz -Wl,--end-group

cat > "$OUT/dcmtk_dicom_fuzzer" << 'EOF'
#!/bin/sh
export ASAN_OPTIONS="${ASAN_OPTIONS}:allocator_may_return_null=1:soft_rss_limit_mb=2000:hard_rss_limit_mb=2300"
[ -f /out/dicom.dic ] && export DCMDICTPATH=/out/dicom.dic
exec /out/dcmtk_dicom_fuzzer_bin "$@"
EOF
chmod +x "$OUT/dcmtk_dicom_fuzzer"

cat > "$OUT/dcmtk_meta_fuzzer" << 'EOF'
#!/bin/sh
export ASAN_OPTIONS="${ASAN_OPTIONS}:allocator_may_return_null=1:soft_rss_limit_mb=2000:hard_rss_limit_mb=2300"
[ -f /out/dicom.dic ] && export DCMDICTPATH=/out/dicom.dic
exec /out/dcmtk_meta_fuzzer_bin "$@"
EOF
chmod +x "$OUT/dcmtk_meta_fuzzer"

cat > "$OUT/dcmtk_dicom_fuzzer.options" << 'EOF'
[libfuzzer]
max_len = 131072
timeout = 25
rss_limit_mb = 2560
dict = /out/dcmtk_dicom_fuzzer.dict
EOF

cat > "$OUT/dcmtk_meta_fuzzer.options" << 'EOF'
[libfuzzer]
max_len = 65536
timeout = 25
rss_limit_mb = 2560
dict = /out/dcmtk_dicom_fuzzer.dict
EOF

cp /src/dcmtk_dicom_fuzzer.dict "$OUT/"

python3 /src/make_seed_corpus.py
