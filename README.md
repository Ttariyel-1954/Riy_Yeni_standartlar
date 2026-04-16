# Riyaziyyat Standartlarının Yenilənməsi Layihəsi

[![Binder](https://mybinder.org/badge_logo.svg)](https://mybinder.org/v2/gh/Ttariyel-1954/Riy_Yeni_standartlar/HEAD?urlpath=shiny/app.R/)
[![R](https://img.shields.io/badge/R-4.2+-blue.svg)](https://www.r-project.org/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-14+-336791.svg)](https://www.postgresql.org/)
[![Claude](https://img.shields.io/badge/AI-Claude%20Sonnet%204-purple.svg)](https://www.anthropic.com/)

**Azərbaycan Respublikasında 1-11-ci siniflər üzrə Riyaziyyat fənninin mövcud 238 alt standartını beynəlxalq tələblərə uyğun təhlil edən, yeniləyən və təkmilləşdirən süni intellekt əsaslı R Shiny dashboard.**

---

## Mündəricat

- [Layihənin Məqsədi](#layihənin-məqsədi)
- [Beynəlxalq Çərçəvələr](#beynəlxalq-çərçəvələr)
- [İş Axını (2 Mərhələ)](#iş-axını-2-mərhələ)
- [Dashboard Tabları](#dashboard-tabları)
- [Mövcud Standartlar Bazası](#mövcud-standartlar-bazası)
- [Standart Kodu Formatı](#standart-kodu-formatı)
- [Texniki Stek](#texniki-stek)
- [Verilənlər Bazası Strukturu](#verilənlər-bazası-strukturu)
- [Layihə Strukturu](#layihə-strukturu)
- [Quraşdırma](#quraşdırma)
- [Git Repo-dan Bərpa Etmə](#git-repo-dan-bərpa-etmə)
- [İstifadə Qaydası](#i̇stifadə-qaydası)
- [Təhlükəsizlik](#təhlükəsizlik)
- [Onlayn Platformalar](#onlayn-platformalar)
- [Layihə Rəhbəri](#layihə-rəhbəri)

---

## Layihənin Məqsədi

Riyaziyyat kurikulumunun mövcud standartları aşağıdakı beynəlxalq çərçəvələr əsasında təhlil edilir, müqayisə olunur və yenilənir. Əsas məqsədlər:

- **Mövcud standartların təhlili** — 1-11-ci siniflərdə 238 alt standartın hər birini beynəlxalq riyaziyyat çərçəvələri əsasında qiymətləndirmək
- **Zəif standartların yenilənməsi** — müasir tələblərə cavab verməyən standartları Claude AI vasitəsilə yenidən yazmaq
- **Yeni standartların təklifi** — beynəlxalq praktikada olan, lakin Azərbaycan kurikulumunda əksini tapmayan standartları əlavə etmək (maksimum 5 yeni standart hər sinif üçün)
- **Şəffaf əsaslandırma** — hər dəyişikliyin TIMSS/PISA/NCTM istinadları ilə əsaslandırılması
- **Müqayisəli təhlil** — köhnə və yeni standartların yan-yana müqayisəsi

---

## Beynəlxalq Çərçəvələr

### TIMSS — Trends in International Mathematics and Science Study

Beynəlxalq riyaziyyat qiymətləndirmə çərçəvəsi (4-cü və 8-ci siniflər).

**Koqnitiv sahələr:**
- **Bilmə (Knowing)** — faktlar, prosedurlar, anlayışlar
- **Tətbiq etmə (Applying)** — riyazi alətlərin real situasiyalarda istifadəsi
- **Mühakimə yürütmə (Reasoning)** — tanış olmayan vəziyyətlərdə məntiqi düşüncə

**Məzmun sahələri:** Ədədlər, Cəbr, Həndəsə, Verilənlər və Ehtimal

### PISA — Riyazi Savadlılıq (Mathematical Literacy)

15 yaşlı şagirdlərin riyazi savadlılığını ölçür (9-10-cu siniflərə uyğundur).

**Proses kateqoriyaları:**
- **Formulə etmə** — real həyat situasiyalarını riyazi formaya gətirmək
- **Tətbiq etmə** — riyazi anlayış, fakt və prosedurları istifadə etmək
- **İnterpretasiya** — riyazi nəticələri kontekstə uyğun şərh etmək
- **Mühakimə yürütmə** — məntiqi arqumentləşdirmə

**PISA 2025 yenilikləri:** hesablama düşüncəsi (computational thinking), modelləşdirmə, riyazi ünsiyyət

### NCTM — Riyaziyyat Standartları (ABŞ Riyaziyyat Müəllimləri Milli Şurası)

**5 proses standartı:**
1. **Problemin həlli** (Problem Solving)
2. **Mühakimə yürütmə və sübut** (Reasoning and Proof)
3. **Ünsiyyət** (Communication)
4. **Əlaqələr** (Connections)
5. **Təqdimat** (Representation)

### Bloom Taksonomiyası (Yenilənmiş)

1. **Xatırlama** — düsturları, qaydaları yadda saxlama
2. **Anlama** — riyazi anlayışların mahiyyətini dərk etmə
3. **Tətbiq etmə** — tanış olmayan situasiyalarda istifadə
4. **Təhlil etmə** — mürəkkəb məsələləri komponentlərə ayırma
5. **Qiymətləndirmə** — həll yollarının effektivliyini qiymətləndirmə
6. **Yaratma** — yeni riyazi modellər və həll yolları qurma

### Aparıcı 6 Ölkənin Təcrübəsi

| Ölkə | Xüsusi yanaşma |
|------|----------------|
| **Sinqapur** | Singapore Math, Bar Model, konseptual anlama, CPA (Concrete-Pictorial-Abstract) |
| **Finlandiya** | Fənlərarası əlaqə, riyazi düşüncə, modelləşdirmə, problem əsaslı öyrənmə |
| **Yaponiya** | Dərin konseptual anlama, Lesson Study, riyazi kommunikasiya, tematik yanaşma |
| **Cənubi Koreya** | Texnologiya inteqrasiyası, riyazi yaradıcılıq, vizuallaşdırma |
| **Kanada (Ontario)** | Kodlaşdırma və hesablama düşüncəsi, riyazi proses bacarıqları |
| **Estoniya** | Rəqəmsal alətlər, statistik düşüncə, ehtimal konseptləri |

---

## İş Axını (2 Mərhələ)

### Mərhələ 1: Təhlil Et və Yaz

1. Sidebar-dan **sinif** (1-11) və **məzmun xətti** seçilir
2. **"Təhlil et və Yaz"** düyməsi basılır
3. Claude AI mövcud standartları TIMSS, PISA, NCTM, Bloom və 6 ölkə standartları əsasında təhlil edir
4. Hər standart üçün status təyin olunur:
   - 🟢 **Mövcud** — standart beynəlxalq tələblərə uyğundur
   - 🟠 **Yenilənib** (3-5 ədəd) — standart yenidən yazılıb, əsaslandırma ilə
   - 🔴 **Silinib** — standart artıq lazım deyil (nadir)
5. Nəticə birbaşa PostgreSQL bazasına yazılır
6. HTML hesabat avtomatik `html_reports/` qovluğuna saxlanır

### Mərhələ 2: Yeni Standartlar Təklif Et

1. **"Yeni standartlar təklif et"** düyməsi basılır
2. Claude AI boşluqları müəyyən edib **maksimum 5** yeni standart təklif edir
3. Yeni standartlar `yeni` statusu ilə yekun cədvələ əlavə olunur
4. Hər sinif üçün fərqli say ola bilər

---

## Dashboard Tabları

| Tab | Məzmun |
|-----|--------|
| **1. Ana Səhifə** | Value box-lar, ümumi statistika, stacked bar chart |
| **2. Mövcud Standartlar** | Orijinal 238 standartın cədvəli (Kod, Məzmun xətti, Mətn) |
| **3. Müqayisə** | Yalnız dəyişiklik olan standartlar, köhnə vs yeni yan-yana |
| **4. Beynəlxalq** | TIMSS/PISA/NCTM uyğunluq cədvəli + 6 ölkə standartları |
| **5. Statistika** | Plotly ilə interaktiv diaqramlar (pie, bar) |
| **6. Claude AI Təhlil** | 2 mərhələli iş axını + taymer + token izləmə |
| **7. Yekun Standartlar** | Tam yekun cədvəl + rəngli statuslar + HTML export |

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
| **YEKUN** |  | **238** |

**5 məzmun xətti:**
1. **Ədədlər və əməllər** — natural ədədlər, kəsrlər, onluq kəsrlər, faiz, nisbət
2. **Cəbr** — ifadələr, tənliklər, bərabərsizliklər, funksiyalar
3. **Həndəsə** — fiqurlar, bucaqlar, çevrə, koordinat həndəsə, transformasiyalar
4. **Ölçmə** — uzunluq, sahə, həcm, vaxt, kütlə, valyuta
5. **Statistika və ehtimal** — verilənlərin təhlili, orta göstəricilər, sadə ehtimal

---

## Standart Kodu Formatı

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
| **Proqramlaşdırma dili** | R (>= 4.2) |
| **Verilənlər bazası** | PostgreSQL (`riy_standartlar`) |
| **Veb interfeys** | R Shiny + shinydashboard |
| **Süni intellekt** | Claude API (Anthropic) — Claude Sonnet 4 |
| **İnteraktiv cədvəl** | DT (DataTables) |
| **Vizuallaşdırma** | Plotly (interaktiv diaqramlar) |
| **HTTP sorğular** | httr paketi |
| **JSON emal** | jsonlite paketi |
| **Port** | 4568 |
| **Dil** | Azərbaycan dili (bütün interfeys və məzmun) |

---

## Verilənlər Bazası Strukturu

Baza adı: `riy_standartlar`

### Əsas cədvəllər

#### 1. `movcud_standartlar` (238 sətir)
Riyaziyyat kurikulumunun rəsmi standartları.

**Əsas sütunlar:**
- `standart_kodu` — Əsas standart kodu (məs: Riy_V_1.1)
- `alt_standart_kodu` — Alt standart kodu (məs: Riy_V_1.1.1)
- `sinif` — Sinif (1-11)
- `mezmun_xetti` — Məzmun xətti
- `standart_metni` — Əsas standart mətni
- `alt_standart_metni` — Alt standart mətni
- `bloom_seviyyesi` — Bloom taksonomiya səviyyəsi

#### 2. `yenilenmi_standartlar`
AI tərəfindən təhlil olunmuş yekun standartlar.

**Əsas sütunlar:**
- `deyisiklik_novu` — movcud / yenilenib / yeni / silinib
- `kohne_standart_metni` — Köhnə mətn (müqayisə üçün)
- `esaslandirma` — Əsaslandırma (TIMSS/PISA/NCTM istinadı ilə)
- `bloom_seviyyesi` — Bloom taksonomiya səviyyəsi

---

## Layihə Strukturu

```
Riy_standartlar/
├── app.R                          # R Shiny dashboard (əsas fayl, ~124KB)
├── README.md                      # Bu fayl
├── .Renviron                      # Konfiqurasiya (git-ə daxil deyil)
├── .gitignore                     # Git ignore qaydaları
├── generate_standards.py          # 238 standart generasiya skripti
├── test_api.py                    # Claude API test skripti
├── setup.sh                       # İlkin quraşdırma skripti
├── install.R                      # R paketlərinin quraşdırılması
├── runtime.txt                    # R versiyası (Binder üçün)
├── data/                          # Data faylları
├── html_reports/                  # AI təhlil nəticələri (HTML)
│   ├── sinif_1_*.html             # Hər sinif üçün hesabat
│   └── index.html                 # Ümumi index
├── word_reports/                  # Word/DOCX hesabatları
├── scripts/
│   ├── 01_db_export.R             # Bazadan standart köçürmə
│   ├── 02_update_standards.R      # Claude API ilə standart yeniləmə
│   ├── 02b_reparse.R              # JSON yenidən parse
│   ├── 03_generate_html.R         # HTML hesabat generasiyası
│   └── 04_generate_docx.R         # DOCX hesabat generasiyası
├── sql/
│   ├── schema.sql                 # PostgreSQL baza sxemi
│   └── seed_standards.sql         # 238 standart (ilkin data)
└── www/                           # Statik veb resursları
```

---

## Quraşdırma

### Tələblər

- **R** >= 4.2
- **PostgreSQL** >= 14
- **Anthropic API açarı** (Claude API)
- R paketləri: `shiny`, `shinydashboard`, `DBI`, `RPostgres`, `DT`, `httr`, `jsonlite`, `plotly`, `dplyr`, `htmltools`, `glue`

### Yeni quraşdırma (sıfırdan)

```bash
# 1. Repo-nu klonlayın
git clone https://github.com/Ttariyel-1954/Riy_Yeni_standartlar.git Riy_standartlar
cd Riy_standartlar

# 2. R paketlərini quraşdırın
Rscript install.R

# 3. .Renviron faylını yaradın
cat > .Renviron << 'EOF'
DB_HOST=localhost
DB_PORT=5432
DB_NAME=riy_standartlar
DB_USER=sizin_user_adiniz
CLAUDE_API_KEY=sk-ant-api03-SİZİN_AÇARINIZ
EOF

# 4. PostgreSQL bazasını yaradın
createdb riy_standartlar
psql -d riy_standartlar -f sql/schema.sql

# 5. İlkin standartları bazaya yükləyin (238 standart)
psql -d riy_standartlar -f sql/seed_standards.sql

# 6. Yoxlayın
psql -d riy_standartlar -c "SELECT sinif, COUNT(*) FROM movcud_standartlar GROUP BY sinif ORDER BY sinif;"

# 7. Dashboard-u işə salın
Rscript -e "shiny::runApp('app.R', port=4568, host='0.0.0.0')"
```

Brauzer: **http://localhost:4568**

Gözlənilən nəticə:
```
 sinif | count
-------+-------
     1 |    18
     2 |    19
     3 |    21
     4 |    24
     5 |    20
     6 |    24
     7 |    24
     8 |    22
     9 |    22
    10 |    22
    11 |    22
```

---

## Git Repo-dan Bərpa Etmə

Əgər lokal baza itibsə, GitHub repo-dan bərpa prosesi:

### Addım 1: Repo-nu klonlayın (əgər yoxdursa)

```bash
cd ~/projects/standards
git clone https://github.com/Ttariyel-1954/Riy_Yeni_standartlar.git Riy_standartlar
```

### Addım 2: Bazanı yaradın

```bash
cd ~/projects/standards/Riy_standartlar
createdb riy_standartlar
```

### Addım 3: Sxemi tətbiq edin

```bash
psql -d riy_standartlar -f sql/schema.sql
```

### Addım 4: 238 standartı yükləyin

```bash
psql -d riy_standartlar -f sql/seed_standards.sql
```

### Addım 5: `.Renviron` yaradın

```bash
cat > .Renviron << 'EOF'
DB_HOST=localhost
DB_PORT=5432
DB_NAME=riy_standartlar
DB_USER=sizin_user_adiniz
CLAUDE_API_KEY=sk-ant-api03-YENI-ACARI-YAZIN
EOF
```

### Addım 6: Yoxlayın və işə salın

```bash
psql -d riy_standartlar -c "SELECT COUNT(*) FROM movcud_standartlar;"
# Gözlənilən: 238

Rscript -e "shiny::runApp('app.R', port=4568)"
```

---

## İstifadə Qaydası

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
   - 🟢 **Mövcudlar** — beynəlxalq tələblərə uyğun
   - 🟠 **Yenilənmişlər** — AI tərəfindən yenidən yazılıb
   - 🔴 **Silinmişlər** — artıq lazım deyil
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

## Təhlükəsizlik

### API açarları
- **Heç vaxt** `.Renviron` faylını git-ə commit etməyin
- `.gitignore` faylı `.Renviron`-u avtomatik istisna edir
- API açarı sızırsa, dərhal [console.anthropic.com](https://console.anthropic.com) saytından **revoke** edin və yenisini yaradın
- API açarını söhbətlərdə, mesajlarda, və ya git-də heç vaxt paylaşmayın

### Baza şifrələri
- PostgreSQL şifrəsini güclü saxlayın
- Lokal development-də şifrəsiz `trust` autentifikasiya məqbuldur
- Production serverdə mütləq `scram-sha-256` istifadə edin

### Backup
- `sql/seed_standards.sql` faylı **238 standart**ın bərpa mənbəyidir — onu git-də saxlayın
- Hər AI təhlilindən sonra PostgreSQL dump alın:
  ```bash
  pg_dump riy_standartlar > backup_$(date +%Y%m%d).sql
  ```

---

## Onlayn Platformalar

| Platforma | Link |
|-----------|------|
| **GitHub** | [github.com/Ttariyel-1954/Riy_Yeni_standartlar](https://github.com/Ttariyel-1954/Riy_Yeni_standartlar) |
| **Binder** | [mybinder.org](https://mybinder.org/v2/gh/Ttariyel-1954/Riy_Yeni_standartlar/HEAD?urlpath=shiny/app.R/) |

---

## Nəticə

Bu layihə Azərbaycanın riyaziyyat kurikulum standartlarının beynəlxalq səviyyədə qiymətləndirilməsi və təkmilləşdirilməsi üçün güclü alətdir. Claude AI-nin analitik gücünü R Shiny-nin interaktiv interfeysi ilə birləşdirərək, TIMSS, PISA, NCTM və 6 aparıcı ölkənin praktikaları əsasında Azərbaycan riyaziyyat təhsilinin modernləşdirilməsinə əhəmiyyətli töhfə verir.

---

## Layihə Rəhbəri

**Talıbov Tariyel İsmayıl oğlu**
Riyaziyyat üzrə fəlsəfə doktoru
Azərbaycan Respublikası Təhsil İnstitutunun direktor müavini

**ARTI — 2026**

---

## Lisenziya

Bu layihə təhsil məqsədli istifadə üçün nəzərdə tutulub.
Azərbaycan Respublikası Elm və Təhsil Nazirliyi — ARTI
