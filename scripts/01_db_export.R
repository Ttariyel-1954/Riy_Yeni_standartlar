# =============================================================================
# 01_db_export.R - Mövcud bazadan standartları köçürmək və referans data daxil etmək
# =============================================================================

library(DBI)
library(RPostgres)
library(dplyr)
library(jsonlite)

# .Renviron oxu
readRenviron("~/Desktop/Riy_standartlar/.Renviron")

cat("=== MƏRHƏLƏ 1: Verilənlər Bazasının Hazırlanması ===\n\n")

# --- Bağlantılar ---
source_con <- dbConnect(Postgres(),
  dbname = Sys.getenv("SOURCE_DB_NAME"),
  host = Sys.getenv("DB_HOST", "localhost"),
  port = as.integer(Sys.getenv("DB_PORT", "5432")),
  user = Sys.getenv("SOURCE_DB_USER", Sys.getenv("DB_USER"))
)

target_con <- dbConnect(Postgres(),
  dbname = Sys.getenv("DB_NAME"),
  host = Sys.getenv("DB_HOST", "localhost"),
  port = as.integer(Sys.getenv("DB_PORT", "5432")),
  user = Sys.getenv("DB_USER")
)

# --- Addım 1: Mövcud standartları köçür ---
cat("1. Mövcud standartlar köçürülür...\n")

subject_id <- Sys.getenv("SOURCE_SUBJECT_ID")

