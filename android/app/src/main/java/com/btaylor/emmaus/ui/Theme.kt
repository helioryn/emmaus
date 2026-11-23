package com.btaylor.emmaus.ui

import android.app.Activity
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalView
import androidx.core.view.WindowCompat
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.unit.sp

data class EmmausColors(
    val background: Color,
    val surface: Color,
    val surfaceAlt: Color,
    val ink: Color,
    val muted: Color,
    val accent: Color,
    val red: Color,
    val border: Color,
    val selection: Color,
    val highlights: List<Color>,
    val isDark: Boolean
)

val LocalEmmausColors = staticCompositionLocalOf {
    EmmausColors(
        background = Color(0xFFF4EFE5),
        surface = Color(0xFFFCF9F3),
        surfaceAlt = Color(0xFFEDE6D8),
        ink = Color(0xFF2B241B),
        muted = Color(0xFF6E6252),
        accent = Color(0xFF8A5A2B),
        red = Color(0xFFA22B2B),
        border = Color(0xFFDCD1BF),
        selection = Color(0xFFEFE2CB),
        highlights = listOf(
            Color(0xFFF5DF9B), Color(0xFFF4C9C9), Color(0xFFCFE6C9),
            Color(0xFFC9E1F2), Color(0xFFDED0F2)
        ),
        isDark = false
    )
}

val ReadingFont = FontFamily.Serif
val UiFont = FontFamily.SansSerif

@Composable
fun EmmausTheme(themeName: String, content: @Composable () -> Unit) {
    val colors = when (themeName) {
        "night" -> EmmausColors(
            background = Color(0xFF14161A),
            surface = Color(0xFF22262E),
            surfaceAlt = Color(0xFF1B1E24),
            ink = Color(0xFFE9E3D7),
            muted = Color(0xFF9B958A),
            accent = Color(0xFFD4A85C),
            red = Color(0xFFE07163),
            border = Color(0xFF30353F),
            selection = Color(0xFF2B313B),
            highlights = listOf(
                Color(0xFF6A5320), Color(0xFF6B3034), Color(0xFF2F5138),
                Color(0xFF26465C), Color(0xFF463A60)
            ),
            isDark = true
        )
        "sepia" -> EmmausColors(
            background = Color(0xFFF0E5CC),
            surface = Color(0xFFFAF2E1),
            surfaceAlt = Color(0xFFE8DABB),
            ink = Color(0xFF3B2E1B),
            muted = Color(0xFF7B6848),
            accent = Color(0xFF8A5A24),
            red = Color(0xFF9C2B20),
            border = Color(0xFFD9C6A3),
            selection = Color(0xFFEBD9B8),
            highlights = listOf(
                Color(0xFFF3DFA9), Color(0xFFF0C4B8), Color(0xFFCBE2C0),
                Color(0xFFC4DDEB), Color(0xFFD8C9E9)
            ),
            isDark = false
        )
        "light" -> EmmausColors(
            background = Color(0xFFFBFBFD),
            surface = Color(0xFFFFFFFF),
            surfaceAlt = Color(0xFFF3F3F7),
            ink = Color(0xFF1C1C1E),
            muted = Color(0xFF6E6E73),
            accent = Color(0xFF3E5F8A),
            red = Color(0xFFB3261E),
            border = Color(0xFFE3E3E9),
            selection = Color(0xFFEAF0F9),
            highlights = listOf(
                Color(0xFFFFF3C9), Color(0xFFF8D7D5), Color(0xFFD7EBD3),
                Color(0xFFD3E8F7), Color(0xFFE5DCF5)
            ),
            isDark = false
        )
        else -> LocalEmmausColors.current
    }
    val scheme = if (colors.isDark) {
        darkColorScheme(
            primary = colors.accent,
            onPrimary = colors.background,
            background = colors.background,
            onBackground = colors.ink,
            surface = colors.surface,
            onSurface = colors.ink,
            surfaceVariant = colors.surfaceAlt,
            onSurfaceVariant = colors.muted,
            outline = colors.border,
            error = colors.red
        )
    } else {
        lightColorScheme(
            primary = colors.accent,
            onPrimary = Color.White,
            background = colors.background,
            onBackground = colors.ink,
            surface = colors.surface,
            onSurface = colors.ink,
            surfaceVariant = colors.surfaceAlt,
            onSurfaceVariant = colors.muted,
            outline = colors.border,
            error = colors.red
        )
    }
    val view = LocalView.current
    if (!view.isInEditMode) {
        SideEffect {
            val activity = view.context as? Activity
            if (activity != null) {
                val window = activity.window
                window.statusBarColor = colors.background.toArgb()
                window.navigationBarColor = colors.surfaceAlt.toArgb()
                val controller = WindowCompat.getInsetsController(window, view)
                controller.isAppearanceLightStatusBars = !colors.isDark
                controller.isAppearanceLightNavigationBars = !colors.isDark
            }
        }
    }
    CompositionLocalProvider(LocalEmmausColors provides colors) {
        MaterialTheme(
            colorScheme = scheme,
            typography = Typography(
                bodyLarge = TextStyle(fontFamily = UiFont, fontSize = 15.sp, lineHeight = 22.sp, fontWeight = FontWeight.Normal),
                bodyMedium = TextStyle(fontFamily = UiFont, fontSize = 13.sp, lineHeight = 19.sp),
                titleLarge = TextStyle(fontFamily = ReadingFont, fontSize = 24.sp, fontWeight = FontWeight.SemiBold),
                titleMedium = TextStyle(fontFamily = ReadingFont, fontSize = 17.sp, fontWeight = FontWeight.SemiBold)
            ),
            content = content
        )
    }
}

object Emmaus {
    val colors: EmmausColors
        @Composable get() = LocalEmmausColors.current
}
