# =============================================================================
# 04_generate_docx.R - Word Sənəd Generasiyası
# Hər sinif üçün ayrı .docx + yekun sənəd
# =============================================================================

library(DBI)
library(RPostgres)
library(officer)
library(flextable)
library(dplyr)
library(jsonlite)

readRenviron("~/Desktop/Riy_standartlar/.Renviron")

cat("=== MƏRHƏLƏ 4: Word Sənəd Generasiyası ===\n\n")

con <- dbConnect(Postgres(),
  dbname = Sys.getenv("DB_NAME"),
  host = Sys.getenv("DB_HOST", "localhost"),
  port = as.integer(Sys.getenv("DB_PORT", "5432")),
  user = Sys.getenv("DB_USER")
)

output_dir <- path.expand("~/Desktop/Riy_standartlar/word_reports")
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

# --- Yardımçı funksiya: JSONB-dən mətn ---
json_to_text <- function(json_str) {
  if (is.na(json_str) || json_str == "" || json_str == "null") return("-")
  tryCatch({
    j <- fromJSON(json_str)
    paste(names(j), j, sep = ": ", collapse = ", ")
  }, error = function(e) "-")
}

# --- Sinif üçün Word sənəd yaratmaq ---
generate_docx <- function(sinif, standards, filename) {
  doc <- read_docx()

  # Başlıq
  doc <- doc |>
    body_add_par("Azərbaycan Respublikası Təhsil İnstitutu (ARTI)", style = "heading 1") |>
    body_add_par("Qiymətləndirmə, Təhlil və Monitorinq şöbəsi", style = "heading 2") |>
    body_add_par("") |>
    body_add_par(sprintf("Riyaziyyat Fənni Standartları — %d-%s Sinif",
      sinif, ifelse(sinif %in% 1:4, "ci", ifelse(sinif %in% 5:10, "cı", "ci"))),
      style = "heading 1") |>
    body_add_par("Yenilənmiş Versiya — Beynəlxalq Tələblərə Uyğun", style = "heading 2") |>
    body_add_par(sprintf("Tarix: %s", Sys.Date()), style = "Normal") |>
    body_add_par("")

  # Statistika
  stats <- standards |>
    count(deyisiklik_novu) |>
    rename(Status = deyisiklik_novu, Say = n)

  status_labels <- c("movcud" = "Mövcud", "yenilenib" = "Yenilənib", "yeni" = "Yeni", "silinib" = "Silinib")
  stats$Status <- ifelse(stats$Status %in% names(status_labels), status_labels[stats$Status], stats$Status)

  doc <- doc |>
    body_add_par("Statistika", style = "heading 2")

  ft_stats <- flextable(stats) |>
    set_header_labels(Status = "Status", Say = "Say") |>
    theme_vanilla() |>
    autofit()
  doc <- doc |>
    body_add_flextable(ft_stats) |>
    body_add_par("")

  # Məzmun xətləri üzrə standartlar
  mezmun_xetleri <- unique(standards$mezmun_xetti)

  for (mx in mezmun_xetleri) {
    doc <- doc |>
      body_add_par(mx, style = "heading 2")

    mx_data <- standards |>
      filter(mezmun_xetti == mx) |>
      mutate(
        Status = case_when(
          deyisiklik_novu == "movcud" ~ "Mövcud",
          deyisiklik_novu == "yenilenib" ~ "Yenilənib",
          deyisiklik_novu == "yeni" ~ "Yeni",
          deyisiklik_novu == "silinib" ~ "Silinib",
          TRUE ~ deyisiklik_novu
        ),
        Bloom = ifelse(is.na(bloom_seviyyesi), "-", bloom_seviyyesi),
        TIMSS = sapply(timss_elaqesi, json_to_text),
        PISA = sapply(pisa_elaqesi, json_to_text)
      ) |>
      select(
        Kod = standart_kodu,
        `Standart mətni` = standart_metni,
        Status,
        Bloom,
        TIMSS,
        PISA
      )

    ft <- flextable(mx_data) |>
      set_header_labels(
        Kod = "Kod",
        `Standart mətni` = "Standart mətni",
        Status = "Status",
        Bloom = "Bloom",
        TIMSS = "TIMSS",
        PISA = "PISA"
      ) |>
      theme_vanilla() |>
      fontsize(size = 9, part = "all") |>
      width(j = "Kod", width = 0.8) |>
      width(j = "Standart mətni", width = 3.5) |>
      width(j = "Status", width = 0.8) |>
      width(j = "Bloom", width = 0.8) |>
      width(j = "TIMSS", width = 1.2) |>
      width(j = "PISA", width = 1.2) |>
      # Yeni standartları sarı fon ilə
      bg(i = ~ Status == "Yeni", bg = "#FFF9C4") |>
      bg(i = ~ Status == "Yenilənib", bg = "#FFF3E0") |>
      autofit()

    doc <- doc |>
      body_add_flextable(ft) |>
      body_add_par("")
  }

  # Əsaslandırmalar (yenilənib və yeni standartlar üçün)
  changed <- standards |>
    filter(deyisiklik_novu %in% c("yenilenib", "yeni"), !is.na(esaslandirma), esaslandirma != "")

  if (nrow(changed) > 0) {
    doc <- doc |>
      body_add_par("Əsaslandırmalar", style = "heading 2")

    for (i in seq_len(nrow(changed))) {
      row <- changed[i, ]
      doc <- doc |>
        body_add_par(sprintf("%s (%s): %s",
          row$standart_kodu,
          ifelse(row$deyisiklik_novu == "yeni", "Yeni", "Yenilənib"),
          row$esaslandirma), style = "Normal")
    }
  }

  # Footer
  doc <- doc |>
    body_add_par("") |>
    body_add_par("ARTI — Azərbaycan Respublikası Təhsil İnstitutu, 2026", style = "Normal")

  print(doc, target = filename)
}

