package com.btaylor.emmaus.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Tab
import androidx.compose.material3.TabRow
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.btaylor.emmaus.AppViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun BookPickerSheet(vm: AppViewModel) {
    val c = Emmaus.colors
    val sheet = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    var testament by remember { mutableStateOf("OT") }

    ModalBottomSheet(
        onDismissRequest = { vm.bookPickerOpen = false },
        sheetState = sheet,
        containerColor = c.surface
    ) {
        Column(Modifier.fillMaxWidth().fillMaxHeight(0.86f)) {
            Column(Modifier.fillMaxWidth().padding(horizontal = 22.dp, vertical = 4.dp)) {
                Text(
                    "Choose a book",
                    color = c.ink,
                    fontFamily = ReadingFont,
                    fontSize = 24.sp,
                    fontWeight = FontWeight.SemiBold
                )
                Text("Tap a book to open its overview.", color = c.muted, fontSize = 10.sp)
            }

            TabRow(
                selectedTabIndex = if (testament == "OT") 0 else 1,
                containerColor = c.surface,
                contentColor = c.accent
            ) {
                Tab(selected = testament == "OT", onClick = { testament = "OT" }, text = { Text("Old Testament") })
                Tab(selected = testament == "NT", onClick = { testament = "NT" }, text = { Text("New Testament") })
            }

            LazyColumn(Modifier.fillMaxWidth()) {
                items(vm.bible.books.filter { it.testament == testament }) { book ->
                    val read = vm.readChapters(book.id).size
                    Row(
                        Modifier
                            .fillMaxWidth()
                            .clickable {
                                vm.bookPickerOpen = false
                                vm.showBookOverview(book.id)
                            }
                            .padding(horizontal = 22.dp, vertical = 11.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Box(
                            Modifier
                                .width(38.dp)
                                .height(34.dp)
                                .clip(RoundedCornerShape(7.dp))
                                .background(c.accent.copy(alpha = 0.10f)),
                            contentAlignment = Alignment.Center
                        ) {
                            Text(book.short, color = c.accent, fontSize = 9.sp, fontWeight = FontWeight.SemiBold)
                        }
                        Spacer(Modifier.width(12.dp))
                        Column(Modifier.weight(1f)) {
                            Text(book.name, color = c.ink, fontSize = 14.sp, fontFamily = ReadingFont)
                            if (read > 0) {
                                Text(
                                    "$read of ${book.chapters} chapters read",
                                    color = c.muted,
                                    fontSize = 9.sp
                                )
                            }
                        }
                        Text("${book.chapters}", color = c.muted, fontSize = 10.sp)
                    }
                }
                item { Spacer(Modifier.height(40.dp)) }
            }
        }
    }
}
