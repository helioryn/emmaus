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
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.Remove
import androidx.compose.material.icons.outlined.Visibility
import androidx.compose.material.icons.outlined.VisibilityOff
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.btaylor.emmaus.AppViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsSheet(vm: AppViewModel) {
    val c = Emmaus.colors
    val context = LocalContext.current
    val sheet = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val themes = listOf(
        Triple("parchment", "Parchment", Color(0xFFF4EFE5)),
        Triple("light", "Daylight", Color(0xFFFBFBFD)),
        Triple("sepia", "Sepia", Color(0xFFF0E5CC)),
        Triple("night", "Night", Color(0xFF14161A))
    )

    ModalBottomSheet(
        onDismissRequest = { vm.settingsOpen = false },
        sheetState = sheet,
        containerColor = c.surface
    ) {
        Column(
            Modifier
                .fillMaxWidth()
                .fillMaxHeight(0.92f)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 22.dp, vertical = 6.dp)
        ) {
            Text("Settings", color = c.ink, fontFamily = ReadingFont, fontSize = 26.sp, fontWeight = FontWeight.SemiBold)
            Text("Scripture, opened.", color = c.muted, fontSize = 10.5.sp)
            Spacer(Modifier.height(18.dp))

            SectionLabel("Appearance")
            Spacer(Modifier.height(8.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                themes.forEach { (id, name, bg) ->
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        modifier = Modifier.clickable { vm.setTheme(id) }
                    ) {
                        Box(
                            Modifier
                                .width(42.dp)
                                .height(42.dp)
                                .clip(CircleShape)
                                .background(bg)
                                .then(
                                    if (vm.themeName == id) Modifier.background(c.accent.copy(alpha = 0.18f), CircleShape) else Modifier
                                ),
                            contentAlignment = Alignment.Center
                        ) {
                            if (vm.themeName == id) {
                                Box(Modifier.width(8.dp).height(8.dp).clip(CircleShape).background(c.accent))
                            }
                        }
                        Text(name, color = c.muted, fontSize = 8.5.sp, modifier = Modifier.padding(top = 3.dp))
                    }
                }
            }
            Spacer(Modifier.height(14.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("Reading size", color = c.ink, fontSize = 13.sp)
                Spacer(Modifier.weight(1f))
                IconButton(onClick = { vm.updateFontSize(vm.fontSize - 1) }) {
                    Icon(Icons.Outlined.Remove, contentDescription = "Smaller", tint = c.accent)
                }
                Text("${vm.fontSize}", color = c.ink, fontSize = 13.sp, fontWeight = FontWeight.Medium)
                IconButton(onClick = { vm.updateFontSize(vm.fontSize + 1) }) {
                    Icon(Icons.Outlined.Add, contentDescription = "Larger", tint = c.accent)
                }
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("Strong's underlines", color = c.ink, fontSize = 13.sp)
                Spacer(Modifier.weight(1f))
                Switch(
                    checked = vm.showStrongs,
                    onCheckedChange = { vm.updateShowStrongs(it) },
                    colors = SwitchDefaults.colors(checkedTrackColor = c.accent)
                )
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("Red letters", color = c.ink, fontSize = 13.sp)
                Spacer(Modifier.weight(1f))
                Switch(
                    checked = vm.redLetter,
                    onCheckedChange = { vm.updateRedLetter(it) },
                    colors = SwitchDefaults.colors(checkedTrackColor = c.accent)
                )
            }

            Spacer(Modifier.height(18.dp))
            SectionLabel("Pronunciation")
            Spacer(Modifier.height(6.dp))
            listOf(
                Triple("Hebrew", "he", "בְּרֵאשִׁית"),
                Triple("Greek", "grc", "ἀγάπη"),
                Triple("Latin", "la", "In principio"),
                Triple("Arabic", "ar", "فِي ٱلْبَدْءِ")
            ).forEach { (name, code, sample) ->
                Row(
                    Modifier.fillMaxWidth().padding(vertical = 4.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column(Modifier.weight(1f)) {
                        Text(name, color = c.ink, fontSize = 12.sp, fontWeight = FontWeight.Medium)
                        Text(vm.tts.languageStatus(code), color = c.muted, fontSize = 9.sp)
                    }
                    Text(sample, color = c.muted, fontSize = 14.sp)
                    Spacer(Modifier.width(5.dp))
                    OutlinedButton(onClick = { vm.speakWord(sample, code) }) { Text("Play", fontSize = 10.sp) }
                }
            }
            Text(
                "Greek and Hebrew use the system TTS voices. If a language is missing, install it in Android Settings → System → Languages & input → Text-to-speech.",
                color = c.muted,
                fontSize = 9.sp,
                lineHeight = 13.sp,
                modifier = Modifier.padding(top = 4.dp)
            )

            Spacer(Modifier.height(18.dp))
            SectionLabel("Online Bibles")
            Spacer(Modifier.height(4.dp))
            Text(
                "NIV, NASB and NKJV are licensed texts and are not bundled. Add your own free API.Bible key to read them — chapters download on demand and stay cached for 30 days.",
                color = c.muted,
                fontSize = 9.5.sp,
                lineHeight = 13.sp
            )
            Spacer(Modifier.height(8.dp))
            var keyField by remember { mutableStateOf(vm.apiKey) }
            var showKey by remember { mutableStateOf(false) }
            OutlinedTextField(
                value = keyField,
                onValueChange = { keyField = it },
                label = { Text("API.Bible key", fontSize = 11.sp) },
                placeholder = { Text("paste the key from your api.bible dashboard", fontSize = 10.sp) },
                singleLine = true,
                visualTransformation = if (showKey) VisualTransformation.None else PasswordVisualTransformation(),
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
                trailingIcon = {
                    IconButton(onClick = { showKey = !showKey }) {
                        Icon(
                            if (showKey) Icons.Outlined.VisibilityOff else Icons.Outlined.Visibility,
                            contentDescription = if (showKey) "Hide API key" else "Show API key"
                        )
                    }
                },
                modifier = Modifier.fillMaxWidth()
            )
            Spacer(Modifier.height(8.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedButton(
                    onClick = {
                        vm.saveApiKey(keyField)
                        vm.testApiKey()
                    }
                ) { Text(if (vm.apiBusy) "Checking…" else "Save & test", fontSize = 10.sp) }
                if (vm.apiKey.isNotEmpty()) {
                    OutlinedButton(onClick = {
                        keyField = ""
                        vm.saveApiKey("")
                        vm.clearApiCache()
                    }) { Text("Remove key", fontSize = 10.sp) }
                }
            }
            vm.apiStatus?.let { status ->
                Text(
                    status,
                    color = if (status.startsWith("Connected")) c.accent else c.muted,
                    fontSize = 10.sp,
                    lineHeight = 13.sp,
                    modifier = Modifier.padding(top = 4.dp)
                )
            }
            Text(
                "Get a free key at api.bible →",
                color = c.accent,
                fontSize = 10.sp,
                fontWeight = FontWeight.Medium,
                modifier = Modifier
                    .padding(top = 8.dp)
                    .clickable {
                        context.startActivity(
                            Intent(Intent.ACTION_VIEW, android.net.Uri.parse("https://api.bible/sign-up"))
                        )
                    }
            )
            Text(
                "The free plan includes 5,000 calls a month and three copyrighted translations. In the api.bible dashboard, open your app's Plan tab and add NIV, NASB and NKJV to the Bible list so this key can read them.",
                color = c.muted,
                fontSize = 9.sp,
                lineHeight = 12.5.sp,
                modifier = Modifier.padding(top = 6.dp)
            )

            Spacer(Modifier.height(18.dp))
            SectionLabel("Data")
            Spacer(Modifier.height(6.dp))
            OutlinedButton(
                onClick = {
                    val intent = Intent(Intent.ACTION_SEND).apply {
                        type = "application/json"
                        putExtra(Intent.EXTRA_TEXT, vm.user.exportJson())
                    }
                    context.startActivity(Intent.createChooser(intent, "Export Emmaus data"))
                },
                modifier = Modifier.fillMaxWidth()
            ) {
                Text("Export notes, highlights & bookmarks", fontSize = 11.sp)
            }
            Spacer(Modifier.height(6.dp))
            Text(
                "Everything is stored locally on this device. Export creates a JSON file you can move to your Mac.",
                color = c.muted,
                fontSize = 9.sp,
                lineHeight = 13.sp
            )

            Spacer(Modifier.height(20.dp))
            HorizontalDivider(color = c.border)
            Spacer(Modifier.height(14.dp))
            SectionLabel("About Emmaus")
            Text(
                "Emmaus 1.0 · a study Bible for Android.\n\n" +
                    "41 offline Bibles: KJV with Strong's and red letters, BSB, WEB, ASV, YLT, Geneva, Douay-Rheims, Darby, BBE, plus Chinese, Spanish, French, German, Portuguese, Russian, Korean, Japanese, Vietnamese, Thai and more. Hebrew WLC, Greek New Testament, Vulgate and Arabic Van Dyck. " +
                    "Public-domain texts courtesy of eBible.org. STEPBible lexicons and interlinear (CC BY 4.0). Cross-references from openbible.info (CC BY). Public-domain commentaries and dictionaries.",
                color = c.muted,
                fontSize = 10.sp,
                lineHeight = 15.sp
            )
            Spacer(Modifier.height(40.dp))
        }
    }
}
