package com.btaylor.emmaus.ui

import android.content.Intent
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Bookmark
import androidx.compose.material.icons.outlined.BookmarkBorder
import androidx.compose.material.icons.outlined.Close
import androidx.compose.material.icons.outlined.VolumeUp
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.TabRow
import androidx.compose.material3.Tab
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.material3.rememberModalBottomSheetState
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
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.btaylor.emmaus.AppViewModel
import com.btaylor.emmaus.SheetTab
import com.btaylor.emmaus.data.CommentaryEntry
import com.btaylor.emmaus.data.CrossRef
import com.btaylor.emmaus.data.InterlinearWord
import com.btaylor.emmaus.data.StrongsEntry
import com.btaylor.emmaus.data.refLabel
import androidx.compose.runtime.CompositionLocalProvider

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun StudySheet(vm: AppViewModel) {
    val c = Emmaus.colors
    val sheet = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    ModalBottomSheet(
        onDismissRequest = { vm.sheetOpen = false },
        sheetState = sheet,
        containerColor = c.surface
    ) {
        StudySheetBody(vm, Modifier.fillMaxWidth().fillMaxHeight(0.92f))
    }
}

/**
 * The study panel without the modal wrapper, so tablets can dock it beside the
 * reader. [modifier] carries the height the caller wants.
 */
@Composable
fun StudySheetBody(vm: AppViewModel, modifier: Modifier = Modifier) {
    val c = Emmaus.colors
    val verse = vm.selectedVerse ?: return
    val context = LocalContext.current

    Column(modifier) {
            Row(
                Modifier.fillMaxWidth().padding(horizontal = 18.dp, vertical = 2.dp),
                verticalAlignment = Alignment.Top
            ) {
                Column(Modifier.weight(1f)) {
                    Text(
                        refLabel(vm.activeBook, vm.chapter, verse),
                        color = c.ink,
                        fontFamily = ReadingFont,
                        fontSize = 24.sp,
                        fontWeight = FontWeight.SemiBold
                    )
                    Spacer(Modifier.height(3.dp))
                    Text(
                        vm.bible.verseText(vm.translationCode, vm.bookId, vm.chapter, verse) ?: "",
                        color = c.muted,
                        fontFamily = ReadingFont,
                        fontSize = 12.5.sp,
                        lineHeight = 18.sp,
                        maxLines = 3
                    )
                }
                IconButton(onClick = { vm.toggleBookmark(verse) }) {
                    Icon(
                        if (vm.isBookmarked(verse)) Icons.Filled.Bookmark else Icons.Outlined.BookmarkBorder,
                        contentDescription = "Bookmark",
                        tint = if (vm.isBookmarked(verse)) c.accent else c.muted
                    )
                }
                IconButton(onClick = { vm.sheetOpen = false }) {
                    Icon(Icons.Outlined.Close, contentDescription = "Close", tint = c.muted)
                }
            }

            TabRow(
                selectedTabIndex = SheetTab.entries.indexOf(vm.sheetTab),
                containerColor = c.surface,
                contentColor = c.accent,
                divider = { HorizontalDivider(color = c.border.copy(alpha = 0.7f)) }
            ) {
                SheetTab.entries.forEach { tab ->
                    Tab(
                        selected = vm.sheetTab == tab,
                        onClick = { vm.selectTab(tab) },
                        text = { Text(tab.label, fontSize = 9.5.sp, fontWeight = if (vm.sheetTab == tab) FontWeight.SemiBold else FontWeight.Normal) }
                    )
                }
            }

            Box(Modifier.weight(1f)) {
                when (vm.sheetTab) {
                    SheetTab.STUDY -> StudyTab(vm, verse, context)
                    SheetTab.WORD -> WordTab(vm)
                    SheetTab.ORIGINAL -> OriginalTab(vm)
                    SheetTab.COMPARE -> CompareTab(vm, verse)
                    SheetTab.NOTES -> NotesTab(vm, verse)
                }
            }
        }
    }

