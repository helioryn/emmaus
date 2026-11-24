package com.btaylor.emmaus.ui

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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.outlined.ArrowOutward
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.btaylor.emmaus.AppViewModel
import com.btaylor.emmaus.Screen
import com.btaylor.emmaus.data.SearchHit
import com.btaylor.emmaus.data.refLabel

@Composable
fun SearchScreen(vm: AppViewModel) {
    val c = Emmaus.colors
    Column(Modifier.fillMaxSize().background(c.background)) {
        Column(Modifier.statusBarsPadding().padding(horizontal = 18.dp, vertical = 10.dp)) {
            Text("Search", color = c.ink, fontFamily = ReadingFont, fontSize = 27.sp, fontWeight = FontWeight.SemiBold)
            Text("Every word of the offline library", color = c.muted, fontSize = 10.5.sp)
            Spacer(Modifier.height(10.dp))
            OutlinedTextField(
                value = vm.searchQuery,
                onValueChange = { vm.searchQuery = it },
                modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(11.dp)),
                placeholder = { Text("Word, phrase, or reference…", fontSize = 13.sp) },
                leadingIcon = { Icon(Icons.Filled.Search, contentDescription = null, tint = c.accent) },
                singleLine = true,
                textStyle = androidx.compose.ui.text.TextStyle(fontSize = 14.sp, color = c.ink),
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
                keyboardActions = KeyboardActions(onSearch = { vm.runSearch() }),
                colors = TextFieldDefaults.colors(
                    focusedContainerColor = c.surface,
                    unfocusedContainerColor = c.surface,
                    focusedIndicatorColor = c.accent,
                    unfocusedIndicatorColor = c.border
                )
            )
            Spacer(Modifier.height(8.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("Searching ${vm.activeTranslation.short}", color = c.muted, fontSize = 9.5.sp)
                Spacer(Modifier.weight(1f))
                if (vm.hasSearched) {
                    Text("${vm.searchResults.size} results", color = c.muted, fontSize = 9.5.sp)
                }
            }
        }

        when {
            vm.searching -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                CircularProgressIndicator(color = c.accent)
            }
            vm.hasSearched && vm.searchResults.isEmpty() -> Box(
                Modifier.fillMaxSize().padding(30.dp),
                contentAlignment = Alignment.Center
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("No verses found", color = c.ink, fontFamily = ReadingFont, fontSize = 20.sp)
                    Text("Try fewer words or a different translation.", color = c.muted, fontSize = 11.sp)
                }
            }
            vm.searchResults.isNotEmpty() -> LazyColumn(
                contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 14.dp, vertical = 6.dp),
                verticalArrangement = Arrangement.spacedBy(3.dp)
            ) {
                items(vm.searchResults, key = { "${it.book}-${it.chapter}-${it.verse}" }) { hit ->
                    SearchResultRow(vm, hit) {
                        vm.open(hit.book, hit.chapter, hit.verse)
                        vm.screen = Screen.READ
                    }
                }
            }
            else -> SearchTips(vm)
        }
    }
}

@Composable
private fun SearchTips(vm: AppViewModel) {
    val c = Emmaus.colors
    Column(Modifier.padding(24.dp), verticalArrangement = Arrangement.spacedBy(9.dp)) {
        Text("Try", color = c.muted, fontSize = 10.sp, fontWeight = FontWeight.SemiBold)
        listOf("love", "grace", "shepherd", "\"in the beginning\"", "G26", "H430").forEach { q ->
            Text(
                q,
                color = c.accent,
                fontSize = 13.sp,
                fontFamily = ReadingFont,
                modifier = Modifier
                    .clip(RoundedCornerShape(7.dp))
                    .background(c.accent.copy(alpha = 0.08f))
                    .clickable {
                        vm.searchQuery = q
                        vm.runSearch()
                    }
                    .padding(horizontal = 12.dp, vertical = 7.dp)
            )
        }
        Spacer(Modifier.height(8.dp))
        Text(
            "Quotes search an exact phrase. A Strong's number jumps to the lexicon. A reference like John 3:16 jumps straight to the verse. Hebrew points and Greek accents are optional.",
            color = c.muted,
            fontSize = 10.sp,
            lineHeight = 15.sp
        )
    }
}

@Composable
private fun SearchResultRow(vm: AppViewModel, hit: SearchHit, onClick: () -> Unit) {
    val c = Emmaus.colors
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(9.dp))
            .background(c.surface)
            .clickable(onClick = onClick)
            .padding(horizontal = 12.dp, vertical = 10.dp),
        verticalAlignment = Alignment.Top
    ) {
        Column(Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    refLabel(vm.bible.book(hit.book), hit.chapter, hit.verse),
                    color = c.accent,
                    fontSize = 10.5.sp,
                    fontWeight = FontWeight.SemiBold
                )
                Spacer(Modifier.width(7.dp))
                EmmausPill(vm.activeTranslation.short, filled = false)
            }
            Spacer(Modifier.height(3.dp))
            Text(
                highlightSnippet(hit.snippet, c.accent),
                color = c.ink.copy(alpha = 0.9f),
                fontSize = 12.5.sp,
                fontFamily = ReadingFont,
                lineHeight = 18.sp,
                maxLines = 4
            )
        }
        Icon(Icons.Outlined.ArrowOutward, contentDescription = null, tint = c.muted.copy(alpha = 0.5f))
    }
}

private fun highlightSnippet(snippet: String, accent: Color): AnnotatedString = buildAnnotatedString {
    var rest = snippet
    while (rest.isNotEmpty()) {
        val open = rest.indexOf('⟦')
        if (open < 0) {
            append(rest)
            break
        }
        append(rest.substring(0, open))
        val after = rest.substring(open + 1)
        val close = after.indexOf('⟧')
        if (close < 0) {
            append(after)
            break
        }
        withStyle(SpanStyle(color = accent, fontWeight = FontWeight.SemiBold, fontFamily = FontFamily.Serif)) {
            append(after.substring(0, close))
        }
        rest = after.substring(close + 1)
    }
}
