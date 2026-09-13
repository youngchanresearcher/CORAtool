# CORA 使用說明書

Combinational Regularity Analysis（組合規律性分析）R 套件

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
#> #a, c, B
```

**兩種演算法**（`algorithm` 參數）：

| | `"ON-DC"`（預設） | `"ON-OFF"` |
|---|---|---|
| 全名 | 正例 + don't care | 正例 + 負例 |
| 來源 | 古典 Quine-McCluskey | McCluskey 修正版 |
| 做法 | 展開完整組態空間，移除負例後化簡 | 直接拿每個正例去對比所有負例 |
| 成本 | 條件多時較慢（空間隨條件數指數成長） | 只用觀察到的列，通常較快 |

**實務建議：兩者結果相同，優先用 `"ON-OFF"`。** 在本套件驗證用的 10 組配對資料上，兩種演算法產生的質蘊涵項與解**完全一致**。條件數多時 `"ON-OFF"` 明顯較快。

### 階段 ③ 質蘊涵項圖表

哪個質蘊涵項涵蓋了哪些真值表列：

```r
cora_pi_chart(ctx)
#>    0 1 3
#> #a 1 1 0
#> c  0 1 1
#> B  0 1 1
```

欄名是真值表中結果為正的列號（從 0 起算）。`#a` 涵蓋第 0、1 列；`c` 與 `B` 各涵蓋第 1、3 列。

第 0 列只有 `#a` 涵蓋 → `#a` 是**必要質蘊涵項**（essential prime implicant），任何解都必須包含它。這就是 `#` 前綴的意思。

### 階段 ④ Petrick 法求解

從圖表中找出所有**不可約解**（irredundant solution）——能涵蓋全部正例、且拿掉任何一項就涵蓋不全的質蘊涵項組合。

```r
cora_irredundant_sums(ctx)
#> M1: #a + c
#> M2: #a + B
```

**兩個解都同樣有效。** 這叫**模型歧義**（model ambiguity），是組態方法的常態現象，不是錯誤——資料本身不足以在這兩個解之間做出區分。誠實的做法是兩個都報告。

> 解的數量可能隨質蘊涵項圖表的大小呈指數成長。需要時可用 `max_depth` 限制解中質蘊涵項的最大個數。

### 階段 ⑤ 充分性統計量

```r
cora_pi_details(ctx)
#>   PI Cov.r Inc.   M1   M2
#> 1 #a  0.67    1 0.33 0.33
#> 2  c  0.67    1 0.33   NA
#> 3  B  0.67    1   NA 0.33

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
| 大寫字母 | 二元條件為 **1**（存在／高） | `A` |
| 小寫字母 | 二元條件為 **0**（不存在／低） | `a` |
| `X{v}` | 多值條件 X 的值為 v | `LENG{2}` |
| `*` | 邏輯乘（AND，連言） | `A*b*C` |
| `+` | 邏輯和（OR，選言） | `A*b + C` |
| `#` 前綴 | 必要質蘊涵項 | `#a` |
| `1` | 恆真（所有觀察到的組態都是正例） | `M1: #1` |

所以 `#LENG{2}*RISK{1} + #DOSI{1} + PRIC{0}` 讀作：

> 「LENG 為 2 **且** RISK 為 1」**或**「DOSI 為 1」**或**「PRIC 為 0」

前兩項是必要質蘊涵項。

### 4.2 敘述式

`cora_describe()` 依據分數把解翻譯成關係陳述：

```r
cora_describe(cora_irredundant_sums(ctx)[[1]])
#> "#a + c <=> OUT"
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
#> X: l*t + S
#> M: l*t + S + T
```

> 系統內的個別式子未必各自不可約，但**整個系統一定是不可約的**。這是 CORA 處理複雜效果的核心：它同時最佳化所有結果，而不是分開跑再拼起來。

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
cora_prime_implicants(ctx)   # #a, c, B
cora_pi_chart(ctx)           # 覆蓋矩陣
cora_irredundant_sums(ctx)   # M1: #a + c ; M2: #a + B
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
#> X: l*t + S
#> M: l*t + S + T