# Əsas standartları çək
standards <- dbGetQuery(source_con, sprintf("
  SELECT grade, standard_code, content_area, standard_text_az, bloom_level, keywords
  FROM curriculum_standards
  WHERE subject_id = '%s'
  ORDER BY grade, standard_code
", subject_id))

cat(sprintf("   Mənbə bazadan %d standart tapıldı (siniflər: %s)\n",
    nrow(standards), paste(sort(unique(standards$grade)), collapse=", ")))

# Məzmun xətti adlarını Azərbaycan dilinə çevir
content_area_map <- c(
  "ededler" = "Ədədlər və əməllər",
  "hendese" = "Həndəsə",
  "cebr" = "Cəbr",
  "statistika" = "Statistika və ehtimal",
  "olcme" = "Ölçmə"
)

if (nrow(standards) > 0) {
  movcud <- data.frame(
    sinif = standards$grade,
    standart_kodu = standards$standard_code,
    mezmun_xetti = ifelse(standards$content_area %in% names(content_area_map),
                          content_area_map[standards$content_area],
                          standards$content_area),
    standart_metni = standards$standard_text_az,
    alt_standart_kodu = NA_character_,
    alt_standart_metni = NA_character_,
    bloom_seviyyesi = standards$bloom_level,
    acarsozler = NA_character_,
    stringsAsFactors = FALSE
  )

  # Mövcud cədvəli təmizlə və yenidən yaz
  dbExecute(target_con, "DELETE FROM movcud_standartlar")
  dbWriteTable(target_con, "movcud_standartlar", movcud, append = TRUE, row.names = FALSE)
  cat(sprintf("   ✓ %d standart movcud_standartlar cədvəlinə yazıldı\n", nrow(movcud)))
} else {
  cat("   ⚠ Mənbə bazada riyaziyyat standartı tapılmadı\n")
}

# --- Addım 2: Beynəlxalq çərçivələri daxil et ---
cat("\n2. Beynəlxalq çərçivələr daxil edilir...\n")

frameworks <- data.frame(
  cerceve_adi = c(
    # TIMSS Məzmun sahələri
    rep("TIMSS", 8),
    # TIMSS Koqnitiv sahələr
    rep("TIMSS", 3),
    # PISA kateqoriyalar
    rep("PISA", 4),
    # PISA proseslər
    rep("PISA", 3),
    # NCTM
    rep("NCTM", 5),
    # Bloom
    rep("Bloom", 6),
    # STEAM
    rep("STEAM", 4)
  ),
  kateqoriya = c(
    # TIMSS Məzmun
    "Ədədlər", "Ədədlər", "Cəbr", "Cəbr", "Həndəsə", "Həndəsə", "Verilənlər və ehtimal", "Verilənlər və ehtimal",
    # TIMSS Koqnitiv
    "Bilmə (Knowing)", "Tətbiq etmə (Applying)", "Mühakimə yürütmə (Reasoning)",
    # PISA kateqoriya
    "Kəmiyyət", "Qeyri-müəyyənlik və verilənlər", "Dəyişmə və münasibətlər", "Məkan və forma",
    # PISA proses
    "Formulate", "Employ", "Interpret",
    # NCTM
    "Problem Solving", "Reasoning and Proof", "Communication", "Connections", "Representation",
    # Bloom
    "Yadda saxlama", "Anlama", "Tətbiq", "Təhlil", "Qiymətləndirmə", "Yaratma",
    # STEAM
    "Science+Math", "Technology+Math", "Engineering+Math", "Arts+Math"
  ),
  alt_kateqoriya = c(
    "Tam ədədlər", "Kəsrlər və onluq kəsrlər", "Nümunələr və tənliklər", "Funksiyalar",
    "Fiqurlar və ölçmə", "Koordinat həndəsə", "Statistika", "Ehtimal",
    NA, NA, NA,
    NA, NA, NA, NA,
    NA, NA, NA,
    NA, NA, NA, NA, NA,
    NA, NA, NA, NA, NA, NA,
    NA, NA, NA, NA
  ),
  tesvir = c(
    "Tam ədədlər, kəsrlər, onluq kəsrlər, nisbətlər, faizlər üzərində əməllər",
    "Kəsr anlayışı, onluq kəsrlər, nisbət və proporsiya",
    "Nümunələr, tənliklər, bərabərsizliklər anlayışları",
    "Funksiya anlayışı, xətti və qeyri-xətti funksiyalar",
    "Həndəsi fiqurlar, xassələr, perimetr, sahə, həcm",
    "Koordinat müstəvisi, transformasiyalar, simmetriya",
    "Verilənlərin toplanması, təqdimatı, orta, median, moda",
    "Ehtimal anlayışı, sadə və mürəkkəb hadisələr",
    "Faktları, prosedurları, anlayışları bilmək — 35%",
    "Həll etmə, modelləşdirmə, təmsil etmə — 40%",
    "Təhlil, ümumiləşdirmə, əsaslandırma — 25%",
    "Ədədlər, əməllər, faizlər, nisbətlər kontekstdə",
    "Statistika, diaqramlar, ehtimal, qeyri-müəyyənlik",
    "Funksiyalar, tənliklər, dəyişmə sürəti",
    "Həndəsə, məkan, forma, ölçmə",
    "Real həyat vəziyyətini riyazi dildə ifadə etmə",
    "Riyazi alətləri və prosedurları tətbiq etmə",
    "Riyazi nəticələri real həyat kontekstində şərh etmə",
    "Problemin həlli strategiyaları",
    "Mühakimə yürütmə və isbat etmə bacarığı",
    "Riyazi fikirləri kommunikasiya etmə bacarığı",
    "Fənlər arası və fəndaxili əlaqələr qurmaq",
    "Riyazi fikirləri qrafik, cədvəl, formula ilə təmsil etmək",
    "Formulları, faktları, terminləri bilmək",
    "Anlayışları izah etmək, nümunə göstərmək",
    "Standart məsələləri həll etmək",
    "Çoxaddımlı məsələləri təhlil etmək, strategiya seçmək",
    "Həll yollarını müqayisə etmək, optimal seçmək",
    "Yeni məsələ qurmaq, model yaratmaq, layihə hazırlamaq",
    "Təbiət elmləri ilə riyaziyyat inteqrasiyası",
    "Texnologiya, proqramlaşdırma, alqoritmik düşüncə",
    "Mühəndislik düşüncəsi, konstruksiya, optimallaşdırma",
    "İncəsənət, dizayn, vizuallaşdırma ilə riyaziyyat"
  ),
  sinif_araligi = c(
    "1-11", "1-11", "3-11", "7-11", "1-11", "5-11", "1-11", "5-11",
    "1-11", "1-11", "1-11",
    "9-11", "9-11", "9-11", "9-11",
    "9-11", "9-11", "9-11",
    "1-11", "1-11", "1-11", "1-11", "1-11",
    "1-11", "1-11", "1-11", "5-11", "7-11", "9-11",
    "1-6", "1-6", "1-6", "1-6"
  ),
  koqnitiv_seviyye = c(
    NA, NA, NA, NA, NA, NA, NA, NA,
    "Bilmə", "Tətbiq", "Mühakimə",
    NA, NA, NA, NA,
    "Formulate", "Employ", "Interpret",
    NA, NA, NA, NA, NA,
    "Yadda saxlama", "Anlama", "Tətbiq", "Təhlil", "Qiymətləndirmə", "Yaratma",
    NA, NA, NA, NA
  ),
  faiz_ceki = c(
    NA, NA, NA, NA, NA, NA, NA, NA,
    35, 40, 25,
    NA, NA, NA, NA,
    NA, NA, NA,
    NA, NA, NA, NA, NA,
    NA, NA, NA, NA, NA, NA,
    NA, NA, NA, NA
  ),
  stringsAsFactors = FALSE
)

dbExecute(target_con, "DELETE FROM beynelxalq_cerceveler")
dbWriteTable(target_con, "beynelxalq_cerceveler", frameworks, append = TRUE, row.names = FALSE)
cat(sprintf("   ✓ %d beynəlxalq çərçivə yazıldı\n", nrow(frameworks)))

# --- Addım 3: Ölkə standartlarını daxil et ---
cat("\n3. Ölkə standartları daxil edilir...\n")

countries <- data.frame(
  olke_adi = c(
    # Sinqapur
    rep("Sinqapur", 5),
    # Finlandiya
    rep("Finlandiya", 5),
    # Yaponiya
    rep("Yaponiya", 5),
    # Cənubi Koreya
    rep("Cənubi Koreya", 5),
    # Estoniya
    rep("Estoniya", 5),
    # Kanada
    rep("Kanada", 5)
  ),
  sinif = c(
    # Sinqapur: ibtidai-orta üzrə
    2, 4, 6, 8, 10,
    2, 4, 6, 8, 10,
    2, 4, 6, 8, 10,
    2, 4, 6, 8, 10,
    2, 4, 6, 8, 10,
    2, 4, 6, 8, 10
  ),
  mezmun_sahesi = rep(c("Ədədlər", "Ədədlər+Həndəsə", "Cəbr+Həndəsə", "Cəbr+Funksiyalar", "Ali riyaziyyat"), 6),
  standart_xulasesi = c(
    # Sinqapur
    "CPA yanaşması: Concrete (əşyalarla) → Pictorial (şəkillərlə) → Abstract. Bar modeli ilə məsələ həlli. Ədəd bağları (number bonds).",
    "Kəsrlər bar modeli ilə, çoxrəqəmli vurma/bölmə, həndəsi fiqurların xassələri, sahə anlayışı.",
    "Nisbət/proporsiya, faiz, cəbri ifadələr, bucaqlar, simmetriya, verilənlər təhlili.",
    "Xətti tənliklər sistemi, Pifaqor teoremi, ehtimal, statistik göstəricilər.",
    "Triqonometriya, loqarifm, diferensial/inteqral anlayışları, matris əsasları.",
    # Finlandiya
    "Oyun əsaslı öyrənmə, ədəd hissi inkişafı, sadə toplama/çıxma, həndəsi formalar.",
    "Problem əsaslı öyrənmə, vurma/bölmə, kəsrlər başlanğıcı, ölçmə, verilənlər.",
    "Mənfi ədədlər, faiz, cəbr başlanğıcı, koordinat müstəvisi, statistika.",
    "Tənliklər, funksiyalar, həndəsə isbatları, ehtimal, modelləşdirmə.",
    "Diferensial hesab, vektor, matris, riyazi modelləşdirmə, tətbiqi riyaziyyat.",
    # Yaponiya
    "Bansho (lövhə planlaşdırması), Lesson Study, ədədlər üzrə dərin anlama, ölçmə.",
    "Kəsrlər, onluq ədədlər, bucaqlar, sahə, həcm, verilənlər oxuma.",
    "Nisbət, proporsiya, simmetriya, cəbri ifadələr, dairə, statistik tədqiqat.",
    "Xətti funksiyalar, Pifaqor, oxşarlıq, ehtimal, riyazi isbat başlanğıcı.",
    "Triqonometrik funksiyalar, ardıcıllıq, limit, diferensial, inteqral.",
    # Cənubi Koreya
    "Rigoroz ədəd öyrənmə, toplama/çıxma, uzunluq/çəki ölçmə, həndəsi formalar.",
    "Böyük ədədlər, kəsrlər, vurma alqoritmləri, bucaq, sahə, diaqramlar.",
    "Rasional ədədlər, tənasüb, dairə, simmetriya, cəbri ifadələr, ehtimal başlanğıcı.",
    "Funksiyalar, tənliklər sistemi, həndəsi transformasiyalar, statistik təhlil.",
    "Limit, törəmə, inteqral, ehtimal paylanması, vektor, matris.",
    # Estoniya
    "Rəqəmsal alətlərlə ədəd öyrənmə, sadə hesab, fiqurlar tanıma, ölçmə.",
    "Kəsrlər, onluq ədədlər, perimetr/sahə, verilənlər oxuma, proqramlaşdırma əsasları.",
    "Mənfi ədədlər, faiz, koordinat, simmetriya, cəbr, kompüter düşüncəsi.",
    "Funksiyalar, tənliklər, ehtimal, rəqəmsal riyaziyyat, modelləşdirmə.",
    "Ali cəbr, triqonometriya, diferensial/inteqral, alqoritmik düşüncə.",
    # Kanada
    "Çoxmədəniyyətli kontekst, ədəd hissi, toplama/çıxma, formaları tanıma, nümunələr.",
    "Vurma/bölmə, kəsrlər başlanğıcı, perimetr, sahə, verilənlər, tənqidi düşüncə.",
    "Rasional ədədlər, nisbət, faiz, simmetriya, cəbr, real həyat məsələləri.",
    "Xətti/qeyri-xətti funksiyalar, həndəsə, ehtimal, statistika, real kontekst.",
    "Ali funksiyalar, kalkulus, vektor, riyazi modelləşdirmə, tətbiqi riyaziyyat."
  ),
  guclu_terefler = c(
    rep("CPA yanaşması, bar modeli, dərin anlama, rigoroz kurikulum", 5),
    rep("Problem əsaslı, şagirdyönümlü, oyun əsaslı, az test-çox düşüncə", 5),
    rep("Lesson Study, Bansho, strukturlaşdırılmış problem həlli", 5),
    rep("Rigoroz kurikulum, texnologiya inteqrasiyası, yüksək gözləntilər", 5),
    rep("Rəqəmsal təhsil, post-sovet transformasiya, balanslaşdırılmış yanaşma", 5),
    rep("Çoxmədəniyyətli, inklüziv, tənqidi düşüncə, real həyat konteksti", 5)
  ),
  timss_pisa_reytinqi = c(
    rep("TIMSS & PISA #1-2", 5),
    rep("PISA Top 10", 5),
    rep("TIMSS Top 5", 5),
    rep("TIMSS & PISA Top 5", 5),
    rep("PISA Top 5 (Avropa lideri)", 5),
    rep("PISA Top 10", 5)
  ),
  stringsAsFactors = FALSE
)

dbExecute(target_con, "DELETE FROM olke_standartlari")
dbWriteTable(target_con, "olke_standartlari", countries, append = TRUE, row.names = FALSE)
cat(sprintf("   ✓ %d ölkə standartı yazıldı\n", nrow(countries)))

# --- Yekun ---
cat("\n=== Mərhələ 1 tamamlandı ===\n")
cat(sprintf("Mövcud standartlar: %s\n", dbGetQuery(target_con, "SELECT COUNT(*) FROM movcud_standartlar")[[1]]))
cat(sprintf("Beynəlxalq çərçivələr: %s\n", dbGetQuery(target_con, "SELECT COUNT(*) FROM beynelxalq_cerceveler")[[1]]))
cat(sprintf("Ölkə standartları: %s\n", dbGetQuery(target_con, "SELECT COUNT(*) FROM olke_standartlari")[[1]]))

dbDisconnect(source_con)
dbDisconnect(target_con)
