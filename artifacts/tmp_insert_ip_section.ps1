$ErrorActionPreference = 'Stop'
$path = 'C:\project\FPGA\master_paper\thesis_completed_draft_v11.docx'
$word = New-Object -ComObject Word.Application
$word.Visible = $false
$doc = $word.Documents.Open($path)

function Add-Paragraph($sel, $text, $style) {
    $sel.Range.Style = $style
    $sel.TypeText($text)
    $sel.TypeParagraph()
}

function Add-Table($doc, $sel, $headers, $rows) {
    $table = $doc.Tables.Add($sel.Range, $rows.Count + 1, $headers.Count)
    $table.Borders.Enable = 1
    for($c=1; $c -le $headers.Count; $c++) {
        $table.Cell(1, $c).Range.Text = [string]$headers[$c-1]
    }
    for($r=1; $r -le $rows.Count; $r++) {
        for($c=1; $c -le $headers.Count; $c++) {
            $table.Cell($r + 1, $c).Range.Text = [string]$rows[$r-1][$c-1]
        }
    }
    $sel.SetRange($table.Range.End, $table.Range.End)
    $sel.TypeParagraph()
}

$h2Style = $doc.Paragraphs.Item(506).Range.Style
$h3Style = $doc.Paragraphs.Item(507).Range.Style
$bodyStyle = $doc.Paragraphs.Item(508).Range.Style
$captionStyle = $doc.Paragraphs.Item(531).Range.Style

$doc.Paragraphs.Item(506).Range.Text = "AES-GCM-256 IP 介紹與介面規格`r"
$doc.Paragraphs.Item(531).Range.Text = "表 3.4　AES-GCM-256 packet-profile 板級驗證結果總表`r"

$sel = $word.Selection
$sel.SetRange($doc.Paragraphs.Item(507).Range.Start, $doc.Paragraphs.Item(507).Range.Start)

Add-Paragraph $sel 'AES-GCM-256 IP 整體介紹' $h3Style
Add-Paragraph $sel '本研究所實作之 AES-GCM-256 核心 IP，係一個可同時支援認證加密與認證解密之頂層運算模組。其核心介面採用共享位元組輸入通道與共享位元組輸出通道之設計方式，透過模式控制訊號、資料類型標示訊號與有效位元數欄位，依序接收初始化向量、金鑰、附加認證資料、明文、密文與認證碼等輸入欄位，並輸出密文、明文或認證碼等結果。此種設計可在不增加大量平行腳位的前提下，保留對多種輸入欄位與 partial block 情境之支援，亦有利於後續板級包裝層與主機端傳輸協定之整合。' $bodyStyle
Add-Paragraph $sel '由內部功能而言，本研究之 AES-GCM-256 IP 可分為四個主要部分：其一為輸入收集模組，負責依照資料類型將初始化向量、附加認證資料與資料區塊整理為後續運算所需格式；其二為 AES 運算模組，負責雜湊子金鑰計算與計數器模式所需之區塊運算；其三為 GHASH 運算模組，負責對附加認證資料、密文（或解密驗證路徑中的資料）與長度區塊進行有限域累積運算；其四為狀態控制邏輯，負責協調雜湊子金鑰產生、J0 準備、資料區塊處理、認證碼產生與解密認證判定等流程。' $bodyStyle
Add-Paragraph $sel '本研究之核心 IP 於加密模式下，先完成雜湊子金鑰與初始計數器相關準備，再依序產生密文與認證碼；於解密模式下，則根據輸入之密文與認證碼完成資料還原與認證判定。由於核心 IP 本身聚焦於 AES-GCM 運算流程，因此其外部介面仍屬演算法層級之抽象資料介面，尚未直接包含實體板上時脈管理、按鍵重置、UART 收發與狀態顯示等功能。此部分則由 FPGA 板級包裝層負責。' $bodyStyle
Add-Paragraph $sel '相較於參考論文以模組介面規格方式說明 AES-GCM IP 與子模組，本研究亦採相同之章節安排方式介紹整體核心與子模組介面；惟在實際實作上，本研究之核心 IP 並非以大量獨立平行輸入腳位直接分別接收所有欄位，而是採共享位元組串流輸入與共享輸出通道架構，以配合後續板級主機通訊流程與封包化驗證方式。故其介面型態與文獻中部分示範型硬體介面不完全相同，應以本研究實際 RTL 設計為準。' $bodyStyle

