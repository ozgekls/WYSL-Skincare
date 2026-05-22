#cosmetic.csv dosyasını alıp veri tabanına yükler

import pandas as pd
import psycopg2
import os

DB_PARAMS = {
    "host": "localhost",
    "database": "wysl_skincare_app",
    "user": "postgres",
    "password": "database4589",
    "port": "5432",
    "client_encoding": "utf-8"   # PostgreSQL bağlantısına UTF-8 zorla
}


def clean_text(value): #buradaki valuse dışarıdan gelecek olan değer
    """Herhangi bir string'i güvenli UTF-8'e çevirir, sorunlu karakterleri atar."""
    if pd.isna(value): 
        return None
#pd pandas kütüphanesinin kısaltmasıdır. pd.isna() fonksiyonu, bir değerin NaN (Not a Number) veya None olup olmadığını kontrol eder. Eğer value NaN veya None ise, bu fonksiyon True döner ve clean_text fonksiyonu None döndürür. yani boş döndürür
    return str(value).encode("utf-8", errors="ignore").decode("utf-8").strip()
#gelen veriyi stringe çevir, metni utf-8 e çevir, bozuk karakterleri at (igonore et), tekrar utf-8 den stringe çevir(decode), başındaki ve sonundaki boşlukları at (strip) ve temizlenmiş metni döndür


def load_data():
    log_file = open("loader_log.txt", "w", encoding="utf-8")
    conn = None
#Veri yükleme işlemi sırasında oluşabilecek hataları ve ilerlemeyi kaydetmek için bir log dosyası açılır.loader_log.txt dosyanın adı ve w ile bu dosyaya yazma işlemi gerçekleştirilir. Veritabanı bağlantısı için conn değişkeni None olarak başlatılır, böylece hata durumunda bağlantının kapatılması kontrol edilebilir.

    try:
        # --- Dosya yolu ---
        current_dir = os.path.dirname(os.path.abspath(__file__))  #abspath ile dosyanın tam yolunu alır, dirname ile bu yolun dizin kısmını alır. Böylece mevcut dosyanın bulunduğu dizini elde eder.
        csv_path = os.path.join(current_dir, "cosmetics.csv") #csv_path değişkeni, mevcut dizinde cosmetics.csv dosyasının yolunu oluşturur. os.path.join() fonksiyonu, dizin ve dosya adını birleştirerek tam bir dosya yolu oluşturur.
        if not os.path.exists(csv_path):
            csv_path = os.path.join(os.path.dirname(current_dir), "cosmetics.csv")

        log_file.write(f"Dosya yolu: {csv_path}\n")
    #__file__ mevcut dosyanın yolunu verir. os.path.dirname() ile bu yolun dizin kısmı alınır. os.path.abspath() ile tam yol elde edilir. csv_path değişkeni, mevcut dizinde cosmetics.csv dosyasının var olup olmadığını kontrol eder. Eğer yoksa, bir üst dizinde aranır. Bu sayede hem backend hem de projenin kök dizininde dosya bulunabilir.

        # --- CSV oku: önce UTF-8, hata verirse latin-1 ---
        try:
            df = pd.read_csv(csv_path, encoding="utf-8")
            log_file.write("Encoding: utf-8\n")
        except UnicodeDecodeError:
            df = pd.read_csv(csv_path, encoding="latin-1")
            log_file.write("Encoding: latin-1 (fallback)\n")

        log_file.write(f"Toplam satir: {len(df)}\n")
        log_file.write("Islem basladi...\n")
        log_file.flush()

        # --- Veritabanı bağlantısı ---
        conn = psycopg2.connect(**DB_PARAMS)
        cur = conn.cursor() #veritabanı bağlantısı kurulur ve bir cursor oluşturulur. Cursor, veritabanı üzerinde SQL sorguları çalıştırmak için kullanılır.

        basarili = 0
        hatali = 0

        for index, row in df.iterrows():
            try:
                brand        = clean_text(row.get("Brand"))
                product_name = clean_text(row.get("Name"))
                category     = clean_text(row.get("Label"))
                ingredients_raw = clean_text(row.get("Ingredients"))

                if not product_name:
                    log_file.write(f"  [{index}] Urun adi bos, atlandi.\n")
                    continue

                # Ürünü ekle
                cur.execute(
                    """
                    INSERT INTO products (brand_name, product_name, category)
                    VALUES (%s, %s, %s)
                    ON CONFLICT DO NOTHING 
                    RETURNING product_id
                    """,
                    (brand, product_name, category),
                )
                #ürün zaten varsa ekleme, yoksa ekle (conflict do nothing) ve eklenen ürünün id'sini döndür
                result = cur.fetchone()

                if result is None:
                    # Zaten vardı, id'sini al
                    cur.execute(
                        "SELECT product_id FROM products WHERE product_name = %s AND brand_name = %s",
                        (product_name, brand),
                    )
                    result = cur.fetchone()

                if result is None:
                    log_file.write(f"  [{index}] product_id alinamadi: {product_name}\n")
                    continue

                product_id = result[0]

                # İçerikleri ekle
                if ingredients_raw:
                    ingredients_list = [
                        i.strip() for i in ingredients_raw.split(",") if i.strip()
                    ]

                    for ing_name in ingredients_list:
                        ing_name = ing_name[:200]  # Fazla uzun isimleri kes

                        cur.execute(
                            """
                            INSERT INTO ingredients (ingredient_name)
                            VALUES (%s)
                            ON CONFLICT (ingredient_name) DO UPDATE SET ingredient_name = EXCLUDED.ingredient_name
                            RETURNING ingredient_id
                            """,
                            (ing_name,),
                        )
                        ing_id = cur.fetchone()[0]

                        cur.execute(
                            """
                            INSERT INTO product_ingredients (product_id, ingredient_id)
                            VALUES (%s, %s)
                            ON CONFLICT DO NOTHING
                            """,
                            (product_id, ing_id),
                        )

                basarili += 1

                if index % 100 == 0:
                    conn.commit()  # Her 100 satırda ara commit
                    log_file.write(f"  {index}. satir tamamlandi ({basarili} basarili, {hatali} hatali)...\n")
                    log_file.flush()

            except Exception as row_err:
                hatali += 1
                log_file.write(f"  [{index}] SATIR HATASI: {str(row_err)}\n")
                conn.rollback()  # Sadece bu satırı geri al, devam et

        conn.commit()
        log_file.write(f"\nTAMAMLANDI: {basarili} basarili, {hatali} hatali.\n")

    except Exception as e:
        log_file.write(f"\nKRITIK HATA: {str(e)}\n")
        if conn:
            conn.rollback()

    finally:
        if conn:
            cur.close()
            conn.close()
        log_file.close()


if __name__ == "__main__":
    load_data()