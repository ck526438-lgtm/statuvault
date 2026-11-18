package com.statuvault.statuvault

import android.app.Activity
import android.content.Intent
import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.Executors

/**
 * Statuvault — accès aux statuts WhatsApp via le Storage Access Framework (SAF).
 * Fonctionne sur Android 5 à 15 sans la permission MANAGE_EXTERNAL_STORAGE :
 * l'utilisateur autorise une seule fois le dossier .Statuses.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "statuvault/statuses"
    private val reqTree = 4242
    private var pending: MethodChannel.Result? = null
    private val io = Executors.newFixedThreadPool(3)
    private val main = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "sdkInt" -> result.success(Build.VERSION.SDK_INT)
                    "persistedTrees" -> result.success(
                        contentResolver.persistedUriPermissions
                            .filter { it.isReadPermission }
                            .map { it.uri.toString() }
                    )
                    "openTree" -> openTree(call.argument<String>("path") ?: "", result)
                    "releaseTree" -> {
                        try {
                            contentResolver.releasePersistableUriPermission(
                                Uri.parse(call.argument<String>("tree")!!),
                                Intent.FLAG_GRANT_READ_URI_PERMISSION
                            )
                        } catch (_: Exception) {
                        }
                        result.success(true)
                    }
                    "list" -> bg(result) { listStatuses(Uri.parse(call.argument<String>("tree")!!)) }
                    "cache" -> bg(result) {
                        cacheFile(Uri.parse(call.argument<String>("uri")!!), call.argument<String>("name")!!)
                    }
                    "thumb" -> bg(result) {
                        videoThumb(Uri.parse(call.argument<String>("uri")!!), call.argument<String>("name")!!)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun bg(result: MethodChannel.Result, block: () -> Any?) {
        io.execute {
            try {
                val value = block()
                main.post { result.success(value) }
            } catch (e: Exception) {
                main.post { result.error("STATUVAULT", e.message ?: e.toString(), null) }
            }
        }
    }

    private fun openTree(path: String, result: MethodChannel.Result) {
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PREFIX_URI_PERMISSION
            )
        }
        if (Build.VERSION.SDK_INT >= 26 && path.isNotEmpty()) {
            val initial = DocumentsContract.buildDocumentUri(
                "com.android.externalstorage.documents", "primary:$path"
            )
            intent.putExtra(DocumentsContract.EXTRA_INITIAL_URI, initial)
        }
        pending?.success(null)
        pending = result
        try {
            @Suppress("DEPRECATION")
            startActivityForResult(intent, reqTree)
        } catch (e: Exception) {
            pending = null
            result.error("STATUVAULT", "Sélecteur de dossier indisponible : ${e.message}", null)
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != reqTree) return
        val r = pending
        pending = null
        val uri = data?.data
        if (resultCode == Activity.RESULT_OK && uri != null) {
            try {
                contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
            } catch (_: Exception) {
            }
            r?.success(uri.toString())
        } else {
            r?.success(null)
        }
    }

    private val cols = arrayOf(
        DocumentsContract.Document.COLUMN_DOCUMENT_ID,
        DocumentsContract.Document.COLUMN_DISPLAY_NAME,
        DocumentsContract.Document.COLUMN_MIME_TYPE,
        DocumentsContract.Document.COLUMN_LAST_MODIFIED,
        DocumentsContract.Document.COLUMN_SIZE
    )

    private data class Child(val id: String, val name: String, val mime: String, val modified: Long, val size: Long)

    private fun children(tree: Uri, docId: String): List<Child> {
        val out = ArrayList<Child>()
        val uri = DocumentsContract.buildChildDocumentsUriUsingTree(tree, docId)
        contentResolver.query(uri, cols, null, null, null)?.use { c ->
            while (c.moveToNext()) {
                val id = c.getString(0) ?: continue
                val name = c.getString(1) ?: continue
                out.add(
                    Child(
                        id, name, c.getString(2) ?: "",
                        if (c.isNull(3)) 0L else c.getLong(3),
                        if (c.isNull(4)) 0L else c.getLong(4)
                    )
                )
            }
        }
        return out
    }

    /** Liste les médias. Si l'utilisateur a choisi un dossier parent, on descend jusqu'à .Statuses. */
    private fun listStatuses(tree: Uri): List<Map<String, Any?>> {
        var docId = DocumentsContract.getTreeDocumentId(tree)
        var items = children(tree, docId)
        for (step in 0 until 4) {
            if (items.any { isMedia(it) }) break
            val dirs = items.filter { it.mime == DocumentsContract.Document.MIME_TYPE_DIR }
            val next = dirs.firstOrNull { it.name == ".Statuses" }
                ?: dirs.firstOrNull { it.name == "Media" }
                ?: dirs.firstOrNull { it.name.startsWith("WhatsApp") }
                ?: break
            docId = next.id
            items = children(tree, docId)
        }
        return items.filter { isMedia(it) }.map {
            mapOf(
                "uri" to DocumentsContract.buildDocumentUriUsingTree(tree, it.id).toString(),
                "name" to it.name,
                "type" to if (isVideo(it)) "video" else "image",
                "modified" to it.modified,
                "size" to it.size
            )
        }
    }

    private fun ext(name: String) = name.substringAfterLast('.', "").lowercase()
    private fun isVideo(c: Child) = c.mime.startsWith("video/") || ext(c.name) in setOf("mp4", "3gp", "mkv", "mov", "webm")
    private fun isImage(c: Child) = c.mime.startsWith("image/") || ext(c.name) in setOf("jpg", "jpeg", "png", "webp", "gif")
    private fun isMedia(c: Child) = !c.name.startsWith(".") && (isVideo(c) || isImage(c))

    private fun safe(name: String) = name.replace(Regex("[^A-Za-z0-9._-]"), "_")

    private fun cacheFile(uri: Uri, name: String): String {
        val dir = File(cacheDir, "statuses").apply { mkdirs() }
        val f = File(dir, safe(name))
        if (f.exists() && f.length() > 0) return f.absolutePath
        val tmp = File(dir, safe(name) + ".part")
        contentResolver.openInputStream(uri).use { input ->
            requireNotNull(input) { "Fichier illisible" }
            FileOutputStream(tmp).use { out -> input.copyTo(out) }
        }
        tmp.renameTo(f)
        return f.absolutePath
    }

    private fun videoThumb(uri: Uri, name: String): String? {
        val dir = File(cacheDir, "thumbs").apply { mkdirs() }
        val f = File(dir, safe(name) + ".jpg")
        if (f.exists() && f.length() > 0) return f.absolutePath
        val r = MediaMetadataRetriever()
        try {
            r.setDataSource(this, uri)
            val frame = r.getFrameAtTime(500_000, MediaMetadataRetriever.OPTION_CLOSEST_SYNC) ?: return null
            val w = 360
            val h = (frame.height * (w.toFloat() / frame.width)).toInt().coerceAtLeast(1)
            val small = Bitmap.createScaledBitmap(frame, w, h, true)
            FileOutputStream(f).use { small.compress(Bitmap.CompressFormat.JPEG, 78, it) }
            return f.absolutePath
        } finally {
            try {
                r.release()
            } catch (_: Exception) {
            }
        }
    }
}
