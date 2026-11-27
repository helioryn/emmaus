package com.btaylor.emmaus.ui

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.MenuBook
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.outlined.CalendarMonth
import androidx.compose.material.icons.outlined.Create
import androidx.compose.material.icons.outlined.Translate
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.btaylor.emmaus.AppViewModel
import com.btaylor.emmaus.Screen
import kotlinx.coroutines.delay

@Composable
fun EmmausApp(vm: AppViewModel) {
    EmmausTheme(vm.themeName) {
        val c = Emmaus.colors
        if (!vm.prepared) {
            PreparingScreen(vm)
            return@EmmausTheme
        }
        val listState = rememberLazyListState()
        // Tablets and foldables get the study panel docked beside the text.
        val wide = LocalConfiguration.current.screenWidthDp >= 840
        val paneOpen = wide && vm.screen == Screen.READ && !vm.overviewOpen &&
            vm.sheetOpen && vm.selectedVerse != null

        LaunchedEffect(vm.bookId, vm.chapter) {
            if (vm.chapterData != null) listState.scrollToItem(0)
        }

        BackHandler(enabled = vm.settingsOpen) { vm.settingsOpen = false }
        BackHandler(enabled = vm.bookPickerOpen) { vm.bookPickerOpen = false }
        BackHandler(enabled = vm.sheetOpen) { vm.sheetOpen = false }
        BackHandler(
            enabled = vm.overviewOpen && !vm.sheetOpen && !vm.bookPickerOpen && !vm.settingsOpen
        ) { vm.closeOverview() }
        BackHandler(enabled = vm.screen != Screen.HOME && !vm.sheetOpen && !vm.bookPickerOpen && !vm.settingsOpen) {
            vm.screen = Screen.HOME
        }
        BackHandler(
            enabled = vm.screen == Screen.PLANS && vm.openPlanId != null &&
                !vm.sheetOpen && !vm.bookPickerOpen && !vm.settingsOpen
        ) { vm.openPlanId = null }

        Scaffold(
            containerColor = c.background,
            contentWindowInsets = WindowInsets(0, 0, 0, 0),
            bottomBar = {
                NavigationBar(containerColor = c.surfaceAlt, contentColor = c.ink) {
                    val items = listOf(
                        Triple(Screen.HOME, "Home", Icons.Filled.Home),
                        Triple(Screen.READ, "Read", Icons.Filled.MenuBook),
                        Triple(Screen.SEARCH, "Search", Icons.Filled.Search),
                        Triple(Screen.PLANS, "Plans", Icons.Outlined.CalendarMonth),
                        Triple(Screen.WORD, "Word", Icons.Outlined.Translate),
                        Triple(Screen.NOTEBOOK, "Notes", Icons.Outlined.Create)
                    )
                    items.forEach { (screen, label, icon) ->
                        NavigationBarItem(
                            selected = vm.screen == screen,
                            onClick = {
                                if (screen == Screen.READ && vm.screen == Screen.READ) vm.closeOverview()
                                vm.screen = screen
                            },
                            icon = { Icon(icon, contentDescription = label) },
                            label = { Text(label, fontSize = 10.sp, fontWeight = FontWeight.Medium) },
                            colors = NavigationBarItemDefaults.colors(
                                selectedIconColor = c.accent,
                                selectedTextColor = c.accent,
                                indicatorColor = c.accent.copy(alpha = 0.12f),
                                unselectedIconColor = c.muted,
                                unselectedTextColor = c.muted
                            )
                        )
                    }
                }
            }
        ) { padding ->
            Box(Modifier.fillMaxSize().padding(padding)) {
                if (paneOpen) {
                    Row(Modifier.fillMaxSize()) {
                        Box(Modifier.weight(1f)) { ReaderScreen(vm, listState) }
                        Surface(
                            Modifier.width(380.dp).fillMaxHeight(),
                            color = c.surface,
                            shadowElevation = 8.dp
                        ) {
                            StudySheetBody(vm)
                        }
                    }
                } else {
                    when (vm.screen) {
                        Screen.HOME -> HomeScreen(vm)
                        Screen.READ -> if (vm.overviewOpen) BookOverviewScreen(vm) else ReaderScreen(vm, listState)
                        Screen.SEARCH -> SearchScreen(vm)
                        Screen.PLANS -> PlansScreen(vm)
                        Screen.WORD -> WordStudyScreen(vm)
                        Screen.NOTEBOOK -> NotebookScreen(vm)
                    }
                }
            }
        }

        when {
            vm.settingsOpen -> SettingsSheet(vm)
            vm.bookPickerOpen -> BookPickerSheet(vm)
            vm.sheetOpen && !paneOpen -> StudySheet(vm)
        }

        vm.toast?.let { message ->
            LaunchedEffect(message) {
                delay(2200)
                if (vm.toast == message) vm.toast = null
            }
            Box(
                Modifier
                    .fillMaxWidth()
                    .padding(bottom = 92.dp),
                contentAlignment = Alignment.BottomCenter
            ) {
                Text(
                    message,
                    color = c.background,
                    fontSize = 11.5.sp,
                    fontWeight = FontWeight.Medium,
                    modifier = Modifier
                        .clip(RoundedCornerShape(50))
                        .background(c.ink.copy(alpha = 0.94f))
                        .padding(horizontal = 16.dp, vertical = 9.dp)
                )
            }
        }
    }
}

@Composable
private fun PreparingScreen(vm: AppViewModel) {
    val c = Emmaus.colors
    Box(
        Modifier.fillMaxSize().background(c.background),
        contentAlignment = Alignment.Center
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text("Emmaus", color = c.ink, fontFamily = ReadingFont, fontSize = 36.sp, fontWeight = FontWeight.SemiBold)
            Text("Scripture, opened.", color = c.muted, fontSize = 10.5.sp)
            Spacer(Modifier.height(30.dp))
            val problem = vm.error
            when {
                problem != null -> {
                    Text(
                        problem,
                        color = c.red,
                        fontSize = 12.sp,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.padding(horizontal = 36.dp)
                    )
                    Spacer(Modifier.height(16.dp))
                    OutlinedButton(onClick = { vm.retryPrepare() }, shape = RoundedCornerShape(9.dp)) {
                        Text("Try again", color = c.ink, fontSize = 12.sp)
                    }
                }
                else -> {
                    val progress by vm.prepareProgress.collectAsState()
                    if (progress > 0f) {
                        LinearProgressIndicator(
                            progress = { progress },
                            modifier = Modifier.width(190.dp).height(3.dp),
                            color = c.accent,
                            trackColor = c.border
                        )
                    } else {
                        CircularProgressIndicator(color = c.accent)
                    }
                    Spacer(Modifier.height(18.dp))
                    Text(
                        if (progress > 0f) "Unpacking the library — ${(progress * 100).toInt()}%"
                        else "Preparing the library…",
                        color = c.ink,
                        fontSize = 13.sp
                    )
                    Spacer(Modifier.height(6.dp))
                    Text(
                        "First launch only — unpacking the bundled Bibles. Needs about 600 MB free and can take a minute.",
                        color = c.muted,
                        fontSize = 10.sp,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.padding(horizontal = 44.dp)
                    )
                }
            }
        }
    }
}
