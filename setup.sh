#!/bin/bash
# Riy_standartlar - Avtomatik quraşdırma skripti

echo "=== Riy_standartlar Layihəsi - Quraşdırma ==="

# R paketlərinin quraşdırılması
echo "R paketləri yoxlanılır və quraşdırılır..."
Rscript -e '
pkgs <- c("DBI", "RPostgres", "httr2", "jsonlite", "glue", "purrr", "dplyr", "tidyr",
          "shiny", "shinydashboard", "DT", "plotly", "htmltools", "officer", "flextable",
          "readr", "stringr", "scales")
missing <- pkgs[!pkgs %in% installed.packages()[,"Package"]]
if (length(missing) > 0) {
  cat("Quraşdırılır:", paste(missing, collapse=", "), "\n")
  install.packages(missing, repos="https://cloud.r-project.org", quiet=TRUE)
} else {
  cat("Bütün paketlər mövcuddur.\n")
}
'

# PostgreSQL bazasının yaradılması
echo "PostgreSQL bazası yaradılır..."
createdb riy_standartlar 2>/dev/null && echo "Baza yaradıldı: riy_standartlar" || echo "Baza artıq mövcuddur"

# Sxemin tətbiqi
echo "Baza sxemi tətbiq edilir..."
psql -d riy_standartlar -f sql/schema.sql 2>/dev/null

echo "=== Quraşdırma tamamlandı ==="
