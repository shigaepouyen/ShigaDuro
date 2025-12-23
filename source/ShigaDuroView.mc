import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.ActivityMonitor;
import Toybox.SensorHistory;
import Toybox.UserProfile;
import Toybox.Weather;

class ShigaDuroView extends WatchUi.WatchFace {

    // ---------- Colors (safe across fenix/enduro) ----------
    const BG      = Graphics.COLOR_BLACK;
    const FG      = Graphics.COLOR_WHITE;
    const SUB     = 0xA8A8A8;
    const TRACK   = 0x4A4A4A;

    const SUNCOL  = 0xFFAA00; // orange/jaune
    const STEPCOL = 0x00AAFF; // bleu steps
    const RECCOL  = 0x3AA8FF; // bleu recovery
    const VO2COL  = 0xB000FF; // violet vo2

    const RED     = 0xFF2D2D;
    const YEL     = 0xFFD400;
    const GRN     = 0x00FF6A;

    // ---------- Weather cache ----------
    var _wxCache = null;
    var _wxCacheAt = 0; // seconds epoch

    function initialize() {
        WatchUi.WatchFace.initialize();
    }

    function onUpdate(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = (w / 2).toNumber();
        var cy = (h / 2).toNumber();

        // Clear
        dc.setColor(BG, BG);
        dc.clear();

        // Ring geometry
        var pen = (w < 300 ? 10 : 12).toNumber();
        var margin = 10;
        var r = ((w / 2) - margin - (pen / 2)).toNumber();

        // ---------- Time ----------
        var clock = System.getClockTime();
        var is24 = true;
        try { is24 = System.getDeviceSettings().is24Hour; } catch(e) {}

        var hh = clock.hour;
        if (!is24) {
            hh = hh % 12;
            if (hh == 0) { hh = 12; }
        }
        var timeStr = hh.format("%02d") + ":" + clock.min.format("%02d");

        // ---------- Data: steps / recovery ----------
        var info = ActivityMonitor.getInfo();

        var steps = 0;
        try { if (info.steps != null) { steps = info.steps; } } catch(e) {}

        var goal = 10000;
        try { if (info.stepGoal != null && info.stepGoal > 0) { goal = info.stepGoal; } } catch(e) {}

        var stepPct = clamp01(steps.toFloat() / goal.toFloat());
        var stepPctStr = ((stepPct * 100.0).toNumber()).format("%d") + "%";

        var recH = null;
        try { if (info.timeToRecovery != null) { recH = info.timeToRecovery.toNumber(); } } catch(e) {}
        var recStr = (recH != null) ? (recH.format("%d") + "h") : "--h";
        var recPct = (recH != null) ? clamp01(recH.toFloat() / 72.0) : 0.0;

        // ---------- Body Battery ----------
        var bbVal = getBodyBattery(); // null if unavailable
        var bbStr = (bbVal != null) ? bbVal.format("%d") : "--";
        var bbPct = (bbVal != null) ? clamp01(bbVal.toFloat() / 100.0) : 0.0;

        var bbCol = TRACK;
        if (bbVal != null) {
            if (bbVal < 20)      { bbCol = RED; }
            else if (bbVal < 40) { bbCol = YEL; }
            else                 { bbCol = GRN; }
        }

        // ---------- Heart rate (reliable on watchface) ----------
        var hr = getLatestHeartRate();
        var hrStr = (hr != null) ? hr.format("%d") : "--";

        // ---------- VO2 running ----------
        var vo2 = getVo2Running();
        var vo2Str = (vo2 != null) ? vo2.format("%d") : "--";
        var vo2Pct = 0.0;
        if (vo2 != null) {
            // 30..70 => 0..1
            vo2Pct = clamp01((vo2.toFloat() - 30.0) / 40.0);
        }

        // ---------- Sun + Temperature + Header strings ----------
        var now = Time.now();
        var sun = getSunAndTemp(now); // Dictionary
        var headerLeft  = sun.get(:dateStr);   // "DEC 23"
        var headerRight = sun.get(:sunStr);    // "SUNSET 18:30" / "SUNRISE 06:58" / "NO GPS"
        var sunPct      = sun.get(:sunPct);    // 0..1
        var tempStr     = sun.get(:tempStr);   // "16°C" / "--°C"

        // ---------- Battery ----------
        var battVal = null;
        var battStr = "--%";
        try {
            var stats = System.getSystemStats();
            if (stats != null && stats.battery != null) {
                battVal = stats.battery;
                battStr = battVal.format("%d") + "%";
            }
        } catch(e) {}

        // =========================================================
        // RING - 4 zones (clean quadrants)
        // Angles: 0=3h, 90=12h, 180=9h, 270=6h
        // Top:    45 -> 135
        // Left:  135 -> 225
        // Bottom:225 -> 315
        // Right: 315 -> 45 (wrap) split in 2x45
        // =========================================================

        var gap = 2; // Degrees

        // TOP - Sun
        drawArcTrack(dc, cx, cy, r, pen, 45 + gap, 135 - gap);
        drawArcFill(dc, cx, cy, r, pen, 45 + gap, 90 - (2 * gap), sunPct, SUNCOL);

        // LEFT - Body Battery
        drawArcTrack(dc, cx, cy, r, pen, 135 + gap, 225 - gap);
        drawArcFill(dc, cx, cy, r, pen, 135 + gap, 90 - (2 * gap), bbPct, bbCol);

        // BOTTOM - Steps
        drawArcTrack(dc, cx, cy, r, pen, 225 + gap, 315 - gap);
        drawArcFill(dc, cx, cy, r, pen, 225 + gap, 90 - (2 * gap), stepPct, STEPCOL);

        // RIGHT - Track
        drawArcTrack(dc, cx, cy, r, pen, 315 + gap, 45 - gap);
        // RIGHT split: VO2 lower-right (315->0), Recovery upper-right (0->45)
        var right_half_span = 45 - gap;
        drawArcFill(dc, cx, cy, r, pen, 315 + gap, right_half_span, vo2Pct, VO2COL);
        drawArcFill(dc, cx, cy, r, pen, 0,           right_half_span, recPct, RECCOL);

        // =========================================================
        // TEXT LAYOUT (prevents overlaps)
        // =========================================================

        // Header - fitted, centered
        var headerY = (h * 0.18).toNumber();
        var header = headerLeft + " | " + headerRight;

        dc.setColor(SUB, Graphics.COLOR_TRANSPARENT);
        drawFittedCenteredText(dc, cx, headerY, Graphics.FONT_SYSTEM_TINY, header, (w - 16).toNumber());

        // Center time
        dc.setColor(FG, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy, Graphics.FONT_NUMBER_HOT, timeStr,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Compute safe side anchors based on time width
        var timeW = dc.getTextWidthInPixels(timeStr, Graphics.FONT_NUMBER_HOT).toNumber();
        var sidePad = 28;
        var xLeft  = (cx - (timeW / 2) - sidePad).toNumber();
        var xRight = (cx + (timeW / 2) + sidePad).toNumber();

        // LEFT block: Body Battery
        var yLeftIcon = (cy - (h * 0.1)).toNumber();
        var yLeftText = (cy + (h * 0.1)).toNumber();
        drawHeartIcon(dc, xLeft, yLeftIcon, 6, bbCol);

        dc.setColor(FG, Graphics.COLOR_TRANSPARENT);
        dc.drawText(xLeft, yLeftText, Graphics.FONT_SYSTEM_MEDIUM, bbStr,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // RIGHT block: Recovery + VO2
        var yRecIcon = (cy - (h * 0.1)).toNumber();
        var yRecText = (cy - (h * 0.02)).toNumber();
        var yVo2Icon = (cy + (h * 0.05)).toNumber();
        var yVo2Text = (cy + (h * 0.13)).toNumber();

        drawTimerIcon(dc, xRight, yRecIcon, 8, RECCOL);
        dc.setColor(FG, Graphics.COLOR_TRANSPARENT);
        dc.drawText(xRight, yRecText, Graphics.FONT_SYSTEM_MEDIUM, recStr,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        drawLungsIcon(dc, xRight, yVo2Icon, 8, 5, VO2COL);
        dc.setColor(FG, Graphics.COLOR_TRANSPARENT);
        dc.drawText(xRight, yVo2Text, Graphics.FONT_SYSTEM_MEDIUM, vo2Str,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Bottom bar: Temp, HR, Battery
        var barY = (h * 0.82).toNumber();
        var spacing = (w / 4).toNumber();
        var x1 = (cx - spacing).toNumber();
        var x2 = cx;
        var x3 = (cx + spacing).toNumber();

        // Temp
        drawThermometerIcon(dc, x1 - 15, barY, 12, SUB);
        dc.drawText(x1 + 10, barY, Graphics.FONT_SYSTEM_MEDIUM, tempStr, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        // HR
        drawHeartIcon(dc, x2 - 15, barY, 5, RED);
        dc.drawText(x2 + 10, barY, Graphics.FONT_SYSTEM_MEDIUM, hrStr, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        // Battery
        var battPct = (battVal != null) ? (battVal / 100.0) : 0.0;
        drawBatteryIcon(dc, x3 - 15, barY, 20, 10, battPct, SUB);
        dc.drawText(x3 + 15, barY, Graphics.FONT_SYSTEM_MEDIUM, battStr, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);


        // Steps % (bottom-center)
        var stepsY = (h * 0.90).toNumber();
        dc.setColor(STEPCOL, Graphics.COLOR_TRANSPARENT);
        drawFootIcon(dc, (cx - 18).toNumber(), stepsY, 5);

        dc.setColor(FG, Graphics.COLOR_TRANSPARENT);
        dc.drawText((cx).toNumber(), stepsY, Graphics.FONT_SYSTEM_MEDIUM, stepPctStr,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // =========================================================
    // DATA HELPERS
    // =========================================================

    function getLatestHeartRate() {
        try {
            var it = ActivityMonitor.getHeartRateHistory(10, true);
            for (var i = 0; i < 10; i += 1) {
                var s = it.next();
                if (s == null) { break; }
                if (s.heartRate != null && s.heartRate != ActivityMonitor.INVALID_HR_SAMPLE) {
                    return s.heartRate;
                }
            }
        } catch(e) {}
        return null;
    }

    function getBodyBattery() {
        try {
            if ((Toybox has :SensorHistory) && (Toybox.SensorHistory has :getBodyBatteryHistory)) {
                var it = SensorHistory.getBodyBatteryHistory({ :period => 1, :order => SensorHistory.ORDER_NEWEST_FIRST });
                var s = it.next();
                if (s != null && s.data != null) {
                    return s.data.toNumber();
                }
            }
        } catch(e) {}
        return null;
    }

    function getVo2Running() {
        try {
            if ((Toybox has :UserProfile) && (Toybox.UserProfile has :getProfile)) {
                var p = UserProfile.getProfile();
                if (p != null && p.vo2maxRunning != null) {
                    return p.vo2maxRunning.toNumber();
                }
            }
        } catch(e) {}
        return null;
    }

    function getWeatherCached(nowMoment) {
        // Cache 10 minutes
        var nowS = nowMoment.value();
        if (_wxCache != null && (nowS - _wxCacheAt) < 600) {
            return _wxCache;
        }
        try {
            _wxCache = Weather.getCurrentConditions();
            _wxCacheAt = nowS;
        } catch(e) {}
        return _wxCache;
    }

    function getSunAndTemp(nowMoment) {
        var out = {
            :dateStr => formatMonthDay(nowMoment), // "DEC 23"
            :sunStr  => "NO GPS",
            :sunPct  => 0.0,
            :tempStr => "--°C"
        };

        if (!(Toybox has :Weather)) {
            return out;
        }

        var cond = null;
        try { cond = getWeatherCached(nowMoment); } catch(e) {}
        if (cond == null) { return out; }

        // Temp
        try {
            if (cond.temperature != null) {
                out.put(:tempStr, cond.temperature.toNumber().format("%d") + "°C");
            }
        } catch(e) {}

        // Location needed for sunrise/sunset
        var loc = null;
        try { loc = cond.observationLocationPosition; } catch(e) {}
        if (loc == null) { return out; }

        var rise = null;
        var set  = null;
        try { rise = Weather.getSunrise(loc, nowMoment); } catch(e) {}
        try { set  = Weather.getSunset(loc, nowMoment); } catch(e) {}
        if (rise == null || set == null) { return out; }

        // Before sunrise
        if (nowMoment.lessThan(rise)) {
            out.put(:sunStr, "SUNRISE " + formatClock(rise));
            out.put(:sunPct, 0.0);
            return out;
        }

        // Daytime
        if (nowMoment.lessThan(set)) {
            out.put(:sunStr, "SUNSET " + formatClock(set));

            var total = set.value() - rise.value();
            var done  = nowMoment.value() - rise.value();
            if (total > 0) {
                out.put(:sunPct, clamp01(done.toFloat() / total.toFloat()));
            } else {
                out.put(:sunPct, 0.0);
            }
            return out;
        }

        // After sunset: show next sunrise (tomorrow)
        var tomorrow = nowMoment.add(new Time.Duration(Gregorian.SECONDS_PER_DAY));
        var nextRise = null;
        try { nextRise = Weather.getSunrise(loc, tomorrow); } catch(e) {}

        if (nextRise != null) {
            out.put(:sunStr, "SUNRISE " + formatClock(nextRise));
        } else {
            out.put(:sunStr, "SUNRISE " + formatClock(rise));
        }
        out.put(:sunPct, 0.0);
        return out;
    }

    // =========================================================
    // DRAW HELPERS
    // =========================================================

    function drawArcTrack(dc, cx, cy, r, pen, startDeg, endDeg) {
        dc.setPenWidth(pen);
        dc.setColor(TRACK, Graphics.COLOR_TRANSPARENT);
        drawArcWrap(dc, cx, cy, r, startDeg, endDeg);
    }

    function drawArcFill(dc, cx, cy, r, pen, startDeg, spanDeg, pct, color) {
        pct = clamp01(pct);
        if (pct <= 0.0) { return; }

        var endF = startDeg.toFloat() + (spanDeg.toFloat() * pct);
        while (endF >= 360.0) { endF -= 360.0; }
        while (endF < 0.0) { endF += 360.0; }

        dc.setPenWidth(pen);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        drawArcWrap(dc, cx, cy, r, startDeg, endF.toNumber());
    }

    function drawArcWrap(dc, cx, cy, r, startDeg, endDeg) {
        if (startDeg <= endDeg) {
            dc.drawArc(cx, cy, r, Graphics.ARC_COUNTER_CLOCKWISE, startDeg, endDeg);
        } else {
            dc.drawArc(cx, cy, r, Graphics.ARC_COUNTER_CLOCKWISE, startDeg, 360);
            dc.drawArc(cx, cy, r, Graphics.ARC_COUNTER_CLOCKWISE, 0, endDeg);
        }
    }

    function drawFittedCenteredText(dc, cx, y, font, text, maxW) {
        var t = text;
        var tw = dc.getTextWidthInPixels(t, font);
        if (tw > maxW) {
            var base = text;
            var n = base.length();
            while (n > 0) {
                t = base.substring(0, n) + "...";
                tw = dc.getTextWidthInPixels(t, font);
                if (tw <= maxW) { break; }
                n -= 1;
            }
        }
        dc.drawText(cx, y, font, t, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function drawHeartIcon(dc, x, y, r, color) {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle((x - r).toNumber(), y, r);
        dc.fillCircle((x + r).toNumber(), y, r);
        var px = x;
        var py = (y + (r * 2)).toNumber();
        dc.drawLine((x - (r * 2)).toNumber(), y, px, py);
        dc.drawLine((x + (r * 2)).toNumber(), y, px, py);
    }

    function drawFootIcon(dc, x, y, r) {
        dc.fillRectangle((x - (r * 0.6)).toNumber(), (y - (r * 0.3)).toNumber(),
                         (r * 1.2).toNumber(), (r * 1.6).toNumber());
        dc.fillCircle((x + (r * 0.8)).toNumber(), (y - (r * 0.4)).toNumber(), (r * 0.35).toNumber());
    }

    function drawLungsIcon(dc, x, y, w, h, color) {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawArc(x, y, w, Graphics.ARC_COUNTER_CLOCKWISE, 45, 135);
        dc.drawArc(x, y, w, Graphics.ARC_COUNTER_CLOCKWISE, 225, 315);
        dc.drawLine(x, y - w, x, y + h);
    }

    function drawTimerIcon(dc, x, y, r, color) {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawCircle(x, y, r);
        dc.drawLine(x, y, x, y - (r / 2));
        dc.drawLine(x, y, x + (r / 2), y);
    }

    function drawThermometerIcon(dc, x, y, h, color) {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        var r = h / 4;
        dc.drawCircle(x, y + r, r);
        dc.drawLine(x, y, x, y - h);
        dc.fillCircle(x, y + r, r / 2);
    }

     function drawBatteryIcon(dc, x, y, w, h, battPct, color) {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawRectangle(x, y, w, h);
        dc.fillRectangle(x + (w/10), y - 2, w - (w/5), 2);

        var battFill = (w - 4) * battPct;
        if (battFill > 0) {
            dc.fillRectangle(x + 2, y + 2, battFill, h - 4);
        }
    }

    function formatClock(m) {
        var i = Gregorian.info(m, Time.FORMAT_SHORT);
        return i.hour.format("%02d") + ":" + i.min.format("%02d");
    }

    function formatMonthDay(m) {
        var i = Gregorian.info(m, Time.FORMAT_SHORT);
        var months = ["JAN","FEB","MAR","APR","MAY","JUN","JUL","AUG","SEP","OCT","NOV","DEC"];
        var mm = (i.month != null) ? i.month.toNumber() : 0;
        var dd = (i.day != null) ? i.day.toNumber() : 0;

        var mStr = (mm >= 1 && mm <= 12) ? months[mm - 1] : "---";
        var dStr = (dd > 0) ? dd.format("%02d") : "--";
        return mStr + " " + dStr;
    }

    function clamp01(v) {
        if (v == null) { return 0.0; }
        if (v < 0.0) { return 0.0; }
        if (v > 1.0) { return 1.0; }
        return v;
    }

    function onExitSleep() {}
    function onEnterSleep() {}
}
