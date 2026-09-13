# CORA 使用說明書

Combinational Regularity Analysis（組合規律性分析）R 套件

---

## 目次

**正文**

1. [這個套件解決什麼問題](#1-這個套件解決什麼問題)——理論背景、INUS 結構、與 QCA / CNA 的關係
2. [輸入：資料要長什麼樣子](#2-輸入資料要長什麼樣子)——格式、編碼規則、結果欄的三種寫法
3. [分析流程：五個階段](#3-分析流程五個階段)——真值表 → 最小化 → 圖表 → Petrick → 統計量
4. [輸出怎麼讀](#4-輸出怎麼讀)——記號法、敘述式、**拿到結果之後該怎麼解讀（§4.4）**
5. [完整範例](#5-完整範例)——四種分析情境，以及**邏輯圖怎麼讀（§5.5）**
6. [函數速查表](#6-函數速查表)
7. [參數選擇與常見陷阱](#7-參數選擇與常見陷阱)——`n_cut`、`inc_score1`、**0 起始編碼（§7.4）**
8. [與 Python 版的差異](#8-與-python-版的差異)
9. [引用與授權](#9-引用與授權)

**附錄**

- [附錄 A：Python 版的六個缺陷](#附錄-apython-版的六個缺陷)——每一條都附原始碼位置與可重現的例子
- [附錄 B：QCA、QCApro、cna 怎麼做](#附錄-bqcaqcaprocna-怎麼做)——三個相鄰套件的設計比較，以及本套件的選擇依據
- [附錄 C：內建資料集沒有變項定義](#附錄-c內建資料集沒有變項定義)
- [附錄 D：作者、引用與責任](#附錄-d作者引用與責任)

> 只想趕快跑起來：看 §5.1，再看 §4.4。
> 要寫進論文：§4.4 第五步列出了必須交代的六件事。
> 要跟 Python 版對照：附錄 A。

---

## 1. 這個套件解決什麼問題

### 1.1 迴歸回答不了的問題

多數量化方法問的是「**每個變數平均而言貢獻多少**」。迴歸係數把每個條件的效果拆開來獨立估計，隱含假設是條件之間可以加總。

但很多社會科學與醫學的因果結構不是這樣。它們長成這個樣子：

> 結果會發生，是因為「A 出現**且** B 不出現**且** C 出現」，**或者**「D 出現**且** E 出現」。

在這種結構裡，單獨問「A 的效果是多少」沒有意義——A 只有在 B 不出現且 C 出現時才起作用。這叫做**組態因果**（configurational causation），特徵是兩種：

- **連言性（conjunctivity）**：多個條件必須同時滿足才構成一個原因。
- **選言性（disjunctivity）**：達成同一個結果可以有好幾條互不相同的路徑。

CORA 就是為了辨識這類結構而設計的。

### 1.2 INUS 結構

哲學上這叫 **INUS 條件**（Mackie 1965）：

> **I**nsufficient but **N**ecessary part of an **U**nnecessary but **S**ufficient condition
> （某個本身不充分、但為某個不必要卻充分的條件之必要部分）

拆開看，以 `A*b*C + D*E => Y` 為例：

| 詞 | 對應 | 說明 |
|---|---|---|
| **I**nsufficient | `A` 單獨不足以造成 `Y` | A 自己不夠 |
| **N**ecessary part | `A` 是 `A*b*C` 這條路徑中不可少的一環 | 拿掉 A，這條路徑就不成立 |
| **U**nnecessary | `A*b*C` 不是 `Y` 的唯一路徑 | 還有 `D*E` |
| **S**ufficient | `A*b*C` 成立就足以造成 `Y` | 這條路徑自己夠了 |

CORA 的輸出就是這種形式的式子。

### 1.3 跟 QCA、CNA 的關係

CORA 屬於**組態比較法**（Configurational Comparative Methods, CCM）家族，跟 QCA（Ragin 1987）與 CNA（Baumgartner 2009）是同一類方法，都在找 INUS 結構。

差別在於出發點。QCA 源自集合論與質性比較，CNA 源自因果推論的規律理論，而 **CORA 源自開關電路分析**——電機工程裡處理布林邏輯電路的一支。

這個選擇不是巧合。命題邏輯（INUS 因果的語言）和開關代數（電路的語言）是同一個布林代數的兩個分支，運算上等價。最早的布林最佳化演算法之一——Quine-McCluskey 演算法——正是由一位分析哲學家（Quine）和一位電機工程師（McCluskey）各自獨立提出的。

**CORA 相對於 QCA / CNA 的獨特能力：**

1. **複雜效果（complex effects）**：CORA 是目前唯一能同時分析「簡單效果」與「複雜效果」的 CCM。所謂複雜效果，是指結果本身就是多個結果變數的組合（例如「`y` 且非 `z`」、「`y` 且 `z`」）。
2. **多值條件**：條件不限於 0/1，可以是 0/1/2/…（Mkrtchyan et al. 2023）。
3. **組態式資料探勘**：列舉所有 n 個條件的組合，找出最少用幾個條件就能得到解——組態版本的奧坎剃刀。
4. **邏輯圖（LOGIGRAM）**：把解畫成兩層邏輯圖。相較於 QCA 常用的 Venn 圖，邏輯圖在表達與可讀性上表現更好（Thiem et al. 2023）。

---

## 2. 輸入：資料要長什麼樣子

### 2.1 基本格式

一個 data frame，**一列一個案例**：

| 欄位類型 | 說明 | 必要 |
|---|---|---|
| 條件欄（conditions） | 自變數，整數編碼 | 是 |
| 結果欄（outcomes） | 依變數，一個或多個 | 是 |
| 案例欄（case column） | 案例識別標籤 | 否 |

```r
df <- data.frame(
  A   = c(1, 0, 1, 0),
  B   = c(1, 0, 0, 1),
  C   = c(0, 1, 1, 0),
  OUT = c(1, 1, 0, 1)
)
```

### 2.2 編碼規則（重要）

**條件必須是從 0 開始的非負整數。**

- 二元條件：`0` = 不存在／低，`1` = 存在／高
- 多值條件：`0`, `1`, `2`, …

不接受小數、`NA`、或字串。**常數欄位會被拒絕**——一個所有案例都相同的條件不帶任何區辨資訊。

**「從 0 開始、中間不跳號」是硬性要求，不符合會直接報錯。** 一個編碼成 `{1, 2}` 而非 `{0, 1}` 的條件會讓 `"ON-OFF"` 演算法算出錯誤結果（見 §7.4），所以套件拒絕計算並告訴你怎麼修：

```
Condition(s) 'B' are not coded from 0 upwards. CORA expects each condition
to take the values 0, 1, 2, ... with no gaps.
  Recode them with:  data <- cora_recode(data, c("B"))
```

照著做就好：

```r
df <- cora_recode(df, c("B"))   # 或 cora_recode(df) 讓它自己找出該改的欄
```

`cora_recode()` 把每個條件映射到 `0, 1, 2, ...`，**保持值的順序**，結果欄完全不動。

最常見的來源是 `as.integer(factor(...))`——R 的 factor 內部從 1 起算：

```r
# 這些都會報錯
data.frame(A = c(1, 1, 1, 1), ...)   # 常數
data.frame(A = c(1, NA, 1, 0), ...)  # 缺失值
data.frame(A = c(1, 0.5, 1, 0), ...) # 小數
```

### 2.3 結果欄的三種寫法

```r
# (1) 結果已經是 0/1
cora_context(df, output_labels = "OUT")

# (2) 結果是多值，宣告哪些值算「正例」
cora_context(df, output_labels = "OUT{1,2}")   # 值為 1 或 2 → 正例

# (3) 複雜效果：多個結果欄同時分析
cora_context(df, output_labels = c("X", "M"))
cora_context(df, output_labels = c("OUT1{1,2}", "OUT2{1}"))
```

第 (2) 種寫法是 CORA 處理多值結果的機制：花括號裡列出的值會被轉成 1，其餘轉成 0。

---

## 3. 分析流程：五個階段

```
原始資料
   │
   │  ① 聚合成組態、套用門檻
   ▼
真值表 (truth table)
   │
   │  ② 布林最小化（ON-DC 或 ON-OFF）
   ▼
質蘊涵項 (prime implicants)
   │
   │  ③ 建立覆蓋矩陣
   ▼
質蘊涵項圖表 (PI chart)
   │
   │  ④ Petrick 法求解
   ▼
不可約解 (irredundant solutions)
   │
   │  ⑤ 計算充分性統計量
   ▼
coverage / inclusion
```

### 階段 ① 真值表建構

多個案例可能共享同一組條件值。這一步把它們聚合成**組態**（configuration），並決定每個組態的結果算 0 還是 1。

```r
raw <- data.frame(
  ID = as.character(1:5),
  A  = c(1, 1, 0, 1, 1),
  B  = c(0, 1, 1, 1, 0),
  C  = c(1, 1, 0, 1, 1),
  O  = c(0, 0, 1, 1, 1)
)
cora_truth_table(cora_context(raw, "O", case_col = "ID", inc_score1 = 0.5),
                 raw = TRUE)
```

```
  A B C n Cases Inc_O O
1 0 1 0 1     3   1.0 1
2 1 0 1 2   1,5   0.5 1
3 1 1 1 2   2,4   0.5 1
```

- `n`：落在這個組態的案例數
- `Cases`：是哪幾個案例
- `Inc_O`：這些案例中結果為 1 的比例（**原始 inclusion 分數**）
- `O`：套用門檻後判定的結果值

**控制這一步的四個參數：**

| 參數 | 作用 | 預設 |
|---|---|---|
| `n_cut` | 案例數低於此值的組態被視為 don't care，從真值表移除 | `1` |
| `inc_score1` | `Inc` 達到此值才判為 1 | `1` |
| `inc_score2` | 第二門檻（下界） | `NULL` |
| `U` | 決定中間帶怎麼判，必須是 0 或 1 | `NULL` |

**`inc_score2` 與 `U` 的用法**：只給 `inc_score1` 時是單一門檻。同時給 `inc_score2`（較低）和 `inc_score1`（較高）時，落在兩者之間的組態屬於「不確定帶」：

- `U = 1` → 不確定帶判為 **1**（寬鬆，納入）
- `U = 0` → 不確定帶判為 **0**（嚴格，排除）

給了 `inc_score2` 卻沒給 `U` 會報錯。

### 階段 ② 布林最小化

把真值表化簡成**質蘊涵項**（prime implicant）——無法再進一步簡化的條件組合。

```r
ctx <- cora_context(df, "OUT")
cora_prime_implicants(ctx)
#> #A{0}, C{0}, B{1}
```

**兩種演算法**（`algorithm` 參數）：

| | `"ON-DC"`（預設） | `"ON-OFF"` |
|---|---|---|
| 全名 | 正例 + don't care | 正例 + 負例 |
| 來源 | 古典 Quine-McCluskey | McCluskey 修正版 |
| 做法 | 展開完整組態空間，移除負例後化簡 | 直接拿每個正例去對比所有負例 |
| 成本 | 條件多時較慢（空間隨條件數指數成長） | 只用觀察到的列，通常較快 |

**實務建議：條件數多、或某個條件的取值多，就用 `"ON-OFF"`。** 編碼正確時兩種演算法給出相同的質蘊涵項與解——這一點在 10 組二元配對資料、多值範例，以及 40 組隨機產生的資料上都驗證過（`tests/testthat/test-properties.R`）。編碼不正確的資料會在開始計算時就被拒絕（見 §7.4），不會進到這一步。

**為什麼 ON-DC 會慢：**它要合併一個條件的**值集合的所有子集**，所以成本隨**單一條件的層級數**指數成長。實測（第一個條件 k 個層級、第二個二元）：

| 該條件的層級數 | ON-DC | ON-OFF |
|---|---|---|
| 12 | 0.16 秒 | 0.01 秒 |
| 14 | 0.85 秒 | 0.01 秒 |
| 16 | 4.0 秒 | 0.01 秒 |
| 18 | 23 秒 | 0.01 秒 |
| 30 | 跑不完 | 0.01 秒 |

每多兩個層級大約乘以 5。**兩者找到的質蘊涵項完全相同**——差別只在 ON-DC 要展開整個組態空間，ON-OFF 只用實際觀察到的列。

> Python 版也是一樣的指數成長（18 層級 5.9 秒），這是演算法本身的性質，不是移植造成的。本套件在絕對時間上約慢 4 倍。
>
> 層級數超過 30 的條件在 `"ON-DC"` 下會直接報錯（那是化簡步驟所用位元遮罩的寬度），`"ON-OFF"` 沒有這個限制。

### 階段 ③ 質蘊涵項圖表

哪個質蘊涵項涵蓋了哪些真值表列：

```r
cora_pi_chart(ctx)
#>       0 1 3
#> #A{0} 1 1 0
#> C{0}  0 1 1
#> B{1}  0 1 1
```

欄名是真值表中結果為正的列號（從 0 起算）。`#A{0}` 涵蓋第 0、1 列；`C{0}` 與 `B{1}` 各涵蓋第 1、3 列。

第 0 列只有 `#A{0}` 涵蓋 → `#A{0}` 是**必要質蘊涵項**（essential prime implicant），任何解都必須包含它。這就是 `#` 前綴的意思。

### 階段 ④ Petrick 法求解

從圖表中找出所有**不可約解**（irredundant solution）——能涵蓋全部正例、且拿掉任何一項就涵蓋不全的質蘊涵項組合。

```r
cora_irredundant_sums(ctx)
#> M1: #A{0} + C{0}
#> M2: #A{0} + B{1}
```

**兩個解都同樣有效。** 這叫**模型歧義**（model ambiguity），是組態方法的常態現象，不是錯誤——資料本身不足以在這兩個解之間做出區分。誠實的做法是兩個都報告。

> 解的數量可能隨質蘊涵項圖表的大小呈指數成長。需要時可用 `max_depth` 限制解中質蘊涵項的最大個數。

### 階段 ⑤ 充分性統計量

```r
cora_pi_details(ctx)
#>      PI Cov.r Inc.   M1   M2
#> 1 #A{0}  0.67    1 0.33 0.33
#> 2  C{0}  0.67    1 0.33   NA
#> 3  B{1}  0.67    1   NA 0.33

cora_system_details(ctx)
#>                  Cov. Inc.
#> Solution details    1    1
```

| 欄位 | 定義 |
|---|---|
| `Cov.r` | **覆蓋分數**：在所有顯示該結果的案例中，被這個質蘊涵項涵蓋的比例 |
| `Inc.` | **包含分數**：在被這個質蘊涵項涵蓋的案例中，顯示該結果的比例 |
| `M1`, `M2`, … | 在該解中，**只被這一項**涵蓋（其他項都沒涵蓋）的正案例比例 |
| `NA` | 這個質蘊涵項不在該解中 |

**怎麼解讀這兩個分數：**

- **Inclusion 高** = 這個條件組合出現時，結果幾乎總是發生 → 接近**充分條件**
- **Coverage 高** = 大部分有這個結果的案例都被它涵蓋 → 解釋力強，接近**必要條件**

兩者是不同的問題，不會互相取代。一個 inclusion = 1 但 coverage = 0.05 的項，意思是「它一出現結果就發生，但只解釋了 5% 的案例」。

---

## 4. 輸出怎麼讀

### 4.1 記號法

| 記號 | 意思 | 例 |
|---|---|---|
| `X{v}` | 條件 X 的值為 v | `A{0}`、`LENG{2}` |
| `*` | 邏輯乘（AND，連言） | `A{1}*B{0}*C{1}` |
| `+` | 邏輯和（OR，選言） | `A{1}*B{0} + C{1}` |
| `#` 前綴 | 必要質蘊涵項 | `#A{0}` |
| `1` | 恆真（所有觀察到的組態都是正例） | `M1: #1` |

**每個字面都直接標出數值**，包括二元條件：`A{1}` 是 A 為 1，`A{0}` 是 A 為 0。

原 Python 版用大小寫表示（大寫 = 1，小寫 = 0），本套件不採用，理由見 §8。簡言之：大小寫的判斷依據是「值集合裡有沒有 0」，條件若編碼成 `{1, 2}`，資料裡沒有 0，所有字面都會印成大寫而無法分辨。`X{v}` 不論條件怎麼編碼都不會有歧義。

（`cora_logigram()` 的**輸入**仍然接受大小寫寫法，所以手寫或從 Python 版取來的運算式可以直接畫。）

所以 `#LENG{2}*RISK{1} + #DOSI{1} + PRIC{0}` 讀作：

> 「LENG 為 2 **且** RISK 為 1」**或**「DOSI 為 1」**或**「PRIC 為 0」

前兩項是必要質蘊涵項。二元條件也是同樣讀法：`#A{0} + B{1}` 就是「A 為 0」**或**「B 為 1」。

### 4.2 敘述式

`cora_describe()` 依據分數把解翻譯成關係陳述：

```r
cora_describe(cora_irredundant_sums(ctx)[[1]])
#> "#A{0} + C{0} <=> OUT"
```

| 符號 | 意思 | 條件 |
|---|---|---|
| `=>` | 充分 | inclusion ≥ 門檻 且 ≥ 0.5 |
| `<=` | 必要 | coverage ≥ `cov` 參數 且 ≥ 0.5 |
| `<=>` | 充分且必要 | 兩者皆滿足 |
| `Warning!` | 都不滿足 | 這個解在統計上站不住腳 |

`cov` 參數預設為 1，可自行放寬：`cora_describe(sol, cov = 0.8)`。

### 4.3 複雜效果的輸出

多結果分析回傳的是**不可約系統**（irredundant system），每個系統對每個結果各有一條式子：

```r
mn <- cora_context(swiss_minaret, c("X", "M"), algorithm = "ON-OFF")
cora_irredundant_systems(mn)
#> ---- System 1 ----
#> X: L{0}*T{0} + S{1}
#> M: L{0}*T{0} + S{1} + T{1}
```

> 系統內的個別式子未必各自不可約，但**整個系統一定是不可約的**。這是 CORA 處理複雜效果的核心：它同時最佳化所有結果，而不是分開跑再拼起來。

### 4.4 拿到結果之後：該怎麼解讀、該怎麼寫

跑完 `cora_solutions(ctx)` 會拿到一張表。表本身不會告訴你哪個解是對的——**這一步是你的工作，不是軟體的**。按下面的順序讀。

#### 第一步：有幾個解？

```r
length(cora_irredundant_sums(ctx))
#> [1] 2
```

出現 2 個以上的解叫做**模型歧義**（model ambiguity）。它的意思很明確：

> 在這份資料上，這些解**一樣好**。沒有任何統計量可以區分它們，因為它們在每一個觀察到的組態上都給出相同的預測。

差別只會出現在**沒有觀察到的組態**上。所以：

- **全部報告**。只挑一個寫進論文，就是在讀者看不到的地方做了選擇。
- 要縮小到一個，只能靠**額外的理論或設計**（例如某個條件組合在理論上不可能出現），不能靠資料，資料已經用完了。
- §5.2 的例子是典型：兩個解只差在第三項是 `PRIC{0}` 還是 `FRFL{0}*MIMA{0}`，兩者的 Cov. 和 Inc. 完全相同。

#### 第二步：整體分數站得住嗎？

```r
cora_system_details(ctx)
#>                  Cov. Inc.
#> Solution details    1    1
```

- **Inc.（包含分數）低** = 這個解會誤報。條件組合成立但結果沒發生的案例存在。
- **Cov.（覆蓋分數）低** = 這個解漏掉很多。有這個結果的案例，大部分它解釋不到。

`Inc. = 1, Cov. = 1` 看起來完美，但在小樣本上這是**常態而非成就**——組態少，容易被完全切開。真正該問的是下一步。

#### 第三步：每一項各自撐起多少？

```r
cora_pi_details(ctx)
#>      PI Cov.r Inc.   M1   M2
#> 1 #A{0}  0.67    1 0.33 0.33
#> 2  C{0}  0.67    1 0.33   NA
#> 3  B{1}  0.67    1   NA 0.33
```

- `Cov.r`、`Inc.` 是這個項**自己**的分數，跟它在哪個解裡無關。
- `M1`、`M2` 欄是**唯一覆蓋**（unique coverage）：在該解中只被這一項涵蓋的正案例比例。
  - 數值**高** = 這一項不可取代，拿掉就漏案例。
  - 數值**為 0** = 它涵蓋的案例別項也全涵蓋了。它之所以還在解裡，是因為拿掉之後其他項的組合就不再是不可約的，但它本身沒有獨佔任何案例——解讀時要謹慎。
  - **`NA` 表示這個項不在該解中**，不是「算不出來」。
- `#` 前綴 = **必要質蘊涵項**（essential prime implicant）：它獨佔了至少一個正案例，因此**每一個**解都必須包含它。這是全部解的共同核心，也是最值得寫進結論的部分。

#### 第四步：Inc. 是 `NaN` 的話

`NaN` 出現在**分母為 0** 時：這個質蘊涵項一個案例也沒涵蓋到。正常資料上不會發生；若出現，通常表示條件的編碼有問題（見 §7.4），或 `n_cut` 設得太高把組態全濾掉了。

#### 第五步：寫進論文時

一份可以被複製的 CORA 結果，至少要交代：

| 要交代的 | 為什麼 |
|---|---|
| `algorithm`（ON-DC 或 ON-OFF） | 兩者處理未觀察組態的假設不同，解可能不同 |
| `n_cut` 與 `inc_score1` | 這兩個值直接決定哪些組態算正例 |
| 條件的編碼方式與每個值的實質意義 | `LENG{2}` 本身沒有意義，除非讀者知道 2 代表什麼 |
| **全部**的解，不是只有一個 | 見第一步 |
| Cov. / Inc. / 唯一覆蓋 | 三個一起看才有意義 |
| 有限多樣性的程度 | 可能組態數 vs. 實際觀察到的組態數 |

**最後一件事，也是最重要的一件事**：CORA 找的是資料裡的**規律結構**（regularity）。「A 是 B 的 INUS 條件」是一個關於資料的陳述，不是關於因果的陳述。要從規律走到因果，需要方法本身給不了的東西——理論、時序、排除共同原因的設計。這一點在 §1.2 說過，在寫結論時要再想一次。

---

## 5. 完整範例

### 5.1 二元條件、單一結果

```r
library(CORA)

df <- data.frame(A   = c(1, 0, 1, 0),
                 B   = c(1, 0, 0, 1),
                 C   = c(0, 1, 1, 0),
                 OUT = c(1, 1, 0, 1))

ctx <- cora_context(df, output_labels = "OUT")

cora_truth_table(ctx)        # 真值表
cora_prime_implicants(ctx)   # #A{0}, C{0}, B{1}
cora_pi_chart(ctx)           # 覆蓋矩陣
cora_irredundant_sums(ctx)   # M1: #A{0} + C{0} ; M2: #A{0} + B{1}
cora_pi_details(ctx)         # 每項的統計量
cora_system_details(ctx)     # 解的整體統計量
cora_solutions(ctx)          # 摘要表
```

### 5.2 多值條件、單一結果

`gross_carvin`：18 個公路主管機關侵權責任案例，7 個多值條件。

```r
tort <- cora_context(gross_carvin, "TORT",
                     case_col = "Case", algorithm = "ON-OFF")

cora_prime_implicants(tort)
#> LENG{0}*UPSI{0}, LENG{0}*RISK{0}, LENG{1}*RISK{0}*FRFL{0},
#> LENG{0}*MIMA{0}, #LENG{2}*RISK{1}, PRIC{0}, FRFL{0}*MIMA{0}, #DOSI{1}

cora_irredundant_sums(tort)
#> M1: #LENG{2}*RISK{1} + #DOSI{1} + PRIC{0}
#> M2: #LENG{2}*RISK{1} + #DOSI{1} + FRFL{0}*MIMA{0}

cora_system_details(tort)
#>                  Cov. Inc.
#> Solution details    1    1
```

兩個解都完全涵蓋（Cov. = 1）且完全包含（Inc. = 1）。差別只在第三項：`PRIC{0}` 或 `FRFL{0}*MIMA{0}`。資料無法區分兩者。

### 5.3 複雜效果

`swiss_minaret`：11 個組態，兩個結果欄 `X` 與 `M`。

```r
mn <- cora_context(swiss_minaret, c("X", "M"), algorithm = "ON-OFF")

cora_irredundant_systems(mn)
#> ---- System 1 ----
#> X: L{0}*T{0} + S{1}
#> M: L{0}*T{0} + S{1} + T{1}

cora_solutions(mn)
#>   L{0}*T{0} S{1} A{1}*T{0} A{1}*L{1} L{0} T{1} A{1} Output System
#> 1         1    1         0         0    0    0    0      X      1
#> 2         1    1         0         0    0    1    0      M      1

cat(cora_describe(cora_irredundant_systems(mn)[[1]]))
#> ---- System 1 ----
#> L{0}*T{0} + S{1} <=> X
#> L{0}*T{0} + S{1} + T{1} <=> M
```

`X` 與 `M` 共用 `L{0}*T{0}` 和 `S{1}` 兩條路徑，`M` 另外多一條 `T{1}`。

### 5.4 組態式資料探勘

問題：**最少需要幾個條件就能得到解？**

```r
cora_data_mining(mccluskey, c("F1", "F2"), len_of_tuple = 2)
#>   Combination Nr_of_systems Inc_score Cov_score Score
#> 1        A, B             1         1     0.333 0.333
#> 2        A, C             1         1     0.667 0.667
#> 3        A, D             1         1     0.333 0.333
#> 4        B, C             1         1     0.667 0.667
#> 5        B, D             1         1     0.333 0.333
#> 6        C, D             1         1     0.667 0.667
```

`Score` = `Inc_score × Cov_score`，是排序用的綜合指標。這裡 `A,C`、`B,C`、`C,D` 三組並列最佳。

`automatic = TRUE` 會從 `len_of_tuple` 開始逐步加大，直到找到非零解為止：

```r
cora_data_mining(df, "OUT", len_of_tuple = 1, automatic = TRUE)
```

> **注意**：唯一解是恆真式 `1` 的組合會被記為 0 解、0 分。這種組合的每個觀察組態都是正例，什麼也沒解釋。

### 5.5 邏輯圖

邏輯圖（logigram）是把解畫成電路。它不提供任何新資訊——圖上有的東西式子裡都有——但它讓「哪些條件一起作用、哪些各走各的路」一眼看得出來。

```r
tort <- cora_context(gross_carvin, "TORT",
                     case_col = "Case", algorithm = "ON-OFF")
sol <- cora_irredundant_sums(tort)[[1]]

cora_logigram(sol)
```

畫出來的圖，頂上是這一行：

```
#LENG{2}*RISK{1} + #DOSI{1} + PRIC{0}  <=>  TORT
M1    Cov. = 1.000    Inc. = 1.000    (# essential)
```

下面是電路。**式子與圖是同一件事的兩種寫法**，放在一起就不必在紙上來回對照。

#### 5.5.1 怎麼讀這張圖

由左往右走一遍：

1. **上方的直線是條件匯流排**，一條一個條件，名字寫在頂端。
   - 只有**出現在這個解裡**的條件才有匯流排。`gross_carvin` 有 7 個條件，上圖只畫了 4 條——`UPSI`、`FRFL`、`MIMA` 不在 M1 裡，就不畫。
   - 排列依**字母順序**，不是資料欄位順序。
2. **匯流排上的實心圓點是一個取值點**（tap），旁邊的 `{v}` 就是取的值。
   - `LENG` 線上標 `{2}` 的點 = 「LENG 等於 2」這個字面。
   - 同一條匯流排上可以有好幾個點（不同的項各取各的值），彼此互不相干。
3. **黃色方塊（右端半圓）是 AND 閘**，把左邊接進來的幾個字面合成一個連言。
   - 上圖的 AND 閘接了 `LENG{2}` 和 `RISK{1}`，輸出就是 `LENG{2}*RISK{1}`。
   - **只有一個字面的項不畫 AND 閘**——一個字面沒有什麼好「合」的，線直接拉到 OR 閘。`DOSI{1}` 和 `PRIC{0}` 就是這樣，所以圖上只有一個 AND 閘，但式子有三項。
4. **藍色盾形是 OR 閘**，把所有項合成選言。任何一項成立，輸出就成立。
5. **最右邊的名字是結果欄**。

所以這張圖念出來是：

> 「LENG 為 2 **且** RISK 為 1」，**或**「DOSI 為 1」，**或**「PRIC 為 0」——三條路任何一條走通，TORT 就發生。

#### 5.5.2 大小寫寫法的圖

`cora_logigram()` 的**輸入**仍然接受 Python 版的大小寫記號（大寫 = 1、小寫 = 0）。這時負字面畫成線上的**小空心圓圈（bubble）**，那是電路圖表示反相的標準畫法：

```r
cora_logigram("A*B+c*A+b<=>F")          # c 和 b 會帶泡泡
cora_logigram("a'*b+c<=>F", notation = "prime")   # 撇號寫法
```

> `notation = "prime"` 的輸入**必須全部小寫**，否定用後綴撇號（`a'` 表示 a 為 0）。混用大小寫會報 `Invalid input entered!`——因為那時無法判斷大寫是「值為 1」還是「還沒加撇號的變項名」。

用 `X{v}` 寫的多值式子不畫泡泡——`{0}` 已經把值講清楚了，再加一個反相符號反而多餘。

#### 5.5.3 多結果的圖

```r
mn <- cora_context(swiss_minaret, c("X", "M"), algorithm = "ON-OFF")
cora_logigram(cora_irredundant_systems(mn)[[1]])
```

- 每個結果各有一個 OR 閘，**由上而下依結果宣告的順序排列**。
- **共用的項只畫一次**，輸出線分岔接到多個 OR 閘。上圖中 `L{0}*T{0}` 和 `S{1}` 的線各自分成兩路，一路去 `X`、一路去 `M`；`T{1}` 只接 `M`。
- 這正是複雜效果分析的重點所在：**哪些機制被多個結果共用、哪些是某個結果獨有的**，在圖上是直接看得到的，在式子裡要比對兩行字。

#### 5.5.4 標註與版面

| 參數 | 作用 |
|---|---|
| `title` | 圖上方的式子。預設 `NULL` = 自動（解物件會印出自己，含標示必要項的 `#`）；`NA` = 不印；給字串向量則逐行印出 |
| `subtitle` | 式子下面那行。預設 `NULL` = 自動（解物件印 `Cov.` 與 `Inc.`）；`NA` = 不印 |
| `show_terms` | `TRUE` 時在每個閘旁邊標出它形成的連言 |
| `color_and` | AND 閘填色 |
| `color_or` | OR 閘填色 |

```r
# 預設：式子 + 分數都標上
cora_logigram(sol)

# 每個閘旁邊也標出該項（圖要單獨放進投影片時好用）
cora_logigram(sol, show_terms = TRUE)

# 完全不要標註（要自己在論文裡寫圖說時）
cora_logigram(sol, title = NA, subtitle = NA)

# 自訂標題
cora_logigram(sol, title = "圖 3：侵權責任的充分條件",
              subtitle = "N = 18，ON-OFF 演算法")

# 換顏色
cora_logigram(sol, color_and = "#f3aea0", color_or = "#aed49c")

# 存檔
png("figure.png", 1300, 850, res = 140)
cora_logigram(sol)
dev.off()
```

版面會自動配合標註：標題比圖寬時，畫布往右加寬，不會把字切掉。

也可以直接給運算式，不必先跑分析：

```r
cora_logigram("A{1}*B{2}+C{0}<=>F")
cora_logigram(c("A{1}*B{2}+A{2}<=>F1", "A{1}+C{1}*B{2}<=>F2"))
cora_logigram("A[1]*B[2]+C[0]<=>F")     # QCA 套件的方括號寫法也讀
```

`cora_dnf()` 可以把解轉成字串形式（這是餵給 `cora_logigram()` 的格式，`#` 會被去掉）：

```r
cora_dnf(cora_irredundant_sums(ctx)[[1]])
#> "A{0}+C{0}<=>OUT"
```

> 恆真式（`1<=>OUT`）沒有兩層邏輯圖可畫。一個恆真的解表示**每個觀察到的組態都是正例**，沒有任何條件在區分什麼，畫出來會是一張輸入匯流排叫做「1」的假圖。`cora_logigram()` 對這種情形直接報錯。

---

## 6. 函數速查表

| 函數 | 用途 |
|---|---|
| `cora_context()` | 建立分析脈絡：資料 + 所有分析選擇 |
| `cora_truth_table()` | 真值表（`raw = TRUE` 另含案例數與原始分數） |
| `cora_prime_implicants()` | 布林最小化，回傳質蘊涵項 |
| `cora_pi_chart()` | 質蘊涵項圖表（覆蓋矩陣） |
| `cora_irredundant_sums()` | 不可約解（**單一結果**） |
| `cora_irredundant_systems()` | 不可約系統（**多個結果**） |
| `cora_pi_details()` | 每個質蘊涵項的統計量 |
| `cora_system_details()` | 解的整體統計量 |
| `cora_solutions()` | 解的摘要表 |
| `cora_coverage_score()` | 覆蓋分數（質蘊涵項或解皆可） |
| `cora_inclusion_score()` | 包含分數（質蘊涵項或解皆可） |
| `cora_describe()` | 把解翻譯成 `=>` / `<=` / `<=>` 陳述 |
| `cora_dnf()` | 把解轉成 DNF 字串 |
| `cora_logigram()` | 畫兩層邏輯圖 |
| `cora_data_mining()` | 組態式資料探勘 |
| `cora_petrick()` | 直接對覆蓋清單跑 Petrick 法 |
| `cora_recode()` | 把條件映射到 `0, 1, 2, ...` |
| `cora_python_available()` | 檢查 Python 版是否可用 |
| `cora_compare_python()` | 與 Python 版交叉比對 |

**內建資料集**：`swiss_minaret`（11 列，多結果）、`gross_carvin`（18 列，多值）、`mccluskey`（16 列，兩輸出開關函數）、`bergschlosser`（48 列，多值、三結果）

> 這四個資料集原封不動取自 Python 版，**上游沒有附變項定義**——只有欄位縮寫，沒有說明縮寫代表什麼、值 0/1/2 各自代表什麼。適合學語法與驗證輸出，**不適合做實質推論**。見附錄 C。

---

## 7. 參數選擇與常見陷阱

### 7.1 `n_cut` 怎麼設

`n_cut` 是「這個組態要有幾個案例我才相信它」。

- `n_cut = 1`（預設）：所有觀察到的組態都採用
- `n_cut = 2` 以上：只採用重複出現的組態，對測量誤差較穩健，但會丟掉資料

小樣本（N < 30）通常只能用 `n_cut = 1`。

### 7.2 `inc_score1` 怎麼設

`inc_score1 = 1` 要求組態內**所有**案例都顯示該結果，是最嚴格的設定。實務上資料很少這麼乾淨，常見做法是放寬到 0.75–0.9。

**放寬 `inc_score1` 會讓更多組態被判為正例，解會變得更簡潔但更不精確。** 這個取捨要在論文裡交代，不能默默調。

### 7.3 常見陷阱

| 陷阱 | 說明 |
|---|---|
| **有限多樣性** | 條件數 k 會產生 2^k（多值更多）個可能組態，實際觀察到的往往只有一小部分。解有多少建立在未觀察組態上，要自己清楚。 |
| **模型歧義** | 出現多個解時，**全部報告**。只挑一個報告是選擇性呈現。 |
| **把 coverage 當 p 值** | 這些不是顯著性檢定，沒有虛無假設。高分數不等於統計顯著。 |
| **條件數過多** | CCM 的解釋力隨條件數快速下降。建議 4–7 個條件，超過就該先用 `cora_data_mining()` 篩選。 |
| **因果解讀** | CORA 找的是資料中的規律結構。要宣稱因果，需要額外的理論與設計支持，方法本身給不了。 |
| **條件沒從 0 編碼** | 見 §7.4。本套件會直接報錯，Python 版不會——那邊會給出看起來合理的錯數字。 |
| **解太多** | 質蘊涵項一多，不可約解的數量會指數成長（本套件的 `bergschlosser` + `PRAET` 有 74,524 個解）。**每一個都是有效的解**，這正是問題所在：沒有人能全部報告。超過一萬個時本套件會警告，並建議用 `max_depth` 問一個更窄的問題。 |

### 7.3.1 解太多的時候：`max_depth`

質蘊涵項一多，不可約解的數量會指數成長。`bergschlosser` 的 `PRAET`（46 個質蘊涵項）有 **74,524 個解**，全部算完要 24 秒；三個結果一起（87 個質蘊涵項）則根本算不完。

每一個解都是有效的、都同樣被資料支持——這正是問題所在：**沒有人能全部報告**。這時該問一個更窄的問題：

```r
ctx <- cora_context(bergschlosser, "PRAET",
                    input_labels = c("AGRPOP","PARCL","APROG","PS","RQ","LRC"),
                    case_col = "Case", inc_score1 = 0.6, algorithm = "ON-OFF")

cora_irredundant_sums(ctx, max_depth = 7)   # 21 個解，0.2 秒
```

| | 解的數量 | 時間 |
|---|---|---|
| 不設限 | 74,524 | 24 秒 |
| `max_depth = 8` | 564 | 0.7 秒 |
| `max_depth = 7` | 21 | 0.2 秒 |
| `max_depth = 6` | 0 | 0.1 秒 |

（`max_depth = 6` 是 0，因為最短的解就要 7 個質蘊涵項。）

**`max_depth` 是在搜尋的時候就設上限，不是算完再過濾。**這是「算得完」與「算不完」的差別。修剪是精確的——一個乘積在繼續相乘的過程中永遠不會變短，所以被丟掉的不可能再回到上限之內——因此結果與「算完再過濾」完全相同（隨機資料上 480 次比對，零差異）。

想走舊路線（算完再過濾）可以用 `search = "exhaustive"`；兩者回傳相同的解，差別只在：

- `"bounded"`（預設）：快，解從 1 開始編號
- `"exhaustive"`：慢，但每個解**保留它在完整解集裡的編號**，所以可能回傳 `M2`、`M5`

> Python 版的 `max_depth` **完全沒有作用**——它只出現在函數簽名和說明文件裡，函數本體從來沒有用到它。傳 0、1、2 都得到一樣的結果。見附錄 A.9。

---

### 7.4 條件必須從 0 開始編碼

每個條件都要編成 `0, 1, 2, ...`，中間不能跳號。`{1, 2}` 不行，`{0, 2}` 也不行。

這是唯一一個在 Python 版會**安靜地產生錯誤數字**的陷阱。本套件改成直接報錯，所以你不會踩到——但你需要知道為什麼。

**原因**：`"ON-OFF"` 演算法把化簡結果還原成完整的條件組合時，對「不在意」的條件要填入一組值。Python 版填的是 `{0, 1, ..., levels-1}`——**假設值從 0 開始**。條件實際編碼成 `{1, 2}` 時，`levels = 2`，填進去的是 `{0, 1}`：包含了一個從未出現的值（0），排除了一個真實存在的值（2）。於是所有該條件為 2 的案例都被排除在覆蓋之外。

實測（Python 版 README 自己的資料，`B` 編碼為 `{1,2}`）：

| 質蘊涵項 | ON-DC Cov. | ON-OFF Cov. | ON-OFF Inc. |
|---|---|---|---|
| `A{1}` | 0.667 | **0.333** | 1 |
| `C{0}` | 0.333 | **0.000** | **NaN** |
| `#C{2}` | 0.333 | **0.000** | **NaN** |
| `D{1}` | 0.333 | **0.000** | **NaN** |

同一份資料、同一個質蘊涵項，只因為換了演算法就得到不同分數。完整的推導、原始碼位置與另外四個相關缺陷，見**附錄 A**。

**本套件怎麼處理——兩層：**

1. **拒絕計算**。第一次真正動手算的時候（`cora_prime_implicants()`、`cora_truth_table()` 等，以及 `cora_data_mining()`）會檢查，不符合就報錯並告訴你怎麼修：

   ```
   Condition(s) 'B' are not coded from 0 upwards. CORA expects each condition
   to take the values 0, 1, 2, ... with no gaps.
     Recode them with:  data <- cora_recode(data, c("B"))
     cora_recode() maps each condition onto 0, 1, 2, ... keeping the order of
     its values.
   ```

2. **底層也修好了**。「不在意」填入的是該條件**實際觀察到的值**，不是 `{0, ..., levels-1}`（這是 `cna` 套件的做法，見附錄 B.3）。所以即使檢查被繞過，覆蓋集也是對的。

修好之後，`cora_recode(df, "B")` 之後的同一份資料，本套件的 ON-DC 與 ON-OFF 給出**完全相同**的質蘊涵項、`Cov.r`、`Inc.` 與唯一覆蓋（只有列的順序不同）。上表裡 ON-OFF 欄的 0.333 / 0.000 / NaN 全部消失。

> **重編碼會位移標籤**：`B` 從 `{1,2}` 變成 `{0,1}` 之後，原本的 `B{2}` 變成 `B{1}`。結構完全相同，只是數值標籤跟著編碼走。對照 Python 版文獻時要注意這一點。

**為什麼不乾脆自動重編碼就好？** 因為那會讓標籤在使用者不知情的情況下位移——你寫論文時引用的 `B{1}`，跟你手上編碼簿的 `B{1}` 會是兩回事。報錯的成本是一行 `cora_recode()`，算錯的成本是一篇論文。（QCA 與 cna 各自的做法與比較，見附錄 B。）

---

## 8. 與 Python 版的差異

本套件移植自 PoliUniLu 的 Python 套件 `CORA` 與 `LOGIGRAM`。移植結果在其自身的測試與範例資料上逐一比對過：**真值表、質蘊涵項、覆蓋集、解集完全一致**（41 個情境、263 個比對欄位）。

七處刻意的差異：

1. **拒絕非 0 編碼的資料**：條件沒有編成 `0, 1, 2, ...` 時本套件報錯（並指示用 `cora_recode()`），Python 版照算並給出錯誤的覆蓋集與分數（見 §7.4）。底層的「不在意」值域也改用實際觀察值，所以兩種演算法在編碼正確時完全一致。
2. **解的排序**：本套件用確定性排序（先短後長，同長度依字典序），所以 R 的 `M1` 未必是 Python 的 `M1`。**解的集合相同。**
3. **記號法**：本套件一律用 `X{v}`，Python 版對二元條件用大小寫。這**不改變任何計算結果**，只改變印出來的樣子——`#a + B` 在本套件是 `#A{0} + B{1}`。改的理由是大小寫的判斷依據（值集合含不含 0）在條件未從 0 編碼時完全失效，見 §7.4。`cora_logigram()` 的輸入仍接受大小寫寫法。
4. **ON-OFF + 多結果時質蘊涵項的 inclusion 分數**：Python 版拿**全部**結果欄計算。該質蘊涵項物件自己的 `outputs` 欄位說它只對應某一個結果，`output_labels` 欄位卻列出全部——兩個欄位互相矛盾，而類別文件說兩者都是「corresponding to the implicant」。本套件用該質蘊涵項自己的結果欄。
5. **資料探勘中的恆真式**：唯一解是 `1` 的組合在本套件記為 0 解 0 分。Python 版原意相同，但其檢查永遠不會觸發。
6. **`max_depth` 真的會限制解**：本套件在 Petrick 法的乘法過程中就修剪，所以它同時是「限制」也是「讓算得完」的手段（見 §7.3.1）。Python 版的 `max_depth` 完全沒有作用。
7. **字面的排列**：本套件把連言內部的字面依條件名稱**排序**後印出（`A{0}*C{1}`，不論欄位順序），Python 版依欄位順序印。這**不改變任何計算結果**，只讓同一份分析每次都印出同一個字串。

這七處都是本套件自己的判斷，不是原作者的。**每一處的原始碼位置、可重現的例子與完整推導見附錄 A**；與 QCA、QCApro、cna 的設計比較見附錄 B。

想自行驗證的話：

```r
if (cora_python_available()) {
  cora_compare_python(ctx)
}
```

需要 `reticulate` 與 Python 版 `cora`。**套件本身完全不需要 Python。**

---

## 9. 引用與授權

```r
citation("CORA")
```

會列出三筆：本套件、CORA 方法論文、原 Python 套件論文。**使用 CORA 做分析時，方法論文一定要引用**，不論用哪個軟體跑的。作者角色的安排與理由見附錄 D。

- Thiem, A., Mkrtchyan, L., & Sebechlebská, Z. (2022). Combinational Regularity Analysis (CORA) — a new method for uncovering complex causation in medical and health research. *BMC Medical Research Methodology*, 22(1), 333.
- Sebechlebská, Z., Mkrtchyan, L., & Thiem, A. (2023). CORA and LOGIGRAM: A duo of Python packages for Combinational Regularity Analysis (CORA). *Journal of Open Source Software*, 8(85), 5019.

授權：GPL (>= 3)，與原始實作相同。本套件為獨立實作，未經原 Python 套件作者背書。

---

## 附錄 A：Python 版的六個缺陷

這一節記錄本套件在移植過程中發現、並在 R 版中修正的問題。列出來有三個理由：

1. 你如果拿本套件的結果跟 Python 版對照，會發現對不上，需要知道為什麼；
2. 已經用 Python 版發表過的分析，可能需要重跑；
3. 這些是**本套件自己的判斷**——每一條都附上原始碼位置與可重現的例子，你可以自己驗證，不必相信我的說法。

驗證用的版本：PoliUniLu `cora`（GitHub 主線）。行號指該版本。

### A.1 共同的起因：把「觀察到的值」當成「0 到 k−1」

六個缺陷裡有三個源自同一個假設。Python 版計算每個條件的**層級數**如下：

```python
# cora/prime_implicants.py:558-573  _get_levels
dim = [inputs[col].unique() for col in inputs]
...
levels = [len(x) for x in dim_corrected]
```

`levels` 是**相異值的個數**。條件 `B` 編碼成 `{1, 2}` 時 `levels = 2`。

到這裡都沒問題。問題出在後面把 `levels` 當成「值域是 `0` 到 `levels−1`」來用。

### A.2 缺陷①：自由字面的值域錯了（ON-OFF）

```python
# cora/multiply.py:45-49
def _transform_to_raw_implicant(impl, levels):
    res = [frozenset(range(i)) for i in levels]      # ← 這一行
    for x in impl:
        res[x._ident] = frozenset([x._val])
    return tuple(res)
```

一個質蘊涵項對「沒有提到的條件」要填入該條件的**全部可能值**（自由字面）。這裡填的是 `range(levels)`。

條件 `B` 實際取值 `{1, 2}`、`levels = 2` 時，填進去的是 `{0, 1}`：

- 包含了一個**從未觀察到**的值（0）
- 排除了一個**真實存在**的值（2）

於是所有 `B = 2` 的案例都不符合這個質蘊涵項，被排除在覆蓋之外。

**用 Python 版 README 自己的資料重現**（`B` 編碼為 `{1,2}`）：

```python
import pandas as pd, cora
df = pd.DataFrame([[1,2,0,1,1],
                   [1,1,1,0,1],
                   [0,2,1,0,0],
                   [0,2,2,0,1]], columns=["A","B","C","D","OUT"])
for alg in ["ON-DC", "ON-OFF"]:
    c = cora.OptimizationContext(data=df, output_labels=["OUT"],
                                 algorithm=alg, inc_score1=0.5)
    for p in c.get_prime_implicants():
        print(alg, p, p.coverage_score(), p.inclusion_score())
```

實際輸出：

| 質蘊涵項 | ON-DC Cov. | ON-DC Inc. | ON-OFF Cov. | ON-OFF Inc. |
|---|---|---|---|---|
| `A{1}` | 0.667 | 1 | **0.333** | 1 |
| `B{1}` | 0.333 | 1 | 0.333 | 1 |
| `C{0}` | 0.333 | 1 | **0.000** | **NaN** |
| `#C{2}` | 0.333 | 1 | **0.000** | **NaN** |
| `D{1}` | 0.333 | 1 | **0.000** | **NaN** |

兩種演算法找到的是**同樣 5 個質蘊涵項、同樣的質蘊涵項圖表**。差別純粹出現在案例層次的分數上。

**為什麼 ON-DC 那一欄是對的**：`A{1}` 的意思是「A 等於 1」，式子裡**完全沒有提到 B**。資料裡 A=1 的列是第 0 列和第 1 列，兩列的 OUT 都是 1；OUT=1 的列共 3 列（第 0、1、3 列）。所以 `A{1}` 的覆蓋分數是 2/3 = 0.667。ON-OFF 算出 0.333，是因為第 0 列的 B=2 被判定為「不在 B 的值域內」而遭排除——**一個沒有對 B 設限的式子，不該因為某列 B 的值而排除該列**。這不是取捨問題，是定義問題。

`C{2}` 更明顯：全資料只有第 3 列 C=2，該列 OUT=1，覆蓋分數應該是 1/3。ON-OFF 算出 0，等於宣告「C 等於 2 這件事在資料裡從來沒發生過」——但 `C{2}` 這個質蘊涵項本身就是從那一列推出來的。

### A.3 缺陷②：涵蓋 0 個案例時的真空為真（ON-OFF）

```python
# cora/prime_implicants.py:738-754
def _output_coverage_of_pi(self, raw_implicant):
    ...
    for ind, out in enumerate(outputs):
        if all( data[out][ data.apply(lambda row: all(...), axis=1) ] ):
            res.add(ind + 1)
    return res
```

這個函數判斷「這個質蘊涵項對應哪幾個結果」：對每個結果欄，檢查被涵蓋的案例**是否全部**都是正例。

Python 的 `all()` 對**空序列**回傳 `True`（真空為真，vacuous truth）。這在數學上是對的——「所有元素都滿足 P」在沒有元素時確實成立——但用在這裡的語意是災難：

> 缺陷① 讓覆蓋集變成空的 → `all([])` 為 `True` → 這個質蘊涵項被指派**全部**結果。

也就是說，一個什麼案例都沒涵蓋到的項，會被記錄成「它解釋了每一個結果」。

**這個函數只有一個呼叫點**，在 `prime_implicants.py:791`，位於 `_get_prime_implicants_on_off` 之內。所以缺陷② 只影響 ON-OFF。（可用 `grep -n "_output_coverage_of_pi" cora/prime_implicants.py` 自行確認：只有定義的 738 行和呼叫的 791 行。）

**本套件的處理**：修好缺陷① 之後，覆蓋集不會無故變空，這個陷阱就不會被觸發。R 版**忠實保留了真空為真的邏輯**（`R/onoff.R` 的 `output_coverage_of_pi()`），因為在編碼正確的資料上它是對的，改掉反而會跟 Python 版不一致。

### A.4 缺陷③：ON-OFF + 多結果時，包含分數讀錯欄位

質蘊涵項物件的類別文件這樣寫（`prime_implicants.py:2043-2045`）：

```
output_labels : array of strings
                The array contains the output labels corresponding to the
                implicant.
```

「**對應於該質蘊涵項的**結果標籤」。但兩條路徑傳進去的東西不一樣：

```python
# ON-DC 路徑，prime_implicants.py:684-685
output_labels=[self.output_labels[i - 1] for i in list(x for x in x[2])]
#              ↑ 只有這個質蘊涵項自己對應的結果

# ON-OFF 路徑，prime_implicants.py:816
self.output_labels,
#              ↑ 全部結果欄
```

而 `inclusion_score()`（`prime_implicants.py:2115` 起）直接使用這個欄位：

```python
if len(self.outputs) == 1:
    tmp_positive_data = tmp_data[data[self.output_labels[0]] == 1]
    #                                  ↑ 取第一個
else:
    tmp_positive_data = tmp_data[ data.apply(
        lambda row: all(row[output] == 1 for output in self.output_labels), axis=1) ]
    #                                              ↑ 要求全部結果欄都是 1
```

所以在 ON-OFF 路徑上，`self.output_labels[0]` 是**資料裡的第一個結果欄**，未必是這個質蘊涵項對應的那一個。

**這不是「兩種合理的定義」**。同一個物件的 `outputs` 欄位說它只對應第 2 個結果，`output_labels` 欄位卻列出全部三個——**兩個欄位在同一個物件內互相矛盾**，而類別文件說兩者都是「corresponding to the implicant」。矛盾的是實作與自己的規格，不是兩種學派。

**本套件的處理**：一律用該質蘊涵項自己的結果欄。所以在本套件裡，同一個質蘊涵項在 ON-DC 和 ON-OFF 下的分數相同。

### A.5 缺陷④：大小寫記號在非 0 編碼下失效（兩種演算法都受影響）

```python
# cora/prime_implicants.py:274-285
def _set_to_str(s, levels, label, is_multi_level):
    if len(s) == levels:
        return ""
    if not is_multi_level:
        if 0 in s:
            return label.lower()        # 小寫 = 值為 0
        else:
            return label.upper()        # 大寫 = 值為 1
    ...

def _minterm_to_str(minterm, levels, labels, tag, multi_output):
    is_multi_level = any(x > 2 for x in levels)
```

判斷大小寫的依據是「**這個值集合裡有沒有 0**」。條件 `B` 編碼成 `{1, 2}` 時，`levels = 2`（相異值兩個），若其他條件也都是二值，`is_multi_level` 就是 `False`，於是：

- `B = 1` → 集合 `{1}`，沒有 0 → 印成 `B`
- `B = 2` → 集合 `{2}`，沒有 0 → 也印成 `B`

**兩個不同的字面印出同一個字串**，看輸出的人無從分辨。這是純粹的顯示問題，不影響內部計算，但它會讓你把結果讀錯——而且 ON-DC 和 ON-OFF 都會這樣印。

**本套件的處理**：一律用 `X{v}`。`#a + B` 在本套件是 `#A{0} + B{1}`。每個字面都帶著自己的值，不論條件怎麼編碼都沒有歧義。（`cora_logigram()` 的**輸入**仍接受大小寫寫法，方便直接畫手寫的或從 Python 版取來的式子。）

### A.6 缺陷⑤：資料探勘的恆真式檢查永遠不會觸發

```python
# cora/data_mining_cora.py:13-21
if (
    out_len == 1
    and len(irrendudant_systems) == 1
    and (str(irrendudant_systems[0].system[0].implicant) == "1")
):
    self.nr_irr_systems = 0
    self.inc_score = 0
    ...
```

原意很清楚也很正確：**唯一解是恆真式 `1` 的組合，應該記為 0 解 0 分**。這種組合的每個觀察組態都是正例，它什麼也沒解釋，不該在排序時名列前茅。

但恆真的解**一定是必要質蘊涵項**（它獨佔了所有正案例），所以 `implicant` 字串是 `"#1"` 而不是 `"1"`，這個相等比較永遠是 `False`。

**實測**：

```python
df = pd.DataFrame([[1,1,0,1],[0,0,1,1],[1,0,1,1],[0,1,0,1]],
                  columns=["A","B","C","OUT"])
cora.data_mining(df, ["OUT"], 1)
```

```
  Combination  Nr_of_systems  Inc_score  Cov_score  Score
0         [A]              1        1.0        1.0    1.0
1         [B]              1        1.0        1.0    1.0
2         [C]              1        1.0        1.0    1.0
```

OUT 全部為 1，三個條件什麼都沒解釋，卻全部拿到滿分 1.0——**可能得到的最高分**。

本套件同一份資料：

```r
df <- data.frame(A = c(1,0,1,0), B = c(1,0,0,1), C = c(0,1,1,0), OUT = c(1,1,1,1))
cora_data_mining(df, "OUT", len_of_tuple = 1)
#>   Combination Nr_of_systems Inc_score Cov_score Score
#> 1           A             0         0         0     0
#> 2           B             0         0         0     0
#> 3           C             0         0         0     0
```

這也是 `automatic = TRUE` 能正常運作的前提：它要「找到非零解才停」，而恆真式如果被當成滿分解，搜尋會在第一步就停下來。

### A.6b 缺陷⑥　`max_depth` 從頭到尾沒有被使用

```python
# cora/prime_implicants.py:1025
def get_irredundant_sums(self, max_depth=None):
    """
    Parameters
    ----------
    max_depth : int
               A positive integer denoting max number of prime implicants
               in the solution.
    ...
    with respect to the max_depth condition.
    """
```

說明文件寫得很清楚：「解中質蘊涵項數量的上限」。但 `max_depth` 這個名字在整個檔案裡**只出現三次**——第 1025 行的簽名、第 1030 和 1037 行的說明文件。**函數本體從來沒有用到它。**

實測：

```python
for md in (None, 1, 2, 0):
    c = cora.OptimizationContext(data=df, output_labels=["OUT"])
    print(md, len(c.get_irredundant_sums(max_depth=md)))
# None -> 2 個解，1 -> 2 個，2 -> 2 個，0 -> 2 個
```

連 `max_depth = 0` 都照樣回傳全部的解。

本套件的 `max_depth` 是在 Petrick 法的乘法過程中就修剪，見 §7.3.1。

### A.7 修正之後

把資料重新編碼成 0 起始之後（`cora_recode(df, "B")`），本套件的兩種演算法給出**完全相同**的結果：

```r
df <- data.frame(A = c(1,1,0,0), B = c(2,1,2,2), C = c(0,1,1,2),
                 D = c(1,0,0,0), OUT = c(1,1,0,1))
df <- cora_recode(df, "B")
for (alg in c("ON-DC", "ON-OFF")) {
  print(cora_pi_details(cora_context(df, "OUT", algorithm = alg,
                                     inc_score1 = 0.5)))
}
```

兩次輸出的質蘊涵項集合、`Cov.r`、`Inc.`、以及每個解的唯一覆蓋，全部一致（只有列的順序不同）。對照 A.2 那張表，ON-OFF 欄的 0.333 / 0.000 / NaN 全部消失。

> **重編碼會位移標籤**：`B` 從 `{1,2}` 變成 `{0,1}` 之後，原本的 `B{2}` 變成 `B{1}`。結構完全相同，只是數值標籤跟著編碼走。跟 Python 版的文獻對照時要記得換算。

### A.8 責任歸屬

本套件與 Python 版**共用同一套理論**（CORA / CCM）。因此：

- **兩者相同之處**若有錯，那是方法本身的問題，屬於原作者的理論與實作。
- **本套件與 Python 版不同之處**若有錯，責任在本套件，與原作者無關。

上面六條都是「不同之處」。每一條都附了原始碼位置與可重現的例子，就是為了讓你能自己判斷我改得對不對，而不是要你相信我。

---

## 附錄 B：QCA、QCApro、cna 怎麼做

這三個 R 套件處理的是相鄰的問題（QCA 與 CNA），對「多值條件怎麼編碼、字面怎麼印」有各自的成熟做法。本套件的兩個設計決定——**一律用 `X{v}`** 和 **拒絕非 0 編碼**——是參考它們之後的選擇。以下每一條都附原始碼位置，版本標在標題上。

### B.1 QCA（3.25.5，Duşa）＋ admisc

**內部表示：0 是哨兵，實際值 +1。**

```r
# admisc/R/writePIs.R:29-38
if (mv) {
    chars <- matrix(paste(chars,
                          ifelse(curly, "{", "["),
                          impmat - 1,                 # ← 印出來時減 1
                          ifelse(curly, "}", "]"), sep = ""), ...)
}
```

蘊涵項矩陣裡 `0` 表示「這個條件不出現在這一項裡」，實際值一律 +1 儲存，印出來時再減回去。

**記號**：多值用 `A[1]`（方括號），加 `curly = TRUE` 則用 `A{1}`。二元的否定用 `~A`：

```r
# admisc/R/writePIs.R:52
chars <- ifelse(impmat == 1L, paste0("~", chars), chars)
```

**注意：QCA 現在不用大小寫表示否定，用波浪號。**這一點值得記——文獻裡的 `a` 是舊版寫法。

**切換到多值記號的時機是自動的**：

```r
# admisc/R/writePIs.R:8-10
if (any(impmat > 2)) {
    mv <- TRUE
}
```

`impmat > 2` 是「有值 ≥ 3」，因為儲存時 +1 過，也就是**實際值 ≥ 2 就自動改用多值記號**。

**層級數的算法假設 0 起始**：

```r
# admisc/R/getLevels.R
noflevels[pN] <- apply(data[, pN, drop = FALSE], 2,
                       function(x) max(as.numeric(x))) + 1
```

`max + 1`。條件編碼成 `{1, 2}` 時 `noflevels = 3`，真值表裡會多出一列「值為 0」的組態——那是資料裡根本沒有的東西，但它會被當成**未觀察組態**（remainder）處理，不會報錯。

> 所以 QCA **也假設 0 起始編碼**，只是它的失效方式比較溫和：多一個幽靈組態，而不是把真實案例排除掉。QCA 的手冊要求使用者自己把多值條件編成 `0, 1, 2, ...`。

### B.2 QCApro（1.1-2，Thiem）

同一位作者的另一個套件（也是 CORA 論文的作者之一）。

```r
# QCApro/R/writePrimeimp.R:12-22
for (i in seq(ncol(idx))) {
    if (uplow) {
        conditions <- c(tolower(colnames(idx)[i]), toupper(colnames(idx)[i]))
    } else if (use.tilde) {
        conditions <- c(paste("~", toupper(colnames(idx)[i]), sep=""), ...)
    } else {
        conditions <- paste(colnames(idx)[i], "{", seq(max(idx[, i])) - 1, "}", sep="")
    }                                      # ↑ X{v}
}
```

三種記號：大小寫、波浪號、`X{v}`。關鍵在**什麼時候用哪一種**：

```r
# QCApro/R/eQMC.R:253-256
if (any(recdata[, seq(ncol(recdata) - 1)] > 1)) {
    uplow <- FALSE
    use.tilde <- FALSE
}
```

**只要任何一個條件取值大於 1，就強制關掉大小寫與波浪號，落到 `X{v}`**——連使用者明確指定的 `use.tilde = TRUE` 也一併覆寫掉。

這是本套件採用 `X{v}` 最直接的依據：**CORA 原作者自己的 R 套件，一碰到多值資料就無條件改用 `X{v}`**。本套件只是把這件事做得更徹底——二元資料也一樣用，不再有兩套記號。

### B.3 cna（4.0.3，Ambühl / Baumgartner）

cna 的做法最乾淨，也最值得學：**它根本不假設值從 0 開始。**

```r
# cna/R/cna_aux.r:60-67
} else if (type == "mv") {
    uniqueValues <- lapply(ct, function(x) sort(unique.default(x)))
    resp_nms <- mapply(paste, names(ct), uniqueValues,
                       MoreArgs = list(sep = "="), SIMPLIFY = FALSE)
    resp_nms <- unlist(resp_nms, use.names = FALSE)
    valueId <- mapply(match, ct, uniqueValues, SIMPLIFY = TRUE, USE.NAMES = TRUE)
    ...
}
```

兩個關鍵：

1. `uniqueValues` 是**實際觀察到的值**（`sort(unique(x))`），不是 `0:(k-1)`。
2. `valueId` 用 `match()` 取得**在觀察值序列中的位置**，不是值本身。內部運算用位置，顯示時用真實的值。

**記號**：`A=1`，直接把真實的值寫進字面名稱裡（字面名稱同時就是內部矩陣的欄名）。

於是「條件編碼成 `{1, 2}`」在 cna 裡完全不是問題：它會印出 `B=1` 和 `B=2`，內部用位置 1 和 2，沒有任何地方需要假設 0 存在。

### B.4 三者的比較，以及本套件的選擇

| | 多值記號 | 二元否定 | 內部值域 | 非 0 編碼時 |
|---|---|---|---|---|
| **QCA** | `A[1]`（可切 `A{1}`） | `~A` | `0` 為哨兵，值 +1；層級 = `max + 1` | 多出幽靈組態，不報錯 |
| **QCApro** | `A{1}` | 大小寫或 `~A`（多值時強制關掉） | 值 `0..max` | — |
| **cna** | `A=1` | 大小寫 | **實際觀察值**，位置索引 | 完全不受影響 |
| **CORA（Python）** | `A{1}` | 大小寫 | 假設 `0..levels-1` | **安靜地算錯**（附錄 A） |
| **CORA（本套件）** | `A{1}`，**一律** | `A{0}`，不用大小寫 | **實際觀察值**（學 cna） | **報錯**，並指示 `cora_recode()` |

三個決定的依據：

1. **一律 `X{v}`** — 跟 QCApro 的多值預設一致，也跟 Python 版 CORA 的多值輸出一致。差別只在本套件對二元資料也這樣印，因為大小寫的判斷依據（值集合含不含 0）在非 0 編碼時會失效（附錄 A.5）。
2. **內部用實際觀察值** — 照 cna 的做法。這一條修掉了附錄 A.2 的缺陷①，也讓附錄 A.3 的陷阱不會被觸發。
3. **非 0 編碼直接報錯** — 這一條**比三者都嚴格**。QCA 不報錯（它把缺口當成未觀察組態），cna 不需要報錯（它根本不假設 0）。本套件即使底層已經修好，仍然報錯，理由是：
   - CORA 的**真值表列數**是 `prod(levels)`，非 0 編碼會讓真值表的意義變得難以解釋；
   - 標籤位移（`B{2}` 變 `B{1}`）如果悄悄發生，使用者對照文獻時會讀錯；
   - 報錯的成本是一行 `cora_recode()`，算錯的成本是一篇論文。

---

## 附錄 C：內建資料集沒有變項定義

本套件附了四個資料集：`swiss_minaret`、`gross_carvin`、`mccluskey`、`bergschlosser`。它們原封不動取自 Python 版 CORA 的 `examples/` 目錄。

**必須說清楚的一點：上游的資料檔裡只有欄位縮寫，沒有任何變項定義。**

- `gross_carvin` 的 `LENG`、`UPSI`、`RISK`、`FRFL`、`MIMA`、`DOSI`、`PRIC`：Python 版沒有附說明哪個縮寫代表什麼、值 0/1/2 各自代表什麼。
- `swiss_minaret` 的 `L`、`T`、`S`、`A` 同理。
- `bergschlosser` 的欄位同理。

所以本套件的說明文件對這些資料集只做**結構性**的描述（幾個條件、幾個結果、多少列、取值範圍），不做實質詮釋。

**這對你的意義：**

- 這些資料集適合用來**學語法、驗證輸出、做效能測試**。
- **不適合拿來做實質推論或引用結論**——`LENG{2}` 在沒有定義的情況下不代表任何東西。
- 要對這些資料做實質分析，得回到原始文獻（`gross_carvin` 指向 Gross & Carvin 的侵權責任研究，`bergschlosser` 指向 Berg-Schlosser 的非洲國家研究），從那裡取得編碼簿。

用自己的資料時不會有這個問題：欄位是你自己編碼的，你知道每個值代表什麼——而這正是**你必須寫進論文**的東西（見 §4.4 第五步）。

---

## 附錄 D：作者、引用與責任

### D.1 為什麼原作者只掛 `cph`，不掛 `aut`

`DESCRIPTION` 的 `Authors@R` 是這樣寫的：

```r
person("Young", "Chan", role = c("aut", "cre", "cph"),
       comment = "Author of the R implementation"),
person("Zuzana", "Sebechlebská", role = "cph",
       comment = "Copyright holder of the original Python implementation"),
person("Lusine", "Mkrtchyan", role = "cph", ...),
person("Alrik", "Thiem", role = "cph", ...)
```

原作者列為 `cph`（著作權人）而**不是** `aut`（作者）。理由：

- 本套件是 GPL-3 衍生作品，原作者對其中衍生自 Python 版的部分**持有著作權**，這一點必須標示，`cph` 正是標示這件事的角色。
- 但 `aut` 在 CRAN 的慣例裡意味著**對這個套件的內容負責**。本套件在五個地方刻意偏離了 Python 版（附錄 A），原作者沒有參與這些判斷，也沒有機會審閱。把他們列為 `aut` 等於讓他們為自己不同意、甚至不知情的改動背書。
- 實務上還有一層：CRAN 審查有時會要求說明 `aut` 的貢獻內容。「他們寫了另一個語言的原版，我改了五個地方」不是 `aut` 的定義。

`DESCRIPTION` 的描述欄位因此以這句話結尾：

> It is an independent implementation and is not endorsed by the authors of the original packages.

`inst/NOTICE` 記錄完整的衍生關係與授權。

### D.2 引用順序

```r
citation("CORA")
```

會列出三筆，順序是：

1. **本套件**（以及後續發表的相關文章）
2. **CORA 方法論文**：Thiem, Mkrtchyan & Sebechlebská (2022), *BMC Medical Research Methodology*, 22(1), 333. doi:10.1186/s12874-022-01800-9
3. **原 Python 套件論文**：Sebechlebská, Mkrtchyan & Thiem (2023), *JOSS*, 8(85), 5019. doi:10.21105/joss.05019

**用 CORA 做分析，第 2 筆一定要引用**，不論用哪個軟體跑的——那是方法的來源。第 3 筆在你有實際用到 Python 版（例如用 `cora_compare_python()` 交叉驗證）時引用。

### D.3 一句話的責任分配

> 與 Python 版**相同**之處若有錯，那是共用的理論與方法的問題。
> 與 Python 版**不同**之處若有錯，責任在本套件，不在原作者。

README 開頭與附錄 A.8 都寫了這句話。這不只是客套——附錄 A 的五條每一條都附了原始碼位置和可重現的例子，就是為了讓這句話可以被檢驗。
