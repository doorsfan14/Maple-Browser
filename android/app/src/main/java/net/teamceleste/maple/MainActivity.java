package net.teamceleste.maple;

import android.app.Activity;
import android.os.Bundle;
import android.content.SharedPreferences;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.LinearLayout;
import android.widget.EditText;
import android.view.KeyEvent;
import android.view.inputmethod.EditorInfo;
import android.app.AlertDialog;

public class MainActivity extends Activity {
    private WebView webView;
    private EditText address;
    private SharedPreferences preferences;

    @Override public void onCreate(Bundle state) {
        super.onCreate(state);

        preferences = getSharedPreferences("maple_preferences", MODE_PRIVATE);

        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);

        address = new EditText(this);
        address.setSingleLine(true);
        address.setHint("Search or enter website");
        address.setImeOptions(EditorInfo.IME_ACTION_GO);

        webView = new WebView(this);
        webView.setWebViewClient(new WebViewClient());
        webView.getSettings().setJavaScriptEnabled(true);
        webView.getSettings().setDomStorageEnabled(true);

        address.setOnEditorActionListener((v, actionId, event) -> {
            if (actionId == EditorInfo.IME_ACTION_GO ||
                (event != null && event.getKeyCode() == KeyEvent.KEYCODE_ENTER)) {
                loadInput(address.getText().toString());
                return true;
            }
            return false;
        });

        root.addView(address, new LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ));
        root.addView(webView, new LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            0,
            1
        ));

        setContentView(root);
        webView.loadUrl("https://www.google.com");

        if (!preferences.getBoolean("did_show_celeste_account_prompt", false)) {
            preferences.edit().putBoolean("did_show_celeste_account_prompt", true).apply();
            new AlertDialog.Builder(this)
                .setTitle("Wanna connect your Celeste Account?")
                .setPositiveButton("Yes", (dialog, which) -> showLocalDataMessage())
                .setNegativeButton("No", null)
                .show();
        }
    }

    private void showLocalDataMessage() {
        new AlertDialog.Builder(this)
            .setTitle("Just kidding, dude.")
            .setMessage("No need to connect accounts if you're gonna use this rarely lol, plus it's better if your data stays local rather than your save data (eg: browser history) stays on a server, enjoy the browser!")
            .setPositiveButton("Enjoy Maple", null)
            .show();
    }

    private void loadInput(String input) {
        String text = input.trim();
        if (text.isEmpty()) return;

        String url;
        if (text.contains("://")) {
            url = text;
        } else if (text.contains(".") && !text.contains(" ")) {
            url = "https://" + text;
        } else {
            url = "https://www.google.com/search?q=" +
                android.net.Uri.encode(text);
        }

        webView.loadUrl(url);
    }

    @Override public void onBackPressed() {
        if (webView.canGoBack()) webView.goBack();
        else super.onBackPressed();
    }
}
