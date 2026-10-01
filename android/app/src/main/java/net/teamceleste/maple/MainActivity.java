package net.teamceleste.maple;

import android.app.Activity;
import android.app.AlertDialog;
import android.os.Bundle;
import android.content.SharedPreferences;
import android.net.Uri;
import android.view.KeyEvent;
import android.view.View;
import android.view.inputmethod.EditorInfo;
import android.webkit.WebChromeClient;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.Set;

public class MainActivity extends Activity {
    private final ArrayList<WebView> tabs = new ArrayList<>();
    private final ArrayList<Boolean> privateTabs = new ArrayList<>();
    private SharedPreferences prefs;
    private EditText address;
    private LinearLayout container;
    private int active = 0;

    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        prefs = getSharedPreferences("maple_preferences", MODE_PRIVATE);

        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        LinearLayout top = new LinearLayout(this);
        top.setOrientation(LinearLayout.HORIZONTAL);

        address = new EditText(this);
        address.setSingleLine(true);
        address.setHint("Search or enter website");
        address.setImeOptions(EditorInfo.IME_ACTION_GO);

        Button menu = button("☰");
        Button tabsButton = button("▢");
        top.addView(address, new LinearLayout.LayoutParams(0, -2, 1));
        top.addView(tabsButton, new LinearLayout.LayoutParams(48, -2));
        top.addView(menu, new LinearLayout.LayoutParams(48, -2));

        container = new LinearLayout(this);
        container.setOrientation(LinearLayout.VERTICAL);
        root.addView(top);
        root.addView(container, new LinearLayout.LayoutParams(-1, 0, 1));
        setContentView(root);

        address.setOnEditorActionListener((v, actionId, event) -> {
            if (actionId == EditorInfo.IME_ACTION_GO ||
                (event != null && event.getKeyCode() == KeyEvent.KEYCODE_ENTER)) {
                loadInput(address.getText().toString()); return true;
            }
            return false;
        });
        tabsButton.setOnClickListener(v -> showTabs());
        menu.setOnClickListener(v -> showMenu());
        addTab(false, "https://www.google.com");
    }

    private Button button(String text) {
        Button b = new Button(this);
        b.setText(text);
        b.setAllCaps(false);
        return b;
    }

    private void addTab(boolean privateMode, String url) {
        WebView w = new WebView(this);
        WebSettings s = w.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);
        s.setBuiltInZoomControls(false);
        s.setSupportZoom(false);
        w.setWebViewClient(new WebViewClient() {
            @Override public void onPageFinished(WebView view, String url) {
                address.setText(url);
                if (!privateMode) addHistory(view.getTitle(), url);
            }
        });
        w.setWebChromeClient(new WebChromeClient());
        tabs.add(w);
        privateTabs.add(privateMode);
        active = tabs.size() - 1;
        showActive();
        w.loadUrl(url);
    }

    private void showActive() {
        container.removeAllViews();
        container.addView(tabs.get(active), new LinearLayout.LayoutParams(-1, 0, 1));
        address.setText(tabs.get(active).getUrl());
    }

    private void switchTab(int i) {
        if (i >= 0 && i < tabs.size()) { active = i; showActive(); }
    }

    private void loadInput(String input) {
        String text = input.trim();
        if (text.isEmpty()) return;
        String url;
        if (text.contains("://")) url = text;
        else if (text.contains(".") && !text.contains(" ")) url = "https://" + text;
        else url = "https://www.google.com/search?q=" + Uri.encode(text);
        tabs.get(active).loadUrl(url);
    }

    private void addHistory(String title, String url) {
        Set<String> old = prefs.getStringSet("history", new HashSet<>());
        Set<String> next = new HashSet<>(old);
        next.add((title == null ? url : title) + "\t" + url);
        prefs.edit().putStringSet("history", next).apply();
    }

    private void addBookmark() {
        String url = tabs.get(active).getUrl();
        if (url == null) return;
        Set<String> old = prefs.getStringSet("bookmarks", new HashSet<>());
        Set<String> next = new HashSet<>(old);
        next.add(tabs.get(active).getTitle() + "\t" + url);
        prefs.edit().putStringSet("bookmarks", next).apply();
    }

    private void showTabs() {
        String[] items = new String[tabs.size() + 2];
        for (int i = 0; i < tabs.size(); i++) items[i] = (i + 1) + ". " + (tabs.get(i).getTitle() == null ? "New Tab" : tabs.get(i).getTitle());
        items[tabs.size()] = "New Tab";
        items[tabs.size() + 1] = "New Private Tab";
        new AlertDialog.Builder(this).setTitle("Tabs (" + tabs.size() + ")")
            .setItems(items, (d, which) -> {
                if (which < tabs.size()) switchTab(which);
                else addTab(which == tabs.size() + 1, "https://www.google.com");
            }).setNegativeButton("Cancel", null).show();
    }

    private void showMenu() {
        new AlertDialog.Builder(this).setTitle("Maple Browser")
            .setItems(new String[]{"Add Bookmark", "Bookmarks", "History", "Settings"}, (d, which) -> {
                if (which == 0) addBookmark();
                else if (which == 1) showSaved("Bookmarks", "bookmarks");
                else if (which == 2) showSaved("History", "history");
                else showSettings();
            }).show();
    }

    private void showSaved(String title, String key) {
        Set<String> values = prefs.getStringSet(key, new HashSet<>());
        String[] items = values.toArray(new String[0]);
        new AlertDialog.Builder(this).setTitle(title).setItems(items, (d, which) -> {
            String[] parts = items[which].split("\\t", 2);
            if (parts.length == 2) tabs.get(active).loadUrl(parts[1]);
        }).setNegativeButton("Close", null).show();
    }

    private void showSettings() {
        new AlertDialog.Builder(this).setTitle("Settings")
            .setItems(new String[]{"Clear History", "Clear Bookmarks", "Clear Web Data"}, (d, which) -> {
                if (which == 0) prefs.edit().remove("history").apply();
                else if (which == 1) prefs.edit().remove("bookmarks").apply();
                else for (WebView w : tabs) w.clearCache(true);
            }).show();
    }

    @Override public void onBackPressed() {
        if (tabs.get(active).canGoBack()) tabs.get(active).goBack();
        else super.onBackPressed();
    }
}
