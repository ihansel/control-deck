#include <opus.h>

// opus_encoder_ctl is variadic, which Swift cannot call directly. Keep the
// controller-specific encoder configuration in this tiny typed C bridge.
static inline int ps5_opus_configure_dualsense_speaker(OpusEncoder *encoder) {
    int result = opus_encoder_ctl(encoder, OPUS_SET_VBR(0));
    if (result != OPUS_OK) return result;
    result = opus_encoder_ctl(encoder, OPUS_SET_COMPLEXITY(0));
    if (result != OPUS_OK) return result;
    result = opus_encoder_ctl(
        encoder,
        OPUS_SET_EXPERT_FRAME_DURATION(OPUS_FRAMESIZE_10_MS)
    );
    if (result != OPUS_OK) return result;
    return opus_encoder_ctl(encoder, OPUS_SET_BITRATE(160000));
}