# --- Hər sinif üçün Word yarat ---
all_standards <- data.frame()

for (sinif in 1:11) {
  standards <- dbGetQuery(con, sprintf(
    "SELECT * FROM yenilenmi_standartlar WHERE sinif = %d ORDER BY standart_kodu", sinif
  ))

  if (nrow(standards) == 0) {
    cat(sprintf("Sinif %d: standart yoxdur, keçilir.\n", sinif))
    next
  }

  filename <- file.path(output_dir, sprintf("sinif_%02d_riy_standartlar.docx", sinif))
  generate_docx(sinif, standards, filename)
  cat(sprintf("   ✓ Sinif %d: %d standart → %s\n", sinif, nrow(standards), basename(filename)))

  # JSONB sütunlarını character-ə çevir (bind_rows uyğunsuzluğunu aradan qaldırmaq üçün)
  standards <- standards |>
    mutate(
      timss_elaqesi = as.character(timss_elaqesi),
      pisa_elaqesi = as.character(pisa_elaqesi)
    )
  all_standards <- bind_rows(all_standards, standards)
}

# --- Yekun sənəd (bütün siniflər) ---
if (nrow(all_standards) > 0) {
  cat("\nYekun sənəd yaradılır...\n")

  doc <- read_docx()
  doc <- doc |>
    body_add_par("Azərbaycan Respublikası Təhsil İnstitutu (ARTI)", style = "heading 1") |>
    body_add_par("Riyaziyyat Fənni Standartları — Yenilənmiş Versiya (1-11-ci Siniflər)", style = "heading 1") |>
    body_add_par(sprintf("Tarix: %s", Sys.Date()), style = "Normal") |>
    body_add_par("")

  # Ümumi statistika
  overall_stats <- all_standards |>
    count(deyisiklik_novu) |>
    rename(Status = deyisiklik_novu, Say = n)
  status_labels <- c("movcud" = "Mövcud", "yenilenib" = "Yenilənib", "yeni" = "Yeni", "silinib" = "Silinib")
  overall_stats$Status <- ifelse(overall_stats$Status %in% names(status_labels), status_labels[overall_stats$Status], overall_stats$Status)

  ft_overall <- flextable(overall_stats) |> theme_vanilla() |> autofit()
  doc <- doc |>
    body_add_par("Ümumi Statistika", style = "heading 2") |>
    body_add_flextable(ft_overall) |>
    body_add_par("")

  # Hər sinif
  for (sinif in 1:11) {
    s_data <- all_standards |> filter(sinif == !!sinif)
    if (nrow(s_data) == 0) next

    doc <- doc |>
      body_add_break() |>
      body_add_par(sprintf("%d-%s Sinif", sinif,
        ifelse(sinif %in% 1:4, "ci", ifelse(sinif %in% 5:10, "cı", "ci"))),
        style = "heading 1")

    ft <- s_data |>
      mutate(
        Status = case_when(
          deyisiklik_novu == "movcud" ~ "Mövcud",
          deyisiklik_novu == "yenilenib" ~ "Yenilənib",
          deyisiklik_novu == "yeni" ~ "Yeni",
          deyisiklik_novu == "silinib" ~ "Silinib",
          TRUE ~ deyisiklik_novu
        ),
        Bloom = ifelse(is.na(bloom_seviyyesi), "-", bloom_seviyyesi)
      ) |>
      select(Kod = standart_kodu, Məzmun = mezmun_xetti, Standart = standart_metni, Status, Bloom) |>
      flextable() |>
      theme_vanilla() |>
      fontsize(size = 9, part = "all") |>
      width(j = "Standart", width = 4) |>
      bg(i = ~ Status == "Yeni", bg = "#FFF9C4") |>
      bg(i = ~ Status == "Yenilənib", bg = "#FFF3E0") |>
      autofit()

    doc <- doc |> body_add_flextable(ft) |> body_add_par("")
  }

  doc <- doc |>
    body_add_par("") |>
    body_add_par("ARTI — Azərbaycan Respublikası Təhsil İnstitutu, 2026", style = "Normal")

  yekun_file <- file.path(output_dir, "yekun_butun_sinifler.docx")
  print(doc, target = yekun_file)
  cat(sprintf("   ✓ Yekun sənəd: %s\n", basename(yekun_file)))
}

dbDisconnect(con)
cat("\n=== Mərhələ 4 tamamlandı ===\n")
