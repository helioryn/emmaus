package com.btaylor.emmaus.ui

import android.content.Intent
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.DeleteOutline
import androidx.compose.material.icons.outlined.IosShare
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Tab
import androidx.compose.material3.TabRow
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.btaylor.emmaus.AppViewModel
import com.btaylor.emmaus.Screen
import com.btaylor.emmaus.data.refLabel

@Composable
fun NotebookScreen(vm: AppViewModel) {
    val c = Emmaus.colors
    val context = LocalContext.current
    var tab by remember { mutableStateOf(0) }
    val tabs = listOf("Notes", "Highlights", "Bookmarks")

    Column(Modifier.fillMaxSize().background(c.background)) {
        Row(
            Modifier.fillMaxWidth().statusBarsPadding().padding(horizontal = 18.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(Modifier.weight(1f)) {
                Text("Notebook", color = c.ink, fontFamily = ReadingFont, fontSize = 27.sp, fontWeight = FontWeight.SemiBold)
                Text(
                    "${vm.user.notes.size} notes · ${vm.user.highlights.size} highlights · ${vm.user.bookmarks.size} bookmarks",
                    color = c.muted,
                    fontSize = 10.sp
                )
            }
            IconButton(onClick = {
                val intent = Intent(Intent.ACTION_SEND).apply {
                    type = "application/json"
                    putExtra(Intent.EXTRA_TEXT, vm.user.exportJson())
                }
                context.startActivity(Intent.createChooser(intent, "Export Emmaus data"))
            }) {
                Icon(Icons.Outlined.IosShare, contentDescription = "Export", tint = c.accent)
            }
        }

        TabRow(
            selectedTabIndex = tab,
            containerColor = c.background,
            contentColor = c.accent
        ) {
            tabs.forEachIndexed { index, title ->
                Tab(selected = tab == index, onClick = { tab = index }, text = { Text(title, fontSize = 11.sp) })
            }
        }

        when (tab) {
            0 -> NotesList(vm)
            1 -> HighlightsList(vm)
            else -> BookmarksList(vm)
        }
    }
}

@Composable
private fun NotesList(vm: AppViewModel) {
    val c = Emmaus.colors
    val keys = vm.user.noteKeys()
    if (keys.isEmpty()) {
        EmptyNote("No notes yet", "Open a verse, tap its number, and use the Notes tab.", vm)
        return
    }
    LazyColumn(
        contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 14.dp, vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        items(keys) { key ->
            val (b, ch, v) = vm.user.parseKey(key) ?: return@items
            val body = vm.user.notes[key] ?: return@items
            Row(
                Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(9.dp))
                    .background(c.surface)
                    .clickable {
                        vm.open(b, ch, v)
                        vm.screen = Screen.READ
                        vm.selectVerse(v)
                    }
                    .padding(12.dp),
                verticalAlignment = Alignment.Top
            ) {
                Column(Modifier.weight(1f)) {
                    Text(refLabel(vm.bible.book(b), ch, v), color = c.accent, fontSize = 10.5.sp, fontWeight = FontWeight.SemiBold)
                    Spacer(Modifier.height(3.dp))
                    Text(body, color = c.ink.copy(alpha = 0.9f), fontSize = 12.sp, fontFamily = ReadingFont, maxLines = 3, overflow = TextOverflow.Ellipsis)
                }
                IconButton(onClick = { vm.user.saveNote(b, ch, v, "") }) {
                    Icon(Icons.Outlined.DeleteOutline, contentDescription = "Delete", tint = c.muted)
                }
            }
        }
    }
}

@Composable
private fun HighlightsList(vm: AppViewModel) {
    val c = Emmaus.colors
    val keys = vm.user.highlightKeys()
    if (keys.isEmpty()) {
        EmptyNote("No highlights", "Select a verse, open Notes, and choose a highlight color.", vm)
        return
    }
    LazyColumn(
        contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 14.dp, vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        items(keys) { key ->
            val (b, ch, v) = vm.user.parseKey(key) ?: return@items
            val colorIndex = vm.user.highlights[key] ?: return@items
            val text = vm.bible.verseText(vm.translationCode, b, ch, v) ?: ""
            Row(
                Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(9.dp))
                    .background(c.surface)
                    .clickable {
                        vm.open(b, ch, v)
                        vm.screen = Screen.READ
                    }
                    .padding(12.dp)
            ) {
                Box(Modifier.width(4.dp).height(38.dp).clip(RoundedCornerShape(2.dp)).background(c.highlights.getOrElse(colorIndex) { c.accent }))
                Spacer(Modifier.width(10.dp))
                Column(Modifier.weight(1f)) {
                    Text(refLabel(vm.bible.book(b), ch, v), color = c.accent, fontSize = 10.5.sp, fontWeight = FontWeight.SemiBold)
                    Text(text, color = c.ink.copy(alpha = 0.88f), fontSize = 12.sp, fontFamily = ReadingFont, maxLines = 2, overflow = TextOverflow.Ellipsis)
                }
            }
        }
    }
}

@Composable
private fun BookmarksList(vm: AppViewModel) {
    val c = Emmaus.colors
    val keys = vm.user.bookmarkKeys()
    if (keys.isEmpty()) {
        EmptyNote("No bookmarks", "Bookmark a verse from the study sheet and it will appear here.", vm)
        return
    }
    LazyColumn(
        contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 14.dp, vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        items(keys) { key ->
            val (b, ch, v) = vm.user.parseKey(key) ?: return@items
            val text = vm.bible.verseText(vm.translationCode, b, ch, v) ?: ""
            Row(
                Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(9.dp))
                    .background(c.surface)
                    .clickable {
                        vm.open(b, ch, v)
                        vm.screen = Screen.READ
                    }
                    .padding(12.dp)
            ) {
                Column(Modifier.weight(1f)) {
                    Text(refLabel(vm.bible.book(b), ch, v), color = c.accent, fontSize = 10.5.sp, fontWeight = FontWeight.SemiBold)
                    Text(text, color = c.ink.copy(alpha = 0.88f), fontSize = 12.sp, fontFamily = ReadingFont, maxLines = 2, overflow = TextOverflow.Ellipsis)
                }
            }
        }
    }
}

@Composable
private fun EmptyNote(title: String, message: String, vm: AppViewModel) {
    val c = Emmaus.colors
    Box(Modifier.fillMaxSize().padding(30.dp), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(title, color = c.ink, fontFamily = ReadingFont, fontSize = 20.sp)
            Spacer(Modifier.height(4.dp))
            Text(message, color = c.muted, fontSize = 11.sp)
            Spacer(Modifier.height(12.dp))
            Text(
                "Open the reader",
                color = c.accent,
                fontSize = 11.sp,
                modifier = Modifier
                    .clip(RoundedCornerShape(8.dp))
                    .background(c.accent.copy(alpha = 0.09f))
                    .clickable { vm.screen = Screen.READ }
                    .padding(horizontal = 12.dp, vertical = 7.dp)
            )
        }
    }
}
