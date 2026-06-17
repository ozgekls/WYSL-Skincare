from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import text
from database import get_db
from pydantic import BaseModel as PydanticBase

# YENİ EKLENEN KÜTÜPHANELER
from thefuzz import process, fuzz

router = APIRouter(prefix="/products", tags=["products"])

@router.get("/")
def get_all_products(db: Session = Depends(get_db)):
    # Veritabanındaki tüm ürünleri çek
    query = text("SELECT product_id, brand_name, product_name, category FROM products")
    result = db.execute(query).fetchall()
    
    # Gelen veriyi Flutter'ın anlayacağı JSON formatına (sözlük listesine) çeviriyoruz
    products_list = []
    for row in result:
        products_list.append({
            "product_id": row[0],
            "brand_name": row[1],
            "product_name": row[2],
            "category": row[3]
        })
        
    return products_list

@router.get("/analyze/{user_id}/{product_id}")
def analyze_product(user_id: int, product_id: int, db: Session = Depends(get_db)):
    # Veritabanındaki Stored Procedure'u çağırıyoruz
    query = text("SELECT * FROM sp_analyze_product(:u_id, :p_id)")
    result = db.execute(query, {"u_id": user_id, "p_id": product_id}).fetchall()
    
    if not result:
        raise HTTPException(status_code=404, detail="Ürün veya kullanıcı bulunamadı")

    # Sonuçları JSON formatına uygun hale getiriyoruz
    analysis = []
    for row in result:
        analysis.append({
            "ingredient_name": row.ingredient_name,
            "status": row.status, # danger, warning, safe
            "reason": row.reason, # "Bu içerik alerji listenizde..." gibi
            "comedogenic": row.comedogenic_score,
            "irritation": row.irritation_score
        })
    return analysis

class IngredientTextAnalysis(PydanticBase):
    user_id: int
    ingredients_text: str

