# =============================================================================
# 02_update_standards.R - Claude API ilə standartları təhlil və yeniləmək
# Hər sinif üçün (1-11) 3 addım: təhlil, yeniləmə, yaratma
# =============================================================================

library(DBI)
library(RPostgres)
library(httr2)
library(jsonlite)
library(dplyr)
library(glue)
library(purrr)

readRenviron("~/Desktop/Riy_standartlar/.Renviron")

cat("=== MƏRHƏLƏ 2: Claude AI ilə Standartların Təhlili və Yenilənməsi ===\n\n")

# --- Bağlantı ---
con <- dbConnect(Postgres(),
  dbname = Sys.getenv("DB_NAME"),
  host = Sys.getenv("DB_HOST", "localhost"),
  port = as.integer(Sys.getenv("DB_PORT", "5432")),
  user = Sys.getenv("DB_USER")
)

api_key <- Sys.getenv("CLAUDE_API_KEY")
if (api_key == "" || api_key == "sk-ant-xxxxx") {
  stop("CLAUDE_API_KEY .Renviron faylında təyin edilməyib!")
}

# --- Yardımçı funksiyalar ---

call_claude <- function(system_prompt, user_prompt, sinif, addim) {
  cat(sprintf("   → Claude API çağırılır (sinif %d, addım %s)...\n", sinif, addim))

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
        messages = list(
          list(role = "user", content = user_prompt)
        )
      )) |>
      req_timeout(120) |>
      req_retry(max_tries = 3, backoff = ~ 5) |>
      req_perform()
  }, error = function(e) {
    cat(sprintf("   ✗ API xətası: %s\n", e$message))
    # Jurnala yaz
    dbExecute(con, sprintf(
      "INSERT INTO tehlil_jurnali (sinif, addim, sorgu_metni, status, xeta_mesaji) VALUES (%d, '%s', '%s', 'xeta', '%s')",
      sinif, addim, substr(gsub("'", "''", user_prompt), 1, 500), gsub("'", "''", e$message)
    ))
    return(NULL)
  })

  if (is.null(resp)) return(NULL)

  body <- resp_body_json(resp)
  result_text <- body$content[[1]]$text
  input_tokens <- body$usage$input_tokens
  output_tokens <- body$usage$output_tokens

  # Jurnala yaz
  dbExecute(con, sprintf(
    "INSERT INTO tehlil_jurnali (sinif, addim, sorgu_metni, cavab_metni, token_sayi, status) VALUES (%d, '%s', '%s', '%s', %d, 'ugurlu')",
    sinif, addim,
    substr(gsub("'", "''", user_prompt), 1, 1000),
    substr(gsub("'", "''", result_text), 1, 50000),
    input_tokens + output_tokens
  ))

  # JSON parse
  json_text <- result_text
  # ```json ... ``` blokundan JSON-u çıxar
  json_text <- gsub("```json\\s*", "", json_text)
  json_text <- gsub("```\\s*$", "", json_text)
  json_text <- trimws(json_text)

  # [ ... ] massivini tap (yeni sətirlərlə birlikdə)
  start_pos <- regexpr("\\[", json_text)
  if (start_pos > 0) {
    # Sonuncu ] mövqeyini tap
    end_pos <- max(gregexpr("\\]", json_text)[[1]])
    if (end_pos > start_pos) {
      json_text <- substr(json_text, start_pos, end_pos)
    }
  }

  tryCatch({
    parsed <- fromJSON(json_text, simplifyDataFrame = FALSE)
    # List of lists -> data.frame (nested JSON-ları string kimi saxla)
    df <- bind_rows(lapply(parsed, function(item) {
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
    df
  },
    error = function(e) {
      cat(sprintf("   ⚠ JSON parse xətası: %s\n", e$message))
      cat("   Cavab mətni:\n", substr(result_text, 1, 300), "\n")
      NULL
    }
  )
}

# --- Beynəlxalq çərçivə məlumatları ---
frameworks_text <- dbGetQuery(con, "SELECT cerceve_adi, kateqoriya, alt_kateqoriya, tesvir, sinif_araligi, koqnitiv_seviyye, faiz_ceki FROM beynelxalq_cerceveler")
frameworks_str <- paste(capture.output(print(frameworks_text, right = FALSE)), collapse = "\n")

countries_text <- dbGetQuery(con, "SELECT olke_adi, sinif, mezmun_sahesi, standart_xulasesi, guclu_terefler FROM olke_standartlari")
countries_str <- paste(capture.output(print(countries_text, right = FALSE)), collapse = "\n")

# --- Sistem promptu ---
system_prompt <- "Sən Azərbaycan Respublikasının riyaziyyat kurikulum ekspertisən. Sənin vəzifən 1-11-ci siniflərin riyaziyyat standartlarını beynəlxalq tələblərə uyğun təhlil etmək və yeniləməkdir.

CAVABINI MÜTLƏQq JSON formatında ver. Başqa heç bir mətn əlavə etmə — YALNIZ JSON massivi.

Azərbaycan dilində yaz. Standart mətnləri qısa, dəqiq və ölçülə bilən olmalıdır.

Bloom taksonomiyası səviyyələri: yadda_saxlama, anlama, tetbiq, tehlil, qiymetlendirme, yaratma

Məzmun xətləri: Ədədlər və əməllər, Cəbr, Həndəsə, Ölçmə, Statistika və ehtimal, Rəqəmsal riyaziyyat"

# --- Hər sinif üçün prosesi icra et ---
for (sinif in 1:11) {
  cat(sprintf("\n{'='*60}\n"))
  cat(sprintf("SİNİF %d - İşlənir...\n", sinif))
  cat(sprintf("{'='*60}\n"))

  # Bu sinifin mövcud standartlarını götür
  movcud <- dbGetQuery(con, sprintf(
    "SELECT standart_kodu, mezmun_xetti, standart_metni, bloom_seviyyesi FROM movcud_standartlar WHERE sinif = %d ORDER BY standart_kodu", sinif
  ))

  has_existing <- nrow(movcud) > 0

  if (has_existing) {
    movcud_str <- paste(apply(movcud, 1, function(r) {
      sprintf("Kod: %s | Məzmun: %s | Mətn: %s | Bloom: %s", r["standart_kodu"], r["mezmun_xetti"], r["standart_metni"], r["bloom_seviyyesi"])
    }), collapse = "\n")
    cat(sprintf("   Mövcud standart sayı: %d\n", nrow(movcud)))
  } else {
    movcud_str <- "Bu sinif üçün mövcud standart yoxdur. Bütün standartlar yeni yaradılmalıdır."
    cat("   Mövcud standart yoxdur — tam yeni yaradılacaq\n")
  }

  # Sinifə uyğun ölkə standartlarını seç
  sinif_olke <- countries_text
  if (sinif <= 3) {
    sinif_olke <- countries_text[countries_text$sinif <= 4, ]
  } else if (sinif <= 6) {
    sinif_olke <- countries_text[countries_text$sinif %in% c(4, 6), ]
  } else if (sinif <= 9) {
    sinif_olke <- countries_text[countries_text$sinif %in% c(6, 8), ]
  } else {
    sinif_olke <- countries_text[countries_text$sinif %in% c(8, 10), ]
  }
  olke_str <- paste(capture.output(print(sinif_olke, right = FALSE)), collapse = "\n")

  # STEAM kontekst (1-6-cı siniflər üçün)
  steam_note <- ""
  if (sinif <= 6) {
    steam_note <- "\n\nVACİB: Bu sinif üçün STEAM (Science+Technology+Engineering+Arts+Mathematics) yanaşması ilə ən azı 2 standart əlavə et. Fənlərarası əlaqə, layihə əsaslı öyrənmə, real həyat konteksti olmalıdır."
  }

  # Rəqəmsal riyaziyyat (5+ siniflər)
  digital_note <- ""
  if (sinif >= 5) {
    digital_note <- "\n\nVACİB: Rəqəmsal riyaziyyat / alqoritmik düşüncə üçün ən azı 1 standart əlavə et (məs: alqoritm qurma, nümunə tapma, sadə proqramlaşdırma elementləri)."
  }

  # =========== ADDIM A: TƏHLİL VƏ YENİLƏMƏ (birləşdirilmiş) ===========

  user_prompt_combined <- glue("
{sinif}-ci sinif riyaziyyat standartlarını təhlil et və tam yenilənmiş standart siyahısını hazırla.

MÖVCUD STANDARTLAR:
{movcud_str}

BEYNƏLXALQ ÇƏRÇƏVƏLƏR (TIMSS, PISA, NCTM, Bloom, STEAM):
{frameworks_str}

APARICI ÖLKƏ STANDARTLARI:
{olke_str}
{steam_note}{digital_note}

TƏLİMATLAR:
1. Mövcud standartları qiymətləndir — hansılar yaxşıdır (movcud), hansılar yenidən yazılmalıdır (yenilenib), hansılar silinməlidir (silinib)
2. Yenidən yazılan standartlar üçün yeni mətn, Bloom səviyyəsi, TIMSS/PISA əlaqəsi göstər
3. Çatışmayan sahələr üçün tam yeni standartlar yarat (yeni)
4. {sinif}-ci sinif üçün standart sayı: ən azı 15, ən çox 30 olsun
5. Hər məzmun xətti üçün ən azı 2 standart olmalıdır
6. Bloom səviyyələri balanslaşdırılmış olmalıdır

CAVAB FORMATI (YALNIZ JSON massivi, başqa mətn yoxdur):
[
  {{
    \"standart_kodu\": \"R{sinif}.1.1\",
    \"mezmun_xetti\": \"Ədədlər və əməllər\",
    \"standart_metni\": \"...\",
    \"deyisiklik_novu\": \"movcud|yenilenib|yeni|silinib\",
    \"kohne_standart_metni\": \"əvvəlki mətn (yalnız yenilenib/silinib üçün)\",
    \"bloom_seviyyesi\": \"anlama\",
    \"timss_elaqesi\": {{\"sahe\": \"Ədədlər\", \"koqnitiv\": \"Bilmə\"}},
    \"pisa_elaqesi\": {{\"kateqoriya\": \"Kəmiyyət\", \"proses\": \"Employ\"}},
    \"esaslandirma\": \"Niyə bu dəyişiklik edilib\",
    \"istinad_olke\": \"Sinqapur\",
    \"steam_elaqesi\": \"varsa\"
  }}
]
")

  result <- call_claude(system_prompt, user_prompt_combined, sinif, "A+B+C")

  if (is.null(result)) {
    cat(sprintf("   ✗ Sinif %d üçün nəticə alınmadı, keçilir.\n", sinif))
    next
  }

  # result artıq tibble/data.frame-dir
  df <- result

  if (is.null(df) || nrow(df) == 0) {
    cat(sprintf("   ⚠ Sinif %d üçün boş nəticə\n", sinif))
    next
  }

  cat(sprintf("   ✓ %d standart alındı\n", nrow(df)))

  # SQL-safe strings
  safe <- function(x) {
    if (is.null(x) || length(x) == 0) return("NULL")
    x <- as.character(x)
    if (is.na(x) || x == "" || x == "NA") return("NULL")
    val <- gsub("'", "''", x)
    sprintf("'%s'", val)
  }

  # Bazaya yaz
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

    tryCatch(dbExecute(con, sql), error = function(e) {
      cat(sprintf("   ⚠ INSERT xətası (sinif %d, %s): %s\n", sinif, row$standart_kodu, e$message))
    })
  }

  # Statistika
  stats <- dbGetQuery(con, sprintf(
    "SELECT deyisiklik_novu, COUNT(*) as say FROM yenilenmi_standartlar WHERE sinif = %d GROUP BY deyisiklik_novu", sinif
  ))
  cat("   Nəticə:\n")
  for (j in seq_len(nrow(stats))) {
    cat(sprintf("     %s: %s\n", stats$deyisiklik_novu[j], stats$say[j]))
  }

  # API rate limit üçün gözlə
  Sys.sleep(2)
}

# --- Yekun statistika ---
cat("\n\n=== YEKUN STATİSTİKA ===\n")
final_stats <- dbGetQuery(con, "SELECT * FROM v_sinif_statistika")
print(final_stats)

total <- dbGetQuery(con, "SELECT COUNT(*) as cemi, COUNT(*) FILTER (WHERE deyisiklik_novu = 'yeni') as yeni, COUNT(*) FILTER (WHERE deyisiklik_novu = 'yenilenib') as yenilenib FROM yenilenmi_standartlar")
cat(sprintf("\nCəmi: %s standart (%s yeni, %s yenilənmiş)\n", total$cemi, total$yeni, total$yenilenib))

dbDisconnect(con)
cat("\n=== Mərhələ 2 tamamlandı ===\n")
