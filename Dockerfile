FROM gcr.io/oss-fuzz-base/base-builder
RUN apt-get update && apt-get install -y --no-install-recommends     cmake ninja-build make pkg-config zlib1g-dev python3 &&     rm -rf /var/lib/apt/lists/*
WORKDIR /src
COPY build.sh dcmtk_dicom_fuzzer.cc dcmtk_meta_fuzzer.cc dcmtk_dicom_fuzzer.dict make_seed_corpus.py ./
