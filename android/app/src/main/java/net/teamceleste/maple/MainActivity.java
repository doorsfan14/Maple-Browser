package net.teamceleste.maple;

import android.app.Activity;
import android.os.Bundle;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.LinearLayout;
import android.widget.EditText;
import android.view.KeyEvent;
import android.view.inputmethod.EditorInfo;
import android.graphics.Color;

public class MainActivity extends Activity {
    private WebView webView;
    private EditText address;

    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
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
                String text = address.getText().toString().trim();
                if (!text.isEmpty()) {
                    String url = text.contains("://") ? text :
                        (text.contains(".") && !text.contains(" ") ? "https://" + text :
                        "https://www.google.com/search?q=" + android.net.Uri.encode(text));
                    webView.loadUrl(url);
                }
                return true;
            }
            return false;
        });

        root.addView(address, new LinearLayout.LayoutParams(-1, -2));
        root.addView(webView, new LinearLayout.LayoutParams(-1, 0, 1));
        setContentView(root);
        webView.loadUrl("https://www.google.com");
    }

    @Override public void onBackPressed() {
        if (webView.canGoBack()) webView.goBack();
        else super.onBackPressed();
    }
}
