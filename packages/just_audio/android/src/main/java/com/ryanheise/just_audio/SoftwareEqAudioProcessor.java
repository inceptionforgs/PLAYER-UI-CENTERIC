package com.ryanheise.just_audio;

import androidx.media3.common.C;
import androidx.media3.common.audio.AudioProcessor;
import androidx.media3.common.audio.AudioProcessor.AudioFormat;
import androidx.media3.common.audio.BaseAudioProcessor;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;

/**
 * Media3 PCM hook for Mewati software EQ.
 * DSP lives in the app ({@link Engine}); this class only moves samples
 * through the ExoPlayer {@link DefaultAudioSink} processor chain.
 *
 * Offload is disabled in {@code AudioPlayer} so this processor is not skipped.
 *
 * Do NOT override {@code isActive()} from engine.isEnabled(): Media3 freezes
 * the active-processor list at configure time. A live preset change (Normal
 * → Mewati Bass while playing) would stay silent until the next track/seek.
 * Disabled EQ is a passthrough copy instead — extra memcpy, correct sound.
 */
public final class SoftwareEqAudioProcessor extends BaseAudioProcessor {

    public interface Engine {
        boolean isEnabled();

        /** 16-bit interleaved PCM. Must not allocate. Safe on the audio thread. */
        void processInterleaved(short[] pcm, int frames, int channels, int sampleRate);

        void reset();
    }

    private static volatile Engine engine;

    public static void setEngine(Engine next) {
        engine = next;
    }

    public static Engine getEngine() {
        return engine;
    }

    private short[] scratch = new short[0];
    private final short[] pending = new short[16];
    private int pendingCount = 0;

    @Override
    protected AudioFormat onConfigure(AudioFormat inputAudioFormat)
            throws AudioProcessor.UnhandledAudioFormatException {
        if (inputAudioFormat.encoding != C.ENCODING_PCM_16BIT) {
            throw new AudioProcessor.UnhandledAudioFormatException(inputAudioFormat);
        }
        return inputAudioFormat;
    }

    @Override
    public void queueInput(ByteBuffer inputBuffer) {
        if (!inputBuffer.hasRemaining() && pendingCount == 0) {
            return;
        }
        int incoming = inputBuffer.remaining() / 2;
        int total = pendingCount + incoming;
        int channels = Math.max(1, inputAudioFormat.channelCount);
        int frames = total / channels;
        int used = frames * channels;
        int leftover = total - used;

        if (scratch.length < Math.max(total, 1)) {
            scratch = new short[Math.max(total, 1)];
        }
        if (pendingCount > 0) {
            System.arraycopy(pending, 0, scratch, 0, pendingCount);
        }
        if (incoming > 0) {
            inputBuffer.order(ByteOrder.nativeOrder());
            inputBuffer.asShortBuffer().get(scratch, pendingCount, incoming);
            inputBuffer.position(inputBuffer.limit());
        } else {
            inputBuffer.position(inputBuffer.limit());
        }

        Engine dsp = engine;
        boolean active = dsp != null && dsp.isEnabled();
        if (active && frames > 0) {
            try {
                dsp.processInterleaved(scratch, frames, channels, inputAudioFormat.sampleRate);
            } catch (Throwable ignored) {
                // Never crash the audio sink.
            }
        }

        if (leftover > 0) {
            System.arraycopy(scratch, used, pending, 0, leftover);
        }
        pendingCount = leftover;

        ByteBuffer output = replaceOutputBuffer(used * 2);
        if (used > 0) {
            output.order(ByteOrder.nativeOrder());
            output.asShortBuffer().put(scratch, 0, used);
            output.position(used * 2);
        }
        output.flip();
    }

    @Override
    protected void onQueueEndOfStream() {
        if (pendingCount <= 0) {
            return;
        }
        ByteBuffer output = replaceOutputBuffer(pendingCount * 2);
        output.order(ByteOrder.nativeOrder());
        output.asShortBuffer().put(pending, 0, pendingCount);
        output.position(pendingCount * 2);
        output.flip();
        pendingCount = 0;
    }

    @Override
    protected void onFlush() {
        pendingCount = 0;
        Engine dsp = engine;
        if (dsp != null) {
            try {
                dsp.reset();
            } catch (Throwable ignored) {
            }
        }
    }

    @Override
    protected void onReset() {
        onFlush();
        scratch = new short[0];
    }
}