@Composable
private fun StudyTab(vm: AppViewModel, verse: Int, context: android.content.Context) {
    val c = Emmaus.colors
    Column(
        Modifier.fillMaxHeight().verticalScroll(rememberScrollState()).padding(horizontal = 18.dp, vertical = 14.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        if (vm.crossRefs.isNotEmpty()) {
            Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    SectionLabel("Cross references")
                    Spacer(Modifier.weight(1f))
                    Text("${vm.crossRefs.size}", color = c.muted, fontSize = 9.5.sp)
                }
                vm.crossRefs.take(18).forEach { ref ->
                    CrossRefRow(vm, ref) {
                        vm.open(ref.toBook, ref.toChapter, ref.toVerseStart)
                        vm.sheetOpen = false
                    }
                }
            }
        }

        if (vm.commentary.isNotEmpty()) {
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    SectionLabel("Commentary")
                    Spacer(Modifier.weight(1f))
                    var menu by remember { mutableStateOf(false) }
                    Box {
                        TextButton(onClick = { menu = true }) {
                            Text(
                                workName(vm.selectedWork),
                                color = c.accent,
                                fontSize = 10.sp
                            )
                        }
                        DropdownMenu(expanded = menu, onDismissRequest = { menu = false }) {
                            vm.commentaryWorks().forEach { w ->
                                DropdownMenuItem(
                                    text = { Text(workName(w), fontSize = 11.sp) },
                                    onClick = { menu = false; vm.preferenceWork(w) }
                                )
                            }
                        }
                    }
                }
                vm.commentaryForSelected().forEach { entry ->
                    CommentaryBlock(vm, entry, c.ink, c.muted, c.surfaceAlt)
                }
            }
        }

        Column(verticalArrangement = Arrangement.spacedBy(3.dp)) {
            SectionLabel("Theologians")
            listOf(
                "Grace to You" to "John MacArthur sermons & resources",
                "Desiring God" to "John Piper",
                "Ligonier" to "R.C. Sproul",
                "The Gospel Coalition" to "Essays and commentary"
            ).forEach { (name, subtitle) ->
                Row(
                    Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(8.dp))
                        .background(c.surfaceAlt)
                        .clickable {
                            context.startActivity(Intent(Intent.ACTION_VIEW, android.net.Uri.parse(vm.theologianUrl(name))))
                        }
                        .padding(10.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column(Modifier.weight(1f)) {
                        Text(name, color = c.ink, fontSize = 12.sp, fontWeight = FontWeight.Medium)
                        Text(subtitle, color = c.muted, fontSize = 9.5.sp)
                    }
                    Text("↗", color = c.muted, fontSize = 12.sp)
                }
            }
            Text(
                "MacArthur's study notes are copyrighted and are linked, not bundled.",
                color = c.muted.copy(alpha = 0.8f),
                fontSize = 9.sp,
                modifier = Modifier.padding(top = 3.dp)
            )
        }
        Spacer(Modifier.height(30.dp))
    }
}

@Composable
private fun CrossRefRow(vm: AppViewModel, ref: CrossRef, onClick: () -> Unit) {
    val c = Emmaus.colors
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(7.dp))
            .background(c.surfaceAlt.copy(alpha = 0.55f))
            .clickable(onClick = onClick)
            .padding(horizontal = 10.dp, vertical = 6.dp),
        verticalAlignment = Alignment.Top
    ) {
        Column(Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    refLabel(vm.bible.book(ref.toBook), ref.toChapter, ref.toVerseStart),
                    color = c.accent,
                    fontSize = 10.5.sp,
                    fontWeight = FontWeight.SemiBold
                )
                if (ref.votes > 0) {
                    Spacer(Modifier.width(5.dp))
                    Text("${ref.votes}", color = c.muted.copy(alpha = 0.65f), fontSize = 8.5.sp)
                }
            }
            if (ref.preview.isNotBlank()) {
                Text(
                    ref.preview,
                    color = c.muted,
                    fontSize = 10.5.sp,
                    fontFamily = ReadingFont,
                    maxLines = 2
                )
            }
        }
        Text("↗", color = c.muted.copy(alpha = 0.4f), fontSize = 10.sp)
    }
}

private fun workName(work: String): String = when (work) {
    "matthew-henry" -> "Matthew Henry"
    "jamieson-fausset-brown" -> "Jamieson–Fausset–Brown"
    "tyndale" -> "Tyndale Open Study Notes"
    "geneva" -> "Geneva Bible Notes"
    "scofield" -> "Scofield Reference Notes"
    else -> work
}

