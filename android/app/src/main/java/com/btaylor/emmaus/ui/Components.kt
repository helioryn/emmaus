package com.btaylor.emmaus.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Bookmark
import androidx.compose.material.icons.outlined.BookmarkBorder
import androidx.compose.material.icons.outlined.VolumeUp
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.btaylor.emmaus.AppViewModel
import com.btaylor.emmaus.data.StrongsEntry
import com.btaylor.emmaus.data.refLabel

fun Modifier.dottedUnderline(color: Color): Modifier = drawBehind {
    val y = size.height - 2.dp.toPx()
    var x = 0f
    val step = 3.dp.toPx()
    val r = 0.7.dp.toPx()
    while (x < size.width) {
        drawCircle(color = color, radius = r, center = Offset(x, y))
        x += step
    }
}

@Composable
fun EmmausPill(text: String, modifier: Modifier = Modifier, filled: Boolean = false) {
    val c = Emmaus.colors
    Text(
        text = text,
        color = if (filled) c.background else c.accent,
        fontSize = 10.sp,
        fontWeight = FontWeight.SemiBold,
        modifier = modifier
            .clip(RoundedCornerShape(99.dp))
            .background(if (filled) c.accent else c.accent.copy(alpha = 0.10f))
            .padding(horizontal = 8.dp, vertical = 4.dp)
    )
}

@Composable
fun SectionLabel(text: String) {
    Text(
        text.uppercase(),
        color = Emmaus.colors.muted,
        fontSize = 9.5.sp,
        fontWeight = FontWeight.SemiBold,
        letterSpacing = 1.1.sp
    )
}

@Composable
fun AudioButton(onClick: () -> Unit) {
    val c = Emmaus.colors
    IconButton(onClick = onClick) {
        Icon(Icons.Outlined.VolumeUp, contentDescription = "Read aloud", tint = c.accent)
    }
}

@Composable
fun BookmarkButton(vm: AppViewModel, verse: Int) {
    val marked = vm.isBookmarked(verse)
    IconButton(onClick = { vm.toggleBookmark(verse) }) {
        Icon(
            if (marked) Icons.Filled.Bookmark else Icons.Outlined.BookmarkBorder,
            contentDescription = "Bookmark",
            tint = if (marked) Emmaus.colors.accent else Emmaus.colors.muted
        )
    }
}

@Composable
fun StrongsDetail(
    vm: AppViewModel,
    entry: StrongsEntry,
    onOpenVerse: (Int, Int, Int) -> Unit
) {
    val c = Emmaus.colors
    var showAll by remember(entry.id) { mutableStateOf(false) }
    val occurrences = remember(entry.id, showAll) {
        vm.bible.occurrences(entry.id, if (showAll) 1000 else 50)
    }
    val count = remember(entry.id) { vm.bible.occurrenceCount(entry.id) }
    Column(
        Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(entry.id, color = c.accent, fontSize = 11.sp, fontWeight = FontWeight.Bold)
            Spacer(Modifier.width(8.dp))
            Text(entry.languageName.uppercase(), color = c.muted, fontSize = 9.5.sp)
            Spacer(Modifier.weight(1f))
            AudioButton { vm.speakWord(entry.lemma, entry.languageCode) }
            AudioButton { vm.speakWord(entry.lemma, entry.languageCode, slow = true) }
        }
        Text(
            entry.lemma,
            color = c.ink,
            fontSize = if (entry.isHebrew) 38.sp else 30.sp,
            fontFamily = FontFamily.Serif
        )
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(entry.translit, color = c.muted, fontSize = 15.sp, fontFamily = FontFamily.Serif, fontStyle = FontStyle.Italic)
            if (entry.pronounce.isNotBlank()) {
                Text(" · ${entry.pronounce}", color = c.muted, fontSize = 11.sp)
            }
        }
        if (entry.gloss.isNotBlank()) {
            Text(entry.gloss, color = c.ink, fontSize = 16.sp, fontFamily = FontFamily.Serif, fontWeight = FontWeight.Medium)
        }
        if (entry.definition.isNotBlank()) {
            Text(entry.definition, color = c.ink.copy(alpha = 0.92f), fontSize = 13.5.sp, fontFamily = FontFamily.Serif, lineHeight = 20.sp)
        }
        if (entry.extended.isNotBlank() && entry.extended != entry.definition) {
            SectionLabel("Extended lexicon")
            Text(entry.extended, color = c.muted, fontSize = 12.sp, fontFamily = FontFamily.Serif, lineHeight = 18.sp)
        }
        if (entry.kjvUsage.isNotBlank()) {
            SectionLabel("KJV usage")
            Text(entry.kjvUsage, color = c.muted, fontSize = 12.sp)
        }
        if (entry.morph.isNotBlank()) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                SectionLabel("Morphology")
                Spacer(Modifier.width(8.dp))
                EmmausPill(entry.morph)
            }
        }
        val family = remember(entry.id) { vm.bible.strongsFamily(entry.id).filter { it.id != entry.id } }
        if (family.isNotEmpty()) {
            SectionLabel("Related senses")
            family.forEach { f ->
                Row(
                    Modifier
                        .fillMaxWidth()
                        .clickable { vm.openStrongs(f.id) }
                        .padding(vertical = 4.dp)
                ) {
                    Text(f.id, color = c.accent, fontSize = 10.sp, fontWeight = FontWeight.Bold)
                    Spacer(Modifier.width(6.dp))
                    Text(
                        f.gloss.ifBlank { f.definition.take(120) },
                        color = c.muted,
                        fontSize = 11.sp
                    )
                }
            }
        }
        Row(verticalAlignment = Alignment.CenterVertically) {
            SectionLabel("Concordance")
            Spacer(Modifier.weight(1f))
            Text("$count occurrences", color = c.muted, fontSize = 10.sp)
        }
        occurrences.forEach { o ->
            Row(
                Modifier
                    .fillMaxWidth()
                    .clickable { onOpenVerse(o.book, o.chapter, o.verse) }
                    .padding(vertical = 3.dp)
            ) {
                Text(refLabel(vm.bible.book(o.book), o.chapter, o.verse), color = c.accent, fontSize = 10.5.sp, modifier = Modifier.width(110.dp))
                Text(o.form, color = c.ink.copy(alpha = 0.85f), fontSize = 12.sp, fontFamily = FontFamily.Serif, fontStyle = FontStyle.Italic)
            }
        }
        if (!showAll && count > 50) {
            Text(
                "Show all $count occurrences",
                color = c.accent,
                fontSize = 11.sp,
                modifier = Modifier
                    .clickable { showAll = true }
                    .padding(vertical = 6.dp)
            )
        }
        Spacer(Modifier.height(10.dp))
    }
}
