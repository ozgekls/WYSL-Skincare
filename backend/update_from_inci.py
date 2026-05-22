import pandas as pd
import psycopg2
import ast

DB_PARAMS = {
    "host": "localhost",
    "database": "wysl_skincare_app",
    "user": "postgres",
    "password": "database4589",
    "port": "5432",
    "client_encoding": "utf-8"
}

# who_is_it_good_for ve who_should_avoid içindeki skin type etiketlerini
# veritabanı skin_type değerlerine dönüştürme haritası
GOOD_FOR_MAP = {
    "acne":                  "oily",
    "blackheads":            "oily",
    "oily":                  "oily",
    "dry and dehydrated":    "dry",
    "dry dehydrated":        "dry",
    "dehydrated":            "dry",
    "sensitive":             "sensitive",
    "redness":               "sensitive",
    "impaired skin barrier": "sensitive",
    "combination":           "combination",
    "fine lines":            "normal",
    "wrinkles":              "normal",
    "elasticity":            "normal",
    "radiance":              "normal",
    "texture":               "normal",
}

AVOID_MAP = {
    "oily":           "oily",
    "combination":    "combination",
    "sensitive":      "sensitive",
    "dry dehydrated": "dry",
}


def parse_list_field(raw):
    """String olarak gelen liste alanını Python listesine çevirir."""
    if pd.isna(raw) or raw == "[]":
        return []
    try:
        items = ast.literal_eval(raw)
        return [i.strip().lower() for i in items if i.strip()]
    except Exception:
        return []


def infer_skin_types(good_for_items, avoid_items):
    """
    good_for ve avoid listelerinden önerilen / kaçınılacak cilt tiplerini çıkarır.
    Dönüş: (good_for_types: set, avoid_types: set)
    """
    good_types = set()
    for item in good_for_items:
        for keyword, skin_type in GOOD_FOR_MAP.items():
            if keyword in item:
                good_types.add(skin_type)

    avoid_types = set()
    for item in avoid_items:
        for keyword, skin_type in AVOID_MAP.items():
            if keyword in item:
                avoid_types.add(skin_type)

    return good_types, avoid_types


def shorten_function(what_does_it_do):
    """
    Uzun açıklamayı kısa bir function etiketine çevirir.
    İlk cümleyi alıp 100 karakterle sınırlar.
    """
    if pd.isna(what_does_it_do):
        return None
    text = str(what_does_it_do).strip()
    # Bullet point varsa ilk maddeyi al
    if "-" in text:
        lines = [l.strip().lstrip("-").strip() for l in text.split("\n") if l.strip().startswith("-")]
        if lines:
            return lines[0][:150]
    # Yoksa ilk cümleyi al
    first = text.split(".")[0].strip()
    return first[:150] if first else None


def update_from_inci():
    log = open("inci_update_log.txt", "w", encoding="utf-8")
    conn = None

    try:
        # CSV oku
        try:
            df = pd.read_csv("/mnt/user-data/uploads/ingredientsList.csv", encoding="utf-8")
        except UnicodeDecodeError:
            df = pd.read_csv("/mnt/user-data/uploads/ingredientsList.csv", encoding="latin-1")

        log.write(f"INCI dataset: {len(df)} satir okundu.\n\n")

        conn = psycopg2.connect(**DB_PARAMS)
        cur = conn.cursor()

        # --- Ingredients tablosuna yeni sütunlar ekle (yoksa) ---
        # good_for_skin_types ve avoid_skin_types sütunları bilgi amaçlı
        # Öneri motoru bunları kullanacak
        cur.execute("""
            ALTER TABLE ingredients
            ADD COLUMN IF NOT EXISTS good_for_skin_types TEXT,
            ADD COLUMN IF NOT EXISTS avoid_skin_types    TEXT,
            ADD COLUMN IF NOT EXISTS description         TEXT;
        """)
        conn.commit()
        log.write("Yeni sutunlar kontrol edildi / eklendi: good_for_skin_types, avoid_skin_types, description\n\n")

        eslesme = 0
        eslesmeme = 0

        for _, row in df.iterrows():
            ing_name = str(row["name"]).strip()
            ing_name_lower = ing_name.lower()

            good_for_items = parse_list_field(row.get("who_is_it_good_for"))
            avoid_items    = parse_list_field(row.get("who_should_avoid"))
            good_types, avoid_types = infer_skin_types(good_for_items, avoid_items)

            function_text = shorten_function(row.get("what_does_it_do"))
            description   = str(row.get("short_description", "")).strip() or None

            good_str  = ",".join(sorted(good_types))  or None
            avoid_str = ",".join(sorted(avoid_types)) or None

            # Tam isim eşleşmesi dene (büyük/küçük harf duyarsız)
            cur.execute(
                """
                UPDATE ingredients
                SET
                    function             = COALESCE(function, %s),
                    good_for_skin_types  = COALESCE(good_for_skin_types, %s),
                    avoid_skin_types     = COALESCE(avoid_skin_types, %s),
                    description          = COALESCE(description, %s)
                WHERE LOWER(TRIM(name)) = %s
                """,
                (function_text, good_str, avoid_str, description, ing_name_lower)
            )

            if cur.rowcount > 0:
                eslesme += cur.rowcount
                log.write(f"  OK  : {ing_name} → good_for={good_str} | avoid={avoid_str}\n")
            else:
                eslesmeme += 1
                log.write(f"  YOK : {ing_name} (DB'de bulunamadi)\n")

        conn.commit()

        # Özet
        cur.execute("SELECT COUNT(*) FROM ingredients WHERE function IS NOT NULL")
        fn_dolu = cur.fetchone()[0]
        cur.execute("SELECT COUNT(*) FROM ingredients WHERE good_for_skin_types IS NOT NULL")
        gf_dolu = cur.fetchone()[0]

        log.write(f"\n--- SONUC ---\n")
        log.write(f"INCI'dan eslesen     : {eslesme}\n")
        log.write(f"DB'de bulunamayan    : {eslesmeme}\n")
        log.write(f"function dolu olan   : {fn_dolu}\n")
        log.write(f"good_for dolu olan   : {gf_dolu}\n")

        print("Tamamlandi. Detaylar: inci_update_log.txt")

    except Exception as e:
        log.write(f"\nKRITIK HATA: {str(e)}\n")
        if conn:
            conn.rollback()
    finally:
        if conn:
            cur.close()
            conn.close()
        log.close()


if __name__ == "__main__":
    update_from_inci()