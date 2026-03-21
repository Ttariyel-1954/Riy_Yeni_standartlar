# Riyaziyyat Standartlarının Yenilənməsi Layihəsi

[![Binder](https://mybinder.org/badge_logo.svg)](https://mybinder.org/v2/gh/Ttariyel-1954/Riy_Yeni_standartlar/HEAD?urlpath=shiny/app.R/)

Bu layihə Azərbaycan Respublikasında 1-11-ci siniflər üzrə **Riyaziyyat** fənninin mövcud standart və alt standartlarını beynəlxalq tələblərə uyğun yeniləmək, təkmilləşdirmək və yeni standartlar əlavə etmək üçün nəzərdə tutulub.

---

## Layihənin Məqsədi

Riyaziyyat kurikulumunun mövcud standartları aşağıdakı beynəlxalq çərçəvələr əsasında təhlil edilir, müqayisə olunur və yenilənir:

- **TIMSS** — Riyaziyyat qiymətləndirmə çərçəvəsi (Bilmə, Tətbiq etmə, Mühakimə yürütmə)
- **PISA** — Riyazi savadlılıq (Formulə etmə, Tətbiq etmə, İnterpretasiya, Mühakimə)
- **NCTM** — Riyaziyyat standartları (ABŞ Riyaziyyat Müəllimləri Milli Şurası)
- **Bloom Taksonomiyası** — Xatırlama → Anlama → Tətbiq → Analiz → Qiymətləndirmə → Yaratma

Həmçinin **6 aparıcı ölkənin** riyaziyyat standartları ilə müqayisə aparılır:

| Ölkə | Xüsusi yanaşma |
|------|---------------|
| Sinqapur | Singapore Math, Bar Model, konseptual anlama |
| Finlandiya | Fənlərarası əlaqə, riyazi düşüncə, modelləşdirmə |
| Yaponiya | Dərin konseptual anlama, Lesson Study, riyazi kommunikasiya |
| Cənubi Koreya | Texnologiya inteqrasiyası, riyazi yaradıcılıq, vizuallaşdırma |
| Kanada (Ontario) | Kodlaşdırma və hesablama düşüncəsi, riyazi proses bacarıqları |
| Estoniya | Rəqəmsal alətlər, statistik düşüncə, ehtimal konseptləri |

---

## İş Axını

Layihə iki mərhələli iş axını ilə işləyir:

### Mərhələ 1: Təhlil et və Yaz
1. Sidebar-dan **sinif** (1-11) və **məzmun xətti** seçilir
2. **"Təhlil et və Yaz"** düyməsi basılır
3. Claude AI mövcud standartları TIMSS, PISA, NCTM, Bloom və 6 ölkə standartları əsasında təhlil edir
4. Hər standart üçün status təyin olunur:
   - **Mövcud** — standart beynəlxalq tələblərə uyğundur
   - **Yenilənib** (3-5 ədəd) — standart yenidən yazılıb, əsaslandırma ilə
   - **Silinib** — standart artıq lazım deyil (nadir)
5. Nəticə birbaşa PostgreSQL bazasına yazılır
6. HTML hesabat avtomatik `html_reports/` qovluğuna saxlanır

### Mərhələ 2: Yeni Standartlar Təklif Et
1. **"Yeni standartlar təklif et"** düyməsi basılır
2. Claude AI boşluqları müəyyən edib **maksimum 5** yeni standart təklif edir
3. Yeni standartlar `yeni` statusu ilə yekun cədvələ əlavə olunur
4. Hər sinif üçün fərqli say ola bilər

---

## Dashboard Tabları

### 1. Ana Səhifə
- Seçilmiş sinif üzrə value box-lar: **Ümumi, Mövcud, Yenilənib, Yeni, Silinib**
- Bütün siniflər üzrə yekun diaqram (stacked bar chart)
- Sidebar-da sinif və məzmun xətti dəyişdikdə bütün göstəricilər avtomatik yenilənir
- Layihə haqqında məlumat paneli

### 2. Mövcud Standartlar
- Orijinal, dəyişilməmiş standartların cədvəli
- 3 sütun: **Kod** (Riy_V_2.1 formatı), **Məzmun xətti**, **Standart mətni**
- Sinif və məzmun xətti filtri

### 3. Müqayisə
- Yalnız dəyişiklik olan standartları göstərir (mövcud olanlar gizlədilir)
- Köhnə standart (italik, boz) vs Yeni standart + Əsaslandırma
- Rəngli sətir: yaşıl (yenilənib), narıncı (yeni), qırmızı (silinib)

### 4. Beynəlxalq
- TIMSS/PISA/NCTM uyğunluq cədvəli
- 6 ölkə standartları (filtrlə)
- Bloom taksonomiyası paylanması diaqramı

### 5. Statistika
- Dəyişiklik növləri üzrə pie chart
- Məzmun xətləri üzrə bar chart
- Bloom səviyyələri üzrə qrafiklər
- Sinif üzrə status paylanması

### 6. Claude AI Təhlil
- **"Təhlil et və Yaz"** — mövcud standartları təhlil edib bazaya yazır
- **"Yeni standartlar təklif et"** — boşluqları doldurmaq üçün yeni standartlar əlavə edir
- Canlı taymer, token izləmə, xərc hesabı

### 7. Yekun Standartlar
- Tam yekun cədvəl: Kod, Məzmun xətti, Status, Standart, Əsaslandırma
- Rənglər: ağ (mövcud), yaşıl (yenilənib), narıncı (yeni), qırmızı (silinib)
- Sinif və status filtri
- **HTML export** — nəfis rəngli cədvəl

---

## Mövcud Standartlar Bazası

1-11-ci siniflər üzrə **238 alt standart**:

| Sinif | Kod formatı | Alt standart sayı |
|-------|-------------|-------------------|
| 1-ci sinif | Riy_I_... | 18 |
| 2-ci sinif | Riy_II_... | 19 |
| 3-cü sinif | Riy_III_... | 21 |
| 4-cü sinif | Riy_IV_... | 24 |
| 5-ci sinif | Riy_V_... | 20 |
| 6-cı sinif | Riy_VI_... | 24 |
| 7-ci sinif | Riy_VII_... | 24 |
| 8-ci sinif | Riy_VIII_... | 22 |
| 9-cu sinif | Riy_IX_... | 22 |
| 10-cu sinif | Riy_X_... | 22 |
| 11-ci sinif | Riy_XI_... | 22 |
| **YEKUN** | | **238** |

### Standart kodu formatı

```
Riy_V_2.1.3
│   │ │ │ └─ Alt standart nömrəsi (3-cü)
│   │ │ └─── Əsas standart nömrəsi (1-ci)
│   │ └───── Məzmun xətti nömrəsi (2 = Cəbr)
│   └─────── Sinif (V = 5-ci sinif, Roma rəqəmi)
└─────────── Fənn (Riyaziyyat)
```

**Məzmun xətti nömrələri:**
1. Ədədlər və əməllər
2. Cəbr
3. Həndəsə
4. Ölçmə
5. Statistika və ehtimal

---

## Texniki Stek

| Komponent | Texnologiya |
|-----------|-------------|
| Verilənlər bazası | PostgreSQL (`riy_standartlar`) |
| Backend/Analiz | R, Claude API (Anthropic) |
| Dashboard | R Shiny (shinydashboard) |
| AI Model | Claude Sonnet 4 (`claude-sonnet-4-20250514`) |
| Vizuallaşdırma | Plotly, DT |
| Hesabatlar | HTML5 |
| Port | 4568 |
| Dil | Azərbaycan dili (bütün interfeys və məzmun) |

---

## Verilənlər Bazası

### movcud_standartlar
Riyaziyyat kurikulumunun rəsmi standartları (238 ədəd).
- `standart_kodu` — Əsas standart kodu (Riy_V_1.1)
- `alt_standart_kodu` — Alt standart kodu (Riy_V_1.1.1)
- `sinif` — Sinif (1-11)
- `mezmun_xetti` — Məzmun xətti (Ədədlər, Cəbr, Həndəsə, Ölçmə, Statistika)
- `standart_metni` — Əsas standart mətni
- `alt_standart_metni` — Alt standart mətni
- `bloom_seviyyesi` — Bloom taksonomiya səviyyəsi

### yenilenmi_standartlar
AI tərəfindən təhlil olunmuş yekun standartlar.
- `standart_kodu`, `alt_standart_kodu` — Standart kodları
- `mezmun_xetti` — Məzmun xətti
- `deyisiklik_novu` — movcud / yenilenib / yeni / silinib
- `standart_metni` — Yekun standart mətni (yenilənmişdirsə, yeni mətn)
- `kohne_standart_metni` — Köhnə mətn (müqayisə üçün)
- `esaslandirma` — Əsaslandırma (beynəlxalq istinad)
- `bloom_seviyyesi` — Bloom taksonomiya səviyyəsi

---

## Layihə Strukturu

```
Riy_standartlar/
├── app.R                          # R Shiny dashboard (əsas fayl)
├── README.md                      # Bu fayl
├── .Renviron                      # Konfiqurasiya (git-ə daxil deyil)
├── .gitignore                     # Git ignore qaydaları
├── generate_standards.py          # 238 standart generasiya skripti
├── setup.sh                       # İlkin quraşdırma skripti
├── data/                          # Statik data faylları
├── html_reports/                  # AI təhlil nəticələri (HTML)
│   ├── sinif_1_*.html             # Hər sinif üçün hesabat
│   └── index.html                 # Ümumi index
├── word_reports/                  # Word/DOCX hesabatları
├── scripts/
│   ├── 01_db_export.R             # Bazadan standart köçürmə
│   ├── 02_update_standards.R      # Claude API ilə standart yeniləmə
│   ├── 02b_reparse.R             # JSON yenidən parse
│   ├── 03_generate_html.R        # HTML hesabat generasiyası
│   └── 04_generate_docx.R        # DOCX hesabat generasiyası
├── sql/
│   ├── schema.sql                 # PostgreSQL baza sxemi
│   └── seed_standards.sql         # 238 standart (ilkin data)
└── www/                           # Statik veb resursları
```

---

## Quraşdırma (Lokal)

### Tələblər
- R (>= 4.2)
- PostgreSQL (>= 14)
- R paketləri: shiny, shinydashboard, DBI, RPostgres, DT, httr, jsonlite, plotly, dplyr, htmltools, glue

### Addımlar

```bash
# 1. Repo-nu klonlayın
git clone https://github.com/Ttariyel-1954/Riy_Yeni_standartlar.git
cd Riy_Yeni_standartlar

# 2. R paketlərini quraşdırın
Rscript -e 'install.packages(c("shiny","shinydashboard","DBI","RPostgres","DT","httr","jsonlite","plotly","dplyr","htmltools","glue"))'

# 3. .Renviron faylını yaradın
cat > .Renviron << 'EOF'
DB_HOST=localhost
DB_PORT=5432
DB_NAME=riy_standartlar
DB_USER=your_username
CLAUDE_API_KEY=your_claude_api_key_here
EOF

# 4. PostgreSQL bazasını yaradın
createdb riy_standartlar
psql -U your_username -d riy_standartlar -f sql/schema.sql

# 5. İlkin standartları bazaya yükləyin (238 standart)
psql -U your_username -d riy_standartlar -f sql/seed_standards.sql

# 6. Dashboard-u işə salın
Rscript -e "shiny::runApp('app.R', port=4568, host='0.0.0.0')"
```

Brauzer: **http://localhost:4568**

---

## Binder ilə Onlayn İstifadə

Layihəni heç nə quraşdırmadan brauzerdə onlayn istifadə etmək üçün:

1. Aşağıdakı düyməyə basın:

   [![Binder](https://mybinder.org/badge_logo.svg)](https://mybinder.org/v2/gh/Ttariyel-1954/Riy_Yeni_standartlar/HEAD?urlpath=shiny/app.R/)

2. Binder mühiti yüklənənə qədər gözləyin (ilk dəfə 5-10 dəqiqə çəkə bilər)
3. Dashboard avtomatik açılacaq
4. Sidebar-dan sinif və məzmun xətti seçin
5. **"Təhlil et və Yaz"** düyməsi ilə AI təhlilini başladın

> **Qeyd:** Binder mühitində AI təhlil funksiyası yalnız `CLAUDE_API_KEY` konfiqurasiya edildikdə işləyir. Əks halda, yalnız mövcud standartlara və statik hesabatlara baxa bilərsiniz.

---

## İstifadə Qaydası (Addım-addım)

### Mövcud standartlara baxış
1. **Ana Səhifə** tabına keçin
2. Sidebar-da sinif seçin (1-11)
3. Value box-larda standart saylarını görün
4. Diaqramda bütün siniflərin statistikasını müşahidə edin

### Standartları təhlil etmək
1. Sidebar-da **sinif** və **məzmun xətti** seçin (məs: 5-ci sinif, Cəbr)
2. **"Claude AI Təhlil"** tabına keçin
3. **"Təhlil et və Yaz"** düyməsini basın
4. AI 60-90 saniyə ərzində standartları təhlil edəcək
5. Nəticə rəngli kartlarla göstəriləcək:
   - 🟢 **MOVCUDlar** — beynəlxalq tələblərə uyğun
   - 🟠 **YENİLƏNİBlər** — AI tərəfindən yenidən yazılıb
   - 🔴 **SİLİNİBlər** — artıq lazım deyil
6. Nəticə avtomatik bazaya yazılır

### Yeni standartlar əlavə etmək
1. Eyni sinif və məzmun xətti seçili ikən
2. **"Yeni standartlar təklif et"** düyməsini basın
3. AI boşluqları tapıb 3-5 yeni standart təklif edəcək
4. Yeni standartlar avtomatik bazaya əlavə olunacaq

### Nəticələrə baxış
- **Müqayisə** tabında köhnə vs yeni standartları müqayisə edin
- **Yekun Standartlar** tabında tam cədvəli görün
- **Statistika** tabında diaqramları araşdırın
- **Export** bölməsindən HTML hesabat yükləyin

---

## Onlayn Platformalar

| Platforma | Link |
|-----------|------|
| **GitHub** | [github.com/Ttariyel-1954/Riy_Yeni_standartlar](https://github.com/Ttariyel-1954/Riy_Yeni_standartlar) |
| **Binder** | [![Binder](https://mybinder.org/badge_logo.svg)](https://mybinder.org/v2/gh/Ttariyel-1954/Riy_Yeni_standartlar/HEAD?urlpath=shiny/app.R/) |

---

## Layihə Rəhbəri

**Talıbov Tariyel İsmayıl oğlu**
Riyaziyyat üzrə fəlsəfə doktoru
Azərbaycan Respublikası Təhsil İnstitutunun direktor müavini

**2026-cı il**

---

## Lisenziya

Bu layihə təhsil məqsədli istifadə üçün nəzərdə tutulub.