@Composable
private fun CommentaryBlock(vm: AppViewModel, entry: CommentaryEntry, ink: Color, muted: Color, surface: Color) {
    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(9.dp))
            .background(surface)
            .padding(12.dp)
    ) {
        Text(
            refLabel(vm.bible.book(entry.book), entry.chapter, entry.verseStart),
            color = muted,
            fontSize = 9.sp,
            fontWeight = FontWeight.SemiBold
        )
        Spacer(Modifier.height(4.dp))
        Text(entry.body, color = ink.copy(alpha = 0.92f), fontSize = 12.sp, fontFamily = ReadingFont, lineHeight = 18.sp)
    }
}

@Composable
private fun WordTab(vm: AppViewModel) {
    val c = Emmaus.colors
    val entry = vm.selectedStrongs
    if (entry != null) {
        Column(Modifier.fillMaxHeight().verticalScroll(rememberScrollState())) {
            StrongsDetail(vm, entry) { b, ch, v ->
                vm.open(b, ch, v)
                vm.sheetOpen = false
            }
            if (vm.studyWords.size > 1) {
                Column(Modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    SectionLabel("Words in this verse")
                    vm.studyWords.forEach { w ->
                        Row(
                            Modifier
                                .fillMaxWidth()
                                .clip(RoundedCornerShape(7.dp))
                                .background(if (w.id == entry.id) c.accent.copy(alpha = 0.10f) else c.surfaceAlt)
                                .clickable { vm.openStrongs(w.id) }
                                .padding(9.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(w.id, color = c.accent, fontSize = 9.5.sp, fontWeight = FontWeight.Bold, modifier = Modifier.width(40.dp))
                            Text(w.lemma, color = c.ink, fontSize = 15.sp, fontFamily = ReadingFont)
                            Spacer(Modifier.width(6.dp))
                            Text(w.translit, color = c.muted, fontSize = 10.sp, fontFamily = ReadingFont, fontStyle = FontStyle.Italic)
                            Spacer(Modifier.weight(1f))
                            Text(w.gloss, color = c.muted, fontSize = 9.5.sp, maxLines = 1)
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun OriginalTab(vm: AppViewModel) {
    val c = Emmaus.colors
    val isHebrew = vm.interlinear.firstOrNull()?.isHebrew == true
    Column(
        Modifier.fillMaxHeight().verticalScroll(rememberScrollState()).padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(7.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            SectionLabel(if (isHebrew) "Hebrew interlinear" else "Greek interlinear")
            Spacer(Modifier.weight(1f))
            IconButton(onClick = {
                vm.speakWord(vm.interlinear.joinToString(" ") { it.text }, if (isHebrew) "he" else "grc")
            }) {
                Icon(Icons.Outlined.VolumeUp, contentDescription = "Read", tint = c.accent)
            }
        }
        if (vm.interlinear.isEmpty()) {
            Text("No interlinear data for this verse.", color = c.muted, fontSize = 11.sp)
        } else {
            vm.interlinear.forEach { word ->
                InterlinearRow(vm, word)
            }
        }
        Spacer(Modifier.height(30.dp))
    }
}

@Composable
private fun InterlinearRow(vm: AppViewModel, word: InterlinearWord) {
    val c = Emmaus.colors
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(8.dp))
            .background(c.surfaceAlt.copy(alpha = 0.6f))
            .padding(horizontal = 8.dp, vertical = 7.dp),
        verticalAlignment = Alignment.Top
    ) {
        IconButton(onClick = { vm.speakWord(word.text, word.lang) }) {
            Icon(Icons.Outlined.VolumeUp, contentDescription = "Read word", tint = c.muted)
        }
        Text(
            word.text,
            color = c.ink,
            fontSize = if (word.isHebrew) 19.sp else 15.sp,
            fontFamily = ReadingFont,
            modifier = Modifier.width(88.dp)
        )
        Column(Modifier.weight(1f)) {
            Text(word.translit, color = c.accent.copy(alpha = 0.85f), fontSize = 11.sp, fontFamily = ReadingFont, fontStyle = FontStyle.Italic)
            Text(word.gloss, color = c.muted, fontSize = 10.5.sp)
        }
        Column(horizontalAlignment = Alignment.End) {
            if (word.strongs.isNotBlank()) {
                Text(
                    word.strongs,
                    color = c.accent,
                    fontSize = 9.sp,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.clickable { vm.openStrongs(word.strongs) }
                )
            }
            Text(word.morph, color = c.muted.copy(alpha = 0.7f), fontSize = 8.sp)
        }
    }
}

@Composable
private fun CompareTab(vm: AppViewModel, verse: Int) {
    val c = Emmaus.colors
    Column(
        Modifier.fillMaxHeight().verticalScroll(rememberScrollState()).padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        SectionLabel("Compare translations")
        vm.bible.translations.filter { it.langCode == "en" }.forEach { tr ->
            val text = vm.bible.verseText(tr.code, vm.bookId, vm.chapter, verse) ?: return@forEach
            Column(
                Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(9.dp))
                    .background(c.surfaceAlt)
                    .padding(11.dp)
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    EmmausPill(tr.short)
                    Spacer(Modifier.width(6.dp))
                    Text(tr.name, color = c.muted, fontSize = 9.sp, maxLines = 1)
                }
                Spacer(Modifier.height(4.dp))
                Text(text, color = c.ink.copy(alpha = 0.92f), fontSize = 12.5.sp, fontFamily = ReadingFont, lineHeight = 18.sp)
            }
        }
        Text(
            "NIV, NASB, and NKJV are available on the Mac app through API.Bible; Android connected Bibles are the next step.",
            color = c.muted.copy(alpha = 0.8f),
            fontSize = 9.sp,
            lineHeight = 13.sp
        )
        Spacer(Modifier.height(30.dp))
    }
}

@Composable
private fun NotesTab(vm: AppViewModel, verse: Int) {
    val c = Emmaus.colors
    var text by remember(verse, vm.bookId, vm.chapter) { mutableStateOf(vm.note(verse)) }
    Column(
        Modifier.fillMaxHeight().verticalScroll(rememberScrollState()).padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            SectionLabel("Your note")
            Spacer(Modifier.weight(1f))
            if (text.isNotBlank()) {
                Text(
                    "Clear",
                    color = c.red.copy(alpha = 0.8f),
                    fontSize = 10.sp,
                    modifier = Modifier.clickable {
                        text = ""
                        vm.saveNote(verse, "")
                    }
                )
            }
        }
        OutlinedTextField(
            value = text,
            onValueChange = {
                text = it
                vm.saveNote(verse, it)
            },
            modifier = Modifier.fillMaxWidth().height(160.dp),
            placeholder = { Text("What do you see?", fontSize = 12.sp) },
            textStyle = TextStyle(fontFamily = ReadingFont, fontSize = 13.sp, color = c.ink),
            colors = TextFieldDefaults.colors(
                focusedContainerColor = c.surfaceAlt,
                unfocusedContainerColor = c.surfaceAlt,
                focusedIndicatorColor = c.accent,
                unfocusedIndicatorColor = c.border
            )
        )
        Text("Saved automatically on this device.", color = c.muted, fontSize = 9.sp)

        SectionLabel("Highlight")
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            val names = listOf("amber", "rose", "sage", "sky", "lilac")
            (0..4).forEach { i ->
                val active = vm.highlight(verse) == i
                val name = names.getOrElse(i) { "colour" }
                Box(
                    Modifier
                        .width(28.dp)
                        .height(28.dp)
                        .clip(CircleShape)
                        .background(c.highlights.getOrElse(i) { c.accent })
                        .then(if (active) Modifier.background(c.accent.copy(alpha = 0.28f), CircleShape) else Modifier)
                        .clickable { vm.setHighlight(verse, i) }
                        .semantics {
                            contentDescription = "Highlight $name"
                            this.selected = active
                        }
                )
            }
            Text(
                "Clear",
                color = c.muted,
                fontSize = 10.sp,
                modifier = Modifier
                    .clip(RoundedCornerShape(6.dp))
                    .clickable { vm.setHighlight(verse, null) }
                    .padding(horizontal = 6.dp, vertical = 7.dp)
            )
        }

        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("Bookmark", color = c.ink, fontSize = 12.sp)
            Spacer(Modifier.weight(1f))
            TextButton(onClick = { vm.toggleBookmark(verse) }) {
                Text(if (vm.isBookmarked(verse)) "Bookmarked" else "Add bookmark", color = c.accent, fontSize = 11.sp)
            }
        }
        Spacer(Modifier.height(30.dp))
    }
}