cora_solutions(mn)
#>   l*t S A*t A*L l T A Output System
#> 1   1 1   0   0 0 0 0      X      1
#> 2   1 1   0   0 0 1 0      M      1

cat(cora_describe(cora_irredundant_systems(mn)[[1]]))
#> ---- System 1 ----
#> l*t + S <=> X
#> l*t + S + T <=> M
```

`X` 與 `M` 共用 `l*t` 和 `S` 兩條路徑，`M` 另外多一條 `T`。

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

```r
# 直接畫解
cora_logigram(cora_irredundant_sums(tort)[[1]])

# 畫多結果系統
cora_logigram(cora_irredundant_systems(mn)[[1]])

# 直接給運算式
cora_logigram("A*B+c*A+b<=>F")
cora_logigram("A{1}*B{2}+C{0}<=>F")
cora_logigram(c("A{1}*B{2}+A{2}<=>F1", "A{1}+C{1}*B{2}<=>F2"))

# 換顏色
cora_logigram(sol, color_and = "#f3aea0", color_or = "#aed49c")

# 存檔
png("figure.png", 1100, 720, res = 130)
cora_logigram(sol)
dev.off()
```

**怎麼讀邏輯圖：**

- 左側直線 = 條件匯流排，每條一個條件
- 線上的小圓圈（泡泡）= 該字面被否定（小寫字母）
- 黃色方塊（右端半圓）= **AND 閘**，連言
- 藍色盾形 = **OR 閘**，選言
- 只有單一字面的項不經 AND 閘，直接連到 OR 閘
- 多結果時，OR 閘由上而下依結果宣告順序排列

`cora_dnf()` 可以把解轉成字串形式：

```r
cora_dnf(cora_irredundant_sums(ctx)[[1]])
#> "a+c<=>OUT"
```

> 恆真式（`1<=>OUT`）沒有兩層邏輯圖可畫，`cora_logigram()` 會明確報錯。

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
| `cora_python_available()` | 檢查 Python 版是否可用 |
| `cora_compare_python()` | 與 Python 版交叉比對 |

**內建資料集**：`swiss_minaret`（多結果）、`gross_carvin`（多值）、`mccluskey`（兩輸出開關函數）、`bergschlosser`（48 個非洲國家，多值、三結果）

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

---

## 8. 與 Python 版的差異

本套件移植自 PoliUniLu 的 Python 套件 `CORA` 與 `LOGIGRAM`。移植結果在其自身的測試與範例資料上逐一比對過：**真值表、質蘊涵項、覆蓋集、解集完全一致**（41 個情境、263 個比對欄位）。

三處刻意的差異：

1. **解的排序**：本套件用確定性排序（先短後長，同長度依字典序），所以 R 的 `M1` 未必是 Python 的 `M1`。**解的集合相同。**
2. **ON-OFF + 多結果時質蘊涵項的 inclusion 分數**：Python 版拿**全部**結果欄計算，導致同一個質蘊涵項在 ON-DC 和 ON-OFF 下分數不一致。本套件用該質蘊涵項自己的結果欄，兩種演算法因此一致。
3. **資料探勘中的恆真式**：唯一解是 `1` 的組合在本套件記為 0 解 0 分。Python 版原意相同，但其檢查永遠不會觸發。

這三處都是本套件自己的判斷，不是原作者的。

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

會列出三筆：本套件、CORA 方法論文、原 Python 套件論文。**使用 CORA 做分析時，方法論文一定要引用**，不論用哪個軟體跑的。

- Thiem, A., Mkrtchyan, L., & Sebechlebská, Z. (2022). Combinational Regularity Analysis (CORA) — a new method for uncovering complex causation in medical and health research. *BMC Medical Research Methodology*, 22(1), 333.
- Sebechlebská, Z., Mkrtchyan, L., & Thiem, A. (2023). CORA and LOGIGRAM: A duo of Python packages for Combinational Regularity Analysis (CORA). *Journal of Open Source Software*, 8(85), 5019.

授權：GPL (>= 3)，與原始實作相同。本套件為獨立實作，未經原 Python 套件作者背書。
