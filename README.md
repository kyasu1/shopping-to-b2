# ヤマト運輸B2 CSV変換ツール

Yahoo!ショッピングの注文CSV（`order.csv`）を、ヤマト運輸のB2クラウドシステムに取り込み可能なCSV形式に変換するためのWebアプリケーションです。

## 主な機能

- **Webインターフェース**: ブラウザ上でCSVの変換、編集、ダウンロードが完結します。
- **ファイル対応**: Yahoo!ショッピングからダウンロードした元の `order.csv` (CP932)と、このツールで出力したUTF-8形式のCSVファイルの両方を読み込めます。
- **データ編集**: お客様管理番号、お届け先情報、品名など、主要なフィールドを画面上で直接編集できます。
- **一括編集**: 「出荷予定日」をカレンダーから選択し、すべての注文に一括で適用できます。
- **入力補助**: 「送り状種類」「配達時間帯」「荷扱い」などのフィールドは、ドロップダウンやコンボボックスから簡単に入力できます。
- **UTF-8出力**: 最終的なCSVファイルは、文字化けしにくく、Excelでも扱いやすいUTF-8形式でダウンロードされます。

## 設定

ご依頼主情報や請求先顧客コードなどの設定は、環境変数で行います。
プロジェクトのルートディレクトリに `.env` ファイルを作成し、必要な情報を記述してください。

1.  まず、`.env.example` ファイルをコピーして `.env` ファイルを作成します。
    ```bash
    cp .env.example .env
    ```

2.  `.env` ファイルをテキストエディタで開き、各項目にご自身の情報を設定します。
    ```dotenv
    # Flaskのセッション情報を暗号化するための秘密鍵（必須）
    # 例: openssl rand -hex 16 などで生成したランダムな文字列
    SECRET_KEY=

    # ご依頼主情報
    SENDER_PHONE=
    SENDER_ZIP=
    SENDER_ADDRESS=
    SENDER_NAME=

    # ヤマトB2クラウド用の設定
    BILLING_CUSTOMER_CODE=
    FREIGHT_MANAGEMENT_NUMBER=
    DEFAULT_ITEM_NAME=
    ```
    **注意:** `SECRET_KEY` は必ず設定してください。設定しない場合、アプリケーションは起動しません。

---

## セットアップと実行方法

このアプリケーションは、ローカル環境で直接実行する方法と、Dockerを使用して実行する方法の2通りがあります。

### 1. ローカル環境での実行

**前提条件:**
- Python 3.8以上

**手順:**
1.  `.env` ファイルを準備します（[設定](#設定)セクションを参照）。
2.  必要なPythonライブラリをインストールします。
    ```bash
    pip install -r requirements.txt
    ```
3.  Webアプリケーションを起動します。
    ```bash
    python app.py
    ```
4.  Webブラウザで以下のURLにアクセスします。
    [http://127.0.0.1:5001](http://127.0.0.1:5001)

### 2. Dockerを使用した実行

**前提条件:**
- Docker
- Docker Compose

**手順:**
1.  `.env` ファイルを準備します（[設定](#設定)セクションを参照）。
2.  レジストリからイメージを取得し、コンテナを起動します。
    ```bash
    docker-compose pull
    docker-compose up -d
    ```

3.  Webブラウザで以下のURLにアクセスします。
    [http://127.0.0.1:5001](http://127.0.0.1:5001)

4.  アプリケーションを停止するには、以下のコマンドを実行します。
    ```bash
    docker-compose down
    ```

---

## 開発者向け情報

### Dockerイメージのビルドとプッシュ

このプロジェクトは、プライベートDockerレジストリ (`registry.tera.officeiko.co.jp`) を使用しています。

**前提条件:**
- Node.js（package.jsonのバージョン情報を読み取るため）
- Dockerレジストリへのログイン: `docker login registry.tera.officeiko.co.jp`

**イメージのビルドとプッシュ:**
```bash
npm run docker:build-push
```

このコマンドは以下を実行します：
1. `package.json` からバージョン番号を読み取り
2. x86（linux/amd64）プラットフォーム向けにDockerイメージをビルド
3. `registry.tera.officeiko.co.jp/shopping-to-b2:<version>` と `latest` タグでプッシュ

**ローカルでのビルド（開発用）:**
```bash
npm run docker:build
```

**バージョン更新の手順:**
1. `package.json` の `version` フィールドを更新（例: "1.0.0" → "1.0.1"）
2. `npm run docker:build-push` を実行
3. デプロイ環境で `docker-compose pull && docker-compose up -d` を実行

### アーキテクチャ

- **フロントエンド**: Elm + Vite + Tailwind CSS + DaisyUI
- **バックエンド**: Python (Flask)
- **ビルド**: マルチステージDockerビルド（Node.js → Python）
- **デプロイ**: Docker Compose + Traefik（リバースプロキシ）
