package com.btaylor.emmaus.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.MenuBook
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.btaylor.emmaus.AppViewModel
import com.btaylor.emmaus.Screen

@Composable
fun WordStudyScreen(vm: AppViewModel) {
    val c = Emmaus.colors
    val focus = LocalFocusManager.current
    Column(Modifier.fillMaxSize().background(c.background)) {
        Column(Modifier.statusBarsPadding().padding(horizontal = 18.dp, vertical = 10.dp)) {
            Text("Word Study", color = c.ink, fontFamily = ReadingFont, fontSize = 27.sp, fontWeight = FontWeight.SemiBold)
            Text("Strong's, morphology, and every occurrence", color = c.muted, fontSize = 10.5.sp)
            Spacer(Modifier.height(10.dp))
            OutlinedTextField(
                value = vm.wordQuery,
                onValueChange = { vm.wordQuery = it },
                modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(11.dp)),
                placeholder = { Text("G26, H430, love, covenant…", fontSize = 13.sp) },
                singleLine = true,
                textStyle = TextStyle(fontSize = 14.sp, color = c.ink),
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
                keyboardActions = KeyboardActions(onSearch = {
                    focus.clearFocus()
                    vm.runWordStudy()
                }),
                colors = TextFieldDefaults.colors(
                    focusedContainerColor = c.surface,
                    unfocusedContainerColor = c.surface,
                    focusedIndicatorColor = c.accent,
                    unfocusedIndicatorColor = c.border
                )
            )
            Spacer(Modifier.height(8.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                listOf("G26", "H430", "G2316", "H3068", "G4102").forEach { q ->
                    Text(
                        q,
                        color = c.accent,
                        fontSize = 10.sp,
                        fontWeight = FontWeight.Medium,
                        modifier = Modifier
                            .clip(RoundedCornerShape(99.dp))
                            .background(c.accent.copy(alpha = 0.09f))
                            .clickable {
                                vm.wordQuery = q
                                vm.runWordStudy()
                            }
                            .padding(horizontal = 8.dp, vertical = 4.dp)
                    )
                }
            }
        }

        val selected = vm.wordSelected
        if (selected != null) {
            if (vm.wordResults.size > 1) {
                LazyRow(
                    contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 16.dp, vertical = 4.dp),
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    items(vm.wordResults) { entry ->
                        val active = entry.id == selected.id
                        Text(
                            entry.id,
                            color = if (active) c.background else c.accent,
                            fontSize = 10.sp,
                            fontWeight = FontWeight.SemiBold,
                            modifier = Modifier
                                .clip(RoundedCornerShape(99.dp))
                                .background(if (active) c.accent else c.accent.copy(alpha = 0.09f))
                                .clickable { vm.wordSelected = entry }
                                .padding(horizontal = 9.dp, vertical = 5.dp)
                        )
                    }
                }
            }
            Column(
                Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
            ) {
                StrongsDetail(vm, selected) { b, ch, v ->
                    vm.open(b, ch, v)
                    vm.screen = Screen.READ
                }
            }
        } else {
            Column(
                Modifier.fillMaxSize().padding(28.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center
            ) {
                androidx.compose.material3.Icon(
                    Icons.AutoMirrored.Outlined.MenuBook,
                    contentDescription = null,
                    tint = c.accent.copy(alpha = 0.7f)
                )
                Spacer(Modifier.height(8.dp))
                Text("Study any word", color = c.ink, fontFamily = ReadingFont, fontSize = 21.sp)
                Text(
                    "Enter a Strong's number, a Hebrew or Greek word, or an English gloss.",
                    color = c.muted,
                    fontSize = 11.sp
                )
            }
        }
    }
}
