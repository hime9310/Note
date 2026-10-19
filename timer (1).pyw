import time
import tkinter as tk

# 透明モードで「透明」として扱う色（この色の部分がくり抜かれる）
TRANSPARENT_KEY = "#010101"

# 背景テーマの設定（背景色・文字色・一時停止中の文字色）
THEMES = {
    "黒":   {"bg": "black",         "fg": "white", "paused": "gray"},
    "白":   {"bg": "white",         "fg": "black", "paused": "#aaaaaa"},
    "透明": {"bg": TRANSPARENT_KEY, "fg": "white", "paused": "#bbbbbb"},
}


class Stopwatch:
    def __init__(self, root):
        self.root = root
        self.running = False      # 計測中かどうか
        self.start_time = 0.0     # 計測を開始（再開）した時刻
        self.elapsed = 0.0        # 一時停止までに累積した経過時間（秒）
        self.theme = tk.StringVar(value="黒")

        # ウィンドウ設定：枠なし・常に最前面・初期位置
        root.overrideredirect(True)
        root.attributes("-topmost", True)
        root.geometry("+60+60")

        # 経過時間を表示するラベル
        self.label = tk.Label(root, text="00:00", font=("Consolas", 48, "bold"),
                              padx=20, pady=10, cursor="hand2")
        self.label.pack()

        # 右クリックメニューの作成
        self.menu = tk.Menu(root, tearoff=0)
        self.menu.add_command(label="開始", command=self.toggle)    # 0番目：開始／一時停止／再開
        self.menu.add_command(label="リセット", command=self.reset)
        self.menu.add_separator()
        bg_menu = tk.Menu(self.menu, tearoff=0)
        for name in THEMES:
            bg_menu.add_radiobutton(label=name, variable=self.theme, value=name,
                                    command=self.apply_theme)
        self.menu.add_cascade(label="背景", menu=bg_menu)
        self.menu.add_separator()
        self.menu.add_command(label="終了", command=root.destroy)

        # マウス操作：左クリックで開始／一時停止、ドラッグで移動、右クリックでメニュー
        self.label.bind("<ButtonPress-1>", self.on_press)
        self.label.bind("<B1-Motion>", self.on_drag)
        self.label.bind("<ButtonRelease-1>", self.on_release)
        self.label.bind("<Button-3>", self.show_menu)

        # キーボード操作：スペースで開始／一時停止、Rでリセット、Escで終了
        root.bind("<space>", lambda e: self.toggle())
        root.bind("<r>", lambda e: self.reset())
        root.bind("<Escape>", lambda e: root.destroy())

        self.apply_theme()
        self.update()

    # ---------- 計測の操作 ----------
    def toggle(self):
        """開始・一時停止・再開を切り替える"""
        if self.running:
            # 一時停止：ここまでの時間を累積に加える
            self.elapsed += time.monotonic() - self.start_time
            self.running = False
        else:
            # 開始または再開
            self.start_time = time.monotonic()
            self.running = True
        self.refresh_state()

    def reset(self):
        """停止して 00:00 に戻す"""
        self.running = False
        self.elapsed = 0.0
        self.refresh_state()

    def refresh_state(self):
        """文字色とメニュー表示を現在の状態に合わせる"""
        t = THEMES[self.theme.get()]
        paused = not self.running and self.elapsed > 0
        self.label.config(fg=t["paused"] if paused else t["fg"])
        if self.running:
            text = "一時停止"
        elif self.elapsed > 0:
            text = "再開"
        else:
            text = "開始"
        self.menu.entryconfig(0, label=text)

    # ---------- 見た目 ----------
    def apply_theme(self):
        """選択された背景テーマを適用する"""
        t = THEMES[self.theme.get()]
        self.root.config(bg=t["bg"])
        self.label.config(bg=t["bg"])
        # 透明モードのときだけ指定色をくり抜く
        self.root.attributes("-transparentcolor",
                             TRANSPARENT_KEY if self.theme.get() == "透明" else "")
        self.refresh_state()

    def update(self):
        """0.2秒ごとに表示を更新する"""
        total = self.elapsed
        if self.running:
            total += time.monotonic() - self.start_time
        secs = int(total)
        self.label.config(text=f"{secs // 60:02d}:{secs % 60:02d}")
        self.root.after(200, self.update)

    # ---------- マウス操作 ----------
    def on_press(self, event):
        # 押した位置を記録（クリックかドラッグかを後で判定する）
        self.press_x, self.press_y = event.x_root, event.y_root
        self.win_x, self.win_y = self.root.winfo_x(), self.root.winfo_y()
        self.dragged = False

    def on_drag(self, event):
        dx = event.x_root - self.press_x
        dy = event.y_root - self.press_y
        # 少しでも動いたらドラッグとみなしてウィンドウを移動
        if abs(dx) > 3 or abs(dy) > 3:
            self.dragged = True
        if self.dragged:
            self.root.geometry(f"+{self.win_x + dx}+{self.win_y + dy}")

    def on_release(self, event):
        # ドラッグしていなければクリックとして開始／一時停止
        if not self.dragged:
            self.toggle()

    def show_menu(self, event):
        self.menu.tk_popup(event.x_root, event.y_root)


root = tk.Tk()
Stopwatch(root)
root.mainloop()
