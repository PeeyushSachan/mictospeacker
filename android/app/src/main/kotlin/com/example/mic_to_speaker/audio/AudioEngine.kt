package com.example.mic_to_speaker.audio

import android.media.*
import kotlinx.coroutines.*
import kotlin.math.abs
import kotlin.math.ln
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sqrt

data class EqBandParam(val freq: Int, val gainDb: Double)
data class DspParams(
    val eq: List<EqBandParam> = emptyList(),
    val pitch: Double = 1.0,     // TODO
    val formant: Int = 0,        // TODO
    val reverb: Boolean = false, // TODO
    val reverbWet: Double = 0.25,// TODO
    val echo: Boolean = false,   // TODO
    val echoDelayMs: Int = 240,  // TODO
    val echoFeedback: Double = 0.35, // TODO
    val volume: Double = 1.0
)

class AudioEngine(
    private val onLevel: (Double) -> Unit
) {
    private var record: AudioRecord? = null
    private var track: AudioTrack? = null
    private var job: Job? = null
    @Volatile private var params = DspParams()

    fun apply(p: DspParams) { params = p }

    fun start(): Boolean {
        if (job != null) return true
        val sampleRate = AudioTrack.getNativeOutputSampleRate(AudioManager.STREAM_MUSIC)
        val channelIn = AudioFormat.CHANNEL_IN_MONO
        val channelOut = AudioFormat.CHANNEL_OUT_MONO
        val fmt = AudioFormat.ENCODING_PCM_16BIT

        val recBuf = AudioRecord.getMinBufferSize(sampleRate, channelIn, fmt).coerceAtLeast(4096)
        val playBuf = AudioTrack.getMinBufferSize(sampleRate, channelOut, fmt).coerceAtLeast(4096)

        record = AudioRecord(
            MediaRecorder.AudioSource.VOICE_RECOGNITION, // low AGC
            sampleRate, channelIn, fmt, recBuf
        )
        track = AudioTrack(
            AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA).setContentType(AudioAttributes.CONTENT_TYPE_SPEECH).build(),
            AudioFormat.Builder().setEncoding(fmt).setChannelMask(channelOut).setSampleRate(sampleRate).build(),
            playBuf,
            AudioTrack.MODE_STREAM,
            AudioManager.AUDIO_SESSION_ID_GENERATE
        )

        if (record?.state != AudioRecord.STATE_INITIALIZED || track?.state != AudioTrack.STATE_INITIALIZED) {
            stop(); return false
        }

        record?.startRecording()
        track?.play()

        job = CoroutineScope(Dispatchers.Default).launch {
            val buf = ShortArray(1024)
            while (isActive) {
                val n = record?.read(buf, 0, buf.size) ?: 0
                if (n > 0) {
                    // simple RMS for VU
                    var sum = 0.0
                    for (i in 0 until n) { val s = buf[i].toDouble(); sum += s*s }
                    val rms = sqrt(sum / n) / 32768.0
                    onLevel(rms.coerceIn(0.0, 1.0))

                    // master volume (linear)
                    val vol = params.volume.coerceIn(0.0, 1.0)
                    if (vol != 1.0) {
                        for (i in 0 until n) {
                            val v = (buf[i] * vol).toInt()
                            buf[i] = v.coerceIn(Short.MIN_VALUE.toInt(), Short.MAX_VALUE.toInt()).toShort()
                        }
                    }

                    // TODO: apply EQ & effects here (Biquad cascade / TarsosDSP)

                    track?.write(buf, 0, n)
                }
            }
        }
        return true
    }

    fun stop() {
        job?.cancel(); job = null
        try { record?.stop() } catch (_: Throwable) {}
        try { track?.stop() } catch (_: Throwable) {}
        record?.release(); record = null
        track?.release(); track = null
    }
}
