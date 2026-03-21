# =============================================================================
# 02b_reparse.R - Jurnaldakı API cavablarını yenidən parse edib bazaya yaz
# + çatışmayan siniflər üçün yeni API sorğusu göndər
# =============================================================================

library(DBI)
library(RPostgres)
library(httr2)
library(jsonlite)
library(dplyr)
library(purrr)
library(glue)

readRenviron("~/Desktop/Riy_standartlar/.Renviron")

cat("=== Jurnaldan Re-parse + Çatışmayan Siniflər ===\n\n")

con <- dbConnect(Postgres(),
  dbname = Sys.getenv("DB_NAME"),
  host = Sys.getenv("DB_HOST", "localhost"),
  port = as.integer(Sys.getenv("DB_PORT", "5432")),
  user = Sys.getenv("DB_USER")
)

api_key <- Sys.getenv("CLAUDE_API_KEY")

# Köhnə nəticələri təmizlə
dbExecute(con, "DELETE FROM yenilenmi_standartlar")

# --- Parse funksiyası ---
parse_response <- function(text) {
  text <- gsub("```json\\s*", "", text)
  text <- gsub("```\\s*$", "", text)
  text <- trimws(text)

  start_pos <- regexpr("\\[", text)
  if (start_pos > 0) {
    end_pos <- max(gregexpr("\\]", text)[[1]])
    if (end_pos > start_pos) {
      text <- substr(text, start_pos, end_pos)
    }
  }

  parsed <- fromJSON(text, simplifyDataFrame = FALSE)

  bind_rows(lapply(parsed, function(item) {
    tibble(
      standart_kodu = as.character(item$standart_kodu %||% ""),
      mezmun_xetti = as.character(item$mezmun_xetti %||% ""),
      standart_metni = as.character(item$standart_metni %||% ""),
      deyisiklik_novu = as.character(item$deyisiklik_novu %||% "yeni"),
      kohne_standart_metni = as.character(item$kohne_standart_metni %||% NA_character_),
      bloom_seviyyesi = as.character(item$bloom_seviyyesi %||% ""),
      timss_elaqesi = if (!is.null(item$timss_elaqesi)) as.character(toJSON(item$timss_elaqesi, auto_unbox = TRUE)) else NA_character_,
      pisa_elaqesi = if (!is.null(item$pisa_elaqesi)) as.character(toJSON(item$pisa_elaqesi, auto_unbox = TRUE)) else NA_character_,
      esaslandirma = as.character(item$esaslandirma %||% NA_character_),
      istinad_olke = as.character(item$istinad_olke %||% NA_character_),
      steam_elaqesi = as.character(item$steam_elaqesi %||% NA_character_)
    )
  }))
}

# --- INSERT funksiyası ---
insert_standards <- function(con, sinif, df) {
  safe <- function(x) {
    if (is.null(x) || length(x) == 0) return("NULL")
    x <- as.character(x)
    if (is.na(x) || x == "" || x == "NA" || x == "null") return("NULL")
    val <- gsub("'", "''", x)
    sprintf("'%s'", val)
  }

  count <- 0
  for (i in seq_len(nrow(df))) {
    row <- df[i, ]

    timss_val <- if (!is.na(row$timss_elaqesi) && row$timss_elaqesi != "" && row$timss_elaqesi != "NA") {
      sprintf("'%s'::jsonb", gsub("'", "''", row$timss_elaqesi))
    } else "NULL"

    pisa_val <- if (!is.na(row$pisa_elaqesi) && row$pisa_elaqesi != "" && row$pisa_elaqesi != "NA") {
      sprintf("'%s'::jsonb", gsub("'", "''", row$pisa_elaqesi))
    } else "NULL"

    sql <- sprintf("INSERT INTO yenilenmi_standartlar (sinif, standart_kodu, mezmun_xetti, standart_metni, alt_standart_kodu, alt_standart_metni, deyisiklik_novu, kohne_standart_metni, bloom_seviyyesi, timss_elaqesi, pisa_elaqesi, esaslandirma, istinad_olke, steam_elaqesi) VALUES (%d, %s, %s, %s, NULL, NULL, %s, %s, %s, %s, %s, %s, %s, %s)",
      sinif,
      safe(row$standart_kodu),
      safe(row$mezmun_xetti),
      safe(row$standart_metni),
      safe(row$deyisiklik_novu),
      safe(row$kohne_standart_metni),
      safe(row$bloom_seviyyesi),
      timss_val,
      pisa_val,
      safe(row$esaslandirma),
      safe(row$istinad_olke),
      safe(row$steam_elaqesi)
    )

    tryCatch({
      dbExecute(con, sql)
      count <- count + 1
    }, error = function(e) {
      cat(sprintf("   ⚠ INSERT xətası (%s): %s\n", row$standart_kodu, e$message))
    })
  }
  count
}

