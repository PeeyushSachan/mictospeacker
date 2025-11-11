package com.example.mic_to_speaker.audio

import android.media.*
import kotlinx.coroutines.*
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.pow
import kotlin.math.sin
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
    private var sampleRate: Int = 44100
    @Volatile private var params = DspParams()
    private val eqFilters = Array(5) { Biquad() }
    @Volatile private var eqEnabled = false

    fun apply(p: DspParams) {
        params = p
        updateEqFilters()
    }

    fun start(): Boolean {
        if (job != null) return true
        val sr = AudioTrack.getNativeOutputSampleRate(AudioManager.STREAM_MUSIC)
        val channelIn = AudioFormat.CHANNEL_IN_MONO
        val channelOut = AudioFormat.CHANNEL_OUT_MONO
        val fmt = AudioFormat.ENCODING_PCM_16BIT

        val recBuf = AudioRecord.getMinBufferSize(sr, channelIn, fmt).coerceAtLeast(4096)
        val playBuf = AudioTrack.getMinBufferSize(sr, channelOut, fmt).coerceAtLeast(4096)

        record = AudioRecord(
            MediaRecorder.AudioSource.VOICE_RECOGNITION, // low AGC
            sr, channelIn, fmt, recBuf
        )
        track = AudioTrack(
            AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA).setContentType(AudioAttributes.CONTENT_TYPE_SPEECH).build(),
            AudioFormat.Builder().setEncoding(fmt).setChannelMask(channelOut).setSampleRate(sr).build(),
            playBuf,
            AudioTrack.MODE_STREAM,
            AudioManager.AUDIO_SESSION_ID_GENERATE
        )

        if (record?.state != AudioRecord.STATE_INITIALIZED || track?.state != AudioTrack.STATE_INITIALIZED) {
            stop(); return false
        }

        record?.startRecording()
        track?.play()
        sampleRate = sr
        updateEqFilters()

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
                    val eqOn = eqEnabled
                    if (vol != 1.0 || eqOn) {
                        for (i in 0 until n) {
                            var sample = buf[i].toDouble() / 32768.0
                            if (eqOn) {
                                for (filter in eqFilters) {
                                    sample = filter.process(sample)
                                }
                            }
                            sample *= vol
                            val v = (sample * 32767.0).toInt()
                                .coerceIn(Short.MIN_VALUE.toInt(), Short.MAX_VALUE.toInt())
                            buf[i] = v.toShort()
                        }
                    }

                    // TODO: implement remaining effects (pitch/formant/reverb/echo)

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

    private fun updateEqFilters() {
        val sr = sampleRate
        if (sr <= 0) return
        val bands = params.eq
        var enabled = false
        for (i in eqFilters.indices) {
            val band = bands.getOrNull(i)
            val gain = band?.gainDb ?: 0.0
            val freq = band?.freq?.toDouble() ?: 0.0
            if (abs(gain) < 0.01 || freq <= 0.0) {
                eqFilters[i].setBypass()
            } else {
                eqFilters[i].setPeaking(freq, gain, 1.0, sr)
                if (!enabled) enabled = true
            }
        }
        eqEnabled = enabled
    }
}

private class Biquad {
    private var b0 = 1.0
    private var b1 = 0.0
    private var b2 = 0.0
    private var a1 = 0.0
    private var a2 = 0.0
    private var z1 = 0.0
    private var z2 = 0.0

    fun setBypass() {
        b0 = 1.0; b1 = 0.0; b2 = 0.0
        a1 = 0.0; a2 = 0.0
        z1 = 0.0; z2 = 0.0
    }

    fun setPeaking(freq: Double, gainDb: Double, q: Double, sampleRate: Int) {
        if (freq <= 0.0 || sampleRate <= 0) { setBypass(); return }
        val A = 10.0.pow(gainDb / 40.0)
        val omega = 2.0 * PI * freq / sampleRate
        val sinW = sin(omega)
        val cosW = cos(omega)
        val alpha = sinW / (2.0 * q.coerceAtLeast(0.1))

        var b0 = 1 + alpha * A
        var b1 = -2 * cosW
        var b2 = 1 - alpha * A
        val a0 = 1 + alpha / A
        var a1 = -2 * cosW
        var a2 = 1 - alpha / A

        b0 /= a0; b1 /= a0; b2 /= a0
        a1 /= a0; a2 /= a0

        this.b0 = b0; this.b1 = b1; this.b2 = b2
        this.a1 = a1; this.a2 = a2
        z1 = 0.0; z2 = 0.0
    }

    fun process(x: Double): Double {
        val y = b0 * x + z1
        z1 = b1 * x - a1 * y + z2
        z2 = b2 * x - a2 * y
        return y
    }
}
