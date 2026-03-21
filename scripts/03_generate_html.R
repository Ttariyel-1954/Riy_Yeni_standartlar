# =============================================================================
# 03_generate_html.R - HTML5 Hesabat Generasiyası
# Hər sinif üçün ayrı HTML + index.html
# =============================================================================

library(DBI)
library(RPostgres)
library(htmltools)
library(dplyr)
library(glue)
library(jsonlite)

readRenviron("~/Desktop/Riy_standartlar/.Renviron")

cat("=== MƏRHƏLƏ 3: HTML5 Hesabat Generasiyası ===\n\n")

con <- dbConnect(Postgres(),
  dbname = Sys.getenv("DB_NAME"),
  host = Sys.getenv("DB_HOST", "localhost"),
  port = as.integer(Sys.getenv("DB_PORT", "5432")),
  user = Sys.getenv("DB_USER")
)

output_dir <- "~/Desktop/Riy_standartlar/html_reports"
dir.create(path.expand(output_dir), showWarnings = FALSE, recursive = TRUE)

# --- CSS stili ---
css_style <- '
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body { font-family: "Segoe UI", Tahoma, Geneva, Verdana, sans-serif; background: #f5f5f5; color: #333; font-size: 16px; line-height: 1.6; }
  .container { max-width: 1200px; margin: 0 auto; padding: 20px; }
  header { background: linear-gradient(135deg, #2E7D32, #4CAF50); color: white; padding: 30px 20px; text-align: center; margin-bottom: 30px; border-radius: 12px; }
  header h1 { font-size: 28px; margin-bottom: 8px; }
  header h2 { font-size: 20px; font-weight: 400; opacity: 0.9; }
  .stats-panel { display: flex; gap: 15px; flex-wrap: wrap; margin-bottom: 25px; justify-content: center; }
  .stat-box { background: white; border-radius: 10px; padding: 15px 25px; text-align: center; box-shadow: 0 2px 8px rgba(0,0,0,0.1); min-width: 120px; }
  .stat-box .number { font-size: 28px; font-weight: 700; }
  .stat-box .label { font-size: 13px; color: #666; }
  .stat-cemi .number { color: #2E7D32; }
  .stat-movcud .number { color: #1976D2; }
  .stat-yenilenib .number { color: #F57F17; }
  .stat-yeni .number { color: #2E7D32; }
  .stat-silinib .number { color: #C62828; }
  .filters { display: flex; gap: 10px; flex-wrap: wrap; margin-bottom: 20px; justify-content: center; }
  .filter-btn { padding: 8px 18px; border: 2px solid #4CAF50; border-radius: 25px; background: white; color: #2E7D32; cursor: pointer; font-size: 14px; font-weight: 500; transition: all 0.2s; }
  .filter-btn:hover, .filter-btn.active { background: #4CAF50; color: white; }
  .cards { display: grid; gap: 20px; }
  .card { background: white; border-radius: 12px; padding: 20px; box-shadow: 0 2px 8px rgba(0,0,0,0.08); border-left: 5px solid #ccc; transition: transform 0.2s; }
  .card:hover { transform: translateY(-2px); box-shadow: 0 4px 16px rgba(0,0,0,0.12); }
  .card-yeni { border-left-color: #4CAF50; background: #f1f8e9; }
  .card-movcud { border-left-color: #1976D2; background: #e3f2fd; }
  .card-yenilenib { border-left-color: #F57F17; background: #fff8e1; }
  .card-silinib { border-left-color: #C62828; background: #ffebee; text-decoration: line-through; opacity: 0.7; }
  .card-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px; flex-wrap: wrap; gap: 8px; }
  .card-code { font-size: 18px; font-weight: 700; color: #2E7D32; }
  .card-badges { display: flex; gap: 6px; flex-wrap: wrap; }
  .badge { padding: 3px 10px; border-radius: 12px; font-size: 12px; font-weight: 600; }
  .badge-bloom { background: #E8EAF6; color: #283593; }
  .badge-status { color: white; }
  .badge-movcud { background: #1976D2; }
  .badge-yenilenib { background: #F57F17; }
  .badge-yeni { background: #4CAF50; }
  .badge-silinib { background: #C62828; }
  .badge-mezmun { background: #E0F2F1; color: #00695C; }
  .card-text { font-size: 16px; margin: 10px 0; }
  .card-old { background: #fff3e0; padding: 10px; border-radius: 8px; margin: 8px 0; font-size: 14px; color: #795548; }
  .card-old::before { content: "Köhnə: "; font-weight: 700; }
  .card-meta { display: flex; gap: 15px; flex-wrap: wrap; font-size: 13px; color: #666; margin-top: 10px; padding-top: 10px; border-top: 1px solid #eee; }
  .card-meta span { display: flex; align-items: center; gap: 4px; }
  .card-reason { font-size: 14px; color: #555; margin-top: 8px; font-style: italic; }
  footer { text-align: center; padding: 30px; color: #888; font-size: 13px; margin-top: 30px; }
  a { color: #2E7D32; text-decoration: none; }
  a:hover { text-decoration: underline; }
  .nav { display: flex; gap: 8px; flex-wrap: wrap; justify-content: center; margin-bottom: 20px; }
  .nav a { padding: 8px 16px; background: white; border-radius: 8px; box-shadow: 0 1px 4px rgba(0,0,0,0.1); font-weight: 500; }
  .nav a:hover { background: #4CAF50; color: white; text-decoration: none; }
  @media (max-width: 768px) {
    .container { padding: 10px; }
    header h1 { font-size: 22px; }
    .stat-box { min-width: 90px; padding: 10px 15px; }
    .stat-box .number { font-size: 22px; }
  }
</style>
'

# --- JavaScript (filtr) ---
js_script <- '
<script>
function filterCards(type, value) {
  const cards = document.querySelectorAll(".card");
  const buttons = document.querySelectorAll(".filter-btn[data-type=\'" + type + "\']");
  buttons.forEach(b => b.classList.remove("active"));
  event.target.classList.add("active");
  cards.forEach(card => {
    if (value === "all") { card.style.display = "block"; }
    else { card.style.display = card.dataset[type] === value ? "block" : "none"; }
  });
}
</script>
'

# --- Kart HTML generasiyası ---
generate_card_html <- function(row) {
  status_class <- paste0("card-", row$deyisiklik_novu)
  badge_class <- paste0("badge-", row$deyisiklik_novu)
  status_label <- switch(row$deyisiklik_novu,
    "movcud" = "Mövcud", "yenilenib" = "Yenilənib", "yeni" = "Yeni", "silinib" = "Silinib")

  old_text <- ""
  if (row$deyisiklik_novu == "yenilenib" && !is.na(row$kohne_standart_metni) && row$kohne_standart_metni != "") {
    old_text <- sprintf('<div class="card-old">%s</div>', htmlEscape(row$kohne_standart_metni))
  }

  timss_text <- ""
  if (!is.na(row$timss_elaqesi) && row$timss_elaqesi != "" && row$timss_elaqesi != "null") {
    timss <- tryCatch(fromJSON(row$timss_elaqesi), error = function(e) NULL)
    if (!is.null(timss)) {
      timss_text <- sprintf("TIMSS: %s / %s",
        ifelse(is.null(timss$sahe), "-", timss$sahe),
        ifelse(is.null(timss$koqnitiv), "-", timss$koqnitiv))
    }
  }

  pisa_text <- ""
  if (!is.na(row$pisa_elaqesi) && row$pisa_elaqesi != "" && row$pisa_elaqesi != "null") {
    pisa <- tryCatch(fromJSON(row$pisa_elaqesi), error = function(e) NULL)
    if (!is.null(pisa)) {
      pisa_text <- sprintf("PISA: %s / %s",
        ifelse(is.null(pisa$kateqoriya), "-", pisa$kateqoriya),
        ifelse(is.null(pisa$proses), "-", pisa$proses))
    }
  }

  reason_html <- ""
  if (!is.na(row$esaslandirma) && row$esaslandirma != "") {
    reason_html <- sprintf('<div class="card-reason">%s</div>', htmlEscape(row$esaslandirma))
  }

  country_text <- if (!is.na(row$istinad_olke) && row$istinad_olke != "") row$istinad_olke else ""
  steam_text <- if (!is.na(row$steam_elaqesi) && row$steam_elaqesi != "") row$steam_elaqesi else ""

  bloom_text <- if (!is.na(row$bloom_seviyyesi) && row$bloom_seviyyesi != "") row$bloom_seviyyesi else "-"

  meta_parts <- c()
  if (timss_text != "") meta_parts <- c(meta_parts, sprintf("<span>%s</span>", timss_text))
  if (pisa_text != "") meta_parts <- c(meta_parts, sprintf("<span>%s</span>", pisa_text))
  if (country_text != "") meta_parts <- c(meta_parts, sprintf("<span>Ölkə: %s</span>", htmlEscape(country_text)))
  if (steam_text != "") meta_parts <- c(meta_parts, sprintf("<span>STEAM: %s</span>", htmlEscape(steam_text)))
  meta_html <- if (length(meta_parts) > 0) sprintf('<div class="card-meta">%s</div>', paste(meta_parts, collapse = "")) else ""

  sprintf('
    <div class="card %s" data-status="%s" data-mezmun="%s">
      <div class="card-header">
        <span class="card-code">%s</span>
        <div class="card-badges">
          <span class="badge badge-mezmun">%s</span>
          <span class="badge badge-status %s">%s</span>
          <span class="badge badge-bloom">%s</span>
        </div>
      </div>
      <div class="card-text">%s</div>
      %s
      %s
      %s
    </div>',
    status_class, row$deyisiklik_novu, gsub(" ", "_", row$mezmun_xetti),
    htmlEscape(row$standart_kodu),
    htmlEscape(row$mezmun_xetti),
    badge_class, status_label,
    htmlEscape(bloom_text),
    htmlEscape(row$standart_metni),
    old_text, reason_html, meta_html
  )
}

# --- Hər sinif üçün HTML yarat ---
all_stats <- list()

for (sinif in 1:11) {
  standards <- dbGetQuery(con, sprintf(
    "SELECT * FROM yenilenmi_standartlar WHERE sinif = %d ORDER BY standart_kodu", sinif
  ))

  if (nrow(standards) == 0) {
    cat(sprintf("Sinif %d: standart yoxdur, keçilir.\n", sinif))
    next
  }

  # Statistika
  stats <- list(
    cemi = nrow(standards),
    movcud = sum(standards$deyisiklik_novu == "movcud"),
    yenilenib = sum(standards$deyisiklik_novu == "yenilenib"),
    yeni = sum(standards$deyisiklik_novu == "yeni"),
    silinib = sum(standards$deyisiklik_novu == "silinib")
  )
  all_stats[[as.character(sinif)]] <- stats

  # Məzmun xətləri
  mezmun_xetleri <- unique(standards$mezmun_xetti)

  # Filtr düymələri
  status_filters <- sprintf('
    <button class="filter-btn active" data-type="status" onclick="filterCards(\'status\', \'all\')">Hamısı</button>
    <button class="filter-btn" data-type="status" onclick="filterCards(\'status\', \'movcud\')">Mövcud (%d)</button>
    <button class="filter-btn" data-type="status" onclick="filterCards(\'status\', \'yenilenib\')">Yenilənib (%d)</button>
    <button class="filter-btn" data-type="status" onclick="filterCards(\'status\', \'yeni\')">Yeni (%d)</button>
    <button class="filter-btn" data-type="status" onclick="filterCards(\'status\', \'silinib\')">Silinib (%d)</button>',
    stats$movcud, stats$yenilenib, stats$yeni, stats$silinib)

  mezmun_filters <- paste(
    '<button class="filter-btn active" data-type="mezmun" onclick="filterCards(\'mezmun\', \'all\')">Hamısı</button>',
    paste(sapply(mezmun_xetleri, function(m) {
      sprintf('<button class="filter-btn" data-type="mezmun" onclick="filterCards(\'mezmun\', \'%s\')">%s</button>',
        gsub(" ", "_", m), m)
    }), collapse = "\n")
  )

  # Kartlar
  cards_html <- paste(sapply(seq_len(nrow(standards)), function(i) {
    generate_card_html(standards[i, ])
  }), collapse = "\n")

  # Naviqasiya
  nav_html <- paste(
    '<div class="nav">',
    paste(sapply(1:11, function(s) {
      if (s == sinif) sprintf('<a href="#" style="background:#4CAF50;color:white;">%d-ci sinif</a>', s)
      else sprintf('<a href="sinif_%02d_riy_standartlar.html">%d-%s sinif</a>', s, s, ifelse(s == 1, "ci", ifelse(s %in% c(2,3,4), "ci", ifelse(s %in% c(5,6,7,8,9,10), "cı", "ci"))))
    }), collapse = "\n"),
    '<a href="index.html">Ana Səhifə</a>',
    '</div>'
  )

  # Tam HTML
  html_content <- sprintf('<!DOCTYPE html>
<html lang="az">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>%d-%s Sinif - Riyaziyyat Standartları</title>
  %s
</head>
<body>
<div class="container">
  %s
  <header>
    <h1>%d-%s Sinif Riyaziyyat Standartları</h1>
    <h2>Yenilənmiş Versiya — Beynəlxalq Tələblərə Uyğun</h2>
  </header>

  <div class="stats-panel">
    <div class="stat-box stat-cemi"><div class="number">%d</div><div class="label">Cəmi</div></div>
    <div class="stat-box stat-movcud"><div class="number">%d</div><div class="label">Mövcud</div></div>
    <div class="stat-box stat-yenilenib"><div class="number">%d</div><div class="label">Yenilənib</div></div>
    <div class="stat-box stat-yeni"><div class="number">%d</div><div class="label">Yeni</div></div>
    <div class="stat-box stat-silinib"><div class="number">%d</div><div class="label">Silinib</div></div>
  </div>

  <h3 style="text-align:center;color:#555;margin-bottom:10px;">Status üzrə filtr:</h3>
  <div class="filters">%s</div>
  <h3 style="text-align:center;color:#555;margin-bottom:10px;">Məzmun xətti üzrə filtr:</h3>
  <div class="filters">%s</div>

  <div class="cards">%s</div>

  <footer>
    <p>ARTI — Azərbaycan Respublikası Təhsil İnstitutu</p>
    <p>Qiymətləndirmə, Təhlil və Monitorinq şöbəsi — 2026</p>
  </footer>
</div>
%s
</body>
</html>',
    sinif, ifelse(sinif == 1, "ci", ifelse(sinif %in% c(2,3,4), "ci", ifelse(sinif %in% c(5,6,7,8,9,10), "cı", "ci"))),
    css_style,
    nav_html,
    sinif, ifelse(sinif == 1, "ci", ifelse(sinif %in% c(2,3,4), "ci", ifelse(sinif %in% c(5,6,7,8,9,10), "cı", "ci"))),
    stats$cemi, stats$movcud, stats$yenilenib, stats$yeni, stats$silinib,
    status_filters, mezmun_filters, cards_html, js_script
  )

  filename <- sprintf("%s/sinif_%02d_riy_standartlar.html", path.expand(output_dir), sinif)
  writeLines(html_content, filename, useBytes = TRUE)
  cat(sprintf("   ✓ Sinif %d: %d standart → %s\n", sinif, nrow(standards), basename(filename)))
}

# --- Index.html ---
cat("\nIndex səhifəsi yaradılır...\n")

sinif_cards <- paste(sapply(1:11, function(sinif) {
  s <- all_stats[[as.character(sinif)]]
  if (is.null(s)) {
    sprintf('<a href="sinif_%02d_riy_standartlar.html" class="index-card" style="opacity:0.5">
      <h3>%d-ci sinif</h3><p>Standart yoxdur</p></a>', sinif, sinif)
  } else {
    sprintf('<a href="sinif_%02d_riy_standartlar.html" class="index-card">
      <h3>%d-%s sinif</h3>
      <div class="index-stats">
        <span style="color:#2E7D32">Cəmi: %d</span>
        <span style="color:#4CAF50">Yeni: %d</span>
        <span style="color:#F57F17">Yenilənib: %d</span>
      </div>
    </a>', sinif, sinif,
    ifelse(sinif == 1, "ci", ifelse(sinif %in% c(2,3,4), "ci", ifelse(sinif %in% c(5,6,7,8,9,10), "cı", "ci"))),
    s$cemi, s$yeni, s$yenilenib)
  }
}), collapse = "\n")

total_all <- Reduce(`+`, lapply(all_stats, function(s) if (!is.null(s)) s$cemi else 0))
total_yeni <- Reduce(`+`, lapply(all_stats, function(s) if (!is.null(s)) s$yeni else 0))
total_yen <- Reduce(`+`, lapply(all_stats, function(s) if (!is.null(s)) s$yenilenib else 0))

index_html <- sprintf('<!DOCTYPE html>
<html lang="az">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Riyaziyyat Standartları — Yenilənmiş</title>
  %s
  <style>
    .index-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(250px, 1fr)); gap: 20px; margin-top: 30px; }
    .index-card { display: block; background: white; border-radius: 12px; padding: 25px; box-shadow: 0 2px 8px rgba(0,0,0,0.1); text-decoration: none; color: #333; transition: transform 0.2s, box-shadow 0.2s; border-top: 4px solid #4CAF50; }
    .index-card:hover { transform: translateY(-4px); box-shadow: 0 6px 20px rgba(0,0,0,0.15); text-decoration: none; }
    .index-card h3 { font-size: 20px; color: #2E7D32; margin-bottom: 10px; }
    .index-stats { display: flex; flex-direction: column; gap: 4px; font-size: 14px; }
    .summary-box { background: white; border-radius: 12px; padding: 20px; text-align: center; margin-top: 20px; }
  </style>
</head>
<body>
<div class="container">
  <header>
    <h1>Azərbaycan Respublikası</h1>
    <h2>Riyaziyyat Fənni Standartları — Yenilənmiş Versiya</h2>
  </header>

  <div class="stats-panel">
    <div class="stat-box stat-cemi"><div class="number">%d</div><div class="label">Cəmi standart</div></div>
    <div class="stat-box stat-yeni"><div class="number">%d</div><div class="label">Yeni</div></div>
    <div class="stat-box stat-yenilenib"><div class="number">%d</div><div class="label">Yenilənib</div></div>
    <div class="stat-box"><div class="number">11</div><div class="label">Sinif</div></div>
  </div>

  <div class="summary-box">
    <p style="font-size:16px;color:#555;">Bu layihə TIMSS, PISA, NCTM, Bloom taksonomiyası və 6 aparıcı ölkənin (Sinqapur, Finlandiya, Yaponiya, Cənubi Koreya, Estoniya, Kanada) standartları əsasında hazırlanmışdır.</p>
  </div>

  <div class="index-grid">
    %s
  </div>

  <footer>
    <p>ARTI — Azərbaycan Respublikası Təhsil İnstitutu</p>
    <p>Qiymətləndirmə, Təhlil və Monitorinq şöbəsi — 2026</p>
  </footer>
</div>
</body>
</html>', css_style, total_all, total_yeni, total_yen, sinif_cards)

writeLines(index_html, file.path(path.expand(output_dir), "index.html"), useBytes = TRUE)
cat("   ✓ index.html yaradıldı\n")

dbDisconnect(con)
cat("\n=== Mərhələ 3 tamamlandı ===\n")
