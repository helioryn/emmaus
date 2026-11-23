package com.btaylor.emmaus.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.outlined.ArrowBack
import androidx.compose.material.icons.outlined.MenuBook
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.btaylor.emmaus.AppViewModel
import com.btaylor.emmaus.data.Book
import com.btaylor.emmaus.data.BookIntros
import com.btaylor.emmaus.data.BookNote
import com.btaylor.emmaus.data.refLabel
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.math.max

@Composable
fun BookOverviewScreen(vm: AppViewModel) {
    val c = Emmaus.colors
    val book = vm.activeBook

    if (book == null) {
        Column(
            Modifier.fillMaxSize().background(c.background).padding(30.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            Text("Book unavailable", color = c.ink, fontFamily = ReadingFont, fontSize = 22.sp)
            Spacer(Modifier.height(10.dp))
            TextButton(onClick = { vm.bookPickerOpen = true }) { Text("Choose a book", color = c.accent) }
        }
        return
    }

    val read = vm.readChapters(book.id)
    val last = vm.lastChapter(book.id)
    val notes = vm.notesInBook(book.id)
    val progress = read.size.toFloat() / max(book.chapters, 1)

    Column(Modifier.fillMaxSize().background(c.background)) {
        OverviewTopBar(vm)
        LazyVerticalGrid(
            columns = GridCells.Adaptive(48.dp),
            modifier = Modifier.weight(1f).fillMaxWidth(),
            contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = 2.dp, bottom = 8.dp),
            horizontalArrangement = Arrangement.spacedBy(7.dp),
            verticalArrangement = Arrangement.spacedBy(7.dp)
        ) {
            item(span = { GridItemSpan(maxLineSpan) }) {
                OverviewHeader(book, read.size, progress)
            }
            item(span = { GridItemSpan(maxLineSpan) }) {
                OverviewActions(vm, book, last)
            }
            item(span = { GridItemSpan(maxLineSpan) }) {
                ChapterSectionHeader()
            }
            items((1..book.chapters).toList()) { chapter ->
                ChapterTile(
                    number = chapter,
                    isRead = read.contains(chapter),
                    isLast = last == chapter,
                    hasMarks = vm.chapterHasMarks(book.id, chapter)
                ) {
                    vm.open(book.id, chapter)
                }
            }
            if (notes.isNotEmpty()) {
                item(span = { GridItemSpan(maxLineSpan) }) {
                    RecentNotes(vm, book, notes)
                }
            }
            item(span = { GridItemSpan(maxLineSpan) }) {
                Spacer(Modifier.height(34.dp))
            }
        }
    }
}

@Composable
private fun OverviewTopBar(vm: AppViewModel) {
    val c = Emmaus.colors
    Row(
        Modifier.fillMaxWidth().statusBarsPadding().padding(top = 4.dp, bottom = 2.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        IconButton(onClick = { vm.closeOverview() }) {
            Icon(Icons.Outlined.ArrowBack, contentDescription = "Back to reading", tint = c.ink)
        }
        Text(
            "Book overview",
            color = c.muted,
            fontSize = 10.sp,
            fontWeight = FontWeight.SemiBold,
            letterSpacing = 1.1.sp
        )
        Spacer(Modifier.weight(1f))
        TextButton(onClick = { vm.bookPickerOpen = true }) {
            Icon(Icons.Outlined.MenuBook, contentDescription = null, tint = c.accent, modifier = Modifier.width(16.dp))
            Spacer(Modifier.width(5.dp))
            Text("All books", color = c.accent, fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
        }
    }
}

@Composable
private fun OverviewHeader(book: Book, readCount: Int, progress: Float) {
    val c = Emmaus.colors
    Column(Modifier.fillMaxWidth().padding(top = 2.dp, bottom = 4.dp)) {
        Text(
            listOf(book.genre.uppercase(), if (book.testament == "OT") "OLD TESTAMENT" else "NEW TESTAMENT")
                .filter { it.isNotBlank() }
                .joinToString("  ·  "),
            color = c.accent,
            fontSize = 9.5.sp,
            fontWeight = FontWeight.SemiBold,
            letterSpacing = 1.3.sp
        )
        Spacer(Modifier.height(5.dp))
        Text(
            book.name,
            color = c.ink,
            fontFamily = ReadingFont,
            fontSize = 36.sp,
            fontWeight = FontWeight.SemiBold,
            lineHeight = 40.sp
        )
        Spacer(Modifier.height(7.dp))
        Text(
            BookIntros.text(book.id),
            color = c.muted,
            fontFamily = ReadingFont,
            fontSize = 15.sp,
            lineHeight = 22.sp
        )
        Spacer(Modifier.height(13.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                "$readCount of ${book.chapters} chapters read",
                color = c.muted,
                fontSize = 9.5.sp,
                fontWeight = FontWeight.Medium
            )
            Spacer(Modifier.width(9.dp))
            Box(
                Modifier
                    .weight(1f)
                    .height(4.dp)
                    .clip(CircleShape)
                    .background(c.border.copy(alpha = 0.6f))
            ) {
                Box(
                    Modifier
                        .fillMaxWidth(progress.coerceIn(0f, 1f))
                        .height(4.dp)
                        .clip(CircleShape)
                        .background(c.accent.copy(alpha = 0.8f))
                )
            }
            Spacer(Modifier.width(9.dp))
            Text("${(progress * 100).toInt()}%", color = c.muted, fontSize = 9.sp)
        }
        Spacer(Modifier.height(6.dp))
        Box(
            Modifier
                .fillMaxWidth()
                .height(1.dp)
                .background(c.accent.copy(alpha = 0.22f))
        )
    }
}

@Composable
private fun OverviewActions(vm: AppViewModel, book: Book, last: Int?) {
    val c = Emmaus.colors
    Row(
        Modifier.fillMaxWidth().padding(vertical = 3.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Button(
            onClick = { vm.continueReading(book.id) },
            modifier = Modifier.weight(1f),
            colors = ButtonDefaults.buttonColors(containerColor = c.accent, contentColor = c.background),
            shape = RoundedCornerShape(9.dp)
        ) {
            Icon(Icons.Filled.PlayArrow, contentDescription = null, modifier = Modifier.width(16.dp))
            Spacer(Modifier.width(4.dp))
            Text(
                if (last != null) "Continue chapter $last" else "Start reading",
                fontSize = 12.5.sp,
                fontWeight = FontWeight.SemiBold
            )
        }
        if (last != null && last != 1) {
            OutlinedButton(
                onClick = { vm.open(book.id, 1) },
                shape = RoundedCornerShape(9.dp)
            ) {
                Text("Chapter 1", color = c.ink, fontSize = 12.sp)
            }
        }
    }
}

@Composable
private fun ChapterSectionHeader() {
    val c = Emmaus.colors
    Row(
        Modifier.fillMaxWidth().padding(top = 14.dp, bottom = 2.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        SectionLabel("Chapters")
        Spacer(Modifier.weight(1f))
        LegendSwatch(c.accent.copy(alpha = 0.16f), "Read")
        Spacer(Modifier.width(9.dp))
        Box(
            Modifier
                .width(8.dp)
                .height(8.dp)
                .clip(RoundedCornerShape(2.dp))
                .border(1.dp, c.accent, RoundedCornerShape(2.dp))
        )
        Text(" Last", color = c.muted, fontSize = 8.5.sp)
        Spacer(Modifier.width(9.dp))
        Box(Modifier.width(3.5.dp).height(3.5.dp).clip(CircleShape).background(c.accent))
        Text(" Notes", color = c.muted, fontSize = 8.5.sp)
    }
}

@Composable
private fun LegendSwatch(color: Color, label: String) {
    val c = Emmaus.colors
    Box(Modifier.width(8.dp).height(8.dp).clip(RoundedCornerShape(2.dp)).background(color))
    Text(" $label", color = c.muted, fontSize = 8.5.sp)
}

@Composable
private fun ChapterTile(
    number: Int,
    isRead: Boolean,
    isLast: Boolean,
    hasMarks: Boolean,
    onClick: () -> Unit
) {
    val c = Emmaus.colors
    val background = when {
        isLast -> c.accent.copy(alpha = 0.16f)
        isRead -> c.accent.copy(alpha = 0.10f)
        else -> c.surface
    }
    Box(
        Modifier
            .height(44.dp)
            .clip(RoundedCornerShape(8.dp))
            .background(background)
            .border(
                width = if (isLast) 1.5.dp else 0.6.dp,
                color = if (isLast) c.accent else c.border.copy(alpha = 0.75f),
                shape = RoundedCornerShape(8.dp)
            )
            .clickable(onClick = onClick)
            .semantics {
                contentDescription = "Chapter $number" +
                    (if (isRead) ", read" else "") +
                    (if (hasMarks) ", has notes" else "")
            },
        contentAlignment = Alignment.Center
    ) {
        Text(
            "$number",
            color = if (isRead || isLast) c.accent else c.ink.copy(alpha = 0.88f),
            fontSize = 12.sp,
            fontWeight = if (isRead || isLast) FontWeight.SemiBold else FontWeight.Normal
        )
        if (hasMarks) {
            Box(
                Modifier
                    .align(Alignment.TopEnd)
                    .padding(top = 5.dp, end = 5.dp)
                    .width(3.5.dp)
                    .height(3.5.dp)
                    .clip(CircleShape)
                    .background(c.accent)
            )
        }
    }
}

@Composable
private fun RecentNotes(vm: AppViewModel, book: Book, notes: List<BookNote>) {
    val c = Emmaus.colors
    val formatter = SimpleDateFormat("MMM d", Locale.getDefault())
    val shown = notes.take(4)
    Column(Modifier.fillMaxWidth().padding(top = 20.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            SectionLabel("Recent in ${book.name}")
            Spacer(Modifier.weight(1f))
            Text(
                if (notes.size == 1) "1 note" else "${notes.size} notes",
                color = c.muted,
                fontSize = 9.sp
            )
        }
        Spacer(Modifier.height(7.dp))
        Column(
            Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(10.dp))
                .background(c.surface)
        ) {
            shown.forEachIndexed { index, note ->
                Row(
                    Modifier
                        .fillMaxWidth()
                        .clickable { vm.openNote(note.book, note.chapter, note.verse) }
                        .padding(horizontal = 11.dp, vertical = 9.dp),
                    verticalAlignment = Alignment.Top
                ) {
                    Text(
                        refLabel(book, note.chapter, note.verse),
                        color = c.accent,
                        fontSize = 10.sp,
                        fontWeight = FontWeight.SemiBold,
                        modifier = Modifier.width(96.dp)
                    )
                    Text(
                        note.body,
                        color = c.muted,
                        fontFamily = ReadingFont,
                        fontSize = 11.5.sp,
                        lineHeight = 16.sp,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.weight(1f)
                    )
                    if (note.updated > 0) {
                        Spacer(Modifier.width(8.dp))
                        Text(
                            formatter.format(Date(note.updated)),
                            color = c.muted.copy(alpha = 0.55f),
                            fontSize = 8.5.sp
                        )
                    }
                }
                if (index < shown.lastIndex) {
                    HorizontalDivider(color = c.border.copy(alpha = 0.5f), modifier = Modifier.padding(start = 11.dp))
                }
            }
        }
    }
}
