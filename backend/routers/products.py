#burada vertabanındaki sp_analyze_product adlı stored procedure'u çağırarak ürün analizi yapacağız. Kullanıcı ID'si ve ürün ID'si alarak, bu bilgileri stored procedure'a parametre olarak geçeceğiz ve sonuçları JSON formatında döndüreceğiz. Stored procedure, ürünün içeriklerini analiz ederek her bir içerik için tehlike durumunu (danger, warning, safe), nedenini ve komedojenik/irritasyon skorlarını döndürecek şekilde tasarlanmıştır.


from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import text
from database import get_db
from pydantic import BaseModel as PydanticBase

router = APIRouter(prefix="/products", tags=["products"])

@router.get("/")
def get_all_products(db: Session = Depends(get_db)):
    # Veritabanındaki tüm ürünleri çeken basit bir SQL sorgusu
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
            "status": row.status, # danger, warning, safe [cite: 383]
            "reason": row.reason, # "Bu içerik alerji listenizde..." gibi [cite: 384]
            "comedogenic": row.comedogenic_score,
            "irritation": row.irritation_score
        })
    return analysis

from pydantic import BaseModel as PydanticBase

class IngredientTextAnalysis(PydanticBase):
    user_id: int
    ingredients_text: str

@router.post("/analyze-text")
def analyze_ingredients_text(data: IngredientTextAnalysis, db: Session = Depends(get_db)):
    # İçerikleri virgülle böl, her birini veritabanında ara
    raw_ingredients = [i.strip() for i in data.ingredients_text.split(',') if i.strip()]
    
    results = []
    for ing_name in raw_ingredients:
        # Veritabanında bu içeriği ara (kısmi eşleşme)
        query = text("""
            SELECT 
                i.ingredient_id,
                i.ingredient_name,
                i.comodogenic_score,
                i.irritation_score,
                -- Kullanıcının bu içerikle geçmişi var mı?
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
            # Veritabanında bulunamadı
            results.append({
                "ingredient_name": ing_name,
                "status": "unknown",
                "reason": "Veritabanında bulunamadı",
                "comedogenic_score": None,
                "irritation_score": None,
                "found_in_db": False
            })
    
    return results