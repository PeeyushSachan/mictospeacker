package com.techfoon.micky

import com.techfoon.micky.audio.*
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val METHOD = "mic_to_speaker/audio"
    private val EVENT  = "mic_to_speaker/level"

    private var levelSink: EventChannel.EventSink? = null
    private val engine = AudioEngine { level ->
        runOnUiThread { levelSink?.success(level) }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD).setMethodCallHandler { call, result ->
            when(call.method){
                "start" -> { result.success(engine.start()) }
                "stop"  -> { engine.stop(); result.success(null) }
                "apply" -> {
                    val map = call.arguments as Map<*, *>
                    engine.apply(map.toDspParams())
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT)
            .setStreamHandler(object: EventChannel.StreamHandler{
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { levelSink = events }
                override fun onCancel(arguments: Any?) { levelSink = null }
            })
    }
}

/** Convert Dart map → DspParams */
private fun Map<*, *>.toDspParams(): DspParams {
    val eqList = (this["eq"] as List<*>).map {
        val m = it as Map<*, *>
        EqBandParam((m["freq"] as Number).toInt(), (m["gainDb"] as Number).toDouble())
    }
    return DspParams(
        eq = eqList,
        pitch = (this["pitch"] as Number).toDouble(),
        formant = (this["formant"] as Number).toInt(),
        reverb = this["reverb"] as Boolean,
        reverbWet = (this["reverbWet"] as Number).toDouble(),
        echo = this["echo"] as Boolean,
        echoDelayMs = (this["echoDelayMs"] as Number).toInt(),
        echoFeedback = (this["echoFeedback"] as Number).toDouble(),
        volume = (this["volume"] as Number).toDouble(),
        voicePreset = (this["voicePreset"] as? String) ?: "normal"
    )
}