# --- Addım 1: Jurnaldakı cavabları re-parse et ---
cat("1. Jurnaldakı API cavablarını re-parse edirik...\n")

journal <- dbGetQuery(con, "SELECT sinif, cavab_metni FROM tehlil_jurnali WHERE status = 'ugurlu' ORDER BY sinif")

parsed_siniflər <- c()
for (i in seq_len(nrow(journal))) {
  sinif <- journal$sinif[i]
  cavab <- journal$cavab_metni[i]

  tryCatch({
    df <- parse_response(cavab)
    n <- insert_standards(con, sinif, df)
    cat(sprintf("   ✓ Sinif %d: %d standart bazaya yazıldı\n", sinif, n))
    parsed_siniflər <- c(parsed_siniflər, sinif)
  }, error = function(e) {
    cat(sprintf("   ✗ Sinif %d: parse xətası — %s\n", sinif, e$message))
  })
}

# --- Addım 2: Çatışmayan siniflər üçün API sorğusu ---
catismayan <- setdiff(1:11, parsed_siniflər)
cat(sprintf("\n2. Çatışmayan siniflər: %s\n", paste(catismayan, collapse = ", ")))

if (length(catismayan) > 0 && api_key != "" && api_key != "sk-ant-xxxxx") {

  # Beynəlxalq məlumatlar
  frameworks_text <- dbGetQuery(con, "SELECT cerceve_adi, kateqoriya, alt_kateqoriya, tesvir, sinif_araligi, koqnitiv_seviyye, faiz_ceki FROM beynelxalq_cerceveler")
  frameworks_str <- paste(capture.output(print(frameworks_text, right = FALSE)), collapse = "\n")

  countries_text <- dbGetQuery(con, "SELECT olke_adi, sinif, mezmun_sahesi, standart_xulasesi, guclu_terefler FROM olke_standartlari")

  system_prompt <- "Sən Azərbaycan Respublikasının riyaziyyat kurikulum ekspertisən. Sənin vəzifən 1-11-ci siniflərin riyaziyyat standartlarını beynəlxalq tələblərə uyğun təhlil etmək və yeniləməkdir.

CAVABINI MÜTLƏQq JSON formatında ver. Başqa heç bir mətn əlavə etmə — YALNIZ JSON massivi. ```json bloku istifadə etmə.

Azərbaycan dilində yaz. Standart mətnləri qısa, dəqiq və ölçülə bilən olmalıdır.

Bloom taksonomiyası səviyyələri: yadda_saxlama, anlama, tetbiq, tehlil, qiymetlendirme, yaratma

Məzmun xətləri: Ədədlər və əməllər, Cəbr, Həndəsə, Ölçmə, Statistika və ehtimal, Rəqəmsal riyaziyyat"

  for (sinif in catismayan) {
    cat(sprintf("\n   Sinif %d üçün API sorğusu göndərilir...\n", sinif))

    movcud <- dbGetQuery(con, sprintf(
      "SELECT standart_kodu, mezmun_xetti, standart_metni, bloom_seviyyesi FROM movcud_standartlar WHERE sinif = %d ORDER BY standart_kodu", sinif
    ))

    has_existing <- nrow(movcud) > 0
    if (has_existing) {
      movcud_str <- paste(apply(movcud, 1, function(r) {
        sprintf("Kod: %s | Məzmun: %s | Mətn: %s | Bloom: %s", r["standart_kodu"], r["mezmun_xetti"], r["standart_metni"], r["bloom_seviyyesi"])
      }), collapse = "\n")
    } else {
      movcud_str <- "Bu sinif üçün mövcud standart yoxdur. Bütün standartlar yeni yaradılmalıdır."
    }

    sinif_olke <- if (sinif <= 3) countries_text[countries_text$sinif <= 4, ]
      else if (sinif <= 6) countries_text[countries_text$sinif %in% c(4, 6), ]
      else if (sinif <= 9) countries_text[countries_text$sinif %in% c(6, 8), ]
      else countries_text[countries_text$sinif %in% c(8, 10), ]
    olke_str <- paste(capture.output(print(sinif_olke, right = FALSE)), collapse = "\n")

    steam_note <- if (sinif <= 6) "\n\nVACİB: STEAM standartları əlavə et." else ""
    digital_note <- if (sinif >= 5) "\n\nVACİB: Rəqəmsal riyaziyyat / alqoritmik düşüncə standartı əlavə et." else ""

    user_prompt <- glue("
{sinif}-ci sinif riyaziyyat standartlarını təhlil et və tam yenilənmiş standart siyahısını hazırla.

MÖVCUD STANDARTLAR:
{movcud_str}

BEYNƏLXALQ ÇƏRÇƏVƏLƏR:
{frameworks_str}

ÖLKƏ STANDARTLARI:
{olke_str}
{steam_note}{digital_note}

TƏLİMATLAR:
1. Mövcud standartları qiymətləndir
2. Çatışmayan sahələr üçün yeni standartlar yarat
3. Standart sayı: ən azı 15, ən çox 30
4. Hər məzmun xətti üçün ən azı 2 standart
5. Bloom balansı olsun

CAVAB: YALNIZ JSON massivi (```json bloku yoxdur):
[
  {{
    \"standart_kodu\": \"R{sinif}.1.1\",
    \"mezmun_xetti\": \"Ədədlər və əməllər\",
    \"standart_metni\": \"...\",
    \"deyisiklik_novu\": \"movcud|yenilenib|yeni|silinib\",
    \"kohne_standart_metni\": \"köhnə mətn\",
    \"bloom_seviyyesi\": \"anlama\",
    \"timss_elaqesi\": {{\"sahe\": \"Ədədlər\", \"koqnitiv\": \"Bilmə\"}},
    \"pisa_elaqesi\": {{\"kateqoriya\": \"Kəmiyyət\", \"proses\": \"Employ\"}},
    \"esaslandirma\": \"...\",
    \"istinad_olke\": \"Sinqapur\",
    \"steam_elaqesi\": \"varsa\"
  }}
]
")

    resp <- tryCatch({
      request("https://api.anthropic.com/v1/messages") |>
        req_headers(
          "x-api-key" = api_key,
          "anthropic-version" = "2023-06-01",
          "content-type" = "application/json"
        ) |>
        req_body_json(list(
          model = "claude-sonnet-4-20250514",
          max_tokens = 8000,
          system = system_prompt,
          messages = list(list(role = "user", content = user_prompt))
        )) |>
        req_timeout(120) |>
        req_retry(max_tries = 3, backoff = ~ 5) |>
        req_perform()
    }, error = function(e) {
      cat(sprintf("   ✗ API xətası: %s\n", e$message))
      NULL
    })

    if (is.null(resp)) next

    body <- resp_body_json(resp)
    result_text <- body$content[[1]]$text

    # Jurnala yaz
    dbExecute(con, sprintf(
      "INSERT INTO tehlil_jurnali (sinif, addim, sorgu_metni, cavab_metni, token_sayi, status) VALUES (%d, 'A+B+C', '%s', '%s', %d, 'ugurlu')",
      sinif,
      substr(gsub("'", "''", user_prompt), 1, 1000),
      gsub("'", "''", result_text),
      (body$usage$input_tokens + body$usage$output_tokens)
    ))

    tryCatch({
      df <- parse_response(result_text)
      n <- insert_standards(con, sinif, df)
      cat(sprintf("   ✓ Sinif %d: %d standart bazaya yazıldı\n", sinif, n))
    }, error = function(e) {
      cat(sprintf("   ✗ Sinif %d parse xətası: %s\n", sinif, e$message))
    })

    Sys.sleep(2)
  }
}

# --- Yekun ---
cat("\n\n=== YEKUN STATİSTİKA ===\n")
final_stats <- dbGetQuery(con, "SELECT * FROM v_sinif_statistika")
print(final_stats)

total <- dbGetQuery(con, "SELECT COUNT(*) as cemi FROM yenilenmi_standartlar")
cat(sprintf("\nCəmi: %s standart\n", total$cemi))

dbDisconnect(con)
cat("\n=== Tamamlandı ===\n")
