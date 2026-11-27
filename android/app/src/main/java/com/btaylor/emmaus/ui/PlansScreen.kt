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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.outlined.ChevronLeft
import androidx.compose.material.icons.outlined.MenuBook
import androidx.compose.material.icons.outlined.RadioButtonUnchecked
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.btaylor.emmaus.AppViewModel
import com.btaylor.emmaus.data.PlanDefinition
import com.btaylor.emmaus.data.PlanLibrary
import com.btaylor.emmaus.data.PlanDay

@Composable
fun PlansScreen(vm: AppViewModel) {
    val definition = vm.openPlanId?.let { PlanLibrary.definition(it) }
    if (definition == null) PlanList(vm) else PlanDetail(vm, definition)
}

@Composable
private fun PlanList(vm: AppViewModel) {
    val c = Emmaus.colors
    Column(Modifier.fillMaxSize().background(c.background)) {
        Column(Modifier.padding(start = 20.dp, end = 20.dp, top = 18.dp, bottom = 10.dp)) {
            Text("Reading Plans", color = c.ink, fontFamily = ReadingFont, fontSize = 27.sp, fontWeight = FontWeight.SemiBold)
            Text(
                "Pick a pace, then keep the streak. Progress is stored on this device.",
                color = c.muted,
                fontSize = 10.5.sp,
                modifier = Modifier.padding(top = 3.dp)
            )
        }
        LazyColumn(
            contentPadding = PaddingValues(start = 16.dp, end = 16.dp, bottom = 28.dp),
            verticalArrangement = Arrangement.spacedBy(9.dp)
        ) {
            items(PlanLibrary.definitions, key = { it.id }) { definition ->
                PlanCard(vm, definition)
            }
        }
    }
}

@Composable
private fun PlanCard(vm: AppViewModel, definition: PlanDefinition) {
    val c = Emmaus.colors
    val completed = vm.planCompleted(definition)
    val current = vm.currentPlanDay(definition)
    val fraction = if (definition.days == 0) 0f else completed.toFloat() / definition.days
    val active = vm.activePlanId == definition.id
    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(c.surface)
            .border(if (active) 1.dp else 0.6.dp, if (active) c.accent.copy(alpha = 0.4f) else c.border, RoundedCornerShape(12.dp))
            .clickable {
                vm.selectPlan(definition)
                vm.openPlanId = definition.id
            }
            .padding(14.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(definition.name, color = c.ink, fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
            Spacer(Modifier.weight(1f))
            if (active) EmmausPill("Active", filled = true)
        }
        Text(definition.subtitle, color = c.muted, fontSize = 10.sp, modifier = Modifier.padding(top = 2.dp))
        Spacer(Modifier.height(10.dp))
        LinearProgressIndicator(
            progress = { fraction },
            modifier = Modifier.fillMaxWidth().height(3.dp).clip(RoundedCornerShape(2.dp)),
            color = c.accent,
            trackColor = c.border.copy(alpha = 0.6f)
        )
        Spacer(Modifier.height(8.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("$completed of ${definition.days} days", color = c.muted, fontSize = 9.5.sp)
            Spacer(Modifier.weight(1f))
            if (current != null) {
                Text("Next: Day ${current.day} · ${current.label}", color = c.accent, fontSize = 9.5.sp, fontWeight = FontWeight.Medium)
            } else {
                Text("Finished", color = c.accent, fontSize = 9.5.sp, fontWeight = FontWeight.Medium)
            }
        }
    }
}

@Composable
private fun PlanDetail(vm: AppViewModel, definition: PlanDefinition) {
    val c = Emmaus.colors
    val plan = vm.readingPlan(definition)
    val completed = vm.planCompleted(definition)
    val current = vm.currentPlanDay(definition)
    val fraction = if (definition.days == 0) 0f else completed.toFloat() / definition.days

    Column(Modifier.fillMaxSize().background(c.background)) {
        Row(
            Modifier.fillMaxWidth().padding(start = 6.dp, end = 16.dp, top = 8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            IconButton(onClick = { vm.openPlanId = null }) {
                Icon(Icons.Outlined.ChevronLeft, contentDescription = "Back to plans", tint = c.ink)
            }
            Column(Modifier.weight(1f)) {
                Text(definition.name, color = c.ink, fontSize = 17.sp, fontWeight = FontWeight.SemiBold)
                Text("$completed of ${definition.days} days", color = c.muted, fontSize = 10.sp)
            }
        }
        LinearProgressIndicator(
            progress = { fraction },
            modifier = Modifier.fillMaxWidth().height(3.dp),
            color = c.accent,
            trackColor = c.border.copy(alpha = 0.6f)
        )
        if (current != null) {
            OutlinedButton(
                onClick = { vm.openPlanDay(current) },
                modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 10.dp),
                shape = RoundedCornerShape(9.dp)
            ) {
                Icon(Icons.Outlined.MenuBook, contentDescription = null, tint = c.accent, modifier = Modifier.width(16.dp))
                Spacer(Modifier.width(7.dp))
                Text("Day ${current.day} — ${current.label}", color = c.ink, fontSize = 11.5.sp)
            }
        }
        LazyColumn(
            contentPadding = PaddingValues(start = 16.dp, end = 16.dp, bottom = 28.dp),
            verticalArrangement = Arrangement.spacedBy(3.dp)
        ) {
            items(plan.days, key = { it.day }) { day ->
                DayRow(vm, definition, day, current?.day == day.day)
            }
        }
    }
}

@Composable
private fun DayRow(vm: AppViewModel, definition: PlanDefinition, day: PlanDay, isNext: Boolean) {
    val c = Emmaus.colors
    val done = vm.user.isPlanDayDone(definition.id, day.day)
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(8.dp))
            .then(if (isNext) Modifier.background(c.accent.copy(alpha = 0.07f)) else Modifier)
            .clickable { vm.openPlanDay(day) }
            .padding(horizontal = 10.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        IconButton(onClick = { vm.togglePlanDay(definition, day.day) }, modifier = Modifier.width(30.dp)) {
            Icon(
                if (done) Icons.Filled.CheckCircle else Icons.Outlined.RadioButtonUnchecked,
                contentDescription = if (done) "Mark day ${day.day} not done" else "Mark day ${day.day} done",
                tint = if (done) c.accent else c.muted.copy(alpha = 0.55f)
            )
        }
        Column(Modifier.weight(1f).padding(start = 2.dp)) {
            Text("Day ${day.day}", color = if (done) c.muted else c.ink, fontSize = 10.5.sp, fontWeight = FontWeight.SemiBold)
            Text(day.label, color = c.muted, fontSize = 10.sp, modifier = Modifier.padding(top = 1.dp))
        }
        if (isNext) EmmausPill("Next")
    }
}
