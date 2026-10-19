import time
import tkinter as tk

class Timer:
    def __init__(self, root):
        self.root = root
        self.running = False
        self.start_time = 0.0
        self.elapsed = 0.0

        root.title("计时")
        root.attributes("-topmost", True)   # 窗口始终置顶
        root.resizable(False, False)

        self.label = tk.Label(root, text="00:00", font=("Consolas", 48, "bold"),
                              fg="white", bg="black", padx=20, pady=10, cursor="hand2")
        self.label.pack()

        self.label.bind("<Button-1>", self.toggle)   # 左键：开始 / 暂停
        self.label.bind("<Button-3>", self.reset)    # 右键：归零
        root.bind("<Escape>", lambda e: root.destroy())  # Esc：退出

        self.update()

    def toggle(self, event=None):
        if self.running:
            self.elapsed += time.monotonic() - self.start_time
            self.running = False
            self.label.config(fg="gray")
        else:
            self.start_time = time.monotonic()
            self.running = True
            self.label.config(fg="white")

    def reset(self, event=None):
        self.running = False
        self.elapsed = 0.0
        self.label.config(fg="white")

    def update(self):
        total = self.elapsed
        if self.running:
            total += time.monotonic() - self.start_time
        secs = int(total)
        self.label.config(text=f"{secs // 60:02d}:{secs % 60:02d}")
        self.root.after(200, self.update)

root = tk.Tk()
Timer(root)
root.mainloop()
