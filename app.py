
import csv
import datetime
import io
import os
import uuid
from flask import Flask, request, jsonify, render_template, session, send_file

app = Flask(__name__)
app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY')
app.config['UPLOAD_FOLDER'] = 'uploads'

# --- 固定情報 ---
SENDER_INFO = {
    "phone": os.environ.get("SENDER_PHONE"),
    "zip": os.environ.get("SENDER_ZIP"),
    "address": os.environ.get("SENDER_ADDRESS"),
    "name": os.environ.get("SENDER_NAME"),
}
BILLING_CUSTOMER_CODE = os.environ.get("BILLING_CUSTOMER_CODE")
FREIGHT_MANAGEMENT_NUMBER = os.environ.get("FREIGHT_MANAGEMENT_NUMBER")
DEFAULT_ITEM_NAME = os.environ.get("DEFAULT_ITEM_NAME")

# ドロップダウンの選択肢
DROPDOWN_OPTIONS = {
    "送り状種類": [
        {"value": "0", "text": "0 : 発払い"},
        {"value": "8", "text": "8 : 宅急便コンパクト"},
        {"value": "A", "text": "A : ネコポス"},
    ],
    "配達時間帯": [
        {"value": "", "text": "指定なし"},
        {"value": "0812", "text": "0812 : 午前中"},
        {"value": "1416", "text": "1416 : 14～16時"},
        {"value": "1618", "text": "1618 : 16～18時"},
        {"value": "1820", "text": "1820 : 18～20時"},
        {"value": "1921", "text": "1921 : 19～21時"},
    ],
    "荷扱い１": [
        {"value": "", "text": "（空白）"},
        {"value": "精密機器", "text": "精密機器"},
        {"value": "ワレ物注意", "text": "ワレ物注意"},
        {"value": "下積現金", "text": "下積現金"},
        {"value": "天地無用", "text": "天地無用"},
        {"value": "ナマモノ", "text": "ナマモノ"},
        {"value": "水濡厳禁", "text": "水濡厳禁"},
    ],
    "荷扱い２": [
        {"value": "", "text": "（空白）"},
        {"value": "精密機器", "text": "精密機器"},
        {"value": "ワレ物注意", "text": "ワレ物注意"},
        {"value": "下積現金", "text": "下積現金"},
        {"value": "天地無用", "text": "天地無用"},
        {"value": "ナマモノ", "text": "ナマモノ"},
        {"value": "水濡厳禁", "text": "水濡厳禁"},
    ]
}
# ---

def get_delivery_time_code(time_str):
    time_mapping = {
        "09:00-12:00": "0812", "0812": "0812", "午前中": "0812",
        "14:00-16:00": "1416", "1416": "1416",
        "16:00-18:00": "1618", "1618": "1618",
        "18:00-20:00": "1820", "1820": "1820",
        "19:00-21:00": "1921", "1921": "1921",
    }
    return time_mapping.get(time_str, "")

def get_template_headers(filename="yahoo_template.csv"):
    try:
        with open(filename, "r", encoding="utf-8") as f:
            reader = csv.reader(f)
            raw_headers = next(reader)
            return [h.splitlines()[0] for h in raw_headers]
    except FileNotFoundError:
        return None