@router.post("/analyze-text")
def analyze_ingredients_text(data: IngredientTextAnalysis, db: Session = Depends(get_db)):
    # Veritabanındaki tüm içerik isimlerini çekiyoruz (Hem Fuzzy hem de yeni Akıllı Bölücü için)
    all_ingredients_query = text("SELECT ingredient_name FROM ingredients")
    all_db_ingredients = db.execute(all_ingredients_query).fetchall()
    db_names = [row[0] for row in all_db_ingredients]
    
    text_clean = data.ingredients_text.strip()
    raw_ingredients = []

    # --- 🌟 YENİ: VİRGÜLSÜZ METİN (AKILLI BÖLÜCÜ) MANTIĞI ---
    # Eğer metinde hiç virgül yoksa (veya çok uzun bir metin olmasına rağmen 1-2 virgül varsa)
    if text_clean.count(',') < 2 and len(text_clean) > 30:
        text_lower = text_clean.lower()
        
        # Veritabanındaki isimleri UZUNLUKLARINA GÖRE (en uzundan kısaya) sırala.
        sorted_db_names = sorted(db_names, key=len, reverse=True)
        
        for db_name in sorted_db_names:
            db_name_lower = db_name.lower()
            
            # Eğer veritabanındaki bu madde, kullanıcının gönderdiği virgülsüz metnin içinde geçiyorsa:
            if db_name_lower in text_lower:
                raw_ingredients.append(db_name) # Maddeyi analiz listesine ekle
                # Bulunan maddeyi metinden SİL ki (yerine | koy), içindeki kelimeler başka maddelerle çakışmasın
                text_lower = text_lower.replace(db_name_lower, " | ")
        
        # Geriye kalan (veritabanında bulamadığı) parçaları da alalım (Fuzzy veya Kök bulur belki)
        leftovers = [w.strip() for w in text_lower.split('|') if len(w.strip()) > 3]
        raw_ingredients.extend(leftovers)
        
    else:
        # Zaten virgül varsa normal şekilde böl
        raw_ingredients = [i.strip() for i in text_clean.split(',') if i.strip()]

    # --- BUNDAN SONRASI MEVCUT KODUNLA BİREBİR AYNI ---
    results = []
    for ing_name in raw_ingredients:
        
        # 1. MEVCUT MANTIK: Orijinal SQL sorgusu ile arama
        query = text("""
            SELECT 
                i.ingredient_id,
                i.ingredient_name,
                i.comodogenic_score,
                i.irritation_score,
                CASE 
                    WHEN ua.ingredient_id IS NOT NULL THEN 'danger'
                    WHEN i.comodogenic_score >= 4 OR i.irritation_score >= 4 THEN 'warning'
                    ELSE 'safe'
                END AS status,
                CASE 
                    WHEN ua.ingredient_id IS NOT NULL THEN 'Alerji listenizde kayıtlı!'
                    WHEN i.comodogenic_score >= 4 THEN 'Yüksek comedogenic (' || i.comodogenic_score || '/5)'
                    WHEN i.irritation_score >= 4 THEN 'Yüksek irritasyon riski (' || i.irritation_score || '/5)'
                    ELSE 'Güvenli görünüyor'
                END AS reason
            FROM ingredients i
            LEFT JOIN user_allergies ua 
                ON ua.ingredient_id = i.ingredient_id 
                AND ua.user_id = :u_id
            WHERE LOWER(i.ingredient_name) LIKE :ing_name
            LIMIT 1
        """)
        
        result = db.execute(query, {
            "u_id": data.user_id,
            "ing_name": f"%{ing_name.lower()}%"
        }).fetchone()
        
        if result:
            results.append({
                "ingredient_name": result.ingredient_name,
                "status": result.status,
                "reason": result.reason,
                "comedogenic_score": result.comodogenic_score,
                "irritation_score": result.irritation_score,
                "found_in_db": True
            })
        else:
            raw_lower = ing_name.lower()
            match_found_in_fuzzy = False
            
            # --- 2. FUZZY MATCHING (Yazım Hatası Düzeltme) ---
            if db_names:
                best_match_name, score = process.extractOne(raw_lower, db_names, scorer=fuzz.token_sort_ratio)
                
                if score >= 82:
                    fuzzy_result = db.execute(query, {
                        "u_id": data.user_id,
                        "ing_name": f"%{best_match_name.lower()}%"
                    }).fetchone()
                    
                    if fuzzy_result:
                        results.append({
                            "ingredient_name": ing_name, 
                            "status": fuzzy_result.status,
                            "reason": fuzzy_result.reason + f" (Sistem bunu algıladı: {best_match_name})",
                            "comedogenic_score": fuzzy_result.comodogenic_score, 
                            "irritation_score": fuzzy_result.irritation_score,
                            "found_in_db": True
                        })
                        match_found_in_fuzzy = True
            
            # --- 3. KÖK KELİME KONTROLLERİ ---
            if not match_found_in_fuzzy:
                if "paraben" in raw_lower:
                    results.append({"ingredient_name": ing_name, "status": "danger", "reason": "Paraben grubu koruyucu", "comedogenic_score": None, "irritation_score": None, "found_in_db": False})
                elif "sulfate" in raw_lower or "sülfat" in raw_lower:
                    results.append({"ingredient_name": ing_name, "status": "warning", "reason": "Sert sürfaktan/temizleyici", "comedogenic_score": None, "irritation_score": None, "found_in_db": False})
                elif "siloxane" in raw_lower or "methicone" in raw_lower:
                    results.append({"ingredient_name": ing_name, "status": "safe", "reason": "Silikon türevi", "comedogenic_score": None, "irritation_score": None, "found_in_db": False})
                elif "fragrance" in raw_lower or "parfum" in raw_lower or "parfüm" in raw_lower:
                    results.append({"ingredient_name": ing_name, "status": "warning", "reason": "Koku verici/Alerjen potansiyeli", "comedogenic_score": None, "irritation_score": None, "found_in_db": False})
                else:
                    # --- 4. HİÇBİR ŞEKİLDE BULUNAMADIYSA ---
                    results.append({
                        "ingredient_name": ing_name,
                        "status": "unknown",
                        "reason": "Veritabanında bulunamadı",
                        "comedogenic_score": None,
                        "irritation_score": None,
                        "found_in_db": False
                    })
    
    return results