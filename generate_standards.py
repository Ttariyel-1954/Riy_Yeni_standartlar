#!/usr/bin/env python3
"""Generate math standards for all 11 grades (Azerbaijan curriculum)."""

ROMAN = {1:'I',2:'II',3:'III',4:'IV',5:'V',6:'VI',7:'VII',8:'VIII',9:'IX',10:'X',11:'XI'}

# Mezmun xetleri numbering:
# 1 = Ədədlər və əməllər
# 2 = Cəbr
# 3 = Həndəsə
# 4 = Ölçmə
# 5 = Statistika və ehtimal

MEZMUN = {1:'Ədədlər və əməllər', 2:'Cəbr', 3:'Həndəsə', 4:'Ölçmə', 5:'Statistika və ehtimal'}

# Structure: {sinif: {mezmun_no: [ (standart_no, standart_metni, [(alt_no, alt_metni, bloom),...]) ] }}
DATA = {
    1: {
        1: [  # Ədədlər
            (1, 'Natural ədədlər: 20 daxilində natural ədədləri tanıyır, oxuyur, yazır və müqayisə edir.', [
                (1, '20-yə qədər ədədləri tanıyır, adlandırır və ardıcıllıqla sıralayır.', 'Xatırlama'),
                (2, 'Ədədləri müqayisə edir (böyük, kiçik, bərabər).', 'Anlama'),
                (3, 'Ədədləri onluq say sistemində yerləşdirir.', 'Tətbiq'),
            ]),
            (2, 'Toplama və çıxma: 20 daxilində toplama və çıxma əməllərini yerinə yetirir.', [
                (1, '20 daxilində toplama əməlini yerinə yetirir.', 'Tətbiq'),
                (2, '20 daxilində çıxma əməlini yerinə yetirir.', 'Tətbiq'),
                (3, 'Toplama və çıxma əlaqəsini başa düşür.', 'Anlama'),
            ]),
        ],
        3: [  # Həndəsə
            (1, 'Həndəsi fiqurlar: Sadə həndəsi fiqurları tanıyır və fərqləndirir.', [
                (1, 'Dairə, üçbucaq, düzbucaqlı, kvadratı tanıyır.', 'Xatırlama'),
                (2, 'Həndəsi fiqurları real həyatda olan əşyalarla əlaqələndirir.', 'Anlama'),
                (3, 'Sadə fiqurları çəkir və qurur.', 'Tətbiq'),
            ]),
            (2, 'Məkan təsəvvürü: Əşyaların mövqeyini müəyyənləşdirir.', [
                (1, 'Yuxarı-aşağı, sağ-sol, qabaq-arxa anlayışlarını bilir.', 'Xatırlama'),
                (2, 'Əşyaların bir-birinə nəzərən yerini təsvir edir.', 'Anlama'),
            ]),
        ],
        4: [  # Ölçmə
            (1, 'Uzunluq ölçmə: Qeyri-standart və standart vahidlərlə uzunluq ölçür.', [
                (1, 'Əşyaların uzunluğunu qeyri-standart vahidlərlə ölçür.', 'Tətbiq'),
                (2, 'Santimetr anlayışını bilir və istifadə edir.', 'Tətbiq'),
            ]),
            (2, 'Vaxt ölçmə: Saat və təqvim anlayışlarını bilir.', [
                (1, 'Tam saat göstəricilərini oxuyur.', 'Xatırlama'),
                (2, 'Həftənin günlərini və ilin fəsillərini bilir.', 'Xatırlama'),
            ]),
        ],
        5: [  # Statistika
            (1, 'Məlumatların təqdimi: Sadə cədvəl və diaqramları oxuyur.', [
                (1, 'Əşyaları əlamətlərinə görə qruplaşdırır.', 'Anlama'),
                (2, 'Sadə cədvəllərdən məlumat oxuyur.', 'Anlama'),
                (3, 'Sadə şəkilli diaqramları oxuyur.', 'Anlama'),
            ]),
        ],
    },

    2: {
        1: [
            (1, 'Natural ədədlər: 100 daxilində natural ədədlərlə işləyir.', [
                (1, '100-ə qədər ədədləri oxuyur, yazır və müqayisə edir.', 'Xatırlama'),
                (2, 'Ədədləri onluqlar və təklərlə ifadə edir.', 'Anlama'),
                (3, 'Ədədlər oxu üzərində ədədləri yerləşdirir.', 'Tətbiq'),
            ]),
            (2, 'Toplama və çıxma: 100 daxilində toplama və çıxma əməllərini yerinə yetirir.', [
                (1, '100 daxilində keçidli toplama əməlini yerinə yetirir.', 'Tətbiq'),
                (2, '100 daxilində keçidli çıxma əməlini yerinə yetirir.', 'Tətbiq'),
                (3, 'Mətn məsələlərini toplama/çıxma ilə həll edir.', 'Tətbiq'),
            ]),
            (3, 'Vurma anlayışı: Vurma əməlinin mənasını başa düşür.', [
                (1, 'Bərabər qruplarla saymanı vurma kimi tanıyır.', 'Anlama'),
                (2, 'Vurma cədvəlini 2, 5, 10 üçün bilir.', 'Xatırlama'),
            ]),
        ],
        3: [
            (1, 'Müstəvi fiqurlar: Həndəsi fiqurların xassələrini öyrənir.', [
                (1, 'Fiqurların tərəflərini və bucaqlarını sayır.', 'Anlama'),
                (2, 'Fiqurları xassələrinə görə təsnif edir.', 'Təhlil'),
                (3, 'Simmetriya anlayışını tanıyır.', 'Anlama'),
            ]),
        ],
        4: [
            (1, 'Uzunluq və kütlə: Uzunluq və kütlə ölçü vahidlərini bilir.', [
                (1, 'Metr və santimetr arasında əlaqəni bilir.', 'Xatırlama'),
                (2, 'Kütlə ölçü vahidlərini (kq, q) bilir.', 'Xatırlama'),
                (3, 'Əşyaların uzunluğunu və kütləsini ölçür.', 'Tətbiq'),
            ]),
            (2, 'Vaxt və pul: Vaxt və pul anlayışları ilə işləyir.', [
                (1, 'Saatı yarım saat dəqiqliyi ilə oxuyur.', 'Tətbiq'),
                (2, 'Manat və qəpik ilə sadə hesablamalar aparır.', 'Tətbiq'),
            ]),
        ],
        5: [
            (1, 'Məlumatlar: Cədvəl və diaqramlarla işləyir.', [
                (1, 'Sadə cədvəllərdən məlumat toplayır.', 'Tətbiq'),
                (2, 'Sütunlu diaqramları oxuyur.', 'Anlama'),
                (3, 'Verilmiş məlumatlara əsasən sadə diaqram qurur.', 'Tətbiq'),
            ]),
        ],
    },

    3: {
        1: [
            (1, 'Çoxrəqəmli ədədlər: 1000 daxilində ədədlərlə işləyir.', [
                (1, '1000-ə qədər ədədləri oxuyur, yazır, müqayisə edir.', 'Xatırlama'),
                (2, 'Ədədləri yüzlüklər, onluqlar və təklərlə ifadə edir.', 'Anlama'),
                (3, 'Ədədləri yuvarlaqlaşdırır.', 'Tətbiq'),
            ]),
            (2, 'Toplama və çıxma: Üçrəqəmli ədədlərlə toplama-çıxma aparır.', [
                (1, 'Üçrəqəmli ədədlərlə toplama əməlini yerinə yetirir.', 'Tətbiq'),
                (2, 'Üçrəqəmli ədədlərlə çıxma əməlini yerinə yetirir.', 'Tətbiq'),
                (3, 'Çoxaddımlı mətn məsələlərini həll edir.', 'Təhlil'),
            ]),
            (3, 'Vurma və bölmə: Vurma və bölmə əməllərini bilir.', [
                (1, 'Vurma cədvəlini tam öyrənir (1-10).', 'Xatırlama'),
                (2, 'Birrəqəmli ədədə vurma əməlini yerinə yetirir.', 'Tətbiq'),
                (3, 'Birrəqəmli ədədə bölmə əməlini yerinə yetirir.', 'Tətbiq'),
                (4, 'Vurma və bölmənin əlaqəsini başa düşür.', 'Anlama'),
            ]),
        ],
        3: [
            (1, 'Həndəsi fiqurlar: Perimetr anlayışını öyrənir.', [
                (1, 'Çoxbucaqlının perimetrini hesablayır.', 'Tətbiq'),
                (2, 'Düzbucaqlı və kvadratın perimetrini düsturla tapır.', 'Tətbiq'),
                (3, 'Paralel və perpendikulyar düz xətləri tanıyır.', 'Anlama'),
            ]),
        ],
        4: [
            (1, 'Ölçmə: Müxtəlif ölçü vahidlərini bilir.', [
                (1, 'Kilometr, metr, santimetr, millimetr arasında əlaqəni bilir.', 'Xatırlama'),
                (2, 'Litr və millilitr anlayışlarını bilir.', 'Xatırlama'),
                (3, 'Ölçü vahidlərini çevirir.', 'Tətbiq'),
            ]),
            (2, 'Vaxt hesablamaları: Vaxtla bağlı hesablamalar aparır.', [
                (1, 'Saatı dəqiqə dəqiqliyi ilə oxuyur.', 'Tətbiq'),
                (2, 'Vaxt intervallarını hesablayır.', 'Tətbiq'),
            ]),
        ],
        5: [
            (1, 'Məlumatların təhlili: Diaqramları oxuyur və qurur.', [
                (1, 'Sütunlu diaqramları oxuyur və təhlil edir.', 'Təhlil'),
                (2, 'Verilmiş məlumatlardan diaqram qurur.', 'Tətbiq'),
                (3, 'Məlumatlara əsasən sadə nəticələr çıxarır.', 'Təhlil'),
            ]),
        ],
    },

    4: {
        1: [
            (1, 'Çoxrəqəmli ədədlər: Milyona qədər ədədlərlə işləyir.', [
                (1, 'Altırəqəmli ədədləri oxuyur, yazır və müqayisə edir.', 'Xatırlama'),
                (2, 'Ədədlərin mövqe dəyərini müəyyən edir.', 'Anlama'),
                (3, 'Ədədləri müxtəlif mənzilə yuvarlaqlaşdırır.', 'Tətbiq'),
            ]),
            (2, 'Dörd əməl: Çoxrəqəmli ədədlərlə dörd əməli yerinə yetirir.', [
                (1, 'Çoxrəqəmli ədədlərlə toplama və çıxma aparır.', 'Tətbiq'),
                (2, 'İki və üçrəqəmli ədədlərə vurma yerinə yetirir.', 'Tətbiq'),
                (3, 'İkirəqəmli ədədə bölmə yerinə yetirir.', 'Tətbiq'),
                (4, 'Əməllərin ardıcıllığını bilir.', 'Anlama'),
            ]),
            (3, 'Kəsrlər: Adi kəsrlər anlayışını öyrənir.', [
                (1, 'Kəsr anlayışını bütövün hissəsi kimi başa düşür.', 'Anlama'),
                (2, 'Sadə adi kəsrləri müqayisə edir.', 'Anlama'),
                (3, 'Eyniadlı kəsrləri toplayır və çıxır.', 'Tətbiq'),
            ]),
        ],
        2: [
            (1, 'Qanunauyğunluqlar: Ədəd qanunauyğunluqlarını tanıyır.', [
                (1, 'Ədəd ardıcıllığında qanunauyğunluğu müəyyən edir.', 'Təhlil'),
                (2, 'Qanunauyğunluğu davam etdirir.', 'Tətbiq'),
            ]),
        ],
        3: [
            (1, 'Sahə: Müstəvi fiqurların sahəsini hesablayır.', [
                (1, 'Kvadrat və düzbucaqlının sahəsini hesablayır.', 'Tətbiq'),
                (2, 'Perimetr və sahə fərqini başa düşür.', 'Anlama'),
                (3, 'Sahə ölçü vahidlərini (sm², m²) bilir.', 'Xatırlama'),
            ]),
            (2, 'Bucaqlar: Bucaq anlayışını öyrənir.', [
                (1, 'Düz, iti və küt bucağı fərqləndirir.', 'Anlama'),
                (2, 'Transportirlə bucaq ölçür.', 'Tətbiq'),
            ]),
        ],
        4: [
            (1, 'Ölçmə: Ölçü vahidlərini çevirir və tətbiq edir.', [
                (1, 'Uzunluq, kütlə, həcm ölçü vahidlərini çevirir.', 'Tətbiq'),
                (2, 'Praktik məsələlərdə ölçmə aparır.', 'Tətbiq'),
                (3, 'Məsələlərdə uyğun ölçü vahidi seçir.', 'Qiymətləndirmə'),
            ]),
        ],
        5: [
            (1, 'Statistika: Məlumatları toplayır, təşkil edir və təqdim edir.', [
                (1, 'Məlumatları cədvəllərdə təşkil edir.', 'Tətbiq'),
                (2, 'Sütunlu və xəttli diaqramları qurur və oxuyur.', 'Tətbiq'),
                (3, 'Orta ədədi hesablayır.', 'Tətbiq'),
                (4, 'Diaqramlar əsasında nəticə çıxarır.', 'Təhlil'),
            ]),
        ],
    },

    5: {
        1: [
            (1, 'Natural ədədlər: Beşrəqəmli və daha böyük ədədlərlə əməllər aparır.', [
                (1, 'Beşrəqəmli ədədlərə qədər dörd əməli yerinə yetirir.', 'Tətbiq'),
                (2, 'Bölünmə əlamətlərini (2, 3, 5, 9, 10) bilir.', 'Xatırlama'),
                (3, 'Sadə və mürəkkəb ədədləri fərqləndirir.', 'Anlama'),
            ]),
            (2, 'Kəsrlər: Adi və onluq kəsrlərlə əməllər aparır.', [
                (1, 'Adi kəsrləri müqayisə edir və sadələşdirir.', 'Tətbiq'),
                (2, 'Müxtəlifadlı kəsrləri toplayır və çıxır.', 'Tətbiq'),
                (3, 'Onluq kəsrlərlə dörd əməl aparır.', 'Tətbiq'),
                (4, 'Adi kəsri onluq kəsrə çevirir və əksinə.', 'Tətbiq'),
            ]),
        ],
        2: [
            (1, 'Tənliklər: Sadə tənlikləri həll edir.', [
                (1, 'Bilinməyəni olan bərabərlikləri həll edir.', 'Tətbiq'),
                (2, 'Tənliklərin həllini yoxlayır.', 'Qiymətləndirmə'),
            ]),
            (2, 'Düsturlar: Düsturla hesablama aparır.', [
                (1, 'Verilmiş düstura qiymət yerləşdirib hesablayır.', 'Tətbiq'),
                (2, 'Sadə düsturlar qurur.', 'Yaratma'),
            ]),
        ],
        3: [
            (1, 'Həndəsi fiqurlar: Müstəvi fiqurların xassələrini bilir.', [
                (1, 'Üçbucaq, dördbucaqlı növlərini tanıyır.', 'Xatırlama'),
                (2, 'Perimetr və sahəni hesablayır.', 'Tətbiq'),
                (3, 'Həndəsi fiqurları koordinat müstəvisində çəkir.', 'Tətbiq'),
            ]),
        ],
        4: [
            (1, 'Ölçmə: Uzunluq, sahə, həcm ölçü vahidlərini bilir.', [
                (1, 'Sahə ölçü vahidlərini çevirir (sm², dm², m²).', 'Tətbiq'),
                (2, 'Həcm anlayışını və kub vahidləri bilir.', 'Anlama'),
                (3, 'Düzbucaqlı paralelepipedin həcmini hesablayır.', 'Tətbiq'),
            ]),
        ],
        5: [
            (1, 'Statistika: Cədvəl və diaqramları oxuyur, qurur və təhlil edir.', [
                (1, 'Dairəvi diaqramları oxuyur.', 'Anlama'),
                (2, 'Məlumatlara əsasən müxtəlif diaqramlar qurur.', 'Tətbiq'),
                (3, 'Orta hesabi, median, moda anlayışlarını bilir.', 'Anlama'),
            ]),
        ],
    },

    6: {
        1: [
            (1, 'Tam ədədlər: Mənfi ədədlər daxil tam ədədlərlə işləyir.', [
                (1, 'Mənfi ədədləri ədədlər oxunda yerləşdirir.', 'Anlama'),
                (2, 'Tam ədədlərlə dörd əməl aparır.', 'Tətbiq'),
                (3, 'Tam ədədlərin modul (mütləq qiymət) anlayışını bilir.', 'Anlama'),
            ]),
            (2, 'Rasional ədədlər: Rasional ədədlər çoxluğunu bilir.', [
                (1, 'Rasional ədədi kəsr şəklində ifadə edir.', 'Anlama'),
                (2, 'Rasional ədədlərlə dörd əməl aparır.', 'Tətbiq'),
            ]),
            (3, 'Nisbət və proporsiya: Nisbət və proporsiya məsələlərini həll edir.', [
                (1, 'Nisbət anlayışını bilir və nisbətləri sadələşdirir.', 'Anlama'),
                (2, 'Düz və tərs mütənasibliyi fərqləndirir.', 'Təhlil'),
                (3, 'Proporsiya məsələlərini həll edir.', 'Tətbiq'),
            ]),
            (4, 'Faiz: Faiz anlayışını bilir və tətbiq edir.', [
                (1, 'Ədədin faizini hesablayır.', 'Tətbiq'),
                (2, 'Faiz məsələlərini həll edir.', 'Tətbiq'),
                (3, 'Faizi kəsrə və onluq kəsrə çevirir.', 'Tətbiq'),
            ]),
        ],
        2: [
            (1, 'Tənliklər: Birməchullu tənlikləri həll edir.', [
                (1, 'Birməchullu birinci dərəcəli tənlikləri həll edir.', 'Tətbiq'),
                (2, 'Tənlik quraraq mətn məsələlərini həll edir.', 'Təhlil'),
            ]),
            (2, 'Koordinat müstəvisi: Koordinat müstəvisini bilir.', [
                (1, 'Nöqtəni koordinat müstəvisində yerləşdirir.', 'Tətbiq'),
                (2, 'Nöqtənin koordinatlarını müəyyən edir.', 'Anlama'),
            ]),
        ],
        3: [
            (1, 'Bucaqlar: Bucaq ölçüləri və növləri ilə işləyir.', [
                (1, 'Bucaqları ölçür və müqayisə edir.', 'Tətbiq'),
                (2, 'Tamamlayıcı və qonşu bucaqları bilir.', 'Anlama'),
            ]),
            (2, 'Simmetriya: Simmetriya və çevirmələri bilir.', [
                (1, 'Ox simmetriyasını tətbiq edir.', 'Tətbiq'),
                (2, 'Simmetrik fiqurları tanıyır və çəkir.', 'Tətbiq'),
            ]),
        ],
        4: [
            (1, 'Ölçmə: Dairənin uzunluğu və sahə hesablamaları.', [
                (1, 'Dairənin uzunluğunu hesablayır.', 'Tətbiq'),
                (2, 'Mürəkkəb fiqurların sahəsini hesablayır.', 'Təhlil'),
            ]),
        ],
        5: [
            (1, 'Statistika: Statistik məlumatları təhlil edir.', [
                (1, 'Tezlik cədvəli tərtib edir.', 'Tətbiq'),
                (2, 'Orta hesabi, median, modanı hesablayır.', 'Tətbiq'),
                (3, 'Statistik məlumatları müqayisə edir.', 'Təhlil'),
            ]),
        ],
    },

    7: {
        1: [
            (1, 'Həqiqi ədədlər: Həqiqi ədədlər çoxluğu ilə işləyir.', [
                (1, 'İrrasional ədəd anlayışını bilir.', 'Anlama'),
                (2, 'Kvadrat kök anlayışını bilir.', 'Anlama'),
                (3, 'Həqiqi ədədləri ədədlər oxunda yerləşdirir.', 'Tətbiq'),
            ]),
        ],
        2: [
            (1, 'Cəbri ifadələr: Cəbri ifadələrlə əməllər aparır.', [
                (1, 'Birhədliləri və çoxhədliləri toplayır, çıxır.', 'Tətbiq'),
                (2, 'Birhədliləri vurur.', 'Tətbiq'),
                (3, 'Çoxhədlini birhədliyə vurur.', 'Tətbiq'),
            ]),
            (2, 'Xətti tənliklər: Xətti tənlik və bərabərsizlikləri həll edir.', [
                (1, 'Birinci dərəcəli tənlikləri həll edir.', 'Tətbiq'),
                (2, 'Birinci dərəcəli bərabərsizlikləri həll edir.', 'Tətbiq'),
                (3, 'İki bilinməyənli xətti tənliklər sistemini həll edir.', 'Tətbiq'),
            ]),
            (3, 'Funksiyalar: Xətti funksiya anlayışını bilir.', [
                (1, 'Funksiya anlayışını başa düşür.', 'Anlama'),
                (2, 'Xətti funksiyanın qrafikini qurur.', 'Tətbiq'),
                (3, 'Qrafik üzrə funksiyanın xassələrini müəyyən edir.', 'Təhlil'),
            ]),
            (4, 'Qüvvət: Qüvvət və kök anlayışlarını bilir.', [
                (1, 'Natural üstlü qüvvətin xassələrini bilir.', 'Xatırlama'),
                (2, 'Qüvvət xassələrini tətbiq edir.', 'Tətbiq'),
            ]),
        ],
        3: [
            (1, 'Çevrə və dairə: Çevrə və dairənin xassələrini öyrənir.', [
                (1, 'Çevrənin elementlərini (radius, diametr, vətər) bilir.', 'Xatırlama'),
                (2, 'Çevrənin uzunluğunu və dairənin sahəsini hesablayır.', 'Tətbiq'),
            ]),
            (2, 'Üçbucaqlar: Üçbucağın xassələri və növləri ilə işləyir.', [
                (1, 'Üçbucağın növlərini (tərəflərinə və bucaqlarına görə) fərqləndirir.', 'Anlama'),
                (2, 'Üçbucağın bucaqlarının cəmini bilir.', 'Xatırlama'),
                (3, 'Üçbucağın sahəsini hesablayır.', 'Tətbiq'),
            ]),
        ],
        4: [
            (1, 'Ölçmə: Həcm və səthi sahə hesablamaları.', [
                (1, 'Prizmanın həcmini hesablayır.', 'Tətbiq'),
                (2, 'Prizmanın səthi sahəsini hesablayır.', 'Tətbiq'),
            ]),
        ],
        5: [
            (1, 'Ehtimal: Ehtimal anlayışını öyrənir.', [
                (1, 'Mümkün, qeyri-mümkün, ehtimallı hadisələri fərqləndirir.', 'Anlama'),
                (2, 'Sadə hadisələrin ehtimalını hesablayır.', 'Tətbiq'),
                (3, 'Eksperiment nəticələrini ehtimalla müqayisə edir.', 'Təhlil'),
            ]),
        ],
    },

    8: {
        1: [
            (1, 'Ədəd çoxluqları: Ədəd çoxluqları ilə əməllər aparır.', [
                (1, 'Natural, tam, rasional, həqiqi ədəd çoxluqlarını fərqləndirir.', 'Anlama'),
                (2, 'Çoxluqlarda birləşmə, kəsişmə, fərq əməllərini bilir.', 'Tətbiq'),
            ]),
        ],
        2: [
            (1, 'Kvadrat tənliklər: İkinci dərəcəli tənlikləri həll edir.', [
                (1, 'Diskriminantı hesablayır.', 'Tətbiq'),
                (2, 'Kvadrat tənliklərin köklərini tapır.', 'Tətbiq'),
                (3, 'Viyet teoremini tətbiq edir.', 'Tətbiq'),
            ]),
            (2, 'Bərabərsizliklər: Bərabərsizliklər sistemini həll edir.', [
                (1, 'Xətti bərabərsizliklər sistemini həll edir.', 'Tətbiq'),
                (2, 'Bərabərsizliyin həllini ədədlər oxunda göstərir.', 'Tətbiq'),
            ]),
            (3, 'Funksiyalar: Kvadrat funksiya və qrafiki.', [
                (1, 'Kvadrat funksiyanın qrafikini (parabolanı) qurur.', 'Tətbiq'),
                (2, 'Funksiyanın xassələrini qrafik üzərində təyin edir.', 'Təhlil'),
                (3, 'Funksiyaların artma-azalma intervallarını müəyyən edir.', 'Təhlil'),
            ]),
            (4, 'Vuruqlara ayırma: Cəbri ifadələri vuruqlara ayırır.', [
                (1, 'Ortaq vuruğu mötərizə xaricinə çıxarır.', 'Tətbiq'),
                (2, 'Qısa vurma düsturlarını tətbiq edir.', 'Tətbiq'),
                (3, 'Qruplaşdırma üsulu ilə vuruqlara ayırır.', 'Tətbiq'),
            ]),
        ],
        3: [
            (1, 'Dördbucaqlılar: Dördbucaqlıların xassələrini öyrənir.', [
                (1, 'Paraleloqram, romb, trapesiya xassələrini bilir.', 'Anlama'),
                (2, 'Dördbucaqlıların sahəsini hesablayır.', 'Tətbiq'),
            ]),
            (2, 'Pifaqor teoremi: Pifaqor teoremini bilir və tətbiq edir.', [
                (1, 'Pifaqor teoremini düzbucaqlı üçbucaqda tətbiq edir.', 'Tətbiq'),
                (2, 'Üçbucağın düzbucaqlı olub-olmadığını yoxlayır.', 'Təhlil'),
            ]),
        ],
        4: [
            (1, 'Ölçmə: Mürəkkəb fiqurların sahə və həcm hesablamaları.', [
                (1, 'Silindrin həcmini və səthi sahəsini hesablayır.', 'Tətbiq'),
                (2, 'Mürəkkəb fiqurların sahəsini hesablayır.', 'Təhlil'),
            ]),
        ],
        5: [
            (1, 'Statistika və ehtimal: Statistik göstəricilər və ehtimal.', [
                (1, 'Yayılma (variasiya) göstəricilərini hesablayır.', 'Tətbiq'),
                (2, 'Şərti ehtimal anlayışını bilir.', 'Anlama'),
                (3, 'Hadisələrin asılı və asılı olmayan olmasını müəyyən edir.', 'Təhlil'),
            ]),
        ],
    },

    9: {
        1: [
            (1, 'Ədədi ardıcıllıqlar: Ədədi ardıcıllıqları öyrənir.', [
                (1, 'Ədədi ardıcıllığın qanunauyğunluğunu müəyyən edir.', 'Təhlil'),
                (2, 'Hesabi silsilə düsturlarını bilir.', 'Xatırlama'),
                (3, 'Hesabi silsilənin cəmini hesablayır.', 'Tətbiq'),
            ]),
        ],
        2: [
            (1, 'Tənliklər və bərabərsizliklər sistemi.', [
                (1, 'İkibilinməyənli tənliklər sistemini müxtəlif üsullarla həll edir.', 'Tətbiq'),
                (2, 'Parametrli sadə tənlikləri həll edir.', 'Təhlil'),
            ]),
            (2, 'Funksiyalar: Müxtəlif funksiyaları öyrənir.', [
                (1, 'y=√x, y=|x|, y=1/x funksiyalarının qrafiklərini qurur.', 'Tətbiq'),
                (2, 'Funksiyanın təyin oblastı və qiymətlər çoxluğunu tapır.', 'Təhlil'),
                (3, 'Funksiyaların xassələrini müqayisə edir.', 'Qiymətləndirmə'),
            ]),
            (3, 'Çoxhədlilər: Çoxhədlilərlə əməllər aparır.', [
                (1, 'Çoxhədliləri vurur.', 'Tətbiq'),
                (2, 'Çoxhədlini çoxhədliyə bölür.', 'Tətbiq'),
                (3, 'Çoxhədlinin köklərini tapır.', 'Tətbiq'),
            ]),
        ],
        3: [
            (1, 'Oxşar üçbucaqlar: Oxşarlıq anlayışını öyrənir.', [
                (1, 'Üçbucaqların oxşarlıq əlamətlərini bilir.', 'Anlama'),
                (2, 'Oxşar fiqurların uyğun tərəflərinin nisbətini tapır.', 'Tətbiq'),
                (3, 'Oxşarlıqdan istifadə edərək məsələ həll edir.', 'Tətbiq'),
            ]),
            (2, 'Triqonometriya girişi: Düzbucaqlı üçbucaqda triqonometrik nisbətlər.', [
                (1, 'Sin, cos, tg anlayışlarını bilir.', 'Xatırlama'),
                (2, 'Düzbucaqlı üçbucaqda triqonometrik nisbətləri hesablayır.', 'Tətbiq'),
            ]),
        ],
        4: [
            (1, 'Ölçmə: Fəza fiqurlarının ölçü parametrləri.', [
                (1, 'Konusun və piramidanın həcmini hesablayır.', 'Tətbiq'),
                (2, 'Kürənin səthi sahəsini və həcmini hesablayır.', 'Tətbiq'),
            ]),
        ],
        5: [
            (1, 'Ehtimal və kombinatorika: Ehtimal nəzəriyyəsinin əsasları.', [
                (1, 'Permutasiya, kombinasiya, yerləşdirmə anlayışlarını bilir.', 'Xatırlama'),
                (2, 'Kombinatorika düsturlarını tətbiq edir.', 'Tətbiq'),
                (3, 'Hadisələrin ehtimalını kombinatorika ilə hesablayır.', 'Tətbiq'),
                (4, 'Tam ehtimal düsturunu tətbiq edir.', 'Tətbiq'),
            ]),
        ],
    },

    10: {
        1: [
            (1, 'Həqiqi ədədlər: Həqiqi ədədlərin tam xassələrini bilir.', [
                (1, 'Həqiqi ədədlərin modul xassələrini tətbiq edir.', 'Tətbiq'),
                (2, 'Bərabərsizlikləri modul ilə həll edir.', 'Tətbiq'),
            ]),
        ],
        2: [
            (1, 'Triqonometriya: Triqonometrik funksiyaları öyrənir.', [
                (1, 'Radian ölçüsü ilə bucaqları ifadə edir.', 'Tətbiq'),
                (2, 'Triqonometrik funksiyaların qrafiklərini qurur.', 'Tətbiq'),
                (3, 'Triqonometrik eyniliklər bilir və tətbiq edir.', 'Tətbiq'),
                (4, 'Triqonometrik tənlikləri həll edir.', 'Tətbiq'),
            ]),
            (2, 'Üstlü və loqarifmik funksiyalar.', [
                (1, 'Üstlü funksiyanın xassələrini bilir.', 'Anlama'),
                (2, 'Loqarifm anlayışını və xassələrini bilir.', 'Anlama'),
                (3, 'Üstlü və loqarifmik tənlikləri həll edir.', 'Tətbiq'),
                (4, 'Üstlü və loqarifmik bərabərsizlikləri həll edir.', 'Tətbiq'),
            ]),
            (3, 'Limit: Funksiyanın limiti anlayışı.', [
                (1, 'Ardıcıllığın limitini hesablayır.', 'Tətbiq'),
                (2, 'Funksiyanın limitini hesablayır.', 'Tətbiq'),
                (3, 'Kəsilməzlik anlayışını bilir.', 'Anlama'),
            ]),
        ],
        3: [
            (1, 'Vektorlar: Vektor anlayışı və vektorlarla əməllər.', [
                (1, 'Vektor anlayışını bilir.', 'Anlama'),
                (2, 'Vektorları toplayır, çıxır, ədədə vurur.', 'Tətbiq'),
                (3, 'Vektorların skalyar hasilini hesablayır.', 'Tətbiq'),
            ]),
            (2, 'Fəza həndəsəsi: Müstəvilərin və düz xətlərin qarşılıqlı vəziyyəti.', [
                (1, 'Düz xətt və müstəvinin qarşılıqlı vəziyyətini müəyyən edir.', 'Təhlil'),
                (2, 'İki müstəvinin qarşılıqlı vəziyyətini müəyyən edir.', 'Təhlil'),
                (3, 'Diedrik bucağı hesablayır.', 'Tətbiq'),
            ]),
        ],
        5: [
            (1, 'Statistika: Statistik təhlil üsulları.', [
                (1, 'Dispersiya və standart kənarlaşma hesablayır.', 'Tətbiq'),
                (2, 'Normal paylanma anlayışını bilir.', 'Anlama'),
                (3, 'Reqressiya xəttini qurur.', 'Tətbiq'),
            ]),
        ],
    },

    11: {
        1: [
            (1, 'Kompleks ədədlər: Kompleks ədədlərlə əməllər.', [
                (1, 'Kompleks ədəd anlayışını bilir.', 'Anlama'),
                (2, 'Kompleks ədədlərlə əməllər aparır.', 'Tətbiq'),
            ]),
        ],
        2: [
            (1, 'Törəmə: Funksiyanın törəməsini hesablayır.', [
                (1, 'Törəmə anlayışını bilir və sadə funksiyaların törəməsini tapır.', 'Tətbiq'),
                (2, 'Törəmə qaydalarını (cəm, hasilə, nisbət) tətbiq edir.', 'Tətbiq'),
                (3, 'Mürəkkəb funksiyanın törəməsini hesablayır.', 'Tətbiq'),
                (4, 'Törəmənin həndəsi (toxunan) və fiziki (sürət) mənasını bilir.', 'Anlama'),
            ]),
            (2, 'Törəmənin tətbiqləri: Törəmə vasitəsilə funksiya tədqiqi.', [
                (1, 'Funksiyanın artma-azalma intervallarını törəmə ilə tapır.', 'Təhlil'),
                (2, 'Funksiyanın ekstremum nöqtələrini müəyyən edir.', 'Təhlil'),
                (3, 'Funksiyanın ən böyük və ən kiçik qiymətlərini tapır.', 'Tətbiq'),
                (4, 'Optimallaşdırma məsələlərini həll edir.', 'Qiymətləndirmə'),
            ]),
            (3, 'İnteqral: Qeyri-müəyyən və müəyyən inteqralı hesablayır.', [
                (1, 'İlk funksiyanı (antitörəməni) tapır.', 'Tətbiq'),
                (2, 'Qeyri-müəyyən inteqralı hesablayır.', 'Tətbiq'),
                (3, 'Müəyyən inteqralı hesablayır.', 'Tətbiq'),
                (4, 'Müəyyən inteqral vasitəsilə sahəni hesablayır.', 'Tətbiq'),
            ]),
        ],
        3: [
            (1, 'Fəza fiqurları: Fəza fiqurlarının xassələri.', [
                (1, 'Prizma, piramida, konus, silindrin xassələrini bilir.', 'Anlama'),
                (2, 'Fəza fiqurlarının həcmini hesablayır.', 'Tətbiq'),
                (3, 'Fəza fiqurlarının səthi sahəsini hesablayır.', 'Tətbiq'),
            ]),
            (2, 'Koordinatlar fəzada: Fəzada koordinatlarla işləyir.', [
                (1, 'Fəzada iki nöqtə arasında məsafəni hesablayır.', 'Tətbiq'),
                (2, 'Fəzada vektorların koordinatlarını tapır.', 'Tətbiq'),
            ]),
        ],
        5: [
            (1, 'Ehtimal: Ehtimal nəzəriyyəsinin tətbiqləri.', [
                (1, 'Bernulli düsturu ilə ehtimal hesablayır.', 'Tətbiq'),
                (2, 'Riyazi gözləmə və dispersiyanı hesablayır.', 'Tətbiq'),
                (3, 'Ehtimal nəzəriyyəsini real məsələlərə tətbiq edir.', 'Qiymətləndirmə'),
            ]),
        ],
    },
}


def esc(s):
    return s.replace("'", "''")


lines = []
lines.append("-- Auto-generated math standards for all 11 grades")
lines.append("-- Format: standart_kodu = Riy_<Roman>_<mezmun>.<std>, alt = Riy_<Roman>_<mezmun>.<std>.<alt>")
lines.append("")
lines.append("TRUNCATE movcud_standartlar RESTART IDENTITY;")
lines.append("TRUNCATE yenilenmi_standartlar RESTART IDENTITY;")
lines.append("")

for sinif in range(1, 12):
    rom = ROMAN[sinif]
    grade_data = DATA.get(sinif, {})
    for mezmun_no in sorted(grade_data.keys()):
        mezmun_name = MEZMUN[mezmun_no]
        standards = grade_data[mezmun_no]
        for std_no, std_text, alts in standards:
            std_code = f"Riy_{rom}_{mezmun_no}.{std_no}"
            for alt_no, alt_text, bloom in alts:
                alt_code = f"Riy_{rom}_{mezmun_no}.{std_no}.{alt_no}"
                lines.append(
                    f"INSERT INTO movcud_standartlar (sinif, standart_kodu, mezmun_xetti, standart_metni, alt_standart_kodu, alt_standart_metni, bloom_seviyyesi) VALUES "
                    f"({sinif}, '{esc(std_code)}', '{esc(mezmun_name)}', '{esc(std_text)}', '{esc(alt_code)}', '{esc(alt_text)}', '{esc(bloom)}');"
                )

lines.append("")
lines.append("-- Copy all to yenilenmi_standartlar as 'movcud'")
lines.append("INSERT INTO yenilenmi_standartlar (sinif, standart_kodu, mezmun_xetti, standart_metni, alt_standart_kodu, alt_standart_metni, deyisiklik_novu, kohne_standart_metni, bloom_seviyyesi)")
lines.append("SELECT sinif, standart_kodu, mezmun_xetti, standart_metni, alt_standart_kodu, alt_standart_metni, 'movcud', standart_metni, bloom_seviyyesi")
lines.append("FROM movcud_standartlar ORDER BY sinif, standart_kodu, alt_standart_kodu;")

sql_content = "\n".join(lines)
with open("/Users/royatalibova/Desktop/Riy_standartlar/sql/seed_standards.sql", "w", encoding="utf-8") as f:
    f.write(sql_content)

# Count totals per grade
for sinif in range(1, 12):
    grade_data = DATA.get(sinif, {})
    total = sum(len(alts) for mezmun_no, stds in grade_data.items() for _, _, alts in stds)
    print(f"Sinif {sinif:2d} ({ROMAN[sinif]:>4s}): {total} standart")

total_all = sum(
    len(alts)
    for sinif_data in DATA.values()
    for stds in sinif_data.values()
    for _, _, alts in stds
)
print(f"\nCəmi: {total_all} standart")