def process_csv_stream(infile, headers):
    """CSVストリームを処理し、構造化されたデータとヘッダーを返す"""
    processed_data = []
    try:
        reader = csv.DictReader(infile)
        fieldnames = reader.fieldnames
        if not fieldnames:
            raise ValueError("CSVファイルにヘッダーがありません。")

        lower_fieldnames = [name.lower() for name in fieldnames]

        file_format = None
        if "order id" in lower_fieldnames:
            file_format = "yahoo"
        elif "お客様管理番号" in fieldnames:
            file_format = "b2"
        else:
            raise ValueError("認識できないCSVフォーマットです。ヘッダーを確認してください。")

        for row in reader:
            output_row = {h: "" for h in headers}
            if file_format == "b2":
                for header in headers:
                    output_row[header] = row.get(header, "")
            else: # "yahoo" format
                output_row["お客様管理番号"] = row.get("Order ID", "")
                output_row["送り状種類"] = "0"
                output_row["出荷予定日"] = datetime.date.today().strftime("%Y/%m/%d")
                output_row["配達時間帯"] = get_delivery_time_code(row.get("Shipping Req Time", ""))
                output_row["お届け先郵便番号"] = row.get("Ship Zip", "").replace("-", "")
                output_row["お届け先住所"] = f"{row.get('Ship State', '')}{row.get('Ship City', '')}{row.get('Ship Address 1', '')}"
                output_row["お届け先アパートマンション名"] = row.get("Ship Address 2", "")
                output_row["お届け先名"] = row.get("Ship Name", "")
                output_row["お届け先電話番号"] = "".join(filter(str.isdigit, row.get("Ship Phone", "")))
                output_row["ご依頼主郵便番号"] = SENDER_INFO["zip"]
                output_row["ご依頼主住所"] = SENDER_INFO["address"]
                output_row["ご依頼主名"] = SENDER_INFO["name"]
                output_row["ご依頼主電話番号"] = SENDER_INFO["phone"]
                output_row["品名１"] = DEFAULT_ITEM_NAME
                output_row["請求先顧客コード"] = BILLING_CUSTOMER_CODE
                output_row["運賃管理番号"] = FREIGHT_MANAGEMENT_NUMBER

            output_row['__id'] = str(uuid.uuid4())
            processed_data.append(output_row)
        
        return processed_data, headers

    except UnicodeDecodeError:
        raise  # エンコーディングエラーは再送出して、次のエンコーディングを試させる
    except Exception as e:
        raise ValueError(f"CSVストリームの処理中にエラーが発生しました: {e}")


def process_uploaded_csv(filepath):
    """Uploaded CSV fileを処理し、構造化されたデータとヘッダーを返す"""
    headers = get_template_headers()
    if not headers:
        raise ValueError("テンプレートファイル 'yahoo_template.csv' が見つからないか、読み込めません。")

    encodings_to_try = ['utf-8-sig', 'utf-8', 'cp932']
    last_error = None

    for encoding in encodings_to_try:
        try:
            errors_mode = 'replace' if encoding == 'cp932' else 'strict'
            with open(filepath, "r", encoding=encoding, errors=errors_mode) as infile:
                return process_csv_stream(infile, headers)
        except UnicodeDecodeError as e:
            last_error = e
            continue
        except Exception as e:
            raise ValueError(f"ファイルの処理中に予期せぬエラーが発生しました ({encoding}): {e}")

    raise ValueError(f"サポートされているエンコーディングでファイルを読み込めませんでした: {last_error}")


@app.route('/', methods=['GET'])
def index():
    """メインページを表示"""
    return render_template('index.html')

@app.route('/upload', methods=['POST'])
def upload_file():
    """CSVファイルをアップロードして処理し、JSONで返す"""
    if 'file' not in request.files:
        return jsonify({"error": "ファイルがありません"}), 400
    file = request.files['file']
    if file.filename == '':
        return jsonify({"error": "ファイルが選択されていません"}), 400
    if file and file.filename.endswith('.csv'):
        try:
            filepath = os.path.join(app.config['UPLOAD_FOLDER'], file.filename)
            file.save(filepath)
            
            data, headers = process_uploaded_csv(filepath)
            
            return jsonify({"data": data, "headers": headers})
        except Exception as e:
            return jsonify({"error": str(e)}), 500
    return jsonify({"error": "無効なファイル形式です"}), 400

@app.route('/save', methods=['POST'])
def save_file():
    """編集されたデータをCSVとして保存・ダウンロード"""
    json_data = request.get_json()
    if not json_data:
        return jsonify({"error": "データがありません"}), 400

    edited_data = json_data.get('data')
    headers = json_data.get('headers')

    if not edited_data or not headers:
        return jsonify({"error": "リクエストにデータまたはヘッダーが含まれていません"}), 400

    # メモリ内でCSVファイルを作成
    output = io.StringIO()
    writer = csv.DictWriter(output, fieldnames=headers, extrasaction='ignore')
    writer.writeheader()
    for row in edited_data:
        writer.writerow(row)

    # UTF-8 BOM付きでエンコード
    output_utf8_sig = output.getvalue().encode('utf-8-sig')

    # ダウンロード用のレスポンスを作成
    mem_file = io.BytesIO(output_utf8_sig)
    
    filename = f"yamato_output_{datetime.datetime.now().strftime('%Y%m%d%H%M%S')}.csv"
    
    return send_file(
        mem_file,
        as_attachment=True,
        download_name=filename,
        mimetype='text/csv'
    )

if __name__ == '__main__':
    if not os.path.exists(app.config['UPLOAD_FOLDER']):
        os.makedirs(app.config['UPLOAD_FOLDER'])
    app.run(host='0.0.0.0', debug=True, port=5001)

