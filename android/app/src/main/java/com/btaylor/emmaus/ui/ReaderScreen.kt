package com.btaylor.emmaus.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
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
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.outlined.ChevronLeft
import androidx.compose.material.icons.outlined.ChevronRight
import androidx.compose.material.icons.outlined.Headphones
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material.icons.outlined.StopCircle
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.lazy.LazyListState
import com.btaylor.emmaus.AppViewModel
import com.btaylor.emmaus.Screen
import com.btaylor.emmaus.data.Token
import com.btaylor.emmaus.data.Verse
import com.btaylor.emmaus.data.WordRun

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun ReaderScreen(vm: AppViewModel, listState: LazyListState) {
    val c = Emmaus.colors
    Column(Modifier.fillMaxSize().background(c.background)) {
        ReaderTopBar(vm)
        when {
            vm.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                CircularProgressIndicator(color = c.accent)
            }
            vm.chapterData == null -> Box(Modifier.fillMaxSize().padding(30.dp), contentAlignment = Alignment.Center) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("Chapter unavailable", color = c.ink, fontFamily = ReadingFont, fontSize = 22.sp)
                    Spacer(Modifier.height(8.dp))
                    Text(vm.error ?: "This chapter is not in the selected translation.", color = c.muted, fontSize = 12.sp, textAlign = TextAlign.Center)
                    Spacer(Modifier.height(14.dp))
                    OutlinedButton(onClick = { vm.changeTranslation("KJV") }) { Text("Open KJV") }
                }
            }
            else -> {
                val data = vm.chapterData!!
                LazyColumn(
                    state = listState,
                    contentPadding = PaddingValues(horizontal = 16.dp, vertical = 14.dp),
                    verticalArrangement = Arrangement.spacedBy(2.dp)
                ) {
                    item(key = "heading") { ChapterHeading(vm) }
                    items(data.verses, key = { it.number }) { verse ->
                        VerseRow(
                            vm = vm,
                            verse = verse,
                            selected = vm.selectedVerse == verse.number,
                            highlight = vm.highlight(verse.number),
                            speaking = vm.tts.currentVerse == verse.number,
                            onSelect = { vm.selectVerse(verse.number) },
                            onWord = { run -> run.strongs.firstOrNull()?.let { vm.selectWord(verse.number, it) } }
                        )
                    }
                    item(key = "footer") { ChapterFooter(vm) }
                }
            }
        }
    }
}

@Composable
private fun ReaderTopBar(vm: AppViewModel) {
    val c = Emmaus.colors
    var translationMenu by remember { mutableStateOf(false) }
    Column(Modifier.fillMaxWidth().statusBarsPadding()) {
        Row(
            Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(
                Modifier.weight(1f).clickable { vm.bookPickerOpen = true }
            ) {
                Text(
                    vm.activeBook?.name ?: "Emmaus",
                    color = c.ink,
                    fontSize = 19.sp,
                    fontFamily = ReadingFont,
                    fontWeight = FontWeight.SemiBold
                )
                Text("Chapter ${vm.chapter} · ${vm.activeTranslation.short}", color = c.muted, fontSize = 10.sp)
            }
            Box {
                Text(
                    vm.activeTranslation.short,
                    color = c.accent,
                    fontSize = 10.5.sp,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier
                        .clip(RoundedCornerShape(99.dp))
                        .background(c.accent.copy(alpha = 0.10f))
                        .clickable { translationMenu = true }
                        .padding(horizontal = 9.dp, vertical = 5.dp)
                )
                DropdownMenu(expanded = translationMenu, onDismissRequest = { translationMenu = false }) {
                    vm.bible.translations.forEach { tr ->
                        DropdownMenuItem(
                            text = { Text("${tr.short} — ${tr.name}", fontSize = 12.sp) },
                            onClick = {
                                translationMenu = false
                                vm.changeTranslation(tr.code)
                            }
                        )
                    }
                }
            }
            IconButton(onClick = { vm.screen = Screen.SEARCH }) {
                Icon(Icons.Filled.Search, contentDescription = "Search", tint = c.muted)
            }
            IconButton(onClick = { vm.toggleSpeech() }) {
                Icon(
                    if (vm.tts.speaking) Icons.Outlined.StopCircle else Icons.Outlined.Headphones,
                    contentDescription = "Read aloud",
                    tint = if (vm.tts.speaking) c.accent else c.muted
                )
            }
            IconButton(onClick = { vm.settingsOpen = true }) {
                Icon(Icons.Outlined.Settings, contentDescription = "Settings", tint = c.muted)
            }
        }
        Row(
            Modifier.fillMaxWidth().padding(horizontal = 14.dp, vertical = 2.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                "Tap a word for Strong's  ·  tap a verse number for study",
                color = c.muted.copy(alpha = 0.85f),
                fontSize = 9.5.sp
            )
            Spacer(Modifier.weight(1f))
            IconButton(onClick = { vm.previousChapter() }, modifier = Modifier.width(34.dp)) {
                Icon(Icons.Outlined.ChevronLeft, contentDescription = "Previous", tint = c.muted)
            }
            IconButton(onClick = { vm.nextChapter() }, modifier = Modifier.width(34.dp)) {
                Icon(Icons.Outlined.ChevronRight, contentDescription = "Next", tint = c.muted)
            }
        }
    }
}

