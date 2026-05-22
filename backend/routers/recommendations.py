#burada kullanıcının kara listesinde bulunan içeriklere göre ürün önerileri yapacağız. Veritabanında sp_recommend_products adlı bir stored procedureu çağırıyoruz. Bu procedure, kullanıcı ID'si ve önerilecek ürün sayısı (limit) alarak, kullanıcının kara listesinde olmayan içeriklere sahip ürünleri analiz eder ve her bir ürün için uyum puanı (compatibility_score), uyum etiketi (compatibility_label) ve uyum notu (compatibility_note) döndürür. Uyum puanı 100 üzerinden verilirken, uyum etiketi good, caution veya avoid olabilir. Uyum notu ise kullanıcının kara listesinde bulunan içeriklerle ilgili bilgilendirici bir mesaj içerebilir.


from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import text
from database import get_db # Üst klasördeki database.py'dan çekiyoruz

router = APIRouter(prefix="/recommendations", tags=["recommendations"])

@router.get("/user/{user_id}")
def get_recommendations(user_id: int, limit: int = 10, db: Session = Depends(get_db)): #sqldeki sp_recommend_products fonskiyonu çağırılıyor. 
    query = text("SELECT * FROM sp_recommend_products(:u_id, :limit)")
    result = db.execute(query, {"u_id": user_id, "limit": limit}).fetchall()

    #ver tabanından gelen bilgileri flutter okuyabileceği fortmata çeviriyoruz.
    return [
        {
            "product_name": row.r_product_name,
            "brand_name": row.r_brand_name,
            "compatibility_score": row.r_compatibility_score, # 100 üzerinden uyum puanı [cite: 260, 268]
            "label": row.r_compatibility_label, # good, caution, avoid [cite: 271, 272]
            "note": row.r_compatibility_note
        } for row in result
    ]