package com.btaylor.emmaus.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.outlined.ArrowForward
import androidx.compose.material.icons.outlined.MenuBook
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.btaylor.emmaus.AppViewModel
import com.btaylor.emmaus.Screen
import com.btaylor.emmaus.data.Book
import com.btaylor.emmaus.data.BookNote
import com.btaylor.emmaus.data.PlanLibrary
import com.btaylor.emmaus.data.ReadingLocation
import com.btaylor.emmaus.data.refLabel
import java.text.SimpleDateFormat
import java.time.LocalDate
import java.time.LocalTime
import java.time.format.DateTimeFormatter
import java.util.Date
import java.util.Locale

@Composable
fun HomeScreen(vm: AppViewModel) {
    val c = Emmaus.colors
    val last = vm.user.lastReading ?: ReadingLocation(vm.bookId, vm.chapter)
    val lastBook = vm.bible.book(last.book)
    val preview = remember(last.book, last.chapter, vm.translationCode) {
        vm.versePreview(last.book, last.chapter)
    }
    val daily = remember(vm.translationCode) { vm.dailyVerse() }
    val recentReads = vm.recentReadings(6).drop(1)
    val recentNotes = vm.recentNotes(3)
    val greeting = when (LocalTime.now().hour) {
        in 0..11 -> "Good morning"
        in 12..17 -> "Good afternoon"
        else -> "Good evening"
    }
    val date = LocalDate.now().format(DateTimeFormatter.ofPattern("EEEE, MMMM d", Locale.getDefault()))

    Column(Modifier.fillMaxSize().background(c.background)) {
        HomeTopBar(greeting, date, vm.streak)
        LazyColumn(
            modifier = Modifier.weight(1f).fillMaxWidth(),
            contentPadding = androidx.compose.foundation.layout.PaddingValues(
                start = 18.dp,
                end = 18.dp,
                top = 4.dp,
                bottom = 8.dp
            ),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            item {
                ContinueCard(
                    book = lastBook,
                    chapter = last.chapter,
                    preview = preview,
                    translation = vm.activeTranslation.short,
                    onOpen = { vm.open(last.book, last.chapter) }
                )
            }

            item {
                VerseOfDayCard(
                    reference = refLabel(vm.bible.book(daily.book), daily.chapter, daily.verse),
                    text = daily.text,
                    onOpen = { vm.open(daily.book, daily.chapter, daily.verse) }
                )
            }

            item {
                StatsRow(
                    chapters = vm.user.chaptersRead,
                    notes = vm.user.notes.size,
                    bookmarks = vm.user.bookmarks.size
                )
            }

            item { HomePlanCard(vm) }

            if (recentReads.isNotEmpty()) {
                item {
                    Column {
                        SectionLabel("Jump back in")
                        Spacer(Modifier.height(8.dp))
                        LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            items(recentReads, key = { "${it.book}-${it.chapter}" }) { location ->
                                val book = vm.bible.book(location.book)
                                Column(
                                    Modifier
                                        .clip(RoundedCornerShape(10.dp))
                                        .background(c.surface)
                                        .border(0.6.dp, c.border, RoundedCornerShape(10.dp))
                                        .clickable { vm.open(location.book, location.chapter) }
                                        .padding(horizontal = 13.dp, vertical = 9.dp)
                                ) {
                                    Text(
                                        book?.name ?: "Book",
                                        color = c.ink,
                                        fontSize = 11.5.sp,
                                        fontWeight = FontWeight.SemiBold
                                    )
                                    Text("Chapter ${location.chapter}", color = c.muted, fontSize = 9.5.sp)
                                }
                            }
                        }
                    }
                }
            }

            if (recentNotes.isNotEmpty()) {
                item { RecentNotesCard(vm, recentNotes) }
            }

            item {
                Row(horizontalArrangement = Arrangement.spacedBy(9.dp)) {
                    OutlinedButton(
                        onClick = { vm.bookPickerOpen = true },
                        modifier = Modifier.weight(1f),
                        shape = RoundedCornerShape(9.dp)
                    ) {
                        Icon(Icons.Outlined.MenuBook, contentDescription = null, tint = c.accent, modifier = Modifier.width(16.dp))
                        Spacer(Modifier.width(6.dp))
                        Text("Browse books", color = c.ink, fontSize = 11.5.sp)
                    }
                    OutlinedButton(
                        onClick = { vm.screen = Screen.SEARCH },
                        modifier = Modifier.weight(1f),
                        shape = RoundedCornerShape(9.dp)
                    ) {
                        Icon(Icons.Outlined.Search, contentDescription = null, tint = c.accent, modifier = Modifier.width(16.dp))
                        Spacer(Modifier.width(6.dp))
                        Text("Search", color = c.ink, fontSize = 11.5.sp)
                    }
                }
            }

            item { Spacer(Modifier.height(24.dp)) }
        }
    }
}

@Composable
private fun HomeTopBar(greeting: String, date: String, streak: Int) {
    val c = Emmaus.colors
    Column(Modifier.fillMaxWidth().statusBarsPadding().padding(start = 18.dp, end = 18.dp, top = 8.dp, bottom = 6.dp)) {
        Row(verticalAlignment = Alignment.Bottom) {
            Column(Modifier.weight(1f)) {
                Text(
                    greeting,
                    color = c.ink,
                    fontFamily = ReadingFont,
                    fontSize = 30.sp,
                    fontWeight = FontWeight.SemiBold
                )
                Text(date, color = c.muted, fontSize = 11.5.sp)
            }
            Row(
                Modifier
                    .clip(RoundedCornerShape(99.dp))
                    .background(c.surface)
                    .padding(horizontal = 11.dp, vertical = 6.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    Icons.Filled.LocalFireDepartment,
                    contentDescription = null,
                    tint = if (streak > 0) c.accent else c.muted.copy(alpha = 0.5f),
                    modifier = Modifier.width(15.dp)
                )
                Spacer(Modifier.width(4.dp))
                Text(
                    if (streak == 1) "1 day" else "$streak days",
                    color = c.ink,
                    fontSize = 10.5.sp,
                    fontWeight = FontWeight.Medium
                )
            }
        }
    }
}

@Composable
private fun ContinueCard(
    book: Book?,
    chapter: Int,
    preview: String,
    translation: String,
    onOpen: () -> Unit
) {
    val c = Emmaus.colors
    val shape = RoundedCornerShape(16.dp)
    Column(
        Modifier
            .fillMaxWidth()
            .clip(shape)
            .background(
                Brush.linearGradient(
                    listOf(c.surface, c.accent.copy(alpha = 0.10f))
                )
            )
            .border(0.7.dp, c.border, shape)
            .clickable(onClick = onOpen)
            .padding(18.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                "CONTINUE READING",
                color = c.accent,
                fontSize = 9.5.sp,
                fontWeight = FontWeight.SemiBold,
                letterSpacing = 1.4.sp
            )
            Spacer(Modifier.weight(1f))
            Icon(Icons.Outlined.ArrowForward, contentDescription = null, tint = c.accent, modifier = Modifier.width(17.dp))
        }
        Spacer(Modifier.height(12.dp))
        Row(verticalAlignment = Alignment.Bottom) {
            Text(
                book?.name ?: "Scripture",
                color = c.ink,
                fontFamily = ReadingFont,
                fontSize = 27.sp,
                fontWeight = FontWeight.SemiBold
            )
            Spacer(Modifier.width(9.dp))
            Text(
                "$chapter",
                color = c.accent.copy(alpha = 0.85f),
                fontFamily = ReadingFont,
                fontSize = 29.sp,
                fontWeight = FontWeight.Light
            )
        }
        Spacer(Modifier.height(7.dp))
        Text(
            preview,
            color = c.muted,
            fontFamily = ReadingFont,
            fontSize = 13.sp,
            lineHeight = 19.sp,
            maxLines = 3,
            overflow = TextOverflow.Ellipsis
        )
        Spacer(Modifier.height(10.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            EmmausPill(translation)
            Spacer(Modifier.width(8.dp))
            Text(
                "${book?.chapters ?: 0} chapters in this book",
                color = c.muted.copy(alpha = 0.75f),
                fontSize = 9.5.sp
            )
            Spacer(Modifier.weight(1f))
            Text(
                "Continue →",
                color = c.accent,
                fontSize = 10.5.sp,
                fontWeight = FontWeight.Medium
            )
        }
    }
}

@Composable
private fun VerseOfDayCard(reference: String, text: String, onOpen: () -> Unit) {
    val c = Emmaus.colors
    val shape = RoundedCornerShape(12.dp)
    Column(
        Modifier
            .fillMaxWidth()
            .clip(shape)
            .background(c.surface)
            .border(0.7.dp, c.border, shape)
            .clickable(onClick = onOpen)
            .padding(17.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            SectionLabel("Verse for today")
            Spacer(Modifier.weight(1f))
            Text(reference, color = c.accent, fontSize = 10.sp, fontWeight = FontWeight.Medium)
        }
        Spacer(Modifier.height(9.dp))
        Text(
            text,
            color = c.ink,
            fontFamily = ReadingFont,
            fontSize = 16.sp,
            lineHeight = 23.sp
        )
        Spacer(Modifier.height(8.dp))
        Row {
            Spacer(Modifier.weight(1f))
            Text("Open passage →", color = c.accent, fontSize = 10.5.sp, fontWeight = FontWeight.Medium)
        }
    }
}

@Composable
private fun StatsRow(chapters: Int, notes: Int, bookmarks: Int) {
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        StatCard(chapters, "Chapters", Modifier.weight(1f))
        StatCard(notes, "Notes", Modifier.weight(1f))
        StatCard(bookmarks, "Bookmarks", Modifier.weight(1f))
    }
}

@Composable
private fun StatCard(value: Int, label: String, modifier: Modifier = Modifier) {
    val c = Emmaus.colors
    Column(
        modifier
            .clip(RoundedCornerShape(10.dp))
            .background(c.surface)
            .border(0.6.dp, c.border, RoundedCornerShape(10.dp))
            .padding(horizontal = 12.dp, vertical = 10.dp)
    ) {
        Text(
            "$value",
            color = c.ink,
            fontFamily = ReadingFont,
            fontSize = 22.sp,
            fontWeight = FontWeight.SemiBold
        )
        Text(label, color = c.muted, fontSize = 9.sp)
    }
}

@Composable
private fun RecentNotesCard(vm: AppViewModel, notes: List<BookNote>) {
    val c = Emmaus.colors
    val formatter = SimpleDateFormat("MMM d", Locale.getDefault())
    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(c.surface)
            .border(0.6.dp, c.border, RoundedCornerShape(12.dp))
    ) {
        Row(
            Modifier.fillMaxWidth().padding(horizontal = 13.dp, vertical = 11.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            SectionLabel("Recent notes")
            Spacer(Modifier.weight(1f))
            Text(
                "All notes",
                color = c.accent,
                fontSize = 10.sp,
                fontWeight = FontWeight.Medium,
                modifier = Modifier.clickable { vm.screen = Screen.NOTEBOOK }
            )
        }
        notes.forEachIndexed { index, note ->
            HorizontalDivider(color = c.border.copy(alpha = 0.5f), modifier = Modifier.padding(horizontal = 13.dp))
            Row(
                Modifier
                    .fillMaxWidth()
                    .clickable { vm.openNote(note.book, note.chapter, note.verse) }
                    .padding(horizontal = 13.dp, vertical = 9.dp),
                verticalAlignment = Alignment.Top
            ) {
                Text(
                    refLabel(vm.bible.book(note.book), note.chapter, note.verse),
                    color = c.accent,
                    fontSize = 10.sp,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.width(100.dp)
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
                    Spacer(Modifier.width(6.dp))
                    Text(
                        formatter.format(Date(note.updated)),
                        color = c.muted.copy(alpha = 0.55f),
                        fontSize = 8.5.sp
                    )
                }
            }
        }
    }
}


@Composable
private fun HomePlanCard(vm: AppViewModel) {
    val c = Emmaus.colors
    val definition = PlanLibrary.definition(vm.activePlanId) ?: PlanLibrary.definitions.first()
    val completed = vm.planCompleted(definition)
    val next = vm.currentPlanDay(definition)
    val fraction = if (definition.days == 0) 0f else completed.toFloat() / definition.days
    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(c.surface)
            .border(0.6.dp, c.border, RoundedCornerShape(12.dp))
            .clickable {
                vm.selectPlan(definition)
                vm.openPlanId = definition.id
                vm.screen = Screen.PLANS
            }
            .padding(14.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            SectionLabel("Reading plan")
            Spacer(Modifier.weight(1f))
            Text("$completed / ${definition.days} days", color = c.muted, fontSize = 9.5.sp)
        }
        Spacer(Modifier.height(6.dp))
        Text(definition.name, color = c.ink, fontSize = 13.5.sp, fontWeight = FontWeight.SemiBold)
        Spacer(Modifier.height(8.dp))
        LinearProgressIndicator(
            progress = { fraction },
            modifier = Modifier.fillMaxWidth().height(3.dp).clip(RoundedCornerShape(2.dp)),
            color = c.accent,
            trackColor = c.border.copy(alpha = 0.6f)
        )
        Spacer(Modifier.height(9.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                if (next != null) "Day ${next.day} · ${next.label}" else "Plan complete",
                color = c.muted,
                fontSize = 10.5.sp,
                modifier = Modifier.weight(1f),
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            Icon(Icons.Outlined.ArrowForward, contentDescription = null, tint = c.accent, modifier = Modifier.width(16.dp))
        }
    }
}
