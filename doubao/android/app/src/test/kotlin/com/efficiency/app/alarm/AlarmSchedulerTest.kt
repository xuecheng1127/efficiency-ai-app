package com.efficiency.app.alarm

import org.junit.Assert.*
import org.junit.Test
import java.util.Calendar

class AlarmSchedulerTest {

    @Test
    fun `daily today passed returns today`() {
        val now = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 10)
            set(Calendar.MINUTE, 30)
        }.timeInMillis
        // 目标 09:00，已过
        val result = AlarmScheduler.lastMissedTriggerMillis(
            nowMillis = now, hourOfDay = 9, minute = 0,
            repeatRule = AlarmScheduler.REPEAT_DAILY, weekdays = emptyList(),
            scheduledDateMillis = null, advanceMinutes = 0
        )
        assertNotNull(result)
        val cal = Calendar.getInstance().apply { timeInMillis = result!! }
        assertEquals(9, cal.get(Calendar.HOUR_OF_DAY))
        assertEquals(0, cal.get(Calendar.MINUTE))
    }

    @Test
    fun `daily today not passed returns yesterday`() {
        val now = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 8)
            set(Calendar.MINUTE, 0)
        }.timeInMillis
        // 目标 09:00，未到
        val result = AlarmScheduler.lastMissedTriggerMillis(
            nowMillis = now, hourOfDay = 9, minute = 0,
            repeatRule = AlarmScheduler.REPEAT_DAILY, weekdays = emptyList(),
            scheduledDateMillis = null, advanceMinutes = 0
        )
        assertNotNull(result)
        val cal = Calendar.getInstance().apply { timeInMillis = result!! }
        assertEquals(9, cal.get(Calendar.HOUR_OF_DAY))
    }

    @Test
    fun `once scheduledDate passed returns that day`() {
        val now = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 12)
            set(Calendar.MINUTE, 0)
        }.timeInMillis
        val scheduled = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 9)
            set(Calendar.MINUTE, 0)
        }.timeInMillis
        val result = AlarmScheduler.lastMissedTriggerMillis(
            nowMillis = now, hourOfDay = 9, minute = 0,
            repeatRule = AlarmScheduler.REPEAT_ONCE, weekdays = emptyList(),
            scheduledDateMillis = scheduled, advanceMinutes = 0
        )
        assertNotNull(result)
    }

    @Test
    fun `once scheduledDate future returns null`() {
        val now = Calendar.getInstance().timeInMillis
        val scheduled = now + 24 * 60 * 60 * 1000 // 明天
        val result = AlarmScheduler.lastMissedTriggerMillis(
            nowMillis = now, hourOfDay = 9, minute = 0,
            repeatRule = AlarmScheduler.REPEAT_ONCE, weekdays = emptyList(),
            scheduledDateMillis = scheduled, advanceMinutes = 0
        )
        assertNull(result)
    }

    @Test
    fun `advanceMinutes subtracts from trigger time`() {
        val now = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 10)
            set(Calendar.MINUTE, 30)
        }.timeInMillis
        val result = AlarmScheduler.lastMissedTriggerMillis(
            nowMillis = now, hourOfDay = 10, minute = 0,
            repeatRule = AlarmScheduler.REPEAT_DAILY, weekdays = emptyList(),
            scheduledDateMillis = null, advanceMinutes = 15
        )
        assertNotNull(result)
        val cal = Calendar.getInstance().apply { timeInMillis = result!! }
        assertEquals(9, cal.get(Calendar.HOUR_OF_DAY))
        assertEquals(45, cal.get(Calendar.MINUTE))
    }
}