Add-Paragraph $sel 'AES-GCM-256 核心 IP 腳位功能定義' $h3Style
Add-Paragraph $sel '表 3.1　AES-GCM-256 核心 IP 腳位功能定義' $captionStyle
$headers = @('腳位名稱','I/O','位元寬度','功能說明')
$rows = @(
    @('clk','I','1','核心系統時脈輸入。'),
    @('rst','I','1','核心重置訊號。'),
    @('mode','I','1','模式選擇訊號；0 表示認證加密，1 表示認證解密。'),
    @('in','I','8','共享資料輸入通道，以位元組為單位輸入欄位資料。'),
    @('in_valid','I','1','輸入資料有效訊號。'),
    @('in_type','I','3','輸入資料類型標示；0=IV、1=KEY、2=AAD、3=PT、4=CT、5=TAG。'),
    @('in_valid_bit','I','11','目前輸入欄位之有效位元數，用於長度記錄與 partial block / partial byte 處理。'),
    @('last','I','1','目前輸入欄位是否為該類型最後一筆資料之指示訊號。'),
    @('pc_ct_valid','O','1','輸出資料有效訊號，用於表示密文或明文輸出有效。'),
    @('tag_valid','O','1','認證碼輸出有效訊號，或於解密流程中作為認證結果有效指示。'),
    @('pc_ct_len_bit','O','11','輸出之密文或明文總有效位元數。'),
    @('pc_ct_valid_bit','O','4','目前輸出位元組之有效位元數，用於最後一個 partial byte 表示。'),
    @('out','O','8','共享輸出通道，以位元組為單位輸出密文、明文或認證碼。')
)
Add-Table $doc $sel $headers $rows
Add-Paragraph $sel '本研究之 AES-GCM-256 核心 IP 採用位元組串流式輸入與共享輸出通道架構，以降低外部介面複雜度，並配合模式控制、資料類型標示與有效位元數資訊，支援初始化向量、金鑰、附加認證資料、明文、密文與認證碼等多種欄位輸入。' $bodyStyle

Add-Paragraph $sel 'FPGA 板級包裝層與 UART 介面規格' $h3Style
Add-Paragraph $sel '表 3.2　FPGA 板級包裝層腳位功能定義' $captionStyle
$rows = @(
    @('clk','I','1','FPGA 板級參考時脈輸入。'),
    @('rst_btn','I','1','板級重置按鈕輸入，供系統初始化與板級操作使用。'),
    @('uart_txd_in','I','1','由主機傳入 FPGA 之 UART 接收訊號。'),
    @('uart_rxd_out','O','1','FPGA 回傳主機之 UART 傳送訊號。'),
    @('led','O','4','板級狀態顯示訊號，用於顯示系統活動或驗證狀態。')
)
Add-Table $doc $sel $headers $rows
Add-Paragraph $sel '為配合 Arty A7-100T 板級驗證，本研究於核心 IP 外部加入板級包裝層，負責 UART 主機通訊、時脈與重置管理，以及驗證期間之狀態顯示。此包裝層並非演算法核心本體，而是為了支援板級 bring-up 與 packet-profile practical validation 所建立之系統整合介面。' $bodyStyle

Add-Paragraph $sel 'GHASH 子模組介面規格' $h3Style
Add-Paragraph $sel '表 3.3　GHASH 子模組腳位功能定義' $captionStyle
$rows = @(
    @('clk','I','1','GHASH 子模組系統時脈。'),
    @('rst_n','I','1','低有效重置訊號。'),
    @('init','I','1','GHASH 累積值初始化控制訊號。'),
    @('GHASH_block','I','128','待吸收之 128-bit 資料區塊。'),
    @('GHASH_en','I','1','啟動 GHASH 區塊更新之有效訊號。'),
    @('H','I','128','GHASH 雜湊子金鑰輸入。'),
    @('H_done','I','1','雜湊子金鑰已可用之指示訊號。'),
    @('busy','O','1','GHASH 子模組目前運算中。'),
    @('done','O','1','單一 128-bit 區塊運算完成。'),
    @('Y','O','128','GHASH 累積輸出值。')
)
Add-Table $doc $sel $headers $rows
Add-Paragraph $sel '本研究之 GHASH 子模組採逐區塊、循序式運算方式，於每次 GHASH_en 有效時吸收一個 128-bit 區塊，並更新累積值 Y。相較於強調平行化或深度管線化之架構，本研究實作較重視與整體控制流程之整合性與可驗證性，因此其介面設計亦較偏向控制簡潔之 sequential block update 方式。' $bodyStyle

Add-Paragraph $sel '核心 IP 與板級包裝層差異說明' $h3Style
Add-Paragraph $sel '本研究之核心 IP 與板級包裝層在功能定位上明確不同。核心 IP 主要負責 AES-GCM 演算法本體之執行，其工作範圍包括資料欄位收集、雜湊子金鑰產生、計數器模式資料處理、GHASH 累積運算、認證碼產生，以及解密端之認證判定；換言之，核心 IP 關注的是給定輸入欄位後，如何完成 AES-GCM 認證加解密。' $bodyStyle
Add-Paragraph $sel '相對地，板級包裝層則屬於系統整合層，其主要功能並非重新實作 AES-GCM，而是將主機端 UART 收到之命令與資料欄位轉換為核心 IP 可接受之共享輸入格式，並將核心 IP 的輸出結果重新封裝為主機端可辨識之回傳格式。此外，板級包裝層亦負責板上時脈管理、重置控制與 LED 狀態顯示等功能。因此，若將核心 IP 視為演算法引擎，則板級包裝層即為連接 FPGA 板級資源與外部主機通訊之介面橋接層。' $bodyStyle

$doc.TablesOfContents.Item(1).Update()
$doc.Save()
$doc.Close()
$word.Quit()
