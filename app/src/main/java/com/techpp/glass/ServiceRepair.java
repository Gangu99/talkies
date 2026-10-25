package com.techpp.glass;

// Adapted from CleanYourTV's launcher (ServiceRepair.java), MIT License, Copyright (c) 2026 Gathin.
// See THIRD_PARTY_NOTICES.md.

import android.Manifest;
import android.content.BroadcastReceiver;
import android.content.ComponentName;
import android.content.ContentResolver;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.provider.Settings;
import android.util.Log;

import java.util.ArrayList;
import java.util.List;
import java.util.Objects;

/**
 * Android takes Talkies' accessibility service off the enabled list when the app is force-stopped (it counts as
 * a crash), and then Home goes to Google TV until you switch it on again. While the service runs it records itself
 * here, and drops the record when Android unbinds it (you turned it off); a force stop kills the process before
 * that, so the record stays. When Talkies starts again (you open it, the TV boots, or it's updated) a recorded
 * service is put back on the list. That needs WRITE_SECURE_SETTINGS, which only you can grant, once, over adb:
 * {@code adb shell pm grant com.techpp.glass android.permission.WRITE_SECURE_SETTINGS}. Without it nothing happens.
 */
final class ServiceRepair {
    private static final String TAG = "GlassRepair";
    private static final String PREFS = "accessibility_helpers";

    private ServiceRepair() { }

    /** Boot and app updates: put the service back without waiting for Talkies to be opened. */
    public static class Starter extends BroadcastReceiver {
        @Override public void onReceive(Context c, Intent i) { restore(c); }
    }

    static boolean canRepair(Context c) {
        return c.checkSelfPermission(Manifest.permission.WRITE_SECURE_SETTINGS) == PackageManager.PERMISSION_GRANTED;
    }

    static void connected(Context c, Class<?> service) {
        prefs(c).edit().putBoolean(service.getName(), true).apply();
    }

    static void disconnected(Context c, Class<?> service) {
        prefs(c).edit().remove(service.getName()).apply();
    }

    static void restore(Context context) {
        if (!canRepair(context)) return;
        try {
            ContentResolver cr = context.getContentResolver();
            String list = Settings.Secure.getString(cr, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES);
            List<ComponentName> enabled = new ArrayList<>();
            if (list != null) {
                for (String entry : list.split(":")) {
                    ComponentName name = ComponentName.unflattenFromString(entry);
                    if (name != null) enabled.add(name);
                }
            }
            List<ComponentName> recorded = new ArrayList<>();
            for (String service : prefs(context).getAll().keySet()) recorded.add(new ComponentName(context.getPackageName(), service));
            if (recorded.isEmpty()) return;
            StringBuilder others = new StringBuilder();
            for (ComponentName name : enabled) {
                if (recorded.contains(name)) continue;
                if (others.length() > 0) others.append(':');
                others.append(name.flattenToShortString());
            }
            StringBuilder updated = new StringBuilder(others);
            boolean missing = false;
            for (ComponentName name : recorded) {
                if (!enabled.contains(name)) missing = true;
                if (updated.length() > 0) updated.append(':');
                updated.append(name.flattenToShortString());
            }
            if (!missing) return;
            Log.i(TAG, "Accessibility service was switched off (force stop?): putting it back");
            // A force-stopped service is also on Android's "crashed" list and isn't bound again just by being listed.
            // Android drops that mark when it sees the service leave the list, so: add, remove, add. Each step only
            // writes if the list still reads what the previous step left, so a change you make meanwhile wins.
            final String without = others.toString(), with = updated.toString();
            new Thread(() -> {
                try {
                    if (!replaceList(cr, list, with)) return;
                    Thread.sleep(1000);
                    if (!replaceList(cr, with, without)) return;
                    Thread.sleep(1000);
                    if (!replaceList(cr, without, with)) return;
                    Settings.Secure.putInt(cr, Settings.Secure.ACCESSIBILITY_ENABLED, 1);
                } catch (RuntimeException | InterruptedException e) {
                    Log.w(TAG, "Couldn't put the service back: " + e);
                }
            }, "ServiceRepair").start();
        } catch (RuntimeException e) {
            Log.w(TAG, "Couldn't check the service: " + e);
        }
    }

    private static boolean replaceList(ContentResolver cr, String expected, String updated) {
        String now = Settings.Secure.getString(cr, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES);
        return Objects.equals(now == null ? "" : now, expected == null ? "" : expected)
                && Settings.Secure.putString(cr, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES, updated);
    }

    private static SharedPreferences prefs(Context c) {
        return c.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
    }
}
