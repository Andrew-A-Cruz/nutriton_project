package com.andrewcruz.logbite

import android.net.Uri
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import kotlin.math.hypot

// A FragmentActivity, because Health Connect's permission flow needs one.
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // The nutrition label scan: "recognize" takes the path of a photo and
        // returns its lines of text with their positions, read on the device
        // by ML Kit. The Dart side (core/label_scan.dart) turns them into a
        // table.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "logbite/label_ocr")
            .setMethodCallHandler { call, result ->
                if (call.method != "recognize") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val path = call.arguments as? String
                if (path == null) {
                    result.error("unreadable", "The photo could not be opened", null)
                    return@setMethodCallHandler
                }
                try {
                    // fromFilePath applies the photo's EXIF rotation.
                    val image = InputImage.fromFilePath(this, Uri.fromFile(File(path)))
                    val recognizer =
                        TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
                    recognizer.process(image)
                        .addOnSuccessListener { text ->
                            // Each line as its text, the middle of its left
                            // edge (x1, y1) and right edge (x2, y2), and its
                            // height, in pixels from the top left. The corner
                            // points run clockwise from the top left.
                            val lines = text.textBlocks.flatMap { it.lines }.mapNotNull { line ->
                                val p = line.cornerPoints
                                if (p == null || p.size < 4) {
                                    null
                                } else {
                                    mapOf(
                                        "text" to line.text,
                                        "x1" to (p[0].x + p[3].x) / 2.0,
                                        "y1" to (p[0].y + p[3].y) / 2.0,
                                        "x2" to (p[1].x + p[2].x) / 2.0,
                                        "y2" to (p[1].y + p[2].y) / 2.0,
                                        "height" to hypot(
                                            (p[3].x - p[0].x).toDouble(),
                                            (p[3].y - p[0].y).toDouble(),
                                        ),
                                    )
                                }
                            }
                            result.success(lines)
                        }
                        .addOnFailureListener { e -> result.error("failed", e.message, null) }
                        .addOnCompleteListener { recognizer.close() }
                } catch (e: Exception) {
                    result.error("failed", e.message, null)
                }
            }
    }
}
