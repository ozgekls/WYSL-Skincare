from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from database import get_db
from sqlalchemy import text
from pydantic import BaseModel, EmailStr
from typing import Optional
import hashlib

router = APIRouter(prefix="/users", tags=["Users"])

def hash_password(password: str) -> str:
    """Şifreyi SHA-256 ile hashle. Üretimde bcrypt kullan!"""
    return hashlib.sha256(password.encode()).hexdigest()

class UserRegister(BaseModel):
    username: str
    email: EmailStr
    password: str

class UserLogin(BaseModel):
    email: EmailStr
    password: str

class SkinTypeUpdate(BaseModel):
    user_id: int
    skin_type: str

# --- KAYIT OL ---
@router.post("/register")
def register_user(user: UserRegister, db: Session = Depends(get_db)):
    try:
        check_query = text("SELECT * FROM users WHERE email = :email")
        existing_user = db.execute(check_query, {"email": user.email}).fetchone()
        
        if existing_user:
            raise HTTPException(status_code=400, detail="Bu e-posta zaten kayıtlı!")

        # Şifreyi hashleyerek kaydet (plaintext asla!)
        hashed = hash_password(user.password)

        query = text("""
            INSERT INTO users (username, email, password_hash) 
            VALUES (:name, :email, :pass) 
            RETURNING user_id
        """)
        result = db.execute(query, {"name": user.username, "email": user.email, "pass": hashed})
        db.commit()
        
        new_id = result.fetchone()[0]
        return {"message": "Kayıt başarılı", "user_id": new_id}
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))

# --- GİRİŞ YAP ---
@router.post("/login")
def login_user(user: UserLogin, db: Session = Depends(get_db)):
    hashed = hash_password(user.password)
    query = text("SELECT user_id, username, skin_type FROM users WHERE email = :email AND password_hash = :pass")
    result = db.execute(query, {"email": user.email, "pass": hashed}).fetchone()
    
    if not result:
        raise HTTPException(status_code=401, detail="E-posta veya şifre hatalı")
    
    return {
        "user_id": result.user_id,
        "username": result.username,
        "skin_type": result.skin_type
    }

# --- CİLT TİPİ GÜNCELLE ---
@router.post("/update-skin-type")
def update_skin_type(data: SkinTypeUpdate, db: Session = Depends(get_db)):
    try:
        query = text("UPDATE users SET skin_type = :s_type WHERE user_id = :u_id")
        db.execute(query, {"s_type": data.skin_type, "u_id": data.user_id})
        db.commit()
        return {"message": "Cilt tipi başarıyla güncellendi"}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))

# --- PROFİL GETİR ---
@router.get("/{user_id}")
def get_user_profile(user_id: int, db: Session = Depends(get_db)):
    try:
        query = text("""
            SELECT user_id, username, email, skin_type 
            FROM users 
            WHERE user_id = :u_id
        """)
        result = db.execute(query, {"u_id": user_id}).fetchone()

        if not result:
            raise HTTPException(status_code=404, detail="Kullanıcı bulunamadı")

        return {
            "user_id": result.user_id,
            "username": result.username,
            "email": result.email,
            "skin_type": result.skin_type
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

class ProductAdd(BaseModel):
    user_id: int
    routine_type: str
    product_name: str
    ingredients: str

# --- RUTİNE ÜRÜN EKLE ---
@router.post("/add-product")
def add_user_product(data: ProductAdd, db: Session = Depends(get_db)):
    try:
        query = text("""
            INSERT INTO user_products (user_id, routine_type, product_name, ingredients_text) 
            VALUES (:user_id, :routine_type, :product_name, :ingredients)
        """)
        db.execute(query, {
            "user_id": data.user_id, 
            "routine_type": data.routine_type, 
            "product_name": data.product_name, 
            "ingredients": data.ingredients
        })
        db.commit()
        return {"message": "Ürün başarıyla eklendi"}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))

# --- RUTİNİ GETİR VE ANALİZ ET ---
@router.get("/{user_id}/routine")
def get_user_routine(user_id: int, db: Session = Depends(get_db)):
    query_products = text("""
        SELECT id, routine_type, product_name, ingredients_text, 
               is_favorite, analysis_date
        FROM user_products 
        WHERE user_id = :u_id
        ORDER BY analysis_date DESC
    """)
    products = db.execute(query_products, {"u_id": user_id}).fetchall()
    
    try:
        query_allergies = text("""
            SELECT i.ingredient_name
            FROM user_allergies ua
            JOIN ingredients i ON ua.ingredient_id = i.ingredient_id
            WHERE ua.user_id = :u_id
        """)
        allergies_result = db.execute(query_allergies, {"u_id": user_id}).fetchall()
        user_bad_ingredients = [row[0].lower() for row in allergies_result]
    except Exception as e:
        db.rollback()
        print(f"Alerji çekilirken hata: {e}")
        user_bad_ingredients = []

    routine_list = []
    for row in products:
        product_ingredients = str(row.ingredients_text).lower()
        
        is_safe = all(bad_ing not in product_ingredients for bad_ing in user_bad_ingredients)
        
        routine_list.append({
            "id": row.id,
            "routine_type": row.routine_type,
            "product_name": row.product_name,
            "ingredients_text": row.ingredients_text,
            "is_favorite": row.is_favorite,
            "analysis_date": str(row.analysis_date),
            "status": "Güvenli" if is_safe else "Dikkat",
            "color": "green" if is_safe else "orange"
        })
        
    return routine_list

# --- GEÇMİŞ ÜRÜNLER ---
@router.get("/{user_id}/past-products")
def get_past_products(user_id: int, db: Session = Depends(get_db)):
    query = text("""
        SELECT id, routine_type, product_name, ingredients_text, is_favorite, analysis_date
        FROM user_products 
        WHERE user_id = :u_id
        ORDER BY analysis_date DESC
    """)
    result = db.execute(query, {"u_id": user_id}).fetchall()
    return [
        {
            "id": row.id,
            "routine_type": row.routine_type,
            "product_name": row.product_name,
            "ingredients_text": row.ingredients_text,
            "is_favorite": row.is_favorite,
            "analysis_date": str(row.analysis_date)
        }
        for row in result
    ]