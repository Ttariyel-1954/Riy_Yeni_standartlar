# ============================================================
# app.R — Riyaziyyat Standartları Dashboard
# R Shiny ilə interaktiv idarəetmə paneli
# ============================================================

library(shiny)
library(shinydashboard)
library(DBI)
library(RPostgres)
library(DT)
library(httr)
library(jsonlite)
library(plotly)
library(dplyr)
library(htmltools)
library(glue)

readRenviron("~/Desktop/Riy_standartlar/.Renviron")

# --- KONFİQURASİYA ---
DB_CONFIG <- list(
  dbname   = Sys.getenv("DB_NAME", "riy_standartlar"),
  host     = Sys.getenv("DB_HOST", "localhost"),
  port     = as.integer(Sys.getenv("DB_PORT", "5432")),
  user     = Sys.getenv("DB_USER", "royatalibova")
)

CLAUDE_API_KEY <- Sys.getenv("CLAUDE_API_KEY", "")

USE_CSV <- FALSE

get_con <- function() {
  dbConnect(RPostgres::Postgres(),
            dbname = DB_CONFIG$dbname, host = DB_CONFIG$host,
            port = DB_CONFIG$port, user = DB_CONFIG$user)
}

# --- Claude API (token izləmə ilə) ---
CLAUDE_MODEL <- "claude-sonnet-4-20250514"
CLAUDE_ENDPOINT <- "https://api.anthropic.com/v1/messages"

call_claude <- function(prompt) {
  if (nchar(CLAUDE_API_KEY) < 10) return(list(success = FALSE, error = "API açarı təyin edilməyib!",
                                               time_sec = 0, input_tokens = 0, output_tokens = 0))
  t0 <- proc.time()["elapsed"]
  tryCatch({
    resp <- POST(CLAUDE_ENDPOINT,
      add_headers(`x-api-key` = CLAUDE_API_KEY, `anthropic-version` = "2023-06-01", `content-type` = "application/json"),
      body = toJSON(list(
        model = CLAUDE_MODEL,
        max_tokens = 16384L,
        messages = list(list(role = "user", content = prompt))
      ), auto_unbox = TRUE),
      encode = "raw", timeout(600))
    elapsed <- round(as.numeric(proc.time()["elapsed"] - t0), 1)
    res <- content(resp, "parsed", encoding = "UTF-8")
    inp_tok <- as.integer(if (!is.null(res$usage$input_tokens)) res$usage$input_tokens else 0)
    out_tok <- as.integer(if (!is.null(res$usage$output_tokens)) res$usage$output_tokens else 0)
    if (resp$status_code == 200) {
      txt <- if (length(res$content) > 0 && !is.null(res$content[[1]]$text)) res$content[[1]]$text else ""
      list(success = TRUE, text = txt, time_sec = elapsed, input_tokens = inp_tok, output_tokens = out_tok)
    } else {
      err_msg <- if (!is.null(res$error)) res$error$message else paste("HTTP", resp$status_code)
      list(success = FALSE, error = err_msg, time_sec = elapsed, input_tokens = inp_tok, output_tokens = out_tok)
    }
  }, error = function(e) {
    elapsed <- round(as.numeric(proc.time()["elapsed"] - t0), 1)
    list(success = FALSE, error = e$message, time_sec = elapsed, input_tokens = 0, output_tokens = 0)
  })
}

# --- JSON təmizləmə: string daxilindəki escape olunmamış dırnaqları düzəlt ---
fix_json_quotes <- function(txt) {
  # JSON string daxilindəki escape olunmamış " işarələrini ' ilə əvəz et
  # Strategiya: sətir-sətir keçib, "key": "value" strukturunu qoruyub, value daxilindəki artıq dırnaqları düzəlt
  lines <- strsplit(txt, "\n")[[1]]
  result <- c()
  for (line in lines) {
    # "key": "...value..." pattern — value hissəsindəki artıq dırnaqları tap
    # Əgər sətirdə 4-dən çox " varsa, ortadakıları düzəlt
    quote_count <- nchar(gsub("[^\"]", "", line))
    if (quote_count > 4) {
      # İlk "key": " hissəsini tap
      m <- regmatches(line, regexpr('^(\\s*"[^"]*"\\s*:\\s*")', line, perl = TRUE))
      if (length(m) > 0 && nchar(m[1]) > 0) {
        prefix <- m[1]
        rest <- substring(line, nchar(prefix) + 1)
        # Son " və , və ya } tap
        end_match <- regmatches(rest, regexpr('"\\s*[,}]?\\s*$', rest, perl = TRUE))
        if (length(end_match) > 0 && nchar(end_match[1]) > 0) {
          middle <- substring(rest, 1, nchar(rest) - nchar(end_match[1]))
          # Ortadakı dırnaqları düzəlt
          middle <- gsub('"', "'", middle)
          line <- paste0(prefix, middle, end_match[1])
        }
      }
    }
    result <- c(result, line)
  }
  paste(result, collapse = "\n")
}

# --- JSON çıxarma (```json ... ``` təmizləmə) ---
extract_json_array <- function(txt) {
  # ```json ... ``` blokundan təmizlə
  txt <- gsub("```json\\s*", "", txt, perl = TRUE)
  txt <- gsub("```\\s*$", "", txt, perl = TRUE)
  txt <- gsub("```", "", txt)
  # [ ... ] arasını tap
  m <- regmatches(txt, regexpr("\\[[\\s\\S]*\\]", txt, perl = TRUE))
  if (length(m) == 0) stop("JSON massivi tapılmadı")
  m[1]
}

# --- Statistika paneli (token/xərc) ---
make_stats_bar <- function(time_sec, input_tokens, output_tokens) {
  total <- input_tokens + output_tokens
  cost <- round((input_tokens * 3 + output_tokens * 15) / 1e6, 4)
  paste0(
    '<div style="background:linear-gradient(135deg,#0f172a,#1e293b);color:#e2e8f0;padding:20px 28px;border-radius:14px;margin-top:24px;box-shadow:0 4px 20px rgba(0,0,0,0.2);">',
    '<div style="font-size:1.5em;font-weight:700;margin-bottom:14px;color:#fbbf24;">Generasiya Statistikası</div>',
    '<div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(170px,1fr));gap:12px;">',
    '<div style="background:rgba(255,255,255,0.06);padding:14px 18px;border-radius:10px;border-left:3px solid #2E7D32;"><div style="font-size:0.98em;color:#94a3b8;">Vaxt</div><div style="font-size:1.6em;font-weight:700;color:#66BB6A;">', sprintf("%.1f", time_sec), ' san</div></div>',
    '<div style="background:rgba(255,255,255,0.06);padding:14px 18px;border-radius:10px;border-left:3px solid #22c55e;"><div style="font-size:0.98em;color:#94a3b8;">Giriş token</div><div style="font-size:1.6em;font-weight:700;color:#4ade80;">', formatC(input_tokens, format = "d", big.mark = ","), '</div></div>',
    '<div style="background:rgba(255,255,255,0.06);padding:14px 18px;border-radius:10px;border-left:3px solid #f59e0b;"><div style="font-size:0.98em;color:#94a3b8;">Çıxış token</div><div style="font-size:1.6em;font-weight:700;color:#fbbf24;">', formatC(output_tokens, format = "d", big.mark = ","), '</div></div>',
    '<div style="background:rgba(255,255,255,0.06);padding:14px 18px;border-radius:10px;border-left:3px solid #ef4444;"><div style="font-size:0.98em;color:#94a3b8;">Cəmi token</div><div style="font-size:1.6em;font-weight:700;color:#f87171;">', formatC(total, format = "d", big.mark = ","), '</div></div>',
    '<div style="background:rgba(255,255,255,0.06);padding:14px 18px;border-radius:10px;border-left:3px solid #a78bfa;"><div style="font-size:0.98em;color:#94a3b8;">Təxmini qiymət</div><div style="font-size:1.6em;font-weight:700;color:#c4b5fd;">$', sprintf("%.4f", cost), '</div></div>',
    '</div></div>')
}

# ============================================================
# UI
# ============================================================
ui <- dashboardPage(
  skin = "green",
  
  dashboardHeader(
    title = "Riyaziyyat Standartları",
    titleWidth = 300
  ),
  
  dashboardSidebar(
    width = 280,
    sidebarMenu(
      id = "tabs",
      menuItem("Ana Səhifə", tabName = "home", icon = icon("home")),
      menuItem("Standartlar", tabName = "standards", icon = icon("book")),
      menuItem("Müqayisə", tabName = "compare", icon = icon("columns")),
      menuItem("Beynəlxalq", tabName = "international", icon = icon("globe")),
      menuItem("Statistika", tabName = "stats", icon = icon("chart-bar")),
      menuItem("Claude AI Təhlil", tabName = "ai_analysis", icon = icon("robot")),
      menuItem("Yekun Standartlar", tabName = "yekun", icon = icon("check-double")),
      menuItem("HTML Export", tabName = "export", icon = icon("download"))
    ),
    hr(),
    div(style = "padding: 15px;",
      selectInput("sinif_sec", "🎓 Sinif seçin:",
                  choices = setNames(1:11, paste0(1:11, "-ci sinif")),
                  selected = 1),
      selectInput("mezmun_sec", "📌 Məzmun xətti:",
                  choices = c("Hamısı" = "all", "Ədədlər və əməllər", "Cəbr", "Həndəsə", "Ölçmə", "Statistika və ehtimal"),
                  selected = "all"),
      selectInput("deyisiklik_sec", "🔄 Status:",
                  choices = c("Hamısı" = "all", "Mövcud" = "movcud", "Yenilənib" = "yenilenib",
                              "Yeni" = "yeni", "Silinib" = "silinib"),
                  selected = "all"),
      hr(),
      div(style = "text-align:center; color:#7f8c8d; font-size:12px;",
          "ARTI — Qiymətləndirmə, Təhlil",
          tags$br(),
          "və Monitorinq şöbəsi")
    )
  ),
  
  dashboardBody(
    tags$head(tags$style(HTML('
      @import url("https://fonts.googleapis.com/css2?family=Noto+Sans:wght@300;400;500;600;700&display=swap");
      body, .content-wrapper, .main-sidebar { font-family: "Noto Sans", sans-serif; }
      .content-wrapper { background-color: #f0f4f8; }
      .info-box .info-box-number { font-size: 28px; }
      .box { border-top: 3px solid #4CAF50; border-radius: 8px; overflow-x: auto; }
      .skin-green .main-header .logo { background-color: #1B5E20; font-weight: 600; }
      .skin-green .main-header .navbar { background-color: #2E7D32; }
      .skin-green .main-sidebar { background-color: #1B5E20; }
      .skin-green .sidebar-menu > li.active > a { background-color: #2E7D32; border-left-color: #64B5F6; }
      .small-box { border-radius: 10px; }
      
      /* Cədvəl düzəlişləri */
      .dataTables_wrapper { overflow-x: auto; -webkit-overflow-scrolling: touch; }
      table.dataTable { font-size: 20px; }
      table.dataTable td {
        white-space: normal !important;
        word-wrap: break-word;
        overflow-wrap: break-word;
        padding: 10px 12px !important;
        vertical-align: top;
        line-height: 1.5em;
        max-height: 4.5em;
        overflow: hidden;
      }
      table.dataTable td:hover {
        max-height: none;
        overflow: visible;
      }
      table.dataTable th {
        white-space: nowrap;
        padding: 12px !important;
        font-size: 19px;
        font-weight: 600;
      }
      .table-scroll-wrapper {
        overflow-x: auto;
        -webkit-overflow-scrolling: touch;
      }
      
      /* Boş mesaj stili */
      .bos-mesaj {
        text-align: center; padding: 40px 20px;
        color: #90A4AE; font-size: 16px;
      }
      .bos-mesaj .icon { font-size: 40px; margin-bottom: 10px; }
      
      /* ===== MÜQAYİSƏ SPLIT PANEL ===== */
      .compare-container {
        display: flex;
        gap: 0;
        height: calc(100vh - 180px);
        min-height: 500px;
      }
      .compare-panel {
        flex: 1;
        overflow-y: auto;
        overflow-x: hidden;
        padding: 15px;
        border: 1px solid #CFD8DC;
        background: #fff;
        border-radius: 8px;
      }
      .compare-panel-left {
        border-right: none;
        border-radius: 8px 0 0 8px;
        resize: horizontal;
        min-width: 300px;
        max-width: 70%;
      }
      .compare-panel-right {
        border-radius: 0 8px 8px 0;
        min-width: 300px;
      }
      .compare-divider {
        width: 8px;
        background: linear-gradient(180deg, #1976D2, #42A5F5);
        cursor: col-resize;
        display: flex;
        align-items: center;
        justify-content: center;
        flex-shrink: 0;
        border-radius: 4px;
        position: relative;
      }
      .compare-divider::after {
        content: "⋮";
        color: white;
        font-size: 18px;
        font-weight: bold;
      }
      .compare-header {
        font-size: 16px;
        font-weight: 600;
        padding: 10px 15px;
        margin: -15px -15px 15px -15px;
        border-bottom: 2px solid #E0E0E0;
      }
      .compare-header-left {
        background: linear-gradient(90deg, #FFF8E1, #FFF);
        color: #E65100;
      }
      .compare-header-right {
        background: linear-gradient(90deg, #E8F5E9, #FFF);
        color: #2E7D32;
      }
      
      /* Standart kartları müqayisədə */
      .cmp-card {
        border: 1px solid #E0E0E0;
        border-radius: 8px;
        margin-bottom: 12px;
        padding: 12px 15px;
        font-size: 14px;
        line-height: 1.7;
        transition: box-shadow 0.2s;
      }
      .cmp-card:hover { box-shadow: 0 2px 8px rgba(0,0,0,0.1); }
      .cmp-card-left {
        border-left: 4px solid #FF9800;
        background: #FFFDE7;
      }
      .cmp-card-right-deyismeyib {
        border-left: 4px solid #BDBDBD;
        background: #FAFAFA;
      }
      .cmp-card-right-yenilenib {
        border-left: 4px solid #4CAF50;
        background: #E8F5E9;
      }
      .cmp-card-right-yeni {
        border-left: 4px solid #FF9800;
        background: #FFF3E0;
      }
      .cmp-card-right-silinib {
        border-left: 4px solid #F44336;
        background: #FFEBEE;
        text-decoration: line-through;
        opacity: 0.6;
      }
      .cmp-kod {
        font-family: "Courier New", monospace;
        font-weight: 700;
        color: #0D47A1;
        font-size: 13px;
        margin-bottom: 5px;
      }
      .cmp-mezmun {
        display: inline-block;
        font-size: 11px;
        background: #E3F2FD;
        color: #1565C0;
        padding: 2px 8px;
        border-radius: 10px;
        margin-left: 8px;
      }
      .cmp-badge {
        display: inline-block;
        font-size: 11px;
        padding: 2px 8px;
        border-radius: 10px;
        margin-left: 5px;
      }
      .cmp-badge-deyismeyib { background: #F5F5F5; color: #333; }
      .cmp-badge-yenilenib { background: #C8E6C9; color: #2E7D32; }
      .cmp-badge-yeni { background: #FFE0B2; color: #E65100; }
      .cmp-badge-silinib { background: #FFCDD2; color: #C62828; }
      
      /* ===== DİFF RENKLEME ===== */
      .diff-added {
        background-color: #C8E6C9;
        color: #1B5E20;
        padding: 1px 3px;
        border-radius: 3px;
        font-weight: 500;
      }
      .diff-same { color: #424242; }

      /* AI taymer/token stilləri */
      .token-display{display:inline-flex;align-items:center;gap:8px;font-size:1.2em;font-weight:700;padding:10px 18px;border-radius:10px;margin-top:15px}
      .token-waiting{background:#fef3c7;color:#92400e;border:1px solid #fde68a}
      .token-done{background:#dcfce7;color:#166534;border:1px solid #86efac}
      .token-error{background:#fef2f2;color:#991b1b;border:1px solid #fca5a5}
      .live-timer-panel{background:linear-gradient(135deg,#0f172a,#1e293b);border:2px solid #22c55e;border-radius:16px;padding:32px 40px;margin:20px 0;text-align:center;box-shadow:0 4px 24px rgba(46,125,50,.15)}
      .live-timer-panel .t-status{font-size:1.3em;color:#94a3b8;margin-bottom:10px}
      .live-timer-panel .t-clock{font-family:"JetBrains Mono",monospace;font-size:3.5em;font-weight:700;color:#66BB6A;letter-spacing:.06em;margin:8px 0}
      .live-timer-panel .t-start{font-size:1em;color:#64748b;margin-bottom:14px}
      .live-timer-panel .t-details{display:flex;justify-content:center;gap:16px;flex-wrap:wrap}
      .live-timer-panel .t-item{background:rgba(255,255,255,.06);padding:10px 20px;border-radius:10px;font-size:1em;color:#cbd5e1}
      .pdot{display:inline-block;width:12px;height:12px;background:#22c55e;border-radius:50%;margin-right:8px;animation:pdot 1s infinite}
      @keyframes pdot{0%,100%{opacity:1}50%{opacity:.3}}
      .ai-output{font-size:16px;line-height:1.85;padding:24px;background:white;border-radius:12px;border:1px solid #e2e8f0;margin-top:16px}
      .ai-output h1{color:#0D47A1;margin-top:24px;font-size:24px}
      .ai-output h2{color:#0D47A1;margin-top:22px;font-size:21px}
      .ai-output h3{color:#0D47A1;margin-top:20px;font-size:19px}
      .ai-output table{width:100%;border-collapse:collapse;margin:18px 0;font-size:15px}
      .ai-output th{background:#1976D2;color:white;padding:10px;text-align:left}
      .ai-output td{padding:8px 10px;border-bottom:1px solid #e2e8f0}
      .ai-output tr:nth-child(even){background:#f8fafc}
    '))),

    # JavaScript: canlı taymer
    tags$script(HTML('
      var _aiTimerInterval = null;
      var _aiTimerStart = null;

      Shiny.addCustomMessageHandler("ai_timer_start", function(m) {
        _aiTimerStart = new Date();
        if (_aiTimerInterval) clearInterval(_aiTimerInterval);
        var e = document.getElementById(m.target);
        if (!e) return;
        var st = _aiTimerStart.toLocaleTimeString("az-AZ", {hour:"2-digit",minute:"2-digit",second:"2-digit"});
        e.innerHTML = "<div class=\\"live-timer-panel\\">" +
          "<div class=\\"t-status\\"><span class=\\"pdot\\"></span>" + m.status + "</div>" +
          "<div class=\\"t-clock\\" id=\\"_clk_" + m.target + "\\">00:00</div>" +
          "<div class=\\"t-start\\">Başlama: " + st + "</div>" +
          "<div class=\\"t-details\\">" +
            "<div class=\\"t-item\\">" + m.info1 + "</div>" +
            "<div class=\\"t-item\\">" + m.info2 + "</div>" +
            "<div class=\\"t-item\\">Claude AI</div>" +
          "</div></div>";
        _aiTimerInterval = setInterval(function() {
          var d = Math.floor((new Date() - _aiTimerStart) / 1000);
          var mm = Math.floor(d / 60), ss = d % 60;
          var t = (mm < 10 ? "0" : "") + mm + ":" + (ss < 10 ? "0" : "") + ss;
          var c = document.getElementById("_clk_" + m.target);
          if (c) c.textContent = t;
        }, 250);
      });

      Shiny.addCustomMessageHandler("ai_timer_stop", function(m) {
        if (_aiTimerInterval) { clearInterval(_aiTimerInterval); _aiTimerInterval = null; }
        var e = document.getElementById(m.target);
        if (!e) return;
        var cl = m.ok ? "" : "border-color:#ef4444";
        var co = m.ok ? "#66BB6A" : "#ef4444";
        var lb = m.ok ? "Tamamlandı" : "Xəta baş verdi";
        e.innerHTML = "<div class=\\"live-timer-panel\\" style=\\"" + cl + "\\">" +
          "<div class=\\"t-status\\" style=\\"color:" + co + "\\">" + lb + "</div>" +
          "<div class=\\"t-clock\\" style=\\"color:" + co + "\\">" + m.elapsed + " san</div>" +
          "<div class=\\"t-details\\">" +
            "<div class=\\"t-item\\">Giriş: " + m.inp + "</div>" +
            "<div class=\\"t-item\\">Çıxış: " + m.out + "</div>" +
            "<div class=\\"t-item\\">" + m.cost + "</div>" +
          "</div></div>";
      });
    ')),

    tabItems(
      # ========== ANA SƏHİFƏ ==========
      tabItem(tabName = "home",
        fluidRow(
          valueBoxOutput("vb_umumi", width = 2),
          valueBoxOutput("vb_movcud", width = 3),
          valueBoxOutput("vb_yenilenib", width = 3),
          valueBoxOutput("vb_yeni", width = 2),
          valueBoxOutput("vb_silinib", width = 2)
        ),

        fluidRow(
          box(title = "📊 Siniflər üzrə Standart Sayı", width = 8, 
              status = "success", solidHeader = TRUE,
              plotlyOutput("chart_sinifler", height = "400px")),
          box(title = "ℹ️ Layihə Haqqında", width = 4, status = "info", solidHeader = TRUE,
              div(style = "font-size: 15px; line-height: 1.8;",
                tags$p("Bu dashboard Riyaziyyat standartlarının beynəlxalq tələblərə uyğun yenilənməsini idarə edir."),
                tags$hr(),
                tags$p(tags$strong("Beynəlxalq çərçəvələr:")),
                tags$ul(
                  tags$li("TIMSS — Riyaziyyat qiymətləndirmə"),
                  tags$li("PISA — Riyazi savadlılıq"),
                  tags$li("NCTM — Riyaziyyat standartları"),
                  tags$li("Bloom Taksonomiyası")
                ),
                tags$p(tags$strong("Aparıcı ölkələr:")),
                tags$p("🇫🇮 Finlandiya • 🇸🇬 Sinqapur • 🇪🇪 Estoniya"),
                tags$p("🇯🇵 Yaponiya • 🇨🇦 Kanada • 🇰🇷 Cənubi Koreya")
              ))
        )
      ),
      
      # ========== STANDARTLAR (mövcud, dəyişilməmiş) ==========
      tabItem(tabName = "standards",
        fluidRow(
          box(title = NULL, width = 12, background = "green",
              tags$h3(style="margin:0;color:white;", "Mövcud Standartlar (Orijinal)"),
              tags$p(style="color:#e3f2fd;margin:5px 0 0 0;",
                "Bu cədvəl orijinal, dəyişilməmiş standartları göstərir. Sinif seçərək standartları gözdən keçirin."))
        ),
        fluidRow(
          column(4,
            selectInput("std_sinif_sec", "Sinif seçin:",
                        choices = setNames(1:11, paste0(1:11, "-ci sinif")),
                        selected = 1, width = "100%")),
          column(4,
            selectInput("std_mezmun_sec", "Məzmun xətti:",
                        choices = c("Hamısı" = "all", "Ədədlər və əməllər", "Cəbr", "Həndəsə", "Ölçmə", "Statistika və ehtimal"),
                        selected = "all", width = "100%")),
          column(4, style = "padding-top: 25px;",
            tags$span(style="font-size:16px; font-weight:600; color:#1565C0;",
              textOutput("std_count_info", inline = TRUE)))
        ),
        fluidRow(
          box(title = NULL, width = 12, status = "success", solidHeader = FALSE,
              DTOutput("dt_standartlar_movcud"))
        )
      ),
      
      # ========== MÜQAYİSƏ ==========
      tabItem(tabName = "compare",
        fluidRow(
          column(12,
            div(style="padding:10px 15px;background:#E3F2FD;border-radius:8px;margin-bottom:15px;",
              tags$span(style="font-weight:600;color:#0D47A1;", "Müqayisə: "),
              tags$span(style="display:inline-block;width:18px;height:18px;background:#FFFFFF;border:1px solid #ccc;border-radius:3px;margin:0 4px;vertical-align:middle;"), " Mövcud  ",
              tags$span(style="display:inline-block;width:18px;height:18px;background:#E8F5E9;border:1px solid #4CAF50;border-radius:3px;margin:0 4px;vertical-align:middle;"), " Yenilənib  ",
              tags$span(style="display:inline-block;width:18px;height:18px;background:#FFEBEE;border:1px solid #F44336;border-radius:3px;margin:0 4px;vertical-align:middle;"), " Silinib  ",
              tags$span(style="display:inline-block;width:18px;height:18px;background:#FFF3E0;border:1px solid #FF9800;border-radius:3px;margin:0 4px;vertical-align:middle;"), " Yeni"
            )
          )
        ),
        fluidRow(
          box(title = NULL, width = 12, solidHeader = FALSE,
            uiOutput("compare_info"),
            DTOutput("dt_compare_table")
          )
        )
      ),
      
      # ========== BEYNƏLXALQ ==========
      tabItem(tabName = "international",
        fluidRow(
          box(title = "🌐 TIMSS/PISA/NCTM Uyğunluğu", width = 12, status = "success", solidHeader = TRUE,
              DTOutput("dt_beynelxalq"))
        ),
        fluidRow(
          box(title = "🏳️ Ölkə Standartları", width = 12, status = "info", solidHeader = TRUE,
              div(style = "margin-bottom: 15px;",
                selectInput("olke_sec", "Ölkə seçin:", width = "300px",
                            choices = c("Hamısı", "Finlandiya", "Sinqapur", "Estoniya", 
                                        "Yaponiya", "Kanada", "Cənubi Koreya"))
              ),
              DTOutput("dt_olkeler"))
        ),
        fluidRow(
          box(title = "📊 Bloom Taksonomiyası Paylanması", width = 12, status = "success", solidHeader = TRUE,
              plotlyOutput("chart_bloom", height = "350px"))
        )
      ),
      
      # ========== STATİSTİKA ==========
      tabItem(tabName = "stats",
        fluidRow(
          box(title = "📈 Dəyişiklik Növləri üzrə Paylanma", width = 6, status = "success", solidHeader = TRUE,
              plotlyOutput("chart_deyisiklik", height = "400px")),
          box(title = "📊 Məzmun Xətləri üzrə", width = 6, status = "success", solidHeader = TRUE,
              plotlyOutput("chart_mezmun", height = "400px"))
        ),
        fluidRow(
          box(title = "🎯 Sinif üzrə Status Paylanması", width = 6, status = "info", solidHeader = TRUE,
              plotlyOutput("chart_cefr", height = "350px")),
          box(title = "📚 Bloom Səviyyələri üzrə", width = 6, status = "info", solidHeader = TRUE,
              plotlyOutput("chart_bloom_all", height = "350px"))
        )
      ),
      
      # ========== AI TƏHLİL ==========
      tabItem(tabName = "ai_analysis",
        # --- TƏHLİL VƏ YAZ ---
        fluidRow(
          box(title = "🤖 Təhlil et və Yaz", width = 12, status = "success", solidHeader = TRUE,
              tags$p(style="font-size:15px; color:#334155; margin-bottom:15px;",
                "Seçilmiş sinifin mövcud standartları TIMSS, PISA, NCTM, Bloom və 6 ölkə standartları əsasında təhlil ediləcək.",
                tags$br(), "AI hər standartı təhlil edəcək, lazım olanları yenidən yazacaq və nəticəni birbaşa bazaya yazacaq."),
              actionButton("btn_analyze_write", "🚀 Təhlil et və Yaz", class = "btn-primary btn-lg",
                           style = "font-size:16px; margin-bottom:15px; font-weight:600;"),
              div(id = "ai_timer_panel"),
              uiOutput("ai_token_display"),
              uiOutput("ai_result"),
              uiOutput("ai_write_status"))
        ),
        # --- YENİ STANDART TƏKLİF ET ---
        fluidRow(
          box(title = "💡 Yeni Standartlar Təklif Et", width = 12, status = "success", solidHeader = TRUE,
              tags$p(style="font-size:15px; color:#334155; margin-bottom:15px;",
                "AI boşluqları müəyyən edib yeni standartlar təklif edəcək. Yeni standartlar yenilenmi_standartlar cədvəlinə 'yeni' statusu ilə əlavə olunacaq."),
              actionButton("btn_new_standards", "💡 Yeni standartlar təklif et", class = "btn-success btn-lg",
                           style = "font-size:16px; margin-bottom:15px; font-weight:600;"),
              div(id = "ai_timer_panel2"),
              uiOutput("ai_new_token_display"),
              uiOutput("ai_new_result"),
              uiOutput("ai_new_write_status"))
        )
      ),
      

      # ========== YEKUN STANDARTLAR ==========
      tabItem(tabName = "yekun",
        fluidRow(
          box(title = NULL, width = 12, background = "green",
              tags$h3(style="margin:0;color:white;", "Yekun Standartlar"),
              tags$p(style="color:#e3f2fd;margin:5px 0 0 0;",
                "3 addımlı təhlildən sonra hər sinif üçün yekun standartlar burada göstərilir."))
        ),
        fluidRow(
          column(6,
            selectInput("yekun_sinif", "Sinif seçin:",
                        choices = setNames(1:11, paste0("Yekun_Standartlar-", 1:11)),
                        selected = 1, width = "100%")),
          column(3,
            selectInput("yekun_status_filter", "Status filtri:",
                        choices = c("Hamısı" = "all", "Mövcud" = "movcud",
                                    "Yenilənib" = "yenilenib",
                                    "Yeni" = "yeni",
                                    "Silinib" = "silinib"),
                        selected = "all", width = "100%")),
          column(3, style = "padding-top:25px;",
            downloadButton("download_yekun_csv", "CSV ixrac", class = "btn-success",
                           style = "margin-right:8px;"),
            downloadButton("download_yekun_excel", "Excel ixrac", class = "btn-primary"))
        ),
        fluidRow(
          valueBoxOutput("vb_yekun_umumi", width = 3),
          valueBoxOutput("vb_yekun_movcud", width = 3),
          valueBoxOutput("vb_yekun_yenilenib", width = 2),
          valueBoxOutput("vb_yekun_yeni", width = 2),
          valueBoxOutput("vb_yekun_silinib", width = 2)
        ),
        fluidRow(
          box(title = NULL, width = 12, status = "success", solidHeader = FALSE,
              DTOutput("dt_yekun"),
              tags$br(),
              uiOutput("yekun_info"))
        )
      ),

      # ========== YENİ TƏKLİFLƏR ==========
      tabItem(tabName = "yeni_teklifler_tab",
        fluidRow(
          box(title = NULL, width = 12, background = "orange",
              tags$h3(style="margin:0;color:white;", "AI Tərəfindən Təklif Olunan Yeni Standartlar"),
              tags$p(style="color:#fff3e0;margin:5px 0 0 0;",
                "Beynəlxalq təhlil nəticəsində AI-nin təklif etdiyi yeni standartlar. Qəbul etdikləriniz yekun standartlara əlavə olunacaq."))
        ),
        fluidRow(
          column(4,
            selectInput("teklif_sinif", "Sinif seçin:",
                        choices = setNames(1:11, paste0(1:11, "-ci sinif")),
                        selected = 1, width = "100%")),
          column(4,
            selectInput("teklif_status_filter", "Status filtri:",
                        choices = c("Hamısı" = "all", "Təklif" = "teklif",
                                    "Qəbul edilib" = "qebul", "Rədd edilib" = "redd"),
                        selected = "all", width = "100%")),
          column(4, style = "padding-top:25px;",
            actionButton("btn_teklif_qebul_sec", "Seçilmişləri Yekuna Əlavə Et",
                         class = "btn-success btn-lg", icon = icon("check"),
                         style = "font-weight:600;"))
        ),
        fluidRow(
          valueBoxOutput("vb_teklif_cemi", width = 3),
          valueBoxOutput("vb_teklif_gozleyen", width = 3),
          valueBoxOutput("vb_teklif_qebul", width = 3),
          valueBoxOutput("vb_teklif_redd", width = 3)
        ),
        fluidRow(
          box(title = NULL, width = 12, status = "warning", solidHeader = FALSE,
              DTOutput("dt_teklifler"),
              tags$br(),
              uiOutput("teklif_status_msg"))
        )
      ),

      # ========== EXPORT ==========
      tabItem(tabName = "export",
        fluidRow(
          box(title = "📥 HTML Hesabat Yüklə", width = 6, status = "success", solidHeader = TRUE,
              tags$p("Seçilmiş sinif üçün nəfis HTML hesabatı yükləyin:"),
              downloadButton("download_html", "⬇️ HTML Yüklə", class = "btn-primary btn-lg")),
          box(title = "📊 CSV Yüklə", width = 4, status = "info", solidHeader = TRUE,
              tags$p("Bütün standartları CSV formatında yükləyin:"),
              downloadButton("download_csv", "⬇️ CSV Yüklə", class = "btn-info btn-lg")),
          box(title = "📝 Word Yüklə", width = 4, status = "success", solidHeader = TRUE,
              tags$p("Yekun standartları nəfis Word formatında yükləyin (redaktə oluna bilər):"),
              downloadButton("download_word", "⬇️ Word Yüklə", class = "btn-success btn-lg"))
        )
      )
    )
  )
)

# ============================================================
# SERVER
# ============================================================
server <- function(input, output, session) {

  # --- Reaktiv məlumat (PostgreSQL + CSV fallback) ---
  # Standartlar tab-ı indi movcud_standartlar-dan oxuyur (orijinal, dəyişilməmiş)

  data_movcud <- reactive({
    if (USE_CSV) {
      df <- csv_movcud()
      if (nrow(df) == 0) return(df)
      df <- df[df$sinif == as.integer(input$sinif_sec), , drop=FALSE]
      return(df[order(df$mezmun_xetti, df$standart_kodu), ])
    }
    con <- get_con()
    on.exit(dbDisconnect(con))
    query <- paste0("SELECT * FROM movcud_standartlar WHERE sinif = ", input$sinif_sec, " ORDER BY mezmun_xetti, standart_kodu")
    dbGetQuery(con, query)
  })

  # Refresh trigger — AI yazandan sonra ana səhifəni yeniləmək üçün
  stats_refresh <- reactiveVal(0)

  all_stats <- reactive({
    stats_refresh()
    mezmun <- input$mezmun_sec
    con <- get_con()
    on.exit(dbDisconnect(con))

    # Mövcud standartlar (əsas say) — mezmun filtri ilə
    mezmun_where_m <- if (!is.null(mezmun) && mezmun != "all") paste0(" WHERE mezmun_xetti = '", mezmun, "'") else ""
    df_m <- tryCatch(
      dbGetQuery(con, paste0("SELECT sinif, COUNT(*)::integer as movcud_say FROM movcud_standartlar", mezmun_where_m, " GROUP BY sinif ORDER BY sinif")),
      error = function(e) data.frame(sinif=integer(), movcud_say=integer()))

    if (nrow(df_m) == 0) return(data.frame(sinif=integer(), umumi=integer(), movcud=integer(),
                                            yenilenib=integer(), yeni=integer(), silinib=integer()))

    # Yekun standartlardan statistika al — mezmun filtri ilə
    mezmun_where_y <- if (!is.null(mezmun) && mezmun != "all") paste0(" WHERE mezmun_xetti = '", mezmun, "'") else ""
    df_yek <- tryCatch(
      dbGetQuery(con, paste0("
        SELECT sinif,
          COUNT(*)::integer as umumi,
          (COUNT(*) FILTER (WHERE deyisiklik_novu = 'movcud'))::integer as movcud,
          (COUNT(*) FILTER (WHERE deyisiklik_novu = 'yenilenib'))::integer as yenilenib,
          (COUNT(*) FILTER (WHERE deyisiklik_novu = 'yeni'))::integer as yeni,
          (COUNT(*) FILTER (WHERE deyisiklik_novu = 'silinib'))::integer as silinib
        FROM yenilenmi_standartlar", mezmun_where_y, " GROUP BY sinif ORDER BY sinif")),
      error = function(e) data.frame())

    df <- df_m
    df$umumi <- df$movcud_say
    df$movcud <- df$movcud_say
    df$yenilenib <- 0L
    df$yeni <- 0L
    df$silinib <- 0L

    # Yekun varsa, həmin siniflərin dəyərlərini üstünə yaz
    if (nrow(df_yek) > 0) {
      for (i in 1:nrow(df_yek)) {
        idx <- which(df$sinif == df_yek$sinif[i])
        if (length(idx) > 0) {
          df$umumi[idx] <- as.integer(df_yek$umumi[i])
          df$movcud[idx] <- as.integer(df_yek$movcud[i])
          df$yenilenib[idx] <- as.integer(df_yek$yenilenib[i])
          df$yeni[idx] <- as.integer(df_yek$yeni[i])
          df$silinib[idx] <- as.integer(df_yek$silinib[i])
        }
      }
    }

    df[, c("sinif", "umumi", "movcud", "yenilenib", "yeni", "silinib")]
  })
  
  # --- TIMSS/NCTM ---
  output$cefr_display <- renderText({
    "—"
  })
  
  # --- VALUE BOXES (seçilmiş sinifə görə) ---
  sinif_stats <- reactive({
    st <- all_stats()
    sinif <- as.integer(input$sinif_sec)
    row <- st[st$sinif == sinif, , drop=FALSE]
    if (nrow(row) == 0) return(list(umumi=0L, movcud=0L, yenilenib=0L, yeni=0L, silinib=0L))
    list(umumi = as.integer(row$umumi[1]),
         movcud = as.integer(row$movcud[1]),
         yenilenib = as.integer(row$yenilenib[1]),
         yeni = as.integer(row$yeni[1]),
         silinib = as.integer(row$silinib[1]))
  })

  output$vb_umumi <- renderValueBox({
    s <- sinif_stats()
    valueBox(s$umumi, paste0(input$sinif_sec, "-ci sinif: Ümumi"), icon = icon("book"), color = "blue")
  })
  output$vb_movcud <- renderValueBox({
    s <- sinif_stats()
    valueBox(s$movcud, "Mövcud", icon = icon("check"), color = "light-blue")
  })
  output$vb_yenilenib <- renderValueBox({
    s <- sinif_stats()
    valueBox(s$yenilenib, "Yenilənib", icon = icon("edit"), color = "green")
  })
  output$vb_yeni <- renderValueBox({
    s <- sinif_stats()
    valueBox(s$yeni, "Yeni", icon = icon("plus"), color = "orange")
  })
  output$vb_silinib <- renderValueBox({
    s <- sinif_stats()
    valueBox(s$silinib, "Silinib", icon = icon("trash"), color = "red")
  })
  
  # --- QRAFİKLƏR (yekun cədvəldən) ---
  output$chart_sinifler <- renderPlotly({
    st <- all_stats()
    if (nrow(st) == 0) return(plotly_empty(type = "bar"))

    plot_ly(st, x = ~paste0(sinif, "-ci sinif"), type = "bar") %>%
      add_bars(y = ~movcud, name = "Mövcud", marker = list(color = "#90CAF9")) %>%
      add_bars(y = ~yenilenib, name = "Yenilənib", marker = list(color = "#4CAF50")) %>%
      add_bars(y = ~yeni, name = "Yeni", marker = list(color = "#FF9800")) %>%
      add_bars(y = ~silinib, name = "Silinib", marker = list(color = "#F44336")) %>%
      layout(barmode = "stack",
             xaxis = list(title = ""), yaxis = list(title = "Standart sayı"),
             legend = list(orientation = "h", y = -0.15),
             font = list(family = "Noto Sans"))
  })
  
  # --- Statistika üçün yekun datası (bütün siniflər) ---
  data_yekun_all <- reactive({
    stats_refresh()  # AI yazdıqdan sonra yenilənsin
    tryCatch({
      if (USE_CSV) {
        f <- file.path(getwd(), "data", "yenilenmi_standartlar_backup.csv")
        if (!file.exists(f)) return(data.frame())
        read.csv(f, stringsAsFactors = FALSE, fileEncoding = "UTF-8")
      } else {
        con <- get_con(); on.exit(dbDisconnect(con))
        dbGetQuery(con, "SELECT * FROM yenilenmi_standartlar ORDER BY sinif, mezmun_xetti, standart_kodu")
      }
    }, error = function(e) data.frame())
  })

  output$chart_deyisiklik <- renderPlotly({
    df <- data_yekun_all()
    if (nrow(df) == 0 || !"deyisiklik_novu" %in% names(df)) return(plotly_empty(type = "bar"))

    status_labels <- c("movcud" = "Mövcud", "yenilenib" = "Yenilənib", "yeni" = "Yeni", "silinib" = "Silinib")
    counts <- table(df$deyisiklik_novu)
    labels <- sapply(names(counts), function(s) if (s %in% names(status_labels)) status_labels[s] else s)
    colors <- c("movcud" = "#90CAF9", "yenilenib" = "#4CAF50", "yeni" = "#FF9800", "silinib" = "#F44336")

    plot_ly(labels = labels, values = as.numeric(counts), type = "pie",
            marker = list(colors = colors[names(counts)]),
            textinfo = "label+percent") %>%
      layout(font = list(family = "Noto Sans"))
  })

  output$chart_mezmun <- renderPlotly({
    df <- data_yekun_all()
    # Yekun boşdursa, mövcud standartlardan göstər
    if (nrow(df) == 0) {
      df <- tryCatch({
        con <- get_con()
        res <- dbGetQuery(con, "SELECT mezmun_xetti FROM movcud_standartlar")
        dbDisconnect(con)
        res
      }, error = function(e) data.frame())
    }
    if (nrow(df) == 0) return(plotly_empty(type = "bar"))

    mezmun_col <- if ("mezmun_xetti" %in% names(df)) df$mezmun_xetti else if ("mezmun_xetti" %in% names(df)) df$mezmun_xetti else rep("", nrow(df))
    mezmun_col <- mezmun_col[!is.na(mezmun_col) & nchar(mezmun_col) > 0]
    if (length(mezmun_col) == 0) return(plotly_empty(type = "bar"))
    counts <- as.data.frame(table(mezmun_col), stringsAsFactors = FALSE)
    names(counts) <- c("mezmun", "say")
    plot_ly(counts, x = ~mezmun, y = ~say, type = "bar",
            marker = list(color = "#1976D2")) %>%
      layout(xaxis = list(title = ""), yaxis = list(title = "Say"),
             font = list(family = "Noto Sans"))
  })

  output$chart_bloom <- renderPlotly({
    df <- data_yekun_all()
    bloom_col_name <- if ("bloom_seviyyesi" %in% names(df)) "bloom_seviyyesi" else if ("bloom_seviyyesi" %in% names(df)) "bloom_seviyyesi" else NULL
    if (nrow(df) == 0 || is.null(bloom_col_name)) return(plotly_empty(type = "bar"))
    bloom_vals <- df[[bloom_col_name]]
    df <- df[!is.na(bloom_vals) & nchar(bloom_vals) > 0, ]
    if (nrow(df) == 0) return(plotly_empty(type = "bar"))
    bloom_vals <- df[[bloom_col_name]]

    bloom_order <- c("Xatırlama", "Anlama", "Tətbiq", "Analiz", "Qiymətləndirmə", "Yaratma")
    counts <- as.data.frame(table(factor(bloom_vals, levels = bloom_order)))

    bloom_colors <- c("#E3F2FD", "#BBDEFB", "#90CAF9", "#42A5F5", "#1976D2", "#0D47A1")
    plot_ly(counts, x = ~Var1, y = ~Freq, type = "bar",
            marker = list(color = bloom_colors)) %>%
      layout(xaxis = list(title = "", categoryorder = "array", categoryarray = bloom_order),
             yaxis = list(title = "Say"), font = list(family = "Noto Sans"))
  })

  output$chart_cefr <- renderPlotly({
    df <- data_yekun_all()
    if (nrow(df) == 0 || !"sinif" %in% names(df)) return(plotly_empty(type = "bar"))
    # Sinif üzrə status paylanması (stacked bar)
    df_stat <- df %>% count(sinif, deyisiklik_novu)
    if (nrow(df_stat) == 0) return(plotly_empty(type = "bar"))
    colors <- c("movcud"="#90CAF9","yenilenib"="#4CAF50","yeni"="#FF9800","silinib"="#F44336")
    plot_ly(df_stat, x = ~paste0(sinif, "-ci"), y = ~n, color = ~deyisiklik_novu, type = "bar", colors = colors) %>%
      layout(barmode = "stack", xaxis = list(title = "Sinif"), yaxis = list(title = "Say"),
             font = list(family = "Noto Sans"))
  })

  output$chart_bloom_all <- renderPlotly({
    df <- data_yekun_all()
    bloom_col_name <- if ("bloom_seviyyesi" %in% names(df)) "bloom_seviyyesi" else if ("bloom_seviyyesi" %in% names(df)) "bloom_seviyyesi" else NULL
    if (nrow(df) == 0 || is.null(bloom_col_name)) return(plotly_empty(type = "bar"))
    bloom_vals <- df[[bloom_col_name]]
    df <- df[!is.na(bloom_vals) & bloom_vals != "", ]
    if (nrow(df) == 0) return(plotly_empty(type = "bar"))
    bloom_vals <- df[[bloom_col_name]]

    counts <- as.data.frame(table(bloom_vals), stringsAsFactors = FALSE)
    names(counts) <- c("bloom_seviyyesi", "say")

    plot_ly(counts, labels = ~bloom_seviyyesi, values = ~say, type = "pie",
            textinfo = "label+percent") %>%
      layout(font = list(family = "Noto Sans"))
  })
  
  # --- CƏDVƏLLƏR ---

  # Standartlar tab — mövcud standartlar (orijinal, dəyişilməmiş)
  # Standartlar tabı üçün data
  data_std_movcud <- reactive({
    sinif <- as.integer(input$std_sinif_sec)
    tryCatch({
      con <- get_con(); on.exit(dbDisconnect(con))
      query <- sprintf("SELECT standart_kodu, mezmun_xetti, standart_metni, alt_standart_metni FROM movcud_standartlar WHERE sinif = %d", sinif)
      if (!is.null(input$std_mezmun_sec) && input$std_mezmun_sec != "all") {
        query <- paste0(query, " AND mezmun_xetti = '", input$std_mezmun_sec, "'")
      }
      query <- paste0(query, " ORDER BY standart_kodu")
      dbGetQuery(con, query)
    }, error = function(e) data.frame())
  })

  output$std_count_info <- renderText({
    df <- data_std_movcud()
    paste0("Cəmi: ", nrow(df), " standart")
  })

  output$dt_standartlar_movcud <- renderDT({
    df <- data_std_movcud()
    if (nrow(df) == 0) {
      return(datatable(data.frame(Mesaj = "Bu sinif üçün standart tapılmadı."),
                       rownames = FALSE, options = list(dom = 't')))
    }

    standart_text <- ifelse(!is.na(df$alt_standart_metni) & nchar(df$alt_standart_metni) > 0,
                            df$alt_standart_metni, df$standart_metni)

    df_show <- data.frame(
      `Kod` = df$standart_kodu,
      `Məzmun xətti` = df$mezmun_xetti,
      `Standart` = standart_text,
      check.names = FALSE, stringsAsFactors = FALSE
    )
    df_show[is.na(df_show)] <- ""

    datatable(df_show,
              options = list(pageLength = 50, scrollX = TRUE, autoWidth = FALSE,
                dom = 'lfrtip',
                columnDefs = list(
                  list(width = '140px', targets = 0),
                  list(width = '160px', targets = 1),
                  list(width = '600px', targets = 2)
                )),
              rownames = FALSE) %>%
      formatStyle('Kod', fontWeight = 'bold', color = '#1565C0') %>%
      formatStyle('Məzmun xətti', fontWeight = '500', color = '#37474F')
  })
  
  # --- Müqayisə üçün yekun datası ---
  data_compare <- reactive({
    stats_refresh()  # AI yazdıqdan sonra yenilənsin
    sinif <- as.integer(input$sinif_sec)
    tryCatch({
      if (USE_CSV) {
        f <- file.path(getwd(), "data", "yenilenmi_standartlar_backup.csv")
        if (!file.exists(f)) return(data.frame())
        df <- read.csv(f, stringsAsFactors = FALSE, fileEncoding = "UTF-8")
        if (nrow(df) > 0) df <- df[df$sinif == sinif, , drop=FALSE]
        df
      } else {
        con <- get_con(); on.exit(dbDisconnect(con))
        dbGetQuery(con, sprintf(
          "SELECT * FROM yenilenmi_standartlar WHERE sinif = %d ORDER BY
           CASE deyisiklik_novu WHEN 'movcud' THEN 1 WHEN 'yenilenib' THEN 1 WHEN 'silinib' THEN 1 WHEN 'yeni' THEN 2 ELSE 3 END,
           mezmun_xetti, standart_kodu", sinif))
      }
    }, error = function(e) data.frame())
  })

  # --- Diff highlight funksiyası ---
  highlight_diff <- function(old_text, new_text) {
    if (is.na(old_text) || is.na(new_text) || nchar(old_text) == 0) return(new_text)
    old_words <- strsplit(old_text, "\\s+")[[1]]
    new_words <- strsplit(new_text, "\\s+")[[1]]
    result <- c()
    for (i in seq_along(new_words)) {
      w <- new_words[i]
      if (i <= length(old_words) && w == old_words[i]) {
        result <- c(result, w)
      } else {
        result <- c(result, sprintf('<span style="background:#C8E6C9;font-weight:600;padding:1px 3px;border-radius:3px;">%s</span>', w))
      }
    }
    paste(result, collapse = " ")
  }

  # Müqayisə — info mesajı
  output$compare_info <- renderUI({
    df <- data_compare()
    if (nrow(df) == 0) return(tags$div(style="padding:40px;text-align:center;color:#9E9E9E;font-size:18px;",
      "Bu sinif üçün yekun standart yoxdur. Əvvəlcə AI Təhlil bölməsindən təhlili tamamlayın."))
    n_changed <- sum(df$deyisiklik_novu != "movcud", na.rm=TRUE)
    tags$div(style="margin-bottom:10px;color:#546E7A;font-size:15px;",
      sprintf("Cəmi: %d standart — Mövcud: %d, Yenilənib: %d, Yeni: %d, Silinib: %d",
              nrow(df),
              sum(df$deyisiklik_novu == "movcud", na.rm=TRUE),
              sum(df$deyisiklik_novu == "yenilenib", na.rm=TRUE),
              sum(df$deyisiklik_novu == "yeni", na.rm=TRUE),
              sum(df$deyisiklik_novu == "silinib", na.rm=TRUE)),
      if (n_changed > 0) tags$span(style="color:#1B5E20;font-weight:600;margin-left:15px;",
        sprintf("(%d dəyişiklik göstərilir)", n_changed)))
  })

  # Müqayisə — DT cədvəl, bütün sətir statusa görə rənglənir
  output$dt_compare_table <- renderDT({
    df <- data_compare()
    req(nrow(df) > 0)

    # Yalnız dəyişiklik olan standartları göstər (deyismeyib olanları gizlət)
    df <- df[df$deyisiklik_novu != "movcud", , drop=FALSE]
    if (nrow(df) == 0) {
      return(datatable(data.frame(Mesaj = "Bu sinif üçün hələ dəyişiklik edilməyib. Əvvəlcə 'Claude AI Təhlil' bölməsindən təhlili tamamlayın."),
                       rownames = FALSE, options = list(dom = 't')))
    }

    status_adi_map <- c("yenilenib" = "Yenilənib", "silinib" = "Silinib", "yeni" = "Yeni")
    df$deyisiklik_novu_adi <- sapply(df$deyisiklik_novu, function(s) {
      if (s %in% names(status_adi_map)) status_adi_map[s] else s
    })

    kohne_col <- if ("kohne_standart_metni" %in% names(df)) df$kohne_standart_metni else rep("", nrow(df))
    kohne_col[is.na(kohne_col) | kohne_col == "NA"] <- ""
    idx_yeni <- df$deyisiklik_novu == "yeni"
    kohne_col[idx_yeni] <- ""

    kod_col <- if ("standart_kodu" %in% names(df)) df$standart_kodu else ""
    mezmun_col <- if ("mezmun_xetti" %in% names(df)) df$mezmun_xetti else if ("mezmun_xetti" %in% names(df)) df$mezmun_xetti else ""
    xarakt_col <- if ("esaslandirma" %in% names(df)) df$esaslandirma else rep("", nrow(df))
    xarakt_col[is.na(xarakt_col)] <- ""

    df_show <- data.frame(
      `Kod` = kod_col,
      `Status` = df$deyisiklik_novu_adi,
      `Məzmun xətti` = mezmun_col,
      `Köhnə standart` = kohne_col,
      `Yeni standart` = df$standart_metni,
      `Xarakteristika` = xarakt_col,
      check.names = FALSE, stringsAsFactors = FALSE
    )
    df_show[is.na(df_show)] <- ""

    datatable(df_show,
              options = list(pageLength = 50, scrollX = TRUE, autoWidth = FALSE,
                scrollXInner = '1500px',
                columnDefs = list(
                  list(width = '130px', targets = 0),
                  list(width = '110px', targets = 1),
                  list(width = '140px', targets = 2),
                  list(width = '350px', targets = 3),
                  list(width = '350px', targets = 4),
                  list(width = '300px', targets = 5)
                )),
              rownames = FALSE) %>%
      formatStyle("Status", target = "row",
                  backgroundColor = styleEqual(
                    c("Yenilənib", "Silinib", "Yeni"),
                    c("#E8F5E9", "#FFEBEE", "#FFF3E0")),
                  color = styleEqual(
                    c("Yenilənib", "Silinib", "Yeni"),
                    c("#1B5E20", "#B71C1C", "#E65100"))) %>%
      formatStyle("Status", fontWeight = "bold") %>%
      formatStyle("Köhnə standart", color = "#757575", fontStyle = "italic")
  })
  
  output$dt_beynelxalq <- renderDT({
    tryCatch({
      if (USE_CSV) return(NULL)
      con <- get_con(); on.exit(dbDisconnect(con))
      sinif <- as.integer(input$sinif_sec)
      df <- dbGetQuery(con, sprintf("
        SELECT cerceve_adi, kateqoriya, alt_kateqoriya, tesvir
        FROM beynelxalq_cerceveler
        WHERE %d BETWEEN SPLIT_PART(sinif_araligi, '-', 1)::int
                    AND SPLIT_PART(sinif_araligi, '-', 2)::int
        ORDER BY cerceve_adi", sinif))
      if (nrow(df) == 0) return(NULL)
      datatable(df, options = list(pageLength = 15, scrollX = TRUE, autoWidth = FALSE,
                  columnDefs = list(
                    list(width = '80px', targets = 0),
                    list(width = '120px', targets = 1),
                    list(width = '180px', targets = 2),
                    list(width = '250px', targets = 3)
                  )),
                rownames = FALSE,
                colnames = c("Çərçəvə", "Kateqoriya", "Alt kateqoriya", "Təsvir"))
    }, error = function(e) NULL)
  })

  output$dt_olkeler <- renderDT({
    tryCatch({
      if (USE_CSV) return(NULL)
      con <- get_con(); on.exit(dbDisconnect(con))
      query <- "SELECT olke, mezmun_xetti, standart_metni, xususi_yanaşma FROM olke_standartlari"
      if (input$olke_sec != "Hamısı") {
        query <- paste0(query, sprintf(" WHERE olke = '%s'", input$olke_sec))
      }
      df <- dbGetQuery(con, query)
      if (nrow(df) == 0) return(NULL)
      datatable(df, options = list(pageLength = 10, scrollX = TRUE, autoWidth = FALSE,
                  columnDefs = list(
                    list(width = '90px', targets = 0),
                    list(width = '90px', targets = 1),
                    list(width = '250px', targets = 2),
                    list(width = '200px', targets = 3)
                  )),
                rownames = FALSE,
                colnames = c("Ölkə", "Məzmun", "Standart", "Xüsusi yanaşma"))
    }, error = function(e) NULL)
  })
  
  # ============================================================
  # TƏHLİL ET VƏ YAZ — Bir addımda təhlil, yenidənyazma və bazaya yazma
  # ============================================================
  observeEvent(input$btn_analyze_write, {
    sinif <- input$sinif_sec
    mezmun <- input$mezmun_sec

    # ===== Mövcud standartları bazadan oxu =====
    if (USE_CSV) {
      df <- csv_movcud()
      if (nrow(df) > 0) {
        df <- df[df$sinif == as.integer(sinif), , drop=FALSE]
        if (mezmun != "all") df <- df[df$mezmun_xetti == mezmun, , drop=FALSE]
        df <- df[order(df$mezmun_xetti, df$standart_kodu), ]
      }
    } else {
      con <- get_con(); on.exit(dbDisconnect(con))
      query <- sprintf("SELECT * FROM movcud_standartlar WHERE sinif = %s", sinif)
      if (mezmun != "all") query <- paste0(query, sprintf(" AND mezmun_xetti = '%s'", mezmun))
      query <- paste0(query, " ORDER BY mezmun_xetti, standart_kodu")
      df <- dbGetQuery(con, query)
    }

    if (nrow(df) == 0) {
      output$ai_result <- renderUI(tags$div(style="padding:30px;color:#dc2626;",
        tags$h3("Məlumat yoxdur"), tags$p("Bu sinif/məzmun xətti üçün standart tapılmadı.")))
      return()
    }

    mezmun_label <- if (mezmun == "all") "bütün məzmun xətləri" else mezmun
    cefr_sev <- "—"
    std_cols <- intersect(c("standart_kodu","standart_metni","alt_standart_kodu","alt_standart_metni",
                            "mezmun_xetti","bloom_seviyyesi","standart_kodu"), names(df))

    session$sendCustomMessage("ai_timer_start", list(
      target = "ai_timer_panel",
      status = "Claude AI təhlil edir və yazır...",
      info1 = paste0(sinif, "-ci sinif"),
      info2 = paste0(nrow(df), " standart (", mezmun_label, ")")
    ))
    output$ai_token_display <- renderUI(tags$div(class = "token-display token-waiting", "⏳ Təhlil və yazma icra olunur..."))
    output$ai_result <- renderUI(NULL)
    output$ai_write_status <- renderUI(NULL)

    std_json <- toJSON(df[, std_cols, drop=FALSE], pretty = TRUE, auto_unbox = TRUE)
    prompt <- paste0(
'Sən riyaziyyat kurikulumu üzrə beynəlxalq ekspertisən. Sənin vəzifən ', sinif, '-ci sinif, "', mezmun_label, '" üçün mövcud standartları dərindən təhlil etmək, lazım olanları yenidən yazmaq və nəticəni JSON formatında qaytarmaqdır.

Bu sinif üçün TIMSS səviyyəsi: ', sinif, '-ci sinif

═══════════════════════════════════════════
MÖVCud STANDARTLAR:
═══════════════════════════════════════════
', std_json, '

═══════════════════════════════════════════
TƏHLİL METODOLOGİYASI (hər standart üçün tətbiq et):
═══════════════════════════════════════════

1. TIMSS RİYAZİYYAT ÇƏRÇƏVƏSİ ilə müqayisə:
   - Bilmə (Knowing): faktlar, prosedurlar, konseptlər
   - Tətbiq etmə (Applying): problemlərin həlli, modelləşdirmə
   - Mühakimə yürütmə (Reasoning): əsaslandırma, ümumiləşdirmə, sübut
   - TIMSS 2023 yenilikləri: rəqəmsal alətlər, real həyat konteksti
   → Hansı TIMSS bacarıqları mövcud standartlarda ƏKSİK qalır?

2. PISA RİYAZİ SAVADLILIQ ÇƏRÇƏVƏSİ ilə müqayisə:
   - Formulə etmə (Formulating): real situasiyanı riyazi modelə çevirmə
   - Tətbiq etmə (Employing): riyazi prosedurları istifadə
   - İnterpretasiya (Interpreting): nəticələri real kontekstə qaytarma
   - Mühakimə (Reasoning): riyazi arqumentasiya və sübut
   - PISA 2025: rəqəmsal riyaziyyat, hesablama düşüncəsi
   → Hansı PISA riyazi bacarıqları mövcud standartlarda yoxdur?

3. BLOOM TAKSONOMİYASI balansı:
   - Xatırlama → Anlama → Tətbiq → Analiz → Qiymətləndirmə → Yaratma
   → Mövcud standartlarda Bloom balansı necədir? Yuxarı səviyyələr (Analiz, Qiymətləndirmə, Yaratma) kifayət qədərmi?

4. 6 APARICI ÖLKƏ ilə müqayisə — HƏR BİRİ üçün BOŞLUQ TƏHLİLİ:

   a) SİNQAPUR (Singapore Math):
      - Problem həlli modelləşdirmə (Bar Model), mücərrəddən konkretə
      - Konseptual anlama, hesablama bacarıqları, tətbiqi məsələlər
      → Sinqapur standartlarında olub bizdə OLMAYAN nədir?

   b) FİNLANDİYA (Finnish Mathematics):
      - Fənlərarası əlaqə, real həyat konteksti, riyazi düşüncə
      - Mühakimə və arqumentasiya, riyazi modelləşdirmə
      → Finlandiya modelindən nə öyrənə bilərik?

   c) YAPONİYA (Japanese Sugaku):
      - Dərin konseptual anlama, problem həlli strategiyaları
      - Lesson Study yanaşması, riyazi kommunikasiya
      → Yaponiya standartlarından hansı elementlər əksikdir?

   d) CƏNUBİ KOREYA (Korean Mathematics):
      - Texnologiya ilə inteqrasiya, yüksək səviyyəli düşüncə
      - Riyazi yaradıcılıq, həndəsi vizuallaşdırma
      → Cənubi Koreya standartlarında hansı güclü tərəflər var?

   e) KANADA - ONTARİO (Mathematics):
      - Diferensial öyrənmə, kodlaşdırma və hesablama düşüncəsi
      - Riyazi proses bacarıqları, sosial ədalət konteksti
      → Ontario modelindən hansı boşluqlar görünür?

   f) ESTONİYA (Estonian Mathematics):
      - Rəqəmsal alətlərin inteqrasiyası, riyazi modellər
      - Statistik düşüncə, ehtimal konseptləri
      → Estoniya təcrübəsindən nə götürülməlidir?

5. MÜASİR RİYAZİYYAT TƏHSİLİ TENDENSİYALARI — BOŞLUQ TƏHLİLİ:
   - Hesablama düşüncəsi (Computational Thinking): alqoritmik düşüncə, kodlaşdırma
   - Rəqəmsal alətlər: GeoGebra, Desmos, dinamik həndəsə proqramları
   - Riyazi modelləşdirmə: real həyat problemlərinin riyazi dildə ifadəsi
   - Statistik savadlılıq: data analizi, qrafik interpretasiyası, ehtimal
   - Riyazi kommunikasiya: ideyaların izahı, sübut və arqumentasiya
   - Problem həlli strategiyaları: evristik yanaşmalar, açıq tipli məsələlər
   - Fənlərarası əlaqə: riyaziyyatın fizika, biologiya, iqtisadiyyatda tətbiqi
   → Bu sahələrdən hansıları mövcud standartlarda ƏKSİKDİR?



═══════════════════════════════════════════
CAVAB FORMATI — YALNIZ JSON
═══════════════════════════════════════════
{
  "umumi_qiymetlendirme": "Mövcud standartların ümumi güclü və zəif tərəfləri. TIMSS/PISA/NCTM/Bloom balansı. Əsas boşluqların xülasəsi. 6 ölkə ilə müqayisənin nəticəsi (5-8 cümlə, ətraflı).",
  "standartlar": [
    {
      "standart_kodu": "1.1",
      "alt_standart_kodu": "1-1.1.1",
      "kohne_metni": "Standartın orijinal mətni",
      "yeni_metni": "Yeni təkmilləşdirilmiş mətn (dəyişməyibsə kohne_metni ilə eyni)",
      "mezmun_xetti": "Ədədlər və əməllər",
      "bloom_seviyyesi": "Anlama",
      "cetinlik_seviyyesi": "asan",
      "status": "movcud",
      "esaslandirma": "DEYİSMEYİB: hansı çərçəvəyə uyğundur, güclü tərəfi (2-3 cümlə). YENİLENİB: köhnədə hansı boşluq var idi, yeni mətn hansı tələbi ödəyir, hansı ölkə modelindən ilhamlanıb (5-6 cümlə). SİLİNİB: niyə lazım deyil (2-3 cümlə)."
    }
  ]
}

status dəyərləri YALNIZ 3 ola bilər: "movcud", "yenilenib", "silinib"
QADAĞAN: "yeni" və ya "yeni" statusu YAZMAQ QADAĞANDIR! Yeni standartlar burada YOX, ayrı funksiyada əlavə olunur.
Sən YALNIZ mövcud standartları təhlil edirsən — yeni standart təklif ETMƏ!
Bloom: Xatırlama, Anlama, Tətbiq, Analiz, Qiymətləndirmə, Yaratma
Cetinlik: asan, orta, cetin
Məzmun xətləri: Ədədlər və əməllər, Cəbr, Həndəsə, Ölçmə, Statistika və ehtimal

KRİTİK QAYDALAR:
1. "standartlar" massivində BÜTÜN mövcud standartlar OLMALIDIR! Heç birini buraxma — hər standart üçün status təyin et.
2. YENİLƏNƏNLƏRİN SAYI 3-dən 5-ə qədər olmalıdır. Hər sinif üçün fərqli say ola bilər — bəzən 3, bəzən 4, bəzən 5. Ən ciddi problemləri olan standartları seç. HƏR SİNİFDƏ DƏQİQ EYNİ SAY OLMAMALIDIR!
3. "yenilenib" statusu ver əgər:
   - Standart müasir beynəlxalq tələblərə uyğun deyil (TIMSS/PISA/NCTM boşluğu var)
   - Bloom səviyyəsi bu sinif üçün uyğun deyil
   - Standart qeyri-müəyyəndir, ölçülə bilən nəticə vermir
   - Standartda aktiv komponent yoxdur, yalnız passiv bacarıq var
4. "silinib" statusu nadir hallarda ver — yalnız standart artıq tamamilə mənasız olanda.
5. "yenilenib" statuslu standartlarda "yeni_metni" FƏRQLI OLMALIDIR — köhnə ilə eyni yazmaq QADAĞANDIR!
6. "movcud" statuslu standartlarda "yeni_metni" = "kohne_metni" olmalıdır.
7. YALNIZ JSON formatında cavab ver, başqa heç nə yazma.
8. JSON STRING dəyərlərində QOŞA DIRNAQ (") İSTİFADƏ ETMƏ! Əvəzinə tək dırnaq (\x27) və ya heç dırnaq istifadə etmə. Məsələn: "TIMSS-in Mühakimə yürütmə komponenti" — düzgün. "TIMSS-in \\"Mühakimə yürütmə\\" komponenti" — SƏHV!
9. Əsaslandırmada KONKRET ölkə adı və çərçəvə adı göstər.
9. "esaslandirma" sahəsi VACİBDİR! "movcud" üçün 2-3 cümlə (qısa: hansı çərçəvəyə uyğundur). "yenilenib" üçün 4-5 cümlə (nə dəyişdi, niyə dəyişdi, hansı beynəlxalq çərçəvə və ölkə modeli əsas götürüldü). Mütəxəssislər bu izahatı oxuyub razılaşmalıdır.

═══════════════════════════════════════════
YOXLAMA KRİTERİYALARI (yalnız ciddi pozuntular üçün "yenilenib"):
═══════════════════════════════════════════

A) BLOOM TAKSONOMİYASI — yalnız çox aydın uyğunsuzluq varsa yenilə:
   - 1-2-ci siniflər: əsasən Xatırlama, Anlama olmalı
   - 5-7-ci siniflər: Tətbiq, Analiz olmalı
   - 10-11-ci siniflər: Qiymətləndirmə, Yaratma olmalı

B) NCTM STANDARTLARI UYĞUNLUĞU — yalnız ciddi uyğunsuzluq varsa:
   - Standart öz sinif səviyyəsi üçün çox sadə və ya çox çətin olanda

C) MÜASİR TƏLƏBLƏRİN əsas boşluqları — yalnız əsaslı dəyişiklik lazım olanda:
   - Standart tamamilə passivdirsə və heç bir aktiv komponent yoxdursa
   - Standart o qədər ümumidür ki, heç nə ölçmək mümkün deyil

DİQQƏT: Standart əsasən yaxşıdırsa, kiçik çatışmazlıqlar varsa belə "movcud" statusu ver və esaslandirmada qeyd et. BOŞLUQLARI "Yeni standart təklif et" düyməsi ilə ayrıca dolduracağıq.')

    session$onFlushed(function() {
      res <- call_claude(prompt)

      if (res$success) {
        tryCatch({
          # JSON parse
          json_text <- res$text
          json_text <- gsub("```json\\s*", "", json_text, perl = TRUE)
          json_text <- gsub("```\\s*$", "", json_text, perl = TRUE)
          json_text <- gsub("```", "", json_text)
          m <- regmatches(json_text, regexpr("\\{[\\s\\S]*\\}", json_text, perl = TRUE))
          if (length(m) == 0) stop("JSON tapilmadi")
          json_clean <- m[1]
          parsed <- tryCatch(fromJSON(json_clean, simplifyDataFrame = TRUE), error = function(e) {
            cat("JSON parse xetasi, duzeltme cehdi...\n")
            json_fixed <- fix_json_quotes(json_clean)
            fromJSON(json_fixed, simplifyDataFrame = TRUE)
          })

          std_df <- parsed$standartlar
          umumi <- if (!is.null(parsed$umumi_qiymetlendirme)) parsed$umumi_qiymetlendirme else ""

          # AI-dan qaytarilmayan standartlari avtomatik "movcud" kimi elave et
          n_orig <- nrow(df)
          n_returned <- if (is.data.frame(std_df)) nrow(std_df) else 0

          if (n_returned < n_orig) {
            matched_idx <- c()
            if (n_returned > 0) {
              for (j in 1:n_returned) {
                ai_row <- std_df[j, ]
                ai_ak <- if ("alt_standart_kodu" %in% names(ai_row)) as.character(ai_row$alt_standart_kodu) else ""
                ai_sk <- if ("standart_kodu" %in% names(ai_row)) as.character(ai_row$standart_kodu) else ""
                idx <- which(as.character(df$alt_standart_kodu) == ai_ak)
                if (length(idx) == 0) idx <- which(endsWith(as.character(df$alt_standart_kodu), ai_ak))
                if (length(idx) == 0) idx <- which(as.character(df$standart_kodu) == ai_sk)
                if (length(idx) > 0) matched_idx <- c(matched_idx, idx[1])
              }
            }
            missing_idx <- setdiff(1:n_orig, matched_idx)
            cat(paste0("AI ", n_returned, "/", n_orig, " standart qaytardi. ", length(missing_idx), " eksik standart movcud olaraq elave olunur.\n"))
            for (mi in missing_idx) {
              orig <- df[mi, ]
              orig_metni <- as.character(orig$alt_standart_metni)
              new_row <- data.frame(
                standart_kodu = as.character(orig$standart_kodu),
                alt_standart_kodu = as.character(orig$alt_standart_kodu),
                kohne_metni = orig_metni,
                yeni_metni = orig_metni,
                mezmun_xetti = as.character(orig$mezmun_xetti),
                bloom_seviyyesi = if ("bloom_seviyyesi" %in% names(orig)) as.character(orig$bloom_seviyyesi) else "",
                cetinlik_seviyyesi = "",
                status = "movcud",
                esaslandirma = "",
                stringsAsFactors = FALSE
              )
              if (is.data.frame(std_df)) {
                for (col in setdiff(names(std_df), names(new_row))) new_row[[col]] <- ""
                for (col in setdiff(names(new_row), names(std_df))) std_df[[col]] <- ""
                std_df <- rbind(std_df, new_row)
              } else {
                std_df <- new_row
              }
            }
            parsed$standartlar <- std_df
          }
          # yeni/yeni statuslu standartları sil — bu addımda yalnız deyismeyib/yenilenib/silinib olmalıdır
          if (is.data.frame(std_df) && nrow(std_df) > 0 && "status" %in% names(std_df)) {
            bad_status <- std_df$status %in% c("yeni", "yeni")
            if (any(bad_status)) {
              cat(paste0("XEBERDARLIQ: ", sum(bad_status), " standart yeni/yeni statusu ile qaytarildi — silinir!\n"))
              std_df <- std_df[!bad_status, , drop=FALSE]
            }
          }
          cat(paste0("Yekun standart sayi: ", nrow(std_df), " (orijinal: ", n_orig, ")\n"))

          # ===== BAZAYA YAZ =====
          sinif_val <- as.integer(isolate(input$sinif_sec))
          tryCatch({
            if (!USE_CSV) {
              con_w <- get_con()
              del_query <- paste0("DELETE FROM yenilenmi_standartlar WHERE sinif = ", sinif_val, " AND deyisiklik_novu != 'yeni'")
              mezmun_val <- isolate(input$mezmun_sec)
              if (!is.null(mezmun_val) && mezmun_val != "all") {
                del_query <- paste0(del_query, " AND mezmun_xetti = '", gsub("'", "''", mezmun_val), "'")
              }
              dbExecute(con_w, del_query)

              for (i in 1:nrow(std_df)) {
                r <- std_df[i, ]
                st <- if ("status" %in% names(r)) as.character(r$status) else "movcud"
                yeni_m <- if ("yeni_metni" %in% names(r)) as.character(r$yeni_metni) else ""
                kohne_m <- if ("kohne_metni" %in% names(r)) as.character(r$kohne_metni) else ""
                mez <- if ("mezmun_xetti" %in% names(r)) as.character(r$mezmun_xetti) else ""
                bloom <- if ("bloom_seviyyesi" %in% names(r)) as.character(r$bloom_seviyyesi) else ""
                cetinlik <- if ("cetinlik_seviyyesi" %in% names(r)) as.character(r$cetinlik_seviyyesi) else ""
                xarak <- if ("esaslandirma" %in% names(r)) as.character(r$esaslandirma) else ""

                # movcud_standartlar-dan kod-u tap
                alt_kod_val <- if ("alt_standart_kodu" %in% names(r)) as.character(r$alt_standart_kodu) else ""
                orig_kod <- ""
                if (nrow(df) > 0 && nchar(alt_kod_val) > 0 && "standart_kodu" %in% names(df)) {
                  idx_m <- which(as.character(df$alt_standart_kodu) == alt_kod_val)
                  if (length(idx_m) == 0) idx_m <- which(endsWith(as.character(df$alt_standart_kodu), alt_kod_val))
                  if (length(idx_m) > 0) orig_kod <- as.character(df$standart_kodu[idx_m[1]])
                }

                alt_kod_db <- if (nchar(alt_kod_val) > 0) alt_kod_val else ""
                dbExecute(con_w, paste0(
                  "INSERT INTO yenilenmi_standartlar (sinif, standart_kodu, alt_standart_kodu, mezmun_xetti, bloom_seviyyesi, deyisiklik_novu, standart_metni, esaslandirma, kohne_standart_metni) VALUES (",
                  sinif_val, ", ",
                  "'", gsub("'", "''", orig_kod), "', ",
                  "'", gsub("'", "''", alt_kod_db), "', ",
                  "'", gsub("'", "''", mez), "', ",
                  "'", gsub("'", "''", bloom), "', ",
                  "'", gsub("'", "''", st), "', ",
                  "'", gsub("'", "''", yeni_m), "', ",
                  "'", gsub("'", "''", xarak), "', ",
                  "'", gsub("'", "''", kohne_m), "')"
                ))
              }
              dbDisconnect(con_w)
            } else {
              csv_path <- file.path(getwd(), "data", "yenilenmi_standartlar_backup.csv")
              df_old <- if (file.exists(csv_path)) read.csv(csv_path, stringsAsFactors=FALSE, fileEncoding="UTF-8") else data.frame()
              if (nrow(df_old) > 0) df_old <- df_old[!(df_old$sinif == sinif_val & df_old$status != "yeni"), , drop=FALSE]
              write_rows <- list()
              for (i in 1:nrow(std_df)) {
                r <- std_df[i, ]
                alt_kod_val <- if ("alt_standart_kodu" %in% names(r)) as.character(r$alt_standart_kodu) else ""
                orig_kod <- ""
                if (nrow(df) > 0 && nchar(alt_kod_val) > 0 && "standart_kodu" %in% names(df)) {
                  idx_m <- which(as.character(df$alt_standart_kodu) == alt_kod_val)
                  if (length(idx_m) > 0) orig_kod <- as.character(df$standart_kodu[idx_m[1]])
                }
                write_rows[[i]] <- data.frame(
                  sinif = sinif_val,
                  kod = orig_kod,
                  mezmun_xetti = if ("mezmun_xetti" %in% names(r)) as.character(r$mezmun_xetti) else "",
                  bloom_seviyyesi = if ("bloom_seviyyesi" %in% names(r)) as.character(r$bloom_seviyyesi) else "",
                  cetinlik_seviyyesi = if ("cetinlik_seviyyesi" %in% names(r)) as.character(r$cetinlik_seviyyesi) else "",
                  status = if ("status" %in% names(r)) as.character(r$status) else "movcud",
                  standart_metni = if ("yeni_metni" %in% names(r)) as.character(r$yeni_metni) else "",
                  esaslandirma = if ("esaslandirma" %in% names(r)) as.character(r$esaslandirma) else "",
                  kohne_standart_metni = if ("kohne_metni" %in% names(r)) as.character(r$kohne_metni) else "",
                  stringsAsFactors = FALSE)
              }
              df_write <- do.call(rbind, write_rows)
              if (nrow(df_old) > 0) {
                common_cols <- intersect(names(df_old), names(df_write))
                df_combined <- rbind(df_old[, common_cols, drop=FALSE], df_write[, common_cols, drop=FALSE])
              } else df_combined <- df_write
              write.csv(df_combined, csv_path, row.names = FALSE, fileEncoding = "UTF-8")
            }

            n_movcud <- sum(std_df$status == "movcud", na.rm=TRUE)
            n_yenilenib <- sum(std_df$status == "yenilenib", na.rm=TRUE)
            n_silinib <- sum(std_df$status == "silinib", na.rm=TRUE)
            save_target <- if (USE_CSV) "CSV faylina" else "PostgreSQL bazasina"

            output$ai_write_status <- renderUI(
              tags$div(style="padding:20px;background:#dcfce7;border:2px solid #4CAF50;border-radius:12px;margin-top:16px;",
                tags$h4(style="color:#166534;margin:0 0 10px 0;", paste0("Yekun standartlar ", save_target, " yazildi!")),
                tags$p(style="font-size:16px;color:#166534;margin:0;",
                  paste0("Sinif ", sinif_val, ": Movcud: ", as.integer(n_movcud),
                         ", Yenilenib: ", as.integer(n_yenilenib),
                         ", Silinib: ", as.integer(n_silinib),
                         " — Cemi: ", nrow(std_df))),
                tags$p(style="font-size:14px;color:#166534;margin:10px 0 0 0;",
                  "'Yekun Standartlar' tab-inda butun standartlari gore bilersiniz."))
            )
            showNotification(paste0("Sinif ", sinif_val, ": ", nrow(std_df), " standart ", save_target, " yazildi!"), type = "message", duration = 10)
            stats_refresh(isolate(stats_refresh()) + 1)  # Ana səhifəni yenilə
            cat(paste0("Yekun yazildi: sinif=", sinif_val, ", deyismeyib=", n_movcud, ", yenilenib=", n_yenilenib, ", silinib=", n_silinib, ", CEMI=", nrow(std_df), "\n"))
          }, error = function(e) {
            output$ai_write_status <- renderUI(
              tags$div(style="padding:20px;color:#dc2626;font-weight:600;margin-top:16px;",
                paste0("Bazaya yazma xetasi: ", e$message)))
          })

          # --- Render HTML kartlar ---
          status_renk <- c("movcud" = "#4CAF50", "yenilenib" = "#FF9800", "silinib" = "#F44336")
          status_adi <- c("movcud" = "MOVCUD", "yenilenib" = "YENiLENiB", "silinib" = "SiLiNiB")

          cards_html <- ""
          if (is.data.frame(std_df) && nrow(std_df) > 0) {
            n_d <- sum(std_df$status == "movcud", na.rm=TRUE)
            n_y <- sum(std_df$status == "yenilenib", na.rm=TRUE)
            n_s <- sum(std_df$status == "silinib", na.rm=TRUE)

            cards_html <- paste0(
              '<div style="display:flex;gap:12px;margin:16px 0;flex-wrap:wrap;">',
              '<div style="padding:10px 20px;background:#E8F5E9;border-radius:8px;font-weight:600;color:#2E7D32;">MOVCUD: ', n_d, '</div>',
              '<div style="padding:10px 20px;background:#FFF3E0;border-radius:8px;font-weight:600;color:#E65100;">YENiLENiB: ', n_y, '</div>',
              '<div style="padding:10px 20px;background:#FFEBEE;border-radius:8px;font-weight:600;color:#C62828;">SiLiNiB: ', n_s, '</div>',
              '</div>')

            for (i in 1:nrow(std_df)) {
              r <- std_df[i, ]
              st <- if ("status" %in% names(r)) as.character(r$status) else "movcud"
              renk <- if (st %in% names(status_renk)) status_renk[[st]] else "#1976D2"
              ad <- if (st %in% names(status_adi)) status_adi[[st]] else st
              kod_raw <- if ("alt_standart_kodu" %in% names(r)) as.character(r$alt_standart_kodu) else if ("standart_kodu" %in% names(r)) as.character(r$standart_kodu) else ""
              kod <- kod_raw
              yeni_m <- if ("yeni_metni" %in% names(r)) as.character(r$yeni_metni) else ""
              kohne_m <- if ("kohne_metni" %in% names(r)) as.character(r$kohne_metni) else ""
              xarak <- if ("esaslandirma" %in% names(r)) as.character(r$esaslandirma) else ""
              bloom <- if ("bloom_seviyyesi" %in% names(r)) as.character(r$bloom_seviyyesi) else ""

              metn_html <- ""
              if (st == "yenilenib") {
                metn_html <- paste0(
                  '<div style="font-size:14px;color:#999;text-decoration:line-through;margin-bottom:4px;">', kohne_m, '</div>',
                  '<div style="font-size:15px;color:#333;margin-bottom:8px;font-weight:500;">', yeni_m, '</div>')
              } else {
                metn_html <- paste0('<div style="font-size:15px;color:#333;margin-bottom:8px;">', yeni_m, '</div>')
              }

              cards_html <- paste0(cards_html,
                '<div style="border:2px solid ', renk, ';border-radius:12px;padding:16px;margin:10px 0;background:#FAFAFA;">',
                '<div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:8px;">',
                '<span style="font-weight:700;color:#0D47A1;font-size:16px;">', kod, '</span>',
                '<div><span style="padding:3px 10px;border-radius:12px;font-size:12px;background:#E3F2FD;color:#1565C0;margin-right:6px;">', bloom, '</span>',
                '<span style="padding:4px 14px;border-radius:20px;font-weight:600;font-size:13px;background:', renk, ';color:white;">', ad, '</span></div>',
                '</div>',
                metn_html,
                '<div style="font-size:14px;color:#555;padding:10px;background:#F5F5F5;border-radius:8px;border-left:4px solid ', renk, ';">',
                '<b>Xarakteristika:</b> ', xarak, '</div>',
                '</div>')
            }
          }

          full_html <- paste0(
            '<div style="font-size:16px;line-height:1.7;padding:16px;background:#F8F9FA;border-radius:10px;border-left:4px solid #1976D2;margin-bottom:20px;">',
            umumi, '</div>', cards_html)

          session$sendCustomMessage("ai_timer_stop", list(
            target = "ai_timer_panel", ok = TRUE,
            elapsed = sprintf("%.1f", res$time_sec),
            inp = formatC(res$input_tokens, format = "d", big.mark = ","),
            out = formatC(res$output_tokens, format = "d", big.mark = ","),
            cost = sprintf("$%.4f", (res$input_tokens * 3 + res$output_tokens * 15) / 1e6)
          ))

          total_tok <- res$input_tokens + res$output_tokens
          output$ai_token_display <- renderUI(
            tags$div(class = "token-display token-done",
              paste0("Tehlil tamamlandi | ", sprintf("%.1f", res$time_sec), " san | ",
                     formatC(total_tok, format="d", big.mark=","), " token | $",
                     sprintf("%.4f", (res$input_tokens * 3 + res$output_tokens * 15) / 1e6)))
          )

          # HTML hesabati yaz
          stats_html <- make_stats_bar(res$time_sec, res$input_tokens, res$output_tokens)
          report_dir <- file.path(getwd(), "html_reports")
          if (!dir.exists(report_dir)) dir.create(report_dir, recursive = TRUE)
          mezmun_suffix <- if (isolate(input$mezmun_sec) == "all") "hamisi" else gsub("[^a-zA-Z0-9]", "_", tolower(isolate(input$mezmun_sec)))
          report_file <- file.path(report_dir, paste0("sinif_", sinif_val, "_", mezmun_suffix, "_tehlil.html"))
          report_content <- paste0(
            '<!DOCTYPE html>\n<html lang="az">\n<head>\n<meta charset="UTF-8">\n',
            '<meta name="viewport" content="width=device-width, initial-scale=1.0">\n',
            '<title>Sinif ', sinif_val, ' - Tehlil</title>\n',
            '<style>body{font-family:"Noto Sans",sans-serif;font-size:17px;line-height:1.85;max-width:1100px;margin:0 auto;padding:40px;background:#f8fafc;color:#1e293b}',
            '.header{background:linear-gradient(135deg,#0D47A1,#1976D2);color:white;padding:30px;border-radius:14px;margin-bottom:30px}',
            '.header h1{color:white;border:none;margin:0}.header p{color:#bbdefb;margin:8px 0 0}',
            '</style>\n</head>\n<body>\n',
            '<div class="header"><h1>Sinif ', sinif_val, ' — Tehlil (', mezmun_label, ')</h1>',
            '<p>TIMSS/NCTM | ', CLAUDE_MODEL, ' | ', format(Sys.time(), "%Y-%m-%d %H:%M"), '</p></div>\n',
            full_html, '\n', stats_html, '\n</body>\n</html>')
          writeLines(report_content, report_file, useBytes = FALSE)

          output$ai_result <- renderUI(tagList(
            tags$div(class = "ai-output", HTML(full_html)),
            HTML(stats_html),
            tags$div(style = "margin-top:16px;padding:12px 20px;background:#dcfce7;border:1px solid #86efac;border-radius:10px;font-size:15px;color:#166534;",
              paste0("Tehlil yazildi: html_reports/sinif_", sinif_val, "_", mezmun_suffix, "_tehlil.html"))
          ))

        }, error = function(e) {
          cat(paste0("\n=== JSON PARSE XETASI ===\n", e$message, "\n", paste(capture.output(traceback()), collapse="\n"), "\n=========================\n"))
          session$sendCustomMessage("ai_timer_stop", list(
            target = "ai_timer_panel", ok = TRUE,
            elapsed = sprintf("%.1f", res$time_sec),
            inp = formatC(res$input_tokens, format="d", big.mark=","),
            out = formatC(res$output_tokens, format="d", big.mark=","),
            cost = sprintf("$%.4f", (res$input_tokens*3 + res$output_tokens*15)/1e6)))
          output$ai_token_display <- renderUI(tags$div(class="token-display token-done",
            paste0(sprintf("%.1f", res$time_sec), " san | XETA: ", e$message)))
          output$ai_result <- renderUI(tags$div(class = "ai-output",
            tags$pre(style="color:red;font-size:13px;white-space:pre-wrap;", e$message),
            HTML(res$text)))
        })

      } else {
        session$sendCustomMessage("ai_timer_stop", list(
          target = "ai_timer_panel", ok = FALSE,
          elapsed = sprintf("%.1f", res$time_sec), inp = "0", out = "0", cost = "$0"))
        output$ai_token_display <- renderUI(tags$div(class = "token-display token-error",
          paste0("Xeta (", sprintf("%.1f", res$time_sec), " san)")))
        output$ai_result <- renderUI(tags$div(style = "padding:30px;color:#dc2626;",
          tags$h3("Xeta bas verdi"), tags$p(res$error)))
      }
    }, once = TRUE)
  })

  # ============================================================
  # YENi STANDART TEKLIF ET — Ayrica API cagirisii ile boslluqlari doldur
  # ============================================================
  observeEvent(input$btn_new_standards, {
    sinif <- input$sinif_sec
    mezmun <- input$mezmun_sec
    cefr_sev <- "—"
    mezmun_label <- if (mezmun == "all") "butun mezmun xetleri" else mezmun

    # Movcud standartlari kontekst kimi ver
    if (USE_CSV) {
      df_existing <- csv_movcud()
      if (nrow(df_existing) > 0) {
        df_existing <- df_existing[df_existing$sinif == as.integer(sinif), , drop=FALSE]
        if (mezmun != "all") df_existing <- df_existing[df_existing$mezmun_xetti == mezmun, , drop=FALSE]
      }
    } else {
      con_n <- get_con()
      query <- paste0("SELECT * FROM movcud_standartlar WHERE sinif = ", sinif)
      if (mezmun != "all") query <- paste0(query, " AND mezmun_xetti = '", gsub("'", "''", mezmun), "'")
      df_existing <- dbGetQuery(con_n, query)
      dbDisconnect(con_n)
    }

    if (nrow(df_existing) == 0) {
      output$ai_new_result <- renderUI(tags$div(style="padding:30px;color:#dc2626;",
        tags$h3("Melumat yoxdur"), tags$p("Bu sinif ucun movcud standart tapilmadi.")))
      return()
    }

    # Movcud kodlarin sonuncu nomresini tap (yeni kodlar ucun)
    existing_kods <- if ("standart_kodu" %in% names(df_existing)) df_existing$kod else c()

    session$sendCustomMessage("ai_timer_start", list(
      target = "ai_timer_panel2",
      status = "AI yeni standartlar teklif edir...",
      info1 = paste0(sinif, "-ci sinif"),
      info2 = mezmun_label
    ))
    output$ai_new_token_display <- renderUI(tags$div(class = "token-display token-waiting", "AI yeni standartlar hazirlayir..."))
    output$ai_new_result <- renderUI(NULL)
    output$ai_new_write_status <- renderUI(NULL)

    std_cols_n <- intersect(c("standart_kodu","standart_metni","alt_standart_kodu","alt_standart_metni",
                              "mezmun_xetti","bloom_seviyyesi","standart_kodu"), names(df_existing))
    existing_json <- toJSON(df_existing[, std_cols_n, drop=FALSE], pretty=TRUE, auto_unbox=TRUE)

    prompt_new <- paste0(
'Sen riyaziyyat kurikulumu uzre beynelxalq ekspertisen.
', sinif, '-ci sinif, "', mezmun_label, '" ucun movcud standartlar bunlardir:
', existing_json, '

Bu sinif ucun TIMSS seviyyesi: ', sinif, '-ci sinif

TIMSS, PISA, NCTM, Bloom taksonomiyasi ve Sinqapur, Finlandiya, Yaponiya, Cenubi Koreya, Kanada, Estoniya standartlari esasinda BOSLLUQLARI mueyyen et ve YENI standartlar teklif et.

Movcud standartlari TEKRARLAMA! Yalniz EKSIK olan, elave edilmeli YENI standartlar teklif et.

Yeni kodlar movcud kodlardan SONRA gelmelidir (mes: movcud son kod 4.1.3 olsa, yeni kod 4.1.4 olsun).
Yeni standartlar ucun "standart_kodu" sahesine R', sinif, '.X.X formati yaz.

CAVABI YALNIZ JSON formatinda ver:
{
  "yeni_standartlar": [
    {
      "standart_kodu": "R', sinif, '.5.1",
      "standart_metni": "Yeni standart metni",
      "mezmun_xetti": "Ededler ve emeller",
      "bloom_seviyyesi": "Anlama",
      "esaslandirma": "Niye lazimdir — hansi boshlugu doldurur, hansi beynelxalq cercheveye esasen"
    }
  ]
}

Bloom: Xatirlama, Anlama, Tetbiq, Analiz, Qiymetlendirme, Yaratma
Cetinlik: asan, orta, cetin

KRİTİK: 3-den 5-e qeder yeni standart teklif et. Her sinif ucun ferqli say ola biler (3, 4 ve ya 5). En vacib bosluqlari sec.

YALNIZ JSON, bashqa hech ne yazma.')

    session$onFlushed(function() {
      res <- call_claude(prompt_new)

      if (res$success) {
        tryCatch({
          json_text <- res$text
          json_text <- gsub("```json\\s*", "", json_text, perl = TRUE)
          json_text <- gsub("```\\s*$", "", json_text, perl = TRUE)
          json_text <- gsub("```", "", json_text)
          m <- regmatches(json_text, regexpr("\\{[\\s\\S]*\\}", json_text, perl = TRUE))
          if (length(m) == 0) stop("JSON tapilmadi")
          json_clean <- m[1]
          parsed_new <- tryCatch(fromJSON(json_clean, simplifyDataFrame = TRUE), error = function(e) {
            json_fixed <- fix_json_quotes(json_clean)
            fromJSON(json_fixed, simplifyDataFrame = TRUE)
          })
          yeni_df <- parsed_new$yeni_standartlar

          if (!is.data.frame(yeni_df) || nrow(yeni_df) == 0) stop("Yeni standart tapilmadi")
          # Maksimum 5 yeni standart
          if (nrow(yeni_df) > 5) yeni_df <- yeni_df[1:5, , drop=FALSE]

          sinif_val <- as.integer(isolate(input$sinif_sec))

          # Bazaya yaz (APPEND - movcudlari silme)
          tryCatch({
            if (!USE_CSV) {
              con_nw <- get_con()
              for (i in 1:nrow(yeni_df)) {
                r <- yeni_df[i, ]
                kod_val <- if ("standart_kodu" %in% names(r)) as.character(r$standart_kodu) else ""
                mez <- if ("mezmun_xetti" %in% names(r)) as.character(r$mezmun_xetti) else ""
                bloom <- if ("bloom_seviyyesi" %in% names(r)) as.character(r$bloom_seviyyesi) else ""
                cetinlik <- if ("cetinlik_seviyyesi" %in% names(r)) as.character(r$cetinlik_seviyyesi) else ""
                metn <- if ("standart_metni" %in% names(r)) as.character(r$standart_metni) else ""
                xarak <- if ("esaslandirma" %in% names(r)) as.character(r$esaslandirma) else ""

                dbExecute(con_nw, paste0(
                  "INSERT INTO yenilenmi_standartlar (sinif, standart_kodu, mezmun_xetti, bloom_seviyyesi, deyisiklik_novu, standart_metni, esaslandirma, kohne_standart_metni) VALUES (",
                  sinif_val, ", ",
                  "'", gsub("'", "''", kod_val), "', ",
                  "'", gsub("'", "''", mez), "', ",
                  "'", gsub("'", "''", bloom), "', ",
                  "'yeni', ",
                  "'", gsub("'", "''", metn), "', ",
                  "'", gsub("'", "''", xarak), "', ",
                  "'')"
                ))
              }
              dbDisconnect(con_nw)
            } else {
              csv_path <- file.path(getwd(), "data", "yenilenmi_standartlar_backup.csv")
              df_old <- if (file.exists(csv_path)) read.csv(csv_path, stringsAsFactors=FALSE, fileEncoding="UTF-8") else data.frame()
              for (i in 1:nrow(yeni_df)) {
                r <- yeni_df[i, ]
                new_row <- data.frame(
                  sinif = sinif_val,
                  kod = if ("standart_kodu" %in% names(r)) as.character(r$standart_kodu) else "",
                  mezmun_xetti = if ("mezmun_xetti" %in% names(r)) as.character(r$mezmun_xetti) else "",
                  bloom_seviyyesi = if ("bloom_seviyyesi" %in% names(r)) as.character(r$bloom_seviyyesi) else "",
                  cetinlik_seviyyesi = if ("cetinlik_seviyyesi" %in% names(r)) as.character(r$cetinlik_seviyyesi) else "",
                  status = "yeni",
                  standart_metni = if ("standart_metni" %in% names(r)) as.character(r$standart_metni) else "",
                  esaslandirma = if ("esaslandirma" %in% names(r)) as.character(r$esaslandirma) else "",
                  kohne_standart_metni = "",
                  stringsAsFactors = FALSE)
                if (nrow(df_old) > 0) {
                  common_cols <- intersect(names(df_old), names(new_row))
                  df_old <- rbind(df_old[, common_cols, drop=FALSE], new_row[, common_cols, drop=FALSE])
                } else df_old <- new_row
              }
              write.csv(df_old, csv_path, row.names = FALSE, fileEncoding = "UTF-8")
            }

            save_target <- if (USE_CSV) "CSV faylina" else "PostgreSQL bazasina"
            output$ai_new_write_status <- renderUI(
              tags$div(style="padding:20px;background:#dcfce7;border:2px solid #4CAF50;border-radius:12px;margin-top:16px;",
                tags$h4(style="color:#166534;margin:0 0 10px 0;",
                  paste0(nrow(yeni_df), " yeni standart ", save_target, " yazildi (status: yeni)")),
                tags$p(style="font-size:14px;color:#166534;margin:0;",
                  "'Yekun Standartlar' tab-inda gore bilersiniz."))
            )
            showNotification(paste0(nrow(yeni_df), " yeni standart elave olundu!"), type = "message", duration = 10)
            stats_refresh(isolate(stats_refresh()) + 1)  # Ana səhifəni yenilə
          }, error = function(e) {
            output$ai_new_write_status <- renderUI(
              tags$div(style="padding:20px;color:#dc2626;font-weight:600;margin-top:16px;",
                paste0("Bazaya yazma xetasi: ", e$message)))
          })

          # Kartlar goster
          yeni_html <- ""
          for (i in 1:nrow(yeni_df)) {
            r <- yeni_df[i, ]
            kod_val <- if ("standart_kodu" %in% names(r)) as.character(r$standart_kodu) else ""
            metn <- if ("standart_metni" %in% names(r)) as.character(r$standart_metni) else ""
            xarak <- if ("esaslandirma" %in% names(r)) as.character(r$esaslandirma) else ""
            bloom <- if ("bloom_seviyyesi" %in% names(r)) as.character(r$bloom_seviyyesi) else ""
            mez <- if ("mezmun_xetti" %in% names(r)) as.character(r$mezmun_xetti) else ""

            yeni_html <- paste0(yeni_html,
              '<div style="border:2px solid #2196F3;border-radius:12px;padding:16px;margin:10px 0;background:#E3F2FD;">',
              '<div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:8px;">',
              '<span style="font-weight:700;color:#0D47A1;font-size:16px;">YENI: ', kod_val, '</span>',
              '<div>',
              '<span style="padding:3px 10px;border-radius:12px;font-size:12px;background:#BBDEFB;color:#0D47A1;margin-right:4px;">', mez, '</span>',
              '<span style="padding:3px 10px;border-radius:12px;font-size:12px;background:#BBDEFB;color:#0D47A1;margin-right:4px;">', bloom, '</span>',
              '<span style="padding:4px 14px;border-radius:20px;font-weight:600;font-size:13px;background:#2196F3;color:white;">YENI</span>',
              '</div></div>',
              '<div style="font-size:15px;color:#333;margin-bottom:8px;">', metn, '</div>',
              '<div style="font-size:14px;color:#555;padding:10px;background:#F5F5F5;border-radius:8px;border-left:4px solid #2196F3;">',
              '<b>Xarakteristika:</b> ', xarak, '</div>',
              '</div>')
          }

          session$sendCustomMessage("ai_timer_stop", list(
            target = "ai_timer_panel2", ok = TRUE,
            elapsed = sprintf("%.1f", res$time_sec),
            inp = formatC(res$input_tokens, format="d", big.mark=","),
            out = formatC(res$output_tokens, format="d", big.mark=","),
            cost = sprintf("$%.4f", (res$input_tokens*3 + res$output_tokens*15)/1e6)
          ))

          total_tok <- res$input_tokens + res$output_tokens
          output$ai_new_token_display <- renderUI(
            tags$div(class = "token-display token-done",
              paste0("Yeni standartlar hazirlandi | ", sprintf("%.1f", res$time_sec), " san | ",
                     formatC(total_tok, format="d", big.mark=","), " token | $",
                     sprintf("%.4f", (res$input_tokens * 3 + res$output_tokens * 15) / 1e6)))
          )
          output$ai_new_result <- renderUI(tagList(
            tags$h3(style="color:#1565C0;", paste0(nrow(yeni_df), " Yeni Standart Teklifi")),
            HTML(yeni_html),
            HTML(make_stats_bar(res$time_sec, res$input_tokens, res$output_tokens))
          ))

        }, error = function(e) {
          session$sendCustomMessage("ai_timer_stop", list(
            target = "ai_timer_panel2", ok = TRUE,
            elapsed = sprintf("%.1f", res$time_sec),
            inp = formatC(res$input_tokens, format="d", big.mark=","),
            out = formatC(res$output_tokens, format="d", big.mark=","),
            cost = sprintf("$%.4f", (res$input_tokens*3 + res$output_tokens*15)/1e6)))
          output$ai_new_token_display <- renderUI(tags$div(class="token-display token-done",
            paste0(sprintf("%.1f", res$time_sec), " san | JSON parse xetasi")))
          output$ai_new_result <- renderUI(tags$div(class = "ai-output", HTML(res$text)))
        })
      } else {
        session$sendCustomMessage("ai_timer_stop", list(
          target = "ai_timer_panel2", ok = FALSE,
          elapsed = sprintf("%.1f", res$time_sec), inp = "0", out = "0", cost = "$0"))
        output$ai_new_token_display <- renderUI(tags$div(class = "token-display token-error",
          paste0("Xeta (", sprintf("%.1f", res$time_sec), " san)")))
        output$ai_new_result <- renderUI(tags$div(style = "padding:30px;color:#dc2626;",
          tags$h3("Xeta bas verdi"), tags$p(res$error)))
      }
    }, once = TRUE)
  })

  # ============================================================
  # YEKUN STANDARTLAR TAB
  # ============================================================

  # Yekun data reactive
  # Yekun tab sinif seçicisini sidebar ilə sinxronlaşdır
  observeEvent(input$sinif_sec, {
    updateSelectInput(session, "yekun_sinif", selected = input$sinif_sec)
  })

  data_yekun <- reactive({
    stats_refresh()  # AI yazdıqdan sonra yenilənsin
    sinif <- as.integer(input$yekun_sinif)
    tryCatch({
      if (USE_CSV) {
        f <- file.path(getwd(), "data", "yenilenmi_standartlar_backup.csv")
        if (!file.exists(f)) return(data.frame())
        df <- read.csv(f, stringsAsFactors = FALSE, fileEncoding = "UTF-8")
        if (nrow(df) == 0) return(df)
        df <- df[df$sinif == sinif, , drop=FALSE]
      } else {
        con <- get_con(); on.exit(dbDisconnect(con))
        df <- dbGetQuery(con, sprintf(
          "SELECT * FROM yenilenmi_standartlar WHERE sinif = %d ORDER BY CASE deyisiklik_novu WHEN 'yeni' THEN 1 ELSE 0 END, mezmun_xetti, standart_kodu", sinif))
      }
      # Status filtri
      if (!is.null(input$yekun_status_filter) && input$yekun_status_filter != "all") {
        df <- df[df$deyisiklik_novu == input$yekun_status_filter, , drop=FALSE]
      }
      df
    }, error = function(e) data.frame())
  })

  # Value boxes
  output$vb_yekun_umumi <- renderValueBox({
    valueBox(yekun_counts()$umumi, "Ümumi", icon = icon("list"), color = "blue")
  })

  # Yekun value boxlar — filtrsiz, sinif üzrə
  yekun_counts <- reactive({
    stats_refresh()  # AI yazdıqdan sonra yenilənsin
    sinif <- as.integer(input$yekun_sinif)
    tryCatch({
      if (USE_CSV) {
        f <- file.path(getwd(), "data", "yenilenmi_standartlar_backup.csv")
        if (!file.exists(f)) return(list(umumi=0L, movcud=0L, yenilenib=0L, yeni=0L, silinib=0L))
        df <- read.csv(f, stringsAsFactors = FALSE, fileEncoding = "UTF-8")
        df <- df[df$sinif == sinif, , drop=FALSE]
      } else {
        con <- get_con(); on.exit(dbDisconnect(con))
        df <- dbGetQuery(con, sprintf("SELECT deyisiklik_novu FROM yenilenmi_standartlar WHERE sinif = %d", sinif))
      }
      list(umumi = as.integer(nrow(df)),
           deyismeyib = as.integer(sum(df$deyisiklik_novu == "movcud", na.rm=TRUE)),
           yenilenib = as.integer(sum(df$deyisiklik_novu == "yenilenib", na.rm=TRUE)),
           yeni = as.integer(sum(df$deyisiklik_novu == "yeni", na.rm=TRUE)),
           silinib = as.integer(sum(df$deyisiklik_novu == "silinib", na.rm=TRUE)))
    }, error = function(e) list(umumi=0L, movcud=0L, yenilenib=0L, yeni=0L, silinib=0L))
  })
  output$vb_yekun_movcud <- renderValueBox({
    valueBox(yekun_counts()$movcud, "Mövcud", icon = icon("check"), color = "light-blue")
  })
  output$vb_yekun_yenilenib <- renderValueBox({
    valueBox(yekun_counts()$yenilenib, "Yenilənib", icon = icon("edit"), color = "green")
  })
  output$vb_yekun_yeni <- renderValueBox({
    valueBox(yekun_counts()$yeni, "Yeni", icon = icon("plus"), color = "orange")
  })
  output$vb_yekun_silinib <- renderValueBox({
    valueBox(yekun_counts()$silinib, "Silinib", icon = icon("trash"), color = "red")
  })

  # Yekun cədvəl — ilkin standartlar kimi nəfis, rəngli sətirlərlə
  output$dt_yekun <- renderDT({
    df <- data_yekun()
    if (nrow(df) == 0) {
      return(datatable(data.frame(Mesaj = "Bu sinif üçün yekun standart yoxdur. Əvvəlcə 'Claude AI Təhlil' bölməsindən təhlili tamamlayın."),
                       rownames = FALSE, options = list(dom = 't')))
    }

    # Status adlarını Riyaziyyatnə çevir
    status_adi_map <- c("movcud" = "Mövcud", "yenilenib" = "Yenilənib", "silinib" = "Silinib", "yeni" = "Yeni")
    df$deyisiklik_novu_adi <- sapply(df$deyisiklik_novu, function(s) {
      if (s %in% names(status_adi_map)) status_adi_map[s] else s
    })

    kod_col <- if ("standart_kodu" %in% names(df)) df$standart_kodu else ""
    mezmun_col <- if ("mezmun_xetti" %in% names(df)) df$mezmun_xetti else if ("mezmun_xetti" %in% names(df)) df$mezmun_xetti else ""
    esaslandirma_col <- if ("esaslandirma" %in% names(df)) df$esaslandirma else ""

    df_show <- data.frame(
      `Kod` = kod_col,
      `Məzmun xətti` = mezmun_col,
      `Status` = df$deyisiklik_novu_adi,
      `Standart` = df$standart_metni,
      `Xarakteristika` = esaslandirma_col,
      check.names = FALSE, stringsAsFactors = FALSE
    )
    df_show[is.na(df_show)] <- ""

    datatable(df_show,
              options = list(pageLength = 50, scrollX = TRUE, autoWidth = FALSE,
                dom = 'lfrtip',
                columnDefs = list(
                  list(width = '140px', targets = 0),
                  list(width = '160px', targets = 1),
                  list(width = '110px', targets = 2),
                  list(width = '500px', targets = 3),
                  list(width = '450px', targets = 4)
                )),
              rownames = FALSE) %>%
      formatStyle('Kod', fontWeight = 'bold', color = '#1565C0') %>%
      formatStyle('Məzmun xətti', fontWeight = '500', color = '#37474F') %>%
      formatStyle("Status", target = "row",
                  backgroundColor = styleEqual(
                    c("Mövcud", "Yenilənib", "Silinib", "Yeni"),
                    c("#FFFFFF", "#E8F5E9", "#FFEBEE", "#FFF3E0")),
                  color = styleEqual(
                    c("Mövcud", "Yenilənib", "Silinib", "Yeni"),
                    c("#333333", "#1B5E20", "#B71C1C", "#E65100"))) %>%
      formatStyle("Status", fontWeight = "bold")
  })

  # Info mesajı
  output$yekun_info <- renderUI({
    df <- data_yekun()
    if (nrow(df) == 0) return(NULL)
    sinif <- input$yekun_sinif
    n_movcud <- sum(df$deyisiklik_novu == "movcud", na.rm=TRUE)
    n_yenilenib <- sum(df$deyisiklik_novu == "yenilenib", na.rm=TRUE)
    n_yeni <- sum(df$deyisiklik_novu == "yeni", na.rm=TRUE)
    n_silinib <- sum(df$deyisiklik_novu == "silinib", na.rm=TRUE)
    tags$div(style="padding:12px 18px;background:#E3F2FD;border:1px solid #90CAF9;border-radius:8px;font-size:14px;color:#0D47A1;",
      sprintf("Yekun_Standartlar-%s: Cəmi %d standart — Mövcud: %d, Yenilənib: %d, Yeni: %d, Silinib: %d",
              sinif, nrow(df), n_movcud, n_yenilenib, n_yeni, n_silinib))
  })

  # Yekun CSV ixrac
  output$download_yekun_csv <- downloadHandler(
    filename = function() { paste0("Yekun_Standartlar_", input$yekun_sinif, ".csv") },
    content = function(file) {
      df <- data_yekun()
      if (nrow(df) > 0) {
        status_adi_map <- c("movcud" = "Mövcud", "yenilenib" = "Yenilənib",
                        "yeni" = "Yeni", "silinib" = "Silinib")
        df$deyisiklik_novu_adi <- sapply(df$deyisiklik_novu, function(s) if (s %in% names(status_adi_map)) status_adi_map[s] else s)
        export_cols <- c("sinif","standart_kodu","mezmun_xetti","bloom_seviyyesi",
                         "standart_metni","esaslandirma","kohne_standart_metni","status_adi")
        export_cols <- intersect(export_cols, names(df))
        df <- df[, export_cols, drop=FALSE]
        names(df)[names(df) == "status_adi"] <- "Status"
      }
      write.csv(df, file, row.names = FALSE, fileEncoding = "UTF-8")
    }
  )

  # Yekun Excel ixrac
  output$download_yekun_excel <- downloadHandler(
    filename = function() { paste0("Yekun_Standartlar_", input$yekun_sinif, ".xlsx") },
    content = function(file) {
      df <- data_yekun()
      if (nrow(df) > 0) {
        status_adi_map <- c("movcud" = "Mövcud", "yenilenib" = "Yenilənib",
                        "yeni" = "Yeni", "silinib" = "Silinib")
        df$deyisiklik_novu_adi <- sapply(df$deyisiklik_novu, function(s) if (s %in% names(status_adi_map)) status_adi_map[s] else s)
        export_cols <- c("sinif","standart_kodu","mezmun_xetti","bloom_seviyyesi",
                         "standart_metni","esaslandirma","kohne_standart_metni","status_adi")
        export_cols <- intersect(export_cols, names(df))
        df <- df[, export_cols, drop=FALSE]
        names(df)[names(df) == "status_adi"] <- "Status"
      }
      if (requireNamespace("writexl", quietly = TRUE)) {
        writexl::write_xlsx(df, file)
      } else {
        write.csv(df, file, row.names = FALSE, fileEncoding = "UTF-8")
      }
    }
  )

  # --- EXPORT ---
  output$download_html <- downloadHandler(
    filename = function() { sprintf("Yekun_Standartlar_Sinif_%s.html", input$sinif_sec) },
    content = function(file) {
      sinif <- as.integer(input$sinif_sec)
      cefr_sev <- "—"
      # Yekun datanı al
      tryCatch({
        if (USE_CSV) {
          f <- file.path(getwd(), "data", "yenilenmi_standartlar_backup.csv")
          df <- if (file.exists(f)) read.csv(f, stringsAsFactors=FALSE, fileEncoding="UTF-8") else data.frame()
          if (nrow(df) > 0) df <- df[df$sinif == sinif, , drop=FALSE]
        } else {
          con <- get_con(); on.exit(dbDisconnect(con))
          df <- dbGetQuery(con, sprintf("SELECT * FROM yenilenmi_standartlar WHERE sinif = %d ORDER BY
            CASE deyisiklik_novu WHEN 'movcud' THEN 1 WHEN 'yenilenib' THEN 2 WHEN 'silinib' THEN 3 WHEN 'yeni' THEN 4 END,
            mezmun_xetti, standart_kodu", sinif))
        }
      }, error = function(e) { df <<- data.frame() })

      n_movcud <- sum(df$deyisiklik_novu == "movcud", na.rm=TRUE)
      n_yenilenib <- sum(df$deyisiklik_novu == "yenilenib", na.rm=TRUE)
      n_yeni <- sum(df$deyisiklik_novu == "yeni", na.rm=TRUE)
      n_silinib <- sum(df$deyisiklik_novu == "silinib", na.rm=TRUE)
      tarix <- format(Sys.time(), "%d.%m.%Y %H:%M")

      # HTML sətirləri yarat
      rows_html <- ""
      if (nrow(df) > 0) {
        for (i in 1:nrow(df)) {
          r <- df[i, ]
          st <- if (!is.na(r$deyisiklik_novu)) r$deyisiklik_novu else "movcud"
          bg <- switch(st, "movcud"="#FFFFFF", "yenilenib"="#E8F5E9", "silinib"="#FFEBEE", "yeni"="#FFF3E0", "#FFFFFF")
          st_label <- switch(st, "movcud"="Mövcud", "yenilenib"="Yenilənib", "silinib"="Silinib", "yeni"="Yeni", st)
          st_color <- switch(st, "movcud"="#333", "yenilenib"="#1B5E20", "silinib"="#B71C1C", "yeni"="#E65100", "#333")

          kod_val <- if ("standart_kodu" %in% names(r) && !is.na(r$standart_kodu)) r$standart_kodu else ""
          mezmun_val <- if ("mezmun_xetti" %in% names(r) && !is.na(r$mezmun_xetti)) r$mezmun_xetti else ""
          kohne_metni <- if ("kohne_standart_metni" %in% names(r) && !is.na(r$kohne_standart_metni)) r$kohne_standart_metni else ""
          yeni_metni <- if (!is.na(r$standart_metni)) r$standart_metni else ""
          bloom <- if ("bloom_seviyyesi" %in% names(r) && !is.na(r$bloom_seviyyesi)) r$bloom_seviyyesi else ""
          xarak <- if ("esaslandirma" %in% names(r) && !is.na(r$esaslandirma)) r$esaslandirma else ""

          rows_html <- paste0(rows_html,
            '<tr style="background:', bg, ';">',
              '<td style="font-weight:600;">', kod_val, '</td>',
              '<td>', mezmun_val, '</td>',
              '<td>', kohne_metni, '</td>',
              '<td>', yeni_metni, '</td>',
              '<td>', bloom, '</td>',
              '<td style="color:', st_color, ';font-weight:600;">', st_label, '</td>',
              '<td>', xarak, '</td>',
            '</tr>\n')
        }
      }

      html <- sprintf('<!DOCTYPE html>
<html lang="az">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Yekun Standartlar — %d-ci sinif</title>
<style>
  * { margin:0; padding:0; box-sizing:border-box; }
  body { font-family: "Segoe UI", "Noto Sans", Arial, sans-serif; background:#f5f5f5; color:#333; }
  .header { background:linear-gradient(135deg, #1565C0, #0D47A1); color:#fff; padding:30px 40px; }
  .header h1 { font-size:35px; margin-bottom:8px; }
  .header p { font-size:18px; opacity:0.9; }
  .stats { display:flex; gap:16px; padding:20px 40px; background:#fff; border-bottom:2px solid #E3F2FD; }
  .stat-box { flex:1; text-align:center; padding:16px; border-radius:10px; }
  .stat-box .num { font-size:40px; font-weight:700; }
  .stat-box .label { font-size:15px; margin-top:4px; }
  .stat-movcud { background:#F5F5F5; } .stat-movcud .num { color:#333; }
  .stat-yenilenib { background:#E8F5E9; } .stat-yenilenib .num { color:#1B5E20; }
  .stat-yeni { background:#FFF3E0; } .stat-yeni .num { color:#E65100; }
  .stat-silinib { background:#FFEBEE; } .stat-silinib .num { color:#B71C1C; }
  .content { padding:20px 40px; }
  table { width:100%%; border-collapse:collapse; background:#fff; border-radius:8px; overflow:hidden; box-shadow:0 2px 8px rgba(0,0,0,0.1); }
  th { background:#1565C0; color:#fff; padding:14px 12px; font-size:20px; text-align:left; }
  td { padding:12px; font-size:20px; border-bottom:1px solid #eee; vertical-align:top; line-height:1.5; }
  tr:hover { background:#F5F5F5 !important; }
  .footer { text-align:center; padding:20px; color:#999; font-size:12px; margin-top:30px; }
  @media print { body { background:#fff; } .header { background:#1565C0 !important; -webkit-print-color-adjust:exact; print-color-adjust:exact; } }
</style>
</head>
<body>
<div class="header">
  <h1>Yekun Standartlar — %d-ci sinif</h1>
  <p>TIMSS/NCTM | Tarix: %s | Riyaziyyat Standartlarının Yenilənməsi Layihəsi</p>
</div>
<div class="stats">
  <div class="stat-box stat-movcud"><div class="num">%d</div><div class="label">Mövcud</div></div>
  <div class="stat-box stat-yenilenib"><div class="num">%d</div><div class="label">Yenilənib</div></div>
  <div class="stat-box stat-yeni"><div class="num">%d</div><div class="label">Yeni</div></div>
  <div class="stat-box stat-silinib"><div class="num">%d</div><div class="label">Silinib</div></div>
</div>
<div class="content">
<table>
<thead>
  <tr>
    <th style="width:100px;">Kod</th>
    <th style="width:100px;">Məzmun xətti</th>
    <th>Köhnə standart</th>
    <th>Yeni standart</th>
    <th style="width:80px;">Bloom</th>
    <th style="width:90px;">Status</th>
    <th>Xarakteristika</th>
  </tr>
</thead>
<tbody>
%s
</tbody>
</table>
</div>
<div class="footer">
  Riyaziyyat Standartlarının Yenilənməsi Layihəsi | Hesabat tarixi: %s
</div>
</body>
</html>',
        sinif, sinif, tarix, n_movcud, n_yenilenib, n_yeni, n_silinib, rows_html, tarix)

      writeLines(html, file, useBytes = TRUE)

      # html_reports qovluğuna da saxla
      report_dir <- file.path(getwd(), "html_reports")
      if (!dir.exists(report_dir)) dir.create(report_dir, recursive = TRUE)
      report_path <- file.path(report_dir, sprintf("sinif_%d_yekun.html", sinif))
      writeLines(html, report_path, useBytes = TRUE)
    },
    contentType = "text/html"
  )

  output$download_csv <- downloadHandler(
    filename = function() { sprintf("standartlar_sinif_%s.csv", input$sinif_sec) },
    content = function(file) {
      sinif <- as.integer(input$sinif_sec)
      tryCatch({
        if (USE_CSV) {
          f2 <- file.path(getwd(), "data", "yenilenmi_standartlar_backup.csv")
          df <- if (file.exists(f2)) read.csv(f2, stringsAsFactors=FALSE, fileEncoding="UTF-8") else data.frame()
          if (nrow(df) > 0) df <- df[df$sinif == sinif, , drop=FALSE]
        } else {
          con <- get_con(); on.exit(dbDisconnect(con))
          df <- dbGetQuery(con, sprintf("SELECT * FROM yenilenmi_standartlar WHERE sinif = %d ORDER BY mezmun_xetti, standart_kodu", sinif))
        }
        write.csv(df, file, row.names = FALSE, fileEncoding = "UTF-8")
      }, error = function(e) write.csv(data.frame(xeta = e$message), file, row.names = FALSE))
    }
  )

  # --- Word ixrac ---
  output$download_word <- downloadHandler(
    filename = function() { sprintf("Yekun_Standartlar_%s_sinif.docx", input$sinif_sec) },
    content = function(file) {
      sinif <- as.integer(input$sinif_sec)
      tryCatch({
        con <- get_con(); on.exit(dbDisconnect(con))
        df <- dbGetQuery(con, sprintf(
          "SELECT standart_kodu, mezmun_xetti, deyisiklik_novu, standart_metni, esaslandirma FROM yenilenmi_standartlar WHERE sinif = %d ORDER BY CASE deyisiklik_novu WHEN 'yeni' THEN 1 ELSE 0 END, mezmun_xetti, standart_kodu", sinif))

        if (nrow(df) == 0) {
          doc <- read_docx()
          doc <- body_add_par(doc, "Bu sinif ucun yekun standart yoxdur.", style = "Normal")
          print(doc, target = file)
          return()
        }

        status_map <- c("movcud" = "Movcud", "yenilenib" = "Yenilenib", "silinib" = "Silinib", "yeni" = "Yeni yazilmis")
        df$deyisiklik_novu <- sapply(df$deyisiklik_novu, function(s) if (s %in% names(status_map)) status_map[s] else s)
        df[is.na(df)] <- ""

        names(df) <- c("Kod", "Mezmun sahesi", "Status", "Standart", "Xarakteristika")

        doc <- read_docx()
        doc <- body_end_section_landscape(doc)
        doc <- body_add_par(doc, paste0("Yekun Standartlar - ", sinif, "-ci sinif"), style = "heading 1")
        doc <- body_add_par(doc, paste0("Tarix: ", Sys.Date()), style = "Normal")
        doc <- body_add_par(doc, "", style = "Normal")

        ft <- flextable(df)
        ft <- set_header_labels(ft, Kod = "Kod", Mezmun.sahesi = "Mezmun sahesi",
                                Status = "Status", Standart = "Standart", Xarakteristika = "Xarakteristika")
        ft <- width(ft, j = 1, width = 1.3)
        ft <- width(ft, j = 2, width = 1.2)
        ft <- width(ft, j = 3, width = 1.0)
        ft <- width(ft, j = 4, width = 3.5)
        ft <- width(ft, j = 5, width = 3.0)
        ft <- fontsize(ft, size = 11, part = "body")
        ft <- fontsize(ft, size = 12, part = "header")
        ft <- padding(ft, padding.top = 4, padding.bottom = 4, part = "body")
        ft <- set_table_properties(ft, layout = "autofit")
        ft <- bold(ft, part = "header")
        ft <- bg(ft, part = "header", bg = "#1976D2")
        ft <- color(ft, part = "header", color = "white")
        ft <- theme_zebra(ft, odd_body = "#FFFFFF", even_body = "#F5F5F5")

        # Rənglər statusa görə
        for (i in 1:nrow(df)) {
          if (df$Status[i] == "Yenilenib") {
            ft <- bg(ft, i = i, bg = "#E8F5E9")
            ft <- color(ft, i = i, j = 3, color = "#1B5E20")
          } else if (df$Status[i] == "Yeni yazilmis") {
            ft <- bg(ft, i = i, bg = "#FFF3E0")
            ft <- color(ft, i = i, j = 3, color = "#E65100")
          } else if (df$Status[i] == "Silinib") {
            ft <- bg(ft, i = i, bg = "#FFEBEE")
            ft <- color(ft, i = i, j = 3, color = "#B71C1C")
          }
        }
        ft <- bold(ft, j = 1)
        ft <- bold(ft, j = 3)
        ft <- border_outer(ft, border = fp_border(color = "#BDBDBD", width = 1))
        ft <- border_inner(ft, border = fp_border(color = "#E0E0E0", width = 0.5))

        doc <- body_add_flextable(doc, ft)

        # Statistika
        n_movcud <- sum(df$Status == "Movcud")
        n_yenilenib <- sum(df$Status == "Yenilenib")
        n_yeni <- sum(df$Status == "Yeni yazilmis")
        n_silinib <- sum(df$Status == "Silinib")
        doc <- body_add_par(doc, "", style = "Normal")
        doc <- body_add_par(doc, paste0("Cemi: ", nrow(df), " standart | Movcud: ", n_movcud,
          " | Yenilenib: ", n_yenilenib, " | Yeni yazilmis: ", n_yeni, " | Silinib: ", n_silinib), style = "Normal")

        # Faylı yaz və word_reports-a da kopyala
        print(doc, target = file)
        word_dir <- file.path(getwd(), "word_reports")
        if (!dir.exists(word_dir)) dir.create(word_dir, recursive = TRUE)
        file.copy(file, file.path(word_dir, sprintf("Yekun_Standartlar_%d_sinif.docx", sinif)), overwrite = TRUE)

      }, error = function(e) {
        doc <- read_docx()
        doc <- body_add_par(doc, paste0("Xeta: ", e$message), style = "Normal")
        print(doc, target = file)
      })
    }
  )

  # ============================================================
  # YENİ TƏKLİFLƏR TAB — Server
  # ============================================================

  # Təklif data reactive
  data_teklifler <- reactive({
    input$btn_teklif_qebul_sec  # refresh trigger
    sinif <- as.integer(input$teklif_sinif)
    tryCatch({
      if (USE_CSV) {
        f <- file.path(getwd(), "data", "yeni_elave_teklifleri_backup.csv")
        if (!file.exists(f)) return(data.frame())
        df <- read.csv(f, stringsAsFactors = FALSE, fileEncoding = "UTF-8")
        if (nrow(df) == 0) return(df)
        df <- df[df$sinif == sinif, , drop=FALSE]
      } else {
        con <- get_con(); on.exit(dbDisconnect(con))
        df <- dbGetQuery(con, sprintf(
          "SELECT * FROM yeni_elave_teklifleri WHERE sinif = %d ORDER BY mezmun_xetti, standart_kodu", sinif))
      }
      if (!is.null(input$teklif_status_filter) && input$teklif_status_filter != "all") {
        df <- df[df$deyisiklik_novu == input$teklif_status_filter, , drop=FALSE]
      }
      df
    }, error = function(e) data.frame())
  })

  # Value boxes
  output$vb_teklif_cemi <- renderValueBox({
    sinif <- as.integer(input$teklif_sinif)
    tryCatch({
      if (USE_CSV) {
        f <- file.path(getwd(), "data", "yeni_elave_teklifleri_backup.csv")
        if (!file.exists(f)) return(valueBox(0L, "Cəmi təklif", icon = icon("lightbulb"), color = "orange"))
        df <- read.csv(f, stringsAsFactors = FALSE, fileEncoding = "UTF-8")
        df <- df[df$sinif == sinif, , drop=FALSE]
      } else {
        con <- get_con(); on.exit(dbDisconnect(con))
        df <- dbGetQuery(con, sprintf("SELECT status FROM yeni_elave_teklifleri WHERE sinif = %d", sinif))
      }
      valueBox(as.integer(nrow(df)), "Cəmi təklif", icon = icon("lightbulb"), color = "orange")
    }, error = function(e) valueBox(0L, "Cəmi təklif", icon = icon("lightbulb"), color = "orange"))
  })

  output$vb_teklif_gozleyen <- renderValueBox({
    df <- data_teklifler()
    n <- if (nrow(df) > 0) as.integer(sum(df$deyisiklik_novu == "teklif", na.rm=TRUE)) else 0L
    valueBox(n, "Gözləyən", icon = icon("clock"), color = "yellow")
  })

  output$vb_teklif_qebul <- renderValueBox({
    df <- data_teklifler()
    n <- if (nrow(df) > 0) as.integer(sum(df$deyisiklik_novu == "qebul", na.rm=TRUE)) else 0L
    valueBox(n, "Qəbul edilib", icon = icon("check"), color = "green")
  })

  output$vb_teklif_redd <- renderValueBox({
    df <- data_teklifler()
    n <- if (nrow(df) > 0) as.integer(sum(df$deyisiklik_novu == "redd", na.rm=TRUE)) else 0L
    valueBox(n, "Rədd edilib", icon = icon("times"), color = "red")
  })

  # Təkliflər cədvəli — Qəbul/Rədd düymələri ilə
  output$dt_teklifler <- renderDT({
    df <- data_teklifler()
    if (nrow(df) == 0) {
      return(datatable(data.frame(Mesaj = "Bu sinif üçün yeni standart təklifi yoxdur. Əvvəlcə 'Claude AI Təhlil' bölməsindən Addım 1-i icra edin."),
                       rownames = FALSE, options = list(dom = 't')))
    }

    # Status adları
    status_adi <- c("teklif" = "Təklif", "qebul" = "Qəbul edilib", "redd" = "Rədd edilib")
    df$deyisiklik_novu_adi <- sapply(df$deyisiklik_novu, function(s) if (s %in% names(status_adi)) status_adi[s] else s)

    # Əməliyyat düymələri
    df$emeliyyat <- sapply(1:nrow(df), function(i) {
      row_id <- df$id[i]
      paste0(
        '<div style="display:flex;gap:4px;flex-wrap:nowrap;">',
        '<button class="btn btn-xs" style="background:#E8F5E9;border:1px solid #4CAF50;color:#2E7D32;font-weight:600;" ',
          'onclick="Shiny.setInputValue(\'teklif_action\', {id:', row_id, ', action:\'qebul\'}, {priority:\'event\'})">Qəbul et</button>',
        '<button class="btn btn-xs" style="background:#FFEBEE;border:1px solid #F44336;color:#C62828;font-weight:600;" ',
          'onclick="Shiny.setInputValue(\'teklif_action\', {id:', row_id, ', action:\'redd\'}, {priority:\'event\'})">Rədd et</button>',
        '</div>')
    })

    show_cols <- c("standart_kodu","alt_standart_kodu","standart_metni","alt_standart_metni",
                   "mezmun_xetti","bloom_seviyyesi","cetinlik","esaslandirma","status_adi","emeliyyat")
    show_cols <- intersect(show_cols, names(df))
    df_show <- df[, show_cols, drop=FALSE]
    # Oxunaqlı kod formatı
    if ("alt_standart_kodu" %in% names(df_show)) df_show$alt_standart_kodu <- df_show$alt_standart_kodu
    if ("standart_kodu" %in% names(df_show) && "sinif" %in% names(df)) df_show$standart_kodu <- df_show$standart_kodu
    col_labels <- c("standart_kodu"="Std. Kod","alt_standart_kodu"="Alt Kod",
                    "standart_metni"="Standart","alt_standart_metni"="Alt standart",
                    "mezmun_xetti"="Məzmun","bloom_seviyyesi"="Bloom","cetinlik"="Çətinlik",
                    "esaslandirma"="Əsaslandırma","status_adi"="Status","emeliyyat"="Əməliyyat")
    names(df_show) <- col_labels[show_cols]

    datatable(df_show,
              escape = FALSE,
              options = list(pageLength = 20, scrollX = TRUE, autoWidth = FALSE,
                scrollXInner = '1400px',
                columnDefs = list(
                  list(width = '100px', targets = 0),
                  list(width = '110px', targets = 1),
                  list(width = '300px', targets = 2),
                  list(width = '300px', targets = 3),
                  list(width = '120px', targets = 4),
                  list(width = '100px', targets = 5),
                  list(width = '80px', targets = 6),
                  list(width = '300px', targets = 7),
                  list(width = '90px', targets = 8),
                  list(width = '130px', targets = 9)
                )),
              rownames = FALSE) %>%
      formatStyle("Status",
                  backgroundColor = styleEqual(
                    c("Təklif", "Qəbul edilib", "Rədd edilib"),
                    c("#FFF3E0", "#C8E6C9", "#FFCDD2")),
                  fontWeight = "bold")
  })

  # Qəbul/Rədd düyməsi handler
  observeEvent(input$teklif_action, {
    row_id <- input$teklif_action$id
    action <- input$teklif_action$action
    tryCatch({
      if (USE_CSV) {
        f <- file.path(getwd(), "data", "yeni_elave_teklifleri_backup.csv")
        if (file.exists(f)) {
          df <- read.csv(f, stringsAsFactors = FALSE, fileEncoding = "UTF-8")
          idx <- which(df$id == row_id)
          if (length(idx) > 0) {
            df$deyisiklik_novu[idx[1]] <- action
            write.csv(df, f, row.names = FALSE, fileEncoding = "UTF-8")
          }
        }
      } else {
        con <- get_con(); on.exit(dbDisconnect(con))
        dbExecute(con, sprintf("UPDATE yeni_elave_teklifleri SET deyisiklik_novu = '%s' WHERE id = %d", action, row_id))
      }
      showNotification(
        if (action == "qebul") "Təklif qəbul edildi!" else "Təklif rədd edildi.",
        type = if (action == "qebul") "message" else "warning", duration = 3)
    }, error = function(e) {
      showNotification(paste("Xəta:", e$message), type = "error")
    })
  })

  # Seçilmişləri yekuna əlavə et
  observeEvent(input$btn_teklif_qebul_sec, {
    sinif <- as.integer(input$teklif_sinif)
    cefr_sev <- "—"
    tryCatch({
      # Qəbul edilmiş təklifləri al
      if (USE_CSV) {
        f <- file.path(getwd(), "data", "yeni_elave_teklifleri_backup.csv")
        if (!file.exists(f)) { showNotification("Təklif yoxdur!", type = "warning"); return() }
        df_qebul <- read.csv(f, stringsAsFactors = FALSE, fileEncoding = "UTF-8")
        df_qebul <- df_qebul[df_qebul$sinif == sinif & df_qebul$status == "qebul", , drop=FALSE]
      } else {
        con <- get_con(); on.exit(dbDisconnect(con))
        df_qebul <- dbGetQuery(con, sprintf(
          "SELECT * FROM yeni_elave_teklifleri WHERE sinif = %d AND status = 'qebul'", sinif))
      }

      if (nrow(df_qebul) == 0) {
        showNotification("Qəbul edilmiş təklif yoxdur! Əvvəlcə təklifləri 'Qəbul et' düyməsi ilə seçin.", type = "warning")
        return()
      }

      # Yekun standartlara əlavə et — yeni standartlar cədvəlin sonuna (APPEND)
      # Mövcud son id-ni tap ki, sıralama düzgün olsun
      n_added <- 0
      if (USE_CSV) {
        yekun_path <- file.path(getwd(), "data", "yenilenmi_standartlar_backup.csv")
        df_yekun <- if (file.exists(yekun_path)) {
          read.csv(yekun_path, stringsAsFactors = FALSE, fileEncoding = "UTF-8")
        } else data.frame()

        for (i in 1:nrow(df_qebul)) {
          row <- df_qebul[i, ]
          standart_text <- if (nchar(as.character(row$alt_standart_metni)) > 0) as.character(row$alt_standart_metni) else as.character(row$standart_metni)
          new_row <- data.frame(
            sinif = sinif,
            kod = "",
            mezmun_xetti = as.character(row$mezmun_xetti),
            bloom_seviyyesi = as.character(row$bloom_seviyyesi),
            cetinlik_seviyyesi = if ("cetinlik" %in% names(row)) as.character(row$cetinlik) else "",
            status = "yeni",
            standart_metni = standart_text,
            esaslandirma = as.character(row$esaslandirma),
            kohne_standart_metni = "",
            stringsAsFactors = FALSE)
          if (nrow(df_yekun) > 0) {
            common <- intersect(names(df_yekun), names(new_row))
            df_yekun <- rbind(df_yekun[, common, drop=FALSE], new_row[, common, drop=FALSE])
          } else df_yekun <- new_row
          n_added <- n_added + 1
        }
        if (n_added > 0) write.csv(df_yekun, yekun_path, row.names = FALSE, fileEncoding = "UTF-8")
      } else {
        for (i in 1:nrow(df_qebul)) {
          row <- df_qebul[i, ]
          standart_text <- if (nchar(as.character(row$alt_standart_metni)) > 0) as.character(row$alt_standart_metni) else as.character(row$standart_metni)
          dbExecute(con, paste0(
            "INSERT INTO yenilenmi_standartlar (sinif, standart_kodu, mezmun_xetti, bloom_seviyyesi, deyisiklik_novu, standart_metni, esaslandirma, kohne_standart_metni) VALUES (",
            sinif, ", '', ",
            "'", gsub("'", "''", as.character(row$mezmun_xetti)), "', ",
            "'", gsub("'", "''", as.character(row$bloom_seviyyesi)), "', ",
            "'yeni', ",
            "'", gsub("'", "''", standart_text), "', ",
            "'", gsub("'", "''", as.character(row$esaslandirma)), "', ",
            "'')"
          ))
          n_added <- n_added + 1
        }
      }

      output$teklif_status_msg <- renderUI(
        tags$div(style="padding:16px;background:#dcfce7;border:2px solid #4CAF50;border-radius:10px;font-size:16px;color:#166534;font-weight:600;",
          sprintf("✅ %d yeni standart yekun standartlara əlavə olundu! 'Yekun Standartlar' tab-ına baxın.", n_added))
      )
      showNotification(sprintf("✅ %d standart yekuna əlavə olundu!", n_added), type = "message", duration = 5)
      stats_refresh(stats_refresh() + 1)  # Ana səhifəni yenilə
    }, error = function(e) {
      showNotification(paste("Xəta:", e$message), type = "error")
      output$teklif_status_msg <- renderUI(
        tags$div(style="padding:16px;background:#FFEBEE;border:2px solid #F44336;border-radius:10px;color:#C62828;",
          paste("❌ Xəta:", e$message)))
    })
  })
}

# --- İŞƏ SALMAQ ---
shinyApp(ui, server)
