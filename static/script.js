
document.addEventListener('DOMContentLoaded', async () => {
    const uploadForm = document.getElementById('upload-form');
    const fileInput = document.getElementById('file-input');
    const table = document.getElementById('data-table');
    const tableHead = document.getElementById('table-head');
    const tableBody = document.getElementById('table-body');
    const loading = document.getElementById('loading');
    const errorMessage = document.getElementById('error-message');
    const editorControls = document.getElementById('editor-controls');
    const saveBtn = document.getElementById('save-btn');
    const batchShipDateInput = document.getElementById('batch-ship-date');
    const batchApplyBtn = document.getElementById('batch-apply-btn');

        const EDITABLE_FIELDS = [
            "出荷予定日", "送り状種類", "お届け先電話番号", "お届け予定日", "配達時間帯",
            "お届け先郵便番号", "お届け先住所", "お届け先アパートマンション名",
            "お届け先会社・部門１", "お届け先会社・部門２", "お届け先名",
            "品名１", "荷扱い１", "荷扱い２"
        ];
    
            const VISIBLE_UI_FIELDS = [
    
                'お客様管理番号', '出荷予定日', '送り状種類', 'お届け先名', '品名１', 'お届け予定日', '配達時間帯',
    
                'お届け先電話番号', 'お届け先郵便番号', 'お届け先住所', 'お届け先アパートマンション名',
    
                'お届け先会社・部門１', 'お届け先会社・部門２',
    
                '荷扱い１', '荷扱い２'
    
            ];
    
        let allHeaders = [];
        let originalData = [];
        let dropdownOptions = {};
    
        try {
            const response = await fetch('/options');
            if (!response.ok) throw new Error('選択肢の取得に失敗しました。');
            dropdownOptions = await response.json();
        } catch (error) {
            showError(error.message);
        }
    
        uploadForm.addEventListener('submit', async (e) => {
            e.preventDefault();
            const formData = new FormData();
            formData.append('file', fileInput.files[0]);
            showLoading(true);
            showError('');
            try {
                const response = await fetch('/upload', { method: 'POST', body: formData });
                const result = await response.json();
                if (!response.ok) throw new Error(result.error || 'サーバーエラー');
                
                allHeaders = result.headers;
                originalData = result.data; // 元データを保存
                renderTable(result.data, result.headers);
                editorControls.classList.remove('hidden');
            } catch (error) {
                showError(`エラー: ${error.message}`);
            } finally {
                showLoading(false);
            }
        });
        
            function renderTable(data, headers) {
        
                const visibleHeaders = VISIBLE_UI_FIELDS.filter(h => headers.includes(h));
        
        
        
                tableHead.innerHTML = '';
        
                let headerRow = '<tr>';
        
                visibleHeaders.forEach(header => {
        
                    headerRow += `<th>${escapeHtml(header)}</th>`;
        
                });
        
                headerRow += '</tr>';
        
                tableHead.innerHTML = headerRow;
        
        
        
                tableBody.innerHTML = '';
        
                data.forEach(row => {
        
                    const tr = document.createElement('tr');
        
                    tr.dataset.id = row['__id'];
        
                    
        
                    visibleHeaders.forEach(header => {
        
                        const td = document.createElement('td');
        
                        const value = row[header] || '';
        
                        
        
                                        if (EDITABLE_FIELDS.includes(header)) {
        
                        
        
                                            if (header === '出荷予定日' || header === 'お届け予定日') {
        
                        
        
                                                const input = document.createElement('input');
        
                        
        
                                                input.type = 'date';
        
                        
        
                                                if (value) {
        
                        
        
                                                    input.value = value.replace(/\//g, '-');
        
                        
        
                                                }
        
                        
        
                                                input.dataset.field = header;
        
                        
        
                                                td.appendChild(input);
        
                        
        
                                            } else if (dropdownOptions[header]) {
        
                        
        
                                                if (header === "荷扱い１" || header === "荷扱い２") {
        
                        
        
                                                    const input = document.createElement('input');
        
                        
        
                                                    input.type = 'text';
        
                        
        
                                                    input.value = value;
        
                        
        
                                                    input.dataset.field = header;
        
                        
        
                                                    const datalistId = `datalist-${header}`;
        
                        
        
                                                    input.setAttribute('list', datalistId);
        
                        
        
                                                    let originalValueOnFocus = value;
        
                        
        
                                                    input.addEventListener('focus', function() {
        
                        
        
                                                        originalValueOnFocus = this.value;
        
                        
        
                                                        this.value = '';
        
                        
        
                                                    });
        
                        
        
                                                    input.addEventListener('blur', function() {
        
                        
        
                                                        if (this.value === '') {
        
                        
        
                                                            this.value = originalValueOnFocus;
        
                        
        
                                                        }
        
                        
        
                                                    });
        
                        
        
                                                    input.addEventListener('change', function() {
        
                        
        
                                                        originalValueOnFocus = this.value;
        
                        
        
                                                    });
        
                        
        
                                                    td.appendChild(input);
        
                        
        
                                                    const datalist = document.createElement('datalist');
        
                        
        
                                                    datalist.id = datalistId;
        
                        
        
                                                    (dropdownOptions[header] || []).forEach(opt => {
        
                        
        
                                                        const option = document.createElement('option');
        
                        
        
                                                        option.value = opt.text;
        
                        
        
                                                        datalist.appendChild(option);
        
                        
        
                                                    });
        
                        
        
                                                    td.appendChild(datalist);
        
                        
        
                                                } else {
        
                        
        
                                                    const select = document.createElement('select');
        
                        
        
                                                    select.dataset.field = header;
        
                        
        
                                                    (dropdownOptions[header] || []).forEach(opt => {
        
                        
        
                                                        const option = document.createElement('option');
        
                        
        
                                                        option.value = opt.value;
        
                        
        
                                                        option.textContent = opt.text;
        
                        
        
                                                        select.appendChild(option);
        
                        
        
                                                    });
        
                        
        
                                                    select.value = value;
        
                        
        
                                                    td.appendChild(select);
        
                        
        
                                                }
        
                        
        
                                            } else {
        
                        
        
                                                const input = document.createElement('input');
        
                        
        
                                                input.type = 'text';
        
                        
        
                                                input.value = value;
        
                        
        
                                                input.dataset.field = header;
        
                        
        
                                                td.appendChild(input);
        
                        
        
                                            }
        
                        
        
                                        } else {
        
                        
        
                                            td.textContent = value;
        
                        
        
                                        }
        
                        tr.appendChild(td);
        
                    });
        
                    tableBody.appendChild(tr);
        
                });
        
                table.classList.remove('hidden');
        
            }
    
        batchApplyBtn.addEventListener('click', () => {
            const newDateValue = batchShipDateInput.value;
            if (!newDateValue) {
                alert('日付を選択してください。');
                return;
            }
            const formattedDate = newDateValue.replace(/-/g, '/');
            tableBody.querySelectorAll('input[data-field="出荷予定日"]').forEach(input => {
                input.value = formattedDate;
            });
        });
    
            saveBtn.addEventListener('click', async () => {
                const tableData = getTableData();
                if (tableData.length === 0) {
                    alert('保存するデータがありません。');
                    return;
                }
        
                showLoading(true);
                showError('');
                try {
                    const response = await fetch('/save', {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({ data: tableData, headers: allHeaders }),
                    });
        
                    if (!response.ok) {
                         const result = await response.json();
                        throw new Error(result.error || 'サーバーエラー');
                    }    
                const blob = await response.blob();
                const downloadUrl = window.URL.createObjectURL(blob);
                const a = document.createElement('a');
                a.href = downloadUrl;
                
                const contentDisposition = response.headers.get('Content-Disposition');
                let filename = "yamato_output.csv";
                if (contentDisposition) {
                    const filenameMatch = contentDisposition.match(/filename="?(.+)"?/);
                    if (filenameMatch.length > 1) filename = filenameMatch[1];
                }
                a.download = filename;
                
                document.body.appendChild(a);
                a.click();
                a.remove();
                window.URL.revokeObjectURL(downloadUrl);
            } catch (error) {
                showError(`保存エラー: ${error.message}`);
            } finally {
                showLoading(false);
            }
        });
    
            function getTableData() {
                const updatedData = JSON.parse(JSON.stringify(originalData));
                const visibleAndEditableHeaders = allHeaders.filter(h => VISIBLE_UI_FIELDS.includes(h) && EDITABLE_FIELDS.includes(h));
        
                tableBody.querySelectorAll('tr').forEach(tr => {
                    const rowId = tr.dataset.id;
                    const dataRow = updatedData.find(d => d.__id === rowId);
                    if (!dataRow) return;
        
                    visibleAndEditableHeaders.forEach(header => {
                        const element = tr.querySelector(`input[data-field="${header}"], select[data-field="${header}"]`);
                        if (element) {
                            if (element.type === 'date' && element.value) {
                                dataRow[header] = element.value.replace(/-/g, '/'); // YYYY-MM-DD -> YYYY/MM/DD
                            } else {
                                dataRow[header] = element.value;
                            }
                        }
                    });
                });
                return updatedData;
            }    function showLoading(isLoading) {
        loading.classList.toggle('hidden', !isLoading);
    }

    function showError(message) {
        errorMessage.textContent = message;
        errorMessage.classList.toggle('hidden', !message);
    }
    
    function escapeHtml(unsafe) {
        return unsafe.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;").replace(/'/g, "&#039;");
     }
});