@Composable
private fun ChapterHeading(vm: AppViewModel) {
    val c = Emmaus.colors
    Column(Modifier.padding(bottom = 12.dp)) {
        Text(
            if (vm.activeBook?.testament == "OT") "OLD TESTAMENT" else "NEW TESTAMENT",
            color = c.accent,
            fontSize = 9.5.sp,
            fontWeight = FontWeight.SemiBold,
            letterSpacing = 1.3.sp
        )
        Row(verticalAlignment = Alignment.Bottom) {
            Text(
                vm.activeBook?.name ?: "",
                color = c.ink,
                fontFamily = ReadingFont,
                fontSize = 32.sp,
                fontWeight = FontWeight.SemiBold
            )
            Spacer(Modifier.width(10.dp))
            Text(
                "${vm.chapter}",
                color = c.accent.copy(alpha = 0.85f),
                fontFamily = ReadingFont,
                fontSize = 38.sp,
                fontWeight = FontWeight.Light
            )
        }
        Spacer(Modifier.height(4.dp))
        Box(
            Modifier
                .fillMaxWidth()
                .height(1.dp)
                .background(
                    androidx.compose.ui.graphics.Brush.horizontalGradient(
                        listOf(c.accent.copy(alpha = 0.55f), c.accent.copy(alpha = 0.02f))
                    )
                )
        )
    }
}

@OptIn(ExperimentalLayoutApi::class, ExperimentalFoundationApi::class)
@Composable
private fun VerseRow(
    vm: AppViewModel,
    verse: Verse,
    selected: Boolean,
    highlight: Int?,
    speaking: Boolean,
    onSelect: () -> Unit,
    onWord: (WordRun) -> Unit
) {
    val c = Emmaus.colors
    val background = when {
        speaking -> c.accent.copy(alpha = 0.16f)
        selected -> c.selection
        highlight != null -> c.highlights.getOrNull(highlight) ?: Color.Transparent
        else -> Color.Transparent
    }
    val runs = remember(verse, vm.showStrongs, vm.redLetter) {
        buildRuns(verse)
    }
    val direction = if (vm.activeTranslation.isRtl) LayoutDirection.Rtl else LayoutDirection.Ltr
    CompositionLocalProvider(LocalLayoutDirection provides direction) {
        FlowRow(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(8.dp))
                .background(background)
                .clickable(onClick = onSelect)
                .padding(horizontal = 11.dp, vertical = 7.dp),
            horizontalArrangement = Arrangement.spacedBy(4.dp),
            verticalArrangement = Arrangement.spacedBy(0.dp)
        ) {
            runs.forEach { run ->
                WordChip(vm = vm, run = run, onSelect = onSelect, onWord = onWord)
            }
        }
    }
}

@Composable
private fun WordChip(vm: AppViewModel, run: WordRun, onSelect: () -> Unit, onWord: (WordRun) -> Unit) {
    val c = Emmaus.colors
    val isTagged = vm.showStrongs && run.strongs.isNotEmpty() && !run.verseNumber
    val color = when {
        run.verseNumber -> c.accent.copy(alpha = 0.8f)
        run.red && vm.redLetter -> c.red
        else -> c.ink
    }
    val base = Modifier
        .padding(vertical = if (run.verseNumber) 0.dp else 1.dp)
        .then(if (isTagged) Modifier.dottedUnderline(c.accent.copy(alpha = 0.35f)) else Modifier)
    Text(
        text = run.text,
        modifier = base.clickable {
            if (run.strongs.isNotEmpty() && !run.verseNumber) onWord(run) else onSelect()
        },
        style = TextStyle(
            color = color,
            fontFamily = ReadingFont,
            fontSize = if (run.verseNumber) 11.sp else vm.fontSize.sp,
            lineHeight = (if (run.verseNumber) 16 else vm.fontSize + 8).sp,
            fontWeight = if (run.verseNumber || run.heading) FontWeight.SemiBold else FontWeight.Normal,
            fontStyle = if (run.italic) FontStyle.Italic else FontStyle.Normal
        )
    )
}

private fun buildRuns(verse: Verse): List<WordRun> {
    val out = mutableListOf<WordRun>()
    out += WordRun("${verse.number}", verseNumber = true)
    val tokens = verse.tokens ?: listOf(Token(verse.text))
    for (token in tokens) {
        val words = token.text.split(" ")
        for (raw in words) {
            if (raw.isEmpty()) continue
            val punctuationOnly = raw.none { it.isLetterOrDigit() }
            if (punctuationOnly && out.isNotEmpty() && !out.last().verseNumber) {
                out[out.lastIndex] = out.last().copy(text = out.last().text + raw)
                continue
            }
            out += WordRun(
                text = raw,
                strongs = token.strongs,
                red = token.red,
                italic = token.italic || token.heading,
                heading = token.heading
            )
        }
    }
    return out
}

@Composable
private fun ChapterFooter(vm: AppViewModel) {
    val c = Emmaus.colors
    Row(
        Modifier.fillMaxWidth().padding(top = 20.dp, bottom = 26.dp),
        horizontalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        OutlinedButton(onClick = { vm.previousChapter() }, modifier = Modifier.weight(1f)) {
            Text("← ${vm.chapter - 1}", color = c.ink)
        }
        OutlinedButton(onClick = { vm.nextChapter() }, modifier = Modifier.weight(1f)) {
            Text("${vm.chapter + 1} →", color = c.ink)
        }
    }
}
