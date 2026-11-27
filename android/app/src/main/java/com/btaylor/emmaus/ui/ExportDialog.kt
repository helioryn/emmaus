package com.btaylor.emmaus.ui

import android.content.Context
import android.content.Intent
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.btaylor.emmaus.AppViewModel

/** Picks between a JSON backup and a Markdown copy of the notebook. */
@Composable
fun ExportDialog(vm: AppViewModel, onDismiss: () -> Unit) {
    val c = Emmaus.colors
    val context = LocalContext.current
    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = c.surface,
        title = { Text("Export", color = c.ink, fontWeight = FontWeight.SemiBold) },
        text = {
            Column {
                ExportOption(
                    title = "JSON backup",
                    detail = "Notes, highlights, bookmarks, history and plan days. Import it on another device."
                ) {
                    share(context, vm.user.exportJson(), "application/json", "Export Emmaus data")
                    onDismiss()
                }
                Spacer(Modifier.height(8.dp))
                ExportOption(
                    title = "Markdown",
                    detail = "Readable notes and bookmarks, for Obsidian, Bear or a text editor."
                ) {
                    share(
                        context,
                        vm.user.exportMarkdown { id -> vm.bible.book(id)?.name ?: "Book $id" },
                        "text/markdown",
                        "Export notes as Markdown"
                    )
                    onDismiss()
                }
            }
        },
        confirmButton = {},
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel", color = c.muted) } }
    )
}

@Composable
private fun ExportOption(title: String, detail: String, onClick: () -> Unit) {
    val c = Emmaus.colors
    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(9.dp))
            .background(c.background)
            .clickable(onClick = onClick)
            .padding(12.dp)
    ) {
        Text(title, color = c.ink, fontSize = 12.5.sp, fontWeight = FontWeight.SemiBold)
        Text(detail, color = c.muted, fontSize = 9.5.sp, modifier = Modifier.padding(top = 2.dp))
    }
}

private fun share(context: Context, text: String, mime: String, title: String) {
    val intent = Intent(Intent.ACTION_SEND).apply {
        type = mime
        putExtra(Intent.EXTRA_TEXT, text)
    }
    context.startActivity(Intent.createChooser(intent, title))
}
