#include <cstdint>
#include <cstddef>
#include <cstdlib>
#include <new>

#include "dcmtk/dcmdata/dctk.h"
#include "dcmtk/dcmdata/dcistrmb.h"
#include "dcmtk/dcmdata/dcxfer.h"
#include "dcmtk/dcmdata/dcrledrg.h"
#include "dcmtk/dcmimage/diregist.h"
#include "dcmtk/dcmimgle/dcmimage.h"
#include "dcmtk/dcmimgle/diutils.h"
#include "dcmtk/dcmjpeg/djdecode.h"
#include "dcmtk/dcmjpls/djdecode.h"

static constexpr std::size_t kNewNothrowCap = 8 * 1024 * 1024;

void* operator new(std::size_t n, const std::nothrow_t&) noexcept {
  if (n > kNewNothrowCap) return nullptr;
  try { return ::operator new(n); } catch (...) { return nullptr; }
}
void* operator new[](std::size_t n, const std::nothrow_t&) noexcept {
  if (n > kNewNothrowCap) return nullptr;
  try { return ::operator new[](n); } catch (...) { return nullptr; }
}

static void cleanupCodecs() {
  DJDecoderRegistration::cleanup();
  DJLSDecoderRegistration::cleanup();
  DcmRLEDecoderRegistration::cleanup();
}

static bool registerCodecs() {
  DJDecoderRegistration::registerCodecs();
  DJLSDecoderRegistration::registerCodecs();
  DcmRLEDecoderRegistration::registerCodecs();
  std::atexit(cleanupCodecs);
  return true;
}

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
  static bool dict_set = (setenv("DCMDICTPATH", "/out/dicom.dic", 0), true);
  static bool codecs_set = registerCodecs();
  (void)dict_set;
  (void)codecs_set;

  DcmInputBufferStream in;
  in.setBuffer((void*)data, size);
  in.setEos();

  DcmFileFormat file;
  const Uint32 kMaxReadLen = 256 * 1024;

  if (file.read(in, EXS_Unknown, EGL_noChange, kMaxReadLen).good()) {
    if (auto* ds = file.getDataset()) {
      DicomImage* image = new (std::nothrow) DicomImage(&file, ds->getOriginalXfer());
      if (image && image->getStatus() == EIS_Normal) {
        unsigned long frames = image->getFrameCount();
        if (frames > 16) frames = 16;
        for (unsigned long f = 0; f < frames; ++f)
          (void)image->getOutputData(8, f);
      }
      delete image;
    }
  }
  return 0;
}
