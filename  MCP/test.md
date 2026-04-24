# 検証フェーズ ディレクトリ構成案
workspace/
├── .kiro/
│   ├── steering/
│   │   ├── coding-standards.md       # ← 既存をそのまま配置
│   │   ├── terraform-rules.md        # ← 既存をそのまま配置
│   │   └── spec-structure-rules.md   # ← 新規（Specフォルダ命名規則）
│   │
│   ├── specs/
│   │   └── aws/
│   │       └── ec2-rds-hub/          # 今回の検証対象
│   │           ├── requirements.md   # Kiro自動生成
│   │           ├── design.md         # Kiro自動生成
│   │           └── tasks.md          # Kiro自動生成
│   │
│   └── skills/
│       ├── terraform-patterns/
│       │   ├── terraform.md          # ← 既存をそのまま配置
│       │   └── references/
│       │       └── module-catalog.md # ← AWS-module-catalog.md をリネーム
│       │
│       └── design-doc/
│           ├── design-doc.md         # 設計書生成手順
│           └── references/
│               ├── design-template.md # ← IaC_EC2-RDS_〜.md から抽出
│               └── images-template.png # ← EC2_architecture.drawio.png
│
├── Eng-repos/
│   └── AWSRepos/                     # git clone先（Skills経由で最新化）
│       └── [既存Terraformモジュール群]
│
└── inputs/                           # ★案件インプット置き場
    └── ec2-rds-hub/                  # 案件名フォルダで管理
        ├── qa-table.md               # ← QA票.md をそのまま
        ├── qa-table.xlsx             # ← QA票.xlsx をそのまま
        ├── parameter-sheet.md        # ← パラメーターシート.md
        ├── parameter-sheet.xlsx      # ← パラメーターシート.xlsx
        └── progress.xlsx             # ← Input進捗.xlsx

---

## 検証の進め方イメージ

