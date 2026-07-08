#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
run_generate_code_terraform_checks.py — generate-code 後の Terraform 後処理パイプライン

処理内容:
  0. .gitignore     : code/ 直下に .gitignore を 1 つだけ配置する
                      （テンプレート: .kiro/hooks/templates/code.gitignore。
                        既存の場合は不足行のみ末尾へ追記・冪等）
  1. terraform-docs : code/{env}/ (環境ルート = Kiro が生成した成果物本体) に
                      README.md を自動生成し、実際に書き込まれたことを検証する
                      ※ --include-modules 指定時は code/modules/ 配下も対象に追加
  2. terraform fmt  : code/ 全体を再帰整形
  3. init/validate  : 各環境ルートで terraform init -backend=false → terraform validate

対象の決定:
  --path で code/ ディレクトリを明示指定。省略時は Outputs/{cloud}/{project}/code/
  のうち .tf の最終更新が最も新しいものを自動検出する。

終了コード: 0 = 全ステップ成功 / 1 = いずれか失敗
前提: Python 3.9+ / terraform (必須) / terraform-docs (任意・無ければスキップ)
"""
import argparse
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

# .kiro/hooks/scripts/run_generate_code_terraform_checks.py → リポジトリルート
REPO_ROOT = Path(__file__).resolve().parents[3]
OUTPUTS = REPO_ROOT / "Outputs"
# code/ 直下で「環境フォルダ」とみなさないディレクトリ
SKIP_DIRS = {"modules", ".terraform", "certs", "shell_script"}

# .gitignore テンプレート（除外内容の正。変更はテンプレート側で行う）
GITIGNORE_TEMPLATE = REPO_ROOT / ".kiro" / "hooks" / "templates" / "code.gitignore"

DOCS_BEGIN = "<!-- BEGIN_TF_DOCS -->"
DOCS_END = "<!-- END_TF_DOCS -->"
DOCS_MARKER = f"{DOCS_BEGIN}\n{DOCS_END}\n"


def log(msg: str) -> None:
    print(msg, flush=True)


def run(cmd, cwd, timeout=600):
    """コマンドを実行し (成功bool, 結合出力) を返す。"""
    try:
        r = subprocess.run(
            cmd, cwd=str(cwd), capture_output=True, text=True,
            encoding="utf-8", errors="replace", timeout=timeout,
        )
        out = ((r.stdout or "") + (r.stderr or "")).strip()
        return r.returncode == 0, out
    except FileNotFoundError:
        return False, f"コマンドが見つかりません: {cmd[0]}"
    except subprocess.TimeoutExpired:
        return False, f"タイムアウト({timeout}s): {' '.join(map(str, cmd))}"


def find_latest_code_dir():
    """Outputs/{cloud}/{project}/code/ のうち .tf の最終更新が最新のものを返す。"""
    candidates = []
    if not OUTPUTS.exists():
        return None
    for code_dir in OUTPUTS.glob("*/*/code"):
        tf_files = list(code_dir.rglob("*.tf"))
        if tf_files:
            latest = max(f.stat().st_mtime for f in tf_files)
            candidates.append((latest, code_dir))
    if not candidates:
        return None
    candidates.sort(key=lambda t: t[0], reverse=True)
    return candidates[0][1]


def iter_env_dirs(code_dir: Path):
    """code/ 直下で main.tf を持つフォルダ（=環境ルート）を列挙する。"""
    for p in sorted(code_dir.iterdir()):
        if p.is_dir() and p.name not in SKIP_DIRS and (p / "main.tf").exists():
            yield p


# ---------------------------------------------------------------------------
# ステップ 0: .gitignore 配置（code/ 直下に 1 つだけ・冪等）
# ---------------------------------------------------------------------------

def step_gitignore(code_dir: Path, results: list) -> bool:
    """code/ 直下に .gitignore を 1 つだけ配置する。

    - 存在しない場合: テンプレートから新規作成
    - 存在する場合  : テンプレートの実効行（コメント・空行以外）のうち
                      不足しているものだけを末尾へ追記（人手の編集は壊さない）
    - すべて揃っている場合: 何もしない
    """
    if not GITIGNORE_TEMPLATE.exists():
        results.append(("NG", ".gitignore",
                        f"テンプレートがありません: {GITIGNORE_TEMPLATE}"))
        return False

    tmpl_lines = GITIGNORE_TEMPLATE.read_text(
        encoding="utf-8", errors="replace").splitlines()
    target = code_dir / ".gitignore"

    if not target.exists():
        target.write_text("\n".join(tmpl_lines) + "\n", encoding="utf-8")
        results.append(("OK", ".gitignore",
                        f"新規作成（code/ 直下・{len(tmpl_lines)} 行）"))
        return True

    have = {l.strip() for l in target.read_text(
        encoding="utf-8", errors="replace").splitlines() if l.strip()}
    missing = [l for l in tmpl_lines
               if l.strip()
               and not l.strip().startswith("#")
               and l.strip() not in have]

    if not missing:
        results.append(("OK", ".gitignore", "変更なし（必要行はすべて存在）"))
        return True

    with target.open("a", encoding="utf-8") as f:
        f.write("\n# ----- hook により追記 -----\n" + "\n".join(missing) + "\n")
    results.append(("OK", ".gitignore", f"{len(missing)} 行を追記"))
    return True


# ---------------------------------------------------------------------------
# ステップ 1: terraform-docs
# ---------------------------------------------------------------------------

def _docs_written(readme: Path) -> bool:
    """マーカー間に実コンテンツが書き込まれたかを検証する。"""
    if not readme.exists():
        return False
    text = readme.read_text(encoding="utf-8", errors="replace")
    m = re.search(re.escape(DOCS_BEGIN) + r"(.*?)" + re.escape(DOCS_END),
                  text, flags=re.DOTALL)
    if not m:
        # マーカーなし = terraform-docs が全文出力した等。空でなければ良しとする
        return bool(text.strip())
    return bool(m.group(1).strip())


def _gen_docs_for(target: Path, label: str, tdocs: str, results: list) -> bool:
    """1 ディレクトリに terraform-docs を実行し、書き込みまで検証する。"""
    readme = target / "README.md"
    if not readme.exists():
        # inject モード用のマーカー入り README を先に用意
        readme.write_text(DOCS_MARKER, encoding="utf-8")
    ok, out = run(
        [tdocs, "markdown", "table",
         "--output-file", "README.md", "--output-mode", "inject", "."],
        cwd=target,
    )
    if ok and not _docs_written(readme):
        ok = False
        out = ("terraform-docs は正常終了しましたが README.md に内容が"
               "書き込まれていません（マーカー間が空）。terraform-docs の"
               "バージョン・実行ディレクトリを確認してください。")
    results.append(("OK" if ok else "NG",
                    f"terraform-docs: {label}",
                    "README.md 生成/更新" if ok else out))
    return ok


def step_terraform_docs(code_dir: Path, results: list,
                        include_modules: bool = False) -> bool:
    """環境ルート(code/{env}/)に成果物 README を生成する。"""
    tdocs = shutil.which("terraform-docs")
    if not tdocs:
        results.append(("SKIP", "terraform-docs",
                        "未インストールのためスキップ（任意ツール）"))
        return True

    envs = list(iter_env_dirs(code_dir))
    if not envs:
        results.append(("NG", "terraform-docs",
                        "main.tf を持つ環境フォルダが code/ 直下に見つかりません"))
        return False

    ok_all = True
    # ① 環境ルート（成果物本体）: stg/ prd/ など
    for env in envs:
        ok_all &= _gen_docs_for(env, env.name, tdocs, results)

    # ② オプション: modules/ 配下（--include-modules 指定時のみ）
    if include_modules:
        modules_dir = code_dir / "modules"
        if modules_dir.exists():
            for mod in sorted(p for p in modules_dir.iterdir() if p.is_dir()):
                if list(mod.glob("*.tf")):
                    ok_all &= _gen_docs_for(
                        mod, f"modules/{mod.name}", tdocs, results)
    return ok_all


# ---------------------------------------------------------------------------
# ステップ 2: terraform fmt
# ---------------------------------------------------------------------------

def step_fmt(code_dir: Path, results: list) -> bool:
    ok, out = run(["terraform", "fmt", "-recursive"], cwd=code_dir)
    detail = (out or "整形対象なし") if ok else out
    results.append(("OK" if ok else "NG", "terraform fmt -recursive", detail))
    return ok


# ---------------------------------------------------------------------------
# ステップ 3: terraform init / validate
# ---------------------------------------------------------------------------

def step_init_validate(code_dir: Path, results: list) -> bool:
    envs = list(iter_env_dirs(code_dir))
    if not envs:
        results.append(("NG", "init/validate",
                        "main.tf を持つ環境フォルダが code/ 直下に見つかりません"))
        return False

    ok_all = True
    for env in envs:
        ok_i, out_i = run(
            ["terraform", "init", "-backend=false", "-input=false", "-no-color"],
            cwd=env,
        )
        results.append(("OK" if ok_i else "NG",
                        f"terraform init -backend=false ({env.name})",
                        "" if ok_i else out_i))
        if not ok_i:
            ok_all = False
            continue  # init 失敗時は validate をスキップ
        ok_v, out_v = run(["terraform", "validate", "-no-color"], cwd=env)
        results.append(("OK" if ok_v else "NG",
                        f"terraform validate ({env.name})", out_v))
        ok_all &= ok_v
    return ok_all


# ---------------------------------------------------------------------------
# エントリポイント
# ---------------------------------------------------------------------------

def main() -> int:
    ap = argparse.ArgumentParser(
        description="generate-code 後の Terraform 後処理パイプライン (v2)")
    ap.add_argument(
        "--path",
        help="対象の code/ ディレクトリ（省略時は Outputs/ 配下で最新更新の code/ を自動検出）")
    ap.add_argument(
        "--include-modules", action="store_true",
        help="code/modules/ 配下の各モジュールにも README を生成する（既定: 環境ルートのみ）")
    args = ap.parse_args()

    code_dir = Path(args.path).resolve() if args.path else find_latest_code_dir()
    if not code_dir or not code_dir.exists():
        log("❌ 対象の code/ ディレクトリが見つかりません。--path で指定してください。")
        return 1
    if not shutil.which("terraform"):
        log("❌ terraform コマンドが見つかりません。PATH を確認してください。")
        return 1

    try:
        shown = code_dir.relative_to(REPO_ROOT)
    except ValueError:
        shown = code_dir
    log("=" * 62)
    log(f"対象: {shown}")
    log("=" * 62)

    results: list = []
    t0 = time.time()
    ok = step_gitignore(code_dir, results)
    ok = step_terraform_docs(code_dir, results,
                             include_modules=args.include_modules) and ok
    ok = step_fmt(code_dir, results) and ok
    ok = step_init_validate(code_dir, results) and ok

    log("")
    log("----- 実行結果サマリ -----")
    icon = {"OK": "✅", "NG": "❌", "SKIP": "⏭️ "}
    for status, name, detail in results:
        log(f"{icon[status]} {name}")
        if detail and status == "NG":
            log("    " + detail.replace("\n", "\n    "))
    log("-" * 26)
    verdict = "成功 ✅" if ok else "失敗 ❌（上記 NG を修正して再実行してください）"
    log(f"所要: {time.time() - t0:.1f}s / 判定: {verdict}")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
