-- Riy_standartlar: PostgreSQL Baza Sxemi
-- 5 cədvəl + 2 view

-- 1. Mövcud standartlar (Riy_Muellim_Agent-dən import, dəyişdirilmir)
CREATE TABLE IF NOT EXISTS movcud_standartlar (
    id SERIAL PRIMARY KEY,
    sinif INTEGER NOT NULL CHECK (sinif BETWEEN 1 AND 11),
    standart_kodu VARCHAR(20) NOT NULL,
    mezmun_xetti VARCHAR(100) NOT NULL,
    standart_metni TEXT NOT NULL,
    alt_standart_kodu VARCHAR(20),
    alt_standart_metni TEXT,
    bloom_seviyyesi VARCHAR(50),
    acarsozler TEXT[],
    import_tarixi TIMESTAMP DEFAULT NOW()
);

-- 2. Yenilənmiş standartlar (əsas iş cədvəli)
CREATE TABLE IF NOT EXISTS yenilenmi_standartlar (
    id SERIAL PRIMARY KEY,
    sinif INTEGER NOT NULL CHECK (sinif BETWEEN 1 AND 11),
    standart_kodu VARCHAR(20) NOT NULL,
    mezmun_xetti VARCHAR(100) NOT NULL,
    standart_metni TEXT NOT NULL,
    alt_standart_kodu VARCHAR(20),
    alt_standart_metni TEXT,
    deyisiklik_novu VARCHAR(20) NOT NULL CHECK (deyisiklik_novu IN ('movcud', 'yenilenib', 'yeni', 'silinib')),
    kohne_standart_metni TEXT,
    bloom_seviyyesi VARCHAR(50),
    timss_elaqesi JSONB,
    pisa_elaqesi JSONB,
    nctm_elaqesi TEXT,
    esaslandirma TEXT,
    istinad_olke VARCHAR(50),
    steam_elaqesi TEXT,
    yaradilma_tarixi TIMESTAMP DEFAULT NOW()
);

-- 3. Beynəlxalq çərçivələr
CREATE TABLE IF NOT EXISTS beynelxalq_cerceveler (
    id SERIAL PRIMARY KEY,
    cerceve_adi VARCHAR(50) NOT NULL,
    kateqoriya VARCHAR(100) NOT NULL,
    alt_kateqoriya VARCHAR(100),
    tesvir TEXT NOT NULL,
    sinif_araligi VARCHAR(20),
    koqnitiv_seviyye VARCHAR(50),
    faiz_ceki NUMERIC(5,2),
    yaradilma_tarixi TIMESTAMP DEFAULT NOW()
);

-- 4. Ölkə standartları
CREATE TABLE IF NOT EXISTS olke_standartlari (
    id SERIAL PRIMARY KEY,
    olke_adi VARCHAR(50) NOT NULL,
    sinif INTEGER,
    mezmun_sahesi VARCHAR(100),
    standart_xulasesi TEXT NOT NULL,
    guclu_terefler TEXT,
    timss_pisa_reytinqi VARCHAR(50),
    yaradilma_tarixi TIMESTAMP DEFAULT NOW()
);

-- 5. Təhlil jurnalı (audit trail)
CREATE TABLE IF NOT EXISTS tehlil_jurnali (
    id SERIAL PRIMARY KEY,
    sinif INTEGER NOT NULL,
    addim VARCHAR(10) NOT NULL,
    sorgu_metni TEXT,
    cavab_metni TEXT,
    model VARCHAR(50) DEFAULT 'claude-sonnet-4-20250514',
    token_sayi INTEGER,
    status VARCHAR(20) DEFAULT 'ugurlu',
    xeta_mesaji TEXT,
    yaradilma_tarixi TIMESTAMP DEFAULT NOW()
);

-- View 1: Yekun standartlar
CREATE OR REPLACE VIEW v_yekun_standartlar AS
SELECT
    y.sinif,
    y.standart_kodu,
    y.mezmun_xetti,
    y.standart_metni,
    y.alt_standart_kodu,
    y.alt_standart_metni,
    y.deyisiklik_novu,
    y.kohne_standart_metni,
    y.bloom_seviyyesi,
    y.timss_elaqesi,
    y.pisa_elaqesi,
    y.esaslandirma,
    y.istinad_olke,
    y.steam_elaqesi
FROM yenilenmi_standartlar y
WHERE y.deyisiklik_novu != 'silinib'
ORDER BY y.sinif, y.standart_kodu;

-- View 2: Sinif üzrə statistika
CREATE OR REPLACE VIEW v_sinif_statistika AS
SELECT
    sinif,
    COUNT(*) AS cemi,
    COUNT(*) FILTER (WHERE deyisiklik_novu = 'movcud') AS movcud_say,
    COUNT(*) FILTER (WHERE deyisiklik_novu = 'yenilenib') AS yenilenib_say,
    COUNT(*) FILTER (WHERE deyisiklik_novu = 'yeni') AS yeni_say,
    COUNT(*) FILTER (WHERE deyisiklik_novu = 'silinib') AS silinib_say
FROM yenilenmi_standartlar
GROUP BY sinif
ORDER BY sinif;

-- İndekslər
CREATE INDEX IF NOT EXISTS idx_movcud_sinif ON movcud_standartlar(sinif);
CREATE INDEX IF NOT EXISTS idx_yenilenmi_sinif ON yenilenmi_standartlar(sinif);
CREATE INDEX IF NOT EXISTS idx_yenilenmi_novu ON yenilenmi_standartlar(deyisiklik_novu);
CREATE INDEX IF NOT EXISTS idx_tehlil_sinif ON tehlil_jurnali(sinif);
