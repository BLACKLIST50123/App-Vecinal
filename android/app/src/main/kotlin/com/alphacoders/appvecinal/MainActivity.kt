package com.alphacoders.appvecinal

import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var botones: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        botones = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "conecta_vecino/botones")
    }

    // Atajo SOS: Android entrega los botones de volumen al control de volumen
    // y Flutter no los ve. Aquí se avisa a Flutter de cada pulsación y luego
    // se deja que el volumen cambie con normalidad.
    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (event.action == KeyEvent.ACTION_DOWN && event.repeatCount == 0 &&
            (event.keyCode == KeyEvent.KEYCODE_VOLUME_UP || event.keyCode == KeyEvent.KEYCODE_VOLUME_DOWN)
        ) {
            botones?.invokeMethod("volumen", null)
        }
        return super.dispatchKeyEvent(event)
    }
}
