package net.teamceleste.maple;

import android.app.Activity;
import android.app.AlertDialog;
import android.graphics.Color;
import android.graphics.drawable.GradientDrawable;
import android.os.Bundle;
import android.net.Uri;
import android.view.Gravity;
import android.view.KeyEvent;
import android.view.View;
import android.view.inputmethod.EditorInfo;
import android.webkit.JavascriptInterface;
import android.webkit.WebChromeClient;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.TextView;
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
        buildUI();
        addTab(false, null);
    }

    private void buildUI() {
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setBackgroundColor(Color.WHITE);

        LinearLayout top = new LinearLayout(this);
        top.setGravity(Gravity.CENTER_VERTICAL);
        top.setPadding(10, 8, 10, 5);

        address = new EditText(this);
        address.setSingleLine(true);
        address.setHint("Search or enter website");
        address.setImeOptions(EditorInfo.IME_ACTION_GO);
        address.setTextSize(16);
        address.setPadding(16, 0, 16, 0);
        GradientDrawable pill = new GradientDrawable();
        pill.setColor(0xFFF1F3F5);
        pill.setCornerRadius(50);
        address.setBackground(pill);

        Button tabsButton = button("▢");
        Button menu = button("⋯");
        top.addView(address, new LinearLayout.LayoutParams(0, 46, 1));
        top.addView(tabsButton, new LinearLayout.LayoutParams(48, 46));
        top.addView(menu, new LinearLayout.LayoutParams(48, 46));

        container = new LinearLayout(this);
        container.setOrientation(LinearLayout.VERTICAL);

        LinearLayout bottom = new LinearLayout(this);
        bottom.setGravity(Gravity.CENTER);
        bottom.setPadding(16, 3, 16, 5);
        Button back = button("‹");
        Button forward = button("›");
        Button home = button("⌂");
        Button plus = button("＋");
        Button more = button("☰");
        bottom.addView(back, new LinearLayout.LayoutParams(0, 48, 1));
        bottom.addView(forward, new LinearLayout.LayoutParams(0, 48, 1));
        bottom.addView(home, new LinearLayout.LayoutParams(0, 48, 1));
        bottom.addView(plus, new LinearLayout.LayoutParams(0, 48, 1));
        bottom.addView(more, new LinearLayout.LayoutParams(0, 48, 1));

        root.addView(top);
        root.addView(container, new LinearLayout.LayoutParams(-1, 0, 1));
        root.addView(bottom);

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
        back.setOnClickListener(v -> { if (tabs.get(active).canGoBack()) tabs.get(active).goBack(); });
        forward.setOnClickListener(v -> { if (tabs.get(active).canGoForward()) tabs.get(active).goForward(); });
        home.setOnClickListener(v -> showHome());
        plus.setOnClickListener(v -> addTab(false, null));
        more.setOnClickListener(v -> showMenu());
    }

    private Button button(String text) {
        Button b = new Button(this);
        b.setText(text);
        b.setTextSize(20);
        b.setAllCaps(false);
        b.setBackgroundColor(Color.TRANSPARENT);
        return b;
    }

    private void addTab(boolean privateMode, String url) {
        WebView w = new WebView(this);
        WebSettings s = w.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);
        s.setBuiltInZoomControls(false);
        s.setSupportZoom(false);
        w.addJavascriptInterface(new HomeBridge(), "Maple");
        w.setWebViewClient(new WebViewClient() {
            @Override public void onPageFinished(WebView view, String pageUrl) {
                if (!pageUrl.startsWith("file:///maple-home")) {
                    address.setText(pageUrl);
                    if (!privateMode) addHistory(view.getTitle(), pageUrl);
                }
            }
        });
        w.setWebChromeClient(new WebChromeClient());
        tabs.add(w);
        privateTabs.add(privateMode);
        active = tabs.size() - 1;
        showActive();
        if (url == null) showHome(); else w.loadUrl(url);
    }

    private void showActive() {
        container.removeAllViews();
        container.addView(tabs.get(active), new LinearLayout.LayoutParams(-1, -1));
        String url = tabs.get(active).getUrl();
        address.setText(url != null && !url.startsWith("file:///maple-home") ? url : "");
    }

    private void showHome() {
        tabs.get(active).loadDataWithBaseURL("file:///maple-home/", homeHTML(), "text/html", "UTF-8", null);
        address.setText("");
    }

    private String homeHTML() {
        return "<!doctype html><html><head><meta name='viewport' content='width=device-width,initial-scale=1'>"
        + "<style>*{box-sizing:border-box}html,body{margin:0;width:100%;height:100%;font-family:sans-serif;color:white}"
        + "body{display:flex;align-items:center;justify-content:center;overflow:hidden;background:linear-gradient(145deg,#0b1728,#163b45 50%,#6b3f2b)}"
        + ".glow{position:absolute;width:360px;height:360px;border-radius:50%;background:rgba(255,196,111,.16);filter:blur(45px);top:-100px;right:-80px}"
        + ".leaf{position:absolute;font-size:170px;opacity:.07;bottom:-35px;left:-20px;transform:rotate(-18deg)}"
        + ".card{position:relative;width:88%;max-width:560px;text-align:center}.mark{font-size:56px}"
        + ".title{font-size:36px;font-weight:bold;letter-spacing:-1px}.sub{font-size:15px;opacity:.68;margin:8px 0 25px}"
        + "form{display:flex;background:rgba(255,255,255,.14);border:1px solid rgba(255,255,255,.2);border-radius:18px;padding:5px}"
        + "input{width:100%;background:transparent;border:0;outline:0;color:white;font-size:17px;padding:13px}"
        + "input::placeholder{color:rgba(255,255,255,.65)}</style></head><body>"
        + "<div class='glow'></div><div class='leaf'>🍁</div><main class='card'>"
        + "<div class='mark'>🍁</div><div class='title'>Maple Browser</div>"
        + "<div class='sub'>A simple, fast place to browse.</div><form onsubmit='event.preventDefault();Maple.search(this.q.value)'>"
        + "<input name='q' autocomplete='off' placeholder='Search or enter a website'></form></main></body></html>";
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

    private class HomeBridge {
        @JavascriptInterface public void search(String query) {
            runOnUiThread(() -> loadInput(query));
        }
    }

    private void addHistory(String title, String url) {
        if (url == null || url.startsWith("file:")) return;
        Set<String> old = prefs.getStringSet("history", new HashSet<>());
        Set<String> next = new HashSet<>(old);
        next.add((title == null ? url : title) + "\t" + url);
        prefs.edit().putStringSet("history", next).apply();
    }

    private void addBookmark() {
        String url = tabs.get(active).getUrl();
        if (url == null || url.startsWith("file:")) return;
        Set<String> old = prefs.getStringSet("bookmarks", new HashSet<>());
        Set<String> next = new HashSet<>(old);
        next.add((tabs.get(active).getTitle() == null ? url : tabs.get(active).getTitle()) + "\t" + url);
        prefs.edit().putStringSet("bookmarks", next).apply();
    }

    private void showTabs() {
        String[] items = new String[tabs.size() + 2];
        for (int i = 0; i < tabs.size(); i++)
            items[i] = (i + 1) + ". " + (tabs.get(i).getTitle() == null ? "New Tab" : tabs.get(i).getTitle());
        items[tabs.size()] = "New Tab";
        items[tabs.size() + 1] = "New Private Tab";
        new AlertDialog.Builder(this).setTitle("Tabs (" + tabs.size() + ")")
            .setItems(items, (d, which) -> {
                if (which < tabs.size()) { active = which; showActive(); }
                else addTab(which == tabs.size() + 1, null);
            }).setNegativeButton("Cancel", null).show();
    }

    private void showMenu() {
        new AlertDialog.Builder(this).setTitle("Maple Browser")
            .setItems(new String[]{"Reload", "Add Bookmark", "Bookmarks", "History", "Settings"}, (d, which) -> {
                if (which == 0) tabs.get(active).reload();
                else if (which == 1) addBookmark();
                else if (which == 2) showSaved("Bookmarks", "bookmarks");
                else if (which == 3) showSaved("History", "history");
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
