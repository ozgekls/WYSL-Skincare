from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import text
from database import get_db
from pydantic import BaseModel as PydanticBase
from thefuzz import process, fuzz
from typing import Optional

router = APIRouter(prefix="/products", tags=["products"])

# Cilt tipine göre kaçınılması gereken içerikler (kural tabanlı)
SKIN_TYPE_AVOID = {
    "yağlı": [
        "coconut oil", "cocoa butter", "isopropyl myristate", "algae extract",
        "wheat germ", "linseed oil", "flaxseed oil", "acetylated lanolin",
        "lauric acid", "myristic acid", "palm oil",
    ],
    "kuru": [
        "alcohol denat", "sd alcohol", "isopropyl alcohol", "denatured alcohol",
        "witch hazel", "menthol", "camphor",
    ],
    "hassas": [
        "methylisothiazolinone", "benzalkonium chloride", "formaldehyde",
        "dmdm hydantoin", "imidazolidinyl urea", "quaternium-15",
        "sodium lauryl sulfate", "sls", "ammonium lauryl sulfate",
    ],
    "karma": [
        "heavy mineral oil", "petrolatum", "acetylated lanolin alcohol",
    ],
    "normal": [],
    "oily": [
        "coconut oil", "cocoa butter", "isopropyl myristate", "algae extract",
        "wheat germ", "linseed oil", "acetylated lanolin",
        "lauric acid", "myristic acid", "palm oil",
    ],
    "dry": [
        "alcohol denat", "sd alcohol", "isopropyl alcohol", "denatured alcohol",
        "witch hazel", "menthol",
    ],
    "sensitive": [
        "methylisothiazolinone", "benzalkonium chloride", "formaldehyde",
        "dmdm hydantoin", "sodium lauryl sulfate", "sls",
    ],
    "combination": [
        "heavy mineral oil", "petrolatum", "acetylated lanolin alcohol",
    ],
}

# Cilt tipine göre dinamik comedogenic/irritation eşiği
SKIN_TYPE_THRESHOLDS = {
    "yağlı":  {"comedogenic": 2, "irritation": 3},
    "kuru":   {"comedogenic": 4, "irritation": 2},
    "hassas": {"comedogenic": 3, "irritation": 2},
    "karma":  {"comedogenic": 3, "irritation": 3},
    "normal": {"comedogenic": 4, "irritation": 4},
    "oily":   {"comedogenic": 2, "irritation": 3},
    "dry":    {"comedogenic": 4, "irritation": 2},
    "sensitive": {"comedogenic": 3, "irritation": 2},
    "combination": {"comedogenic": 3, "irritation": 3},
}

DEFAULT_THRESHOLD = {"comedogenic": 4, "irritation": 4}

SKIN_TYPE_LABELS = {
    "yağlı": "Yağlı",
    "kuru": "Kuru",
    "hassas": "Hassas",
    "karma": "Karma",
    "normal": "Normal",
    "oily": "Yağlı",
    "dry": "Kuru",
    "sensitive": "Hassas",
    "combination": "Karma",
}


def get_user_skin_type(user_id: int, db: Session) -> str:
    """Kullanıcının cilt tipini veritabanından çeker."""
    try:
        result = db.execute(
            text("SELECT skin_type FROM users WHERE user_id = :uid"),
            {"uid": user_id}
        ).fetchone()
        if result and result.skin_type:
            return result.skin_type.lower().strip()
    except Exception:
        pass
    return "normal"


def check_skin_type_rule(ing_name_lower: str, skin_type: str) -> Optional[str]:
    """Kural tabanlı cilt tipi kontrolü."""
    avoid_list = SKIN_TYPE_AVOID.get(skin_type, [])
    for avoid_term in avoid_list:
        if avoid_term in ing_name_lower:
            label = SKIN_TYPE_LABELS.get(skin_type, skin_type.capitalize())
            return f"{label} ciltler için kaçınılması önerilir ({avoid_term})"
    return None


def check_root_keywords(raw_lower: str) -> Optional[dict]:
    """Bilinen zararlı içerik gruplarını kök kelime ile kontrol eder."""
    if "paraben" in raw_lower:
        return {
            "status": "danger",
            "reason": "Paraben grubu koruyucu - hormonal etki riski",
            "comedogenic_score": None,
            "irritation_score": None,
        }
    if "sulfate" in raw_lower or "sülfat" in raw_lower or "sls" in raw_lower:
        return {
            "status": "warning",
            "reason": "Sert sürfaktan - cilt bariyerini bozabilir",
            "comedogenic_score": None,
            "irritation_score": None,
        }
    if "siloxane" in raw_lower or "methicone" in raw_lower:
        return {
            "status": "safe",
            "reason": "Silikon türevi - gözenek tıkayabilir",
            "comedogenic_score": None,
            "irritation_score": None,
        }
    if "fragrance" in raw_lower or "parfum" in raw_lower or "parfüm" in raw_lower:
        return {
            "status": "warning",
            "reason": "Koku verici - alerjen potansiyeli taşır",
            "comedogenic_score": None,
            "irritation_score": None,
        }
    if "alcohol denat" in raw_lower or "sd alcohol" in raw_lower or "denatured alcohol" in raw_lower:
        return {
            "status": "warning",
            "reason": "Kurutucu alkol - kuru/hassas ciltler için önerilmez",
            "comedogenic_score": None,
            "irritation_score": None,
        }
    if "formaldehyde" in raw_lower or "dmdm hydantoin" in raw_lower or "imidazolidinyl urea" in raw_lower:
        return {
            "status": "danger",
            "reason": "Formaldehit salıcı koruyucu - tahrişe neden olabilir",
            "comedogenic_score": None,
            "irritation_score": None,
        }
    if "methylisothiazolinone" in raw_lower or "methylchloroisothiazolinone" in raw_lower:
        return {
            "status": "danger",
            "reason": "Güçlü alerjen koruyucu",
            "comedogenic_score": None,
            "irritation_score": None,
        }
    return None


@router.get("/")
def get_all_products(db: Session = Depends(get_db)):
    query = text("SELECT product_id, brand_name, product_name, category FROM products")
    result = db.execute(query).fetchall()
    return [
        {
            "product_id": row[0],
            "brand_name": row[1],
            "product_name": row[2],
            "category": row[3],
        }
        for row in result
    ]


@router.get("/analyze/{user_id}/{product_id}")
def analyze_product(user_id: int, product_id: int, db: Session = Depends(get_db)):
    query = text("SELECT * FROM sp_analyze_product(:u_id, :p_id)")
    result = db.execute(query, {"u_id": user_id, "p_id": product_id}).fetchall()
    if not result:
        raise HTTPException(status_code=404, detail="Ürün veya kullanıcı bulunamadı")
    return [
        {
            "ingredient_name": row.ingredient_name,
            "status": row.status,
            "reason": row.reason,
            "comedogenic": row.comedogenic_score,
            "irritation": row.irritation_score,
        }
        for row in result
    ]


class IngredientTextAnalysis(PydanticBase):
    user_id: int
    ingredients_text: str


@router.post("/analyze-text")
def analyze_ingredients_text(data: IngredientTextAnalysis, db: Session = Depends(get_db)):
    # Kullanıcının cilt tipini çek
    skin_type = get_user_skin_type(data.user_id, db)
    threshold = SKIN_TYPE_THRESHOLDS.get(skin_type, DEFAULT_THRESHOLD)
    comedogenic_limit = threshold["comedogenic"]
    irritation_limit = threshold["irritation"]

    # Veritabanındaki tüm ingredient isimlerini çek (fuzzy matching için)
    all_ingredients_query = text("SELECT ingredient_name FROM ingredients")
    all_db_ingredients = db.execute(all_ingredients_query).fetchall()
    db_names = [row[0] for row in all_db_ingredients]

    # İçerikleri böl
    text_clean = data.ingredients_text.strip()
    raw_ingredients = []

    if text_clean.count(",") < 2 and len(text_clean) > 30:
        text_lower = text_clean.lower()
        sorted_db_names = sorted(db_names, key=len, reverse=True)
        for db_name in sorted_db_names:
            db_name_lower = db_name.lower()
            if db_name_lower in text_lower:
                raw_ingredients.append(db_name)
                text_lower = text_lower.replace(db_name_lower, " | ")
        leftovers = [w.strip() for w in text_lower.split("|") if len(w.strip()) > 3]
        raw_ingredients.extend(leftovers)
    else:
        raw_ingredients = [i.strip() for i in text_clean.split(",") if i.strip()]

    # user_ingredient_feedback ile zenginleştirilmiş SQL sorgusu
    # v_user_safe_ingredients mantığını inline olarak uyguluyoruz:
    #   - user_allergies → is_allergen
    #   - feedback reaction_type='negative' AND severity >= 3 → has_severe_reaction
    db_query = text("""
        SELECT 
            i.ingredient_id,
            i.ingredient_name,
            i.comodogenic_score,
            i.irritation_score,

            -- Alerji kaydı var mı?
            CASE WHEN ua.ingredient_id IS NOT NULL THEN TRUE ELSE FALSE END AS is_allergen,

            -- Daha önce şiddetli negatif reaksiyon yaşandı mı? (severity >= 3)
            CASE WHEN neg.ingredient_id IS NOT NULL THEN TRUE ELSE FALSE END AS has_severe_reaction,

            -- Durum: alerji > şiddetli reaksiyon > skor eşiği > güvenli
            CASE 
                WHEN ua.ingredient_id IS NOT NULL THEN 'danger'
                WHEN neg.ingredient_id IS NOT NULL THEN 'danger'
                WHEN i.comodogenic_score >= :comedogenic_limit 
                     OR i.irritation_score >= :irritation_limit THEN 'warning'
                ELSE 'safe'
            END AS status,

            -- Açıklama
            CASE 
                WHEN ua.ingredient_id IS NOT NULL THEN 'Alerji listenizde kayıtlı!'
                WHEN neg.ingredient_id IS NOT NULL THEN 
                    'Bu içeriğe daha önce şiddetli reaksiyon verdiniz (geçmiş verilerinizden)'
                WHEN i.comodogenic_score >= :comedogenic_limit THEN 
                    'Comedogenic skoru yüksek (' || i.comodogenic_score || '/5) - Cilt tipiniz için eşik: ' || :comedogenic_limit
                WHEN i.irritation_score >= :irritation_limit THEN 
                    'Irritasyon riski (' || i.irritation_score || '/5) - Cilt tipiniz için eşik: ' || :irritation_limit
                ELSE 'Güvenli görünüyor'
            END AS reason

        FROM ingredients i

        -- Alerji kontrolü
        LEFT JOIN user_allergies ua 
            ON ua.ingredient_id = i.ingredient_id 
            AND ua.user_id = :u_id

        -- Şiddetli negatif reaksiyon kontrolü (v_user_safe_ingredients mantığı)
        LEFT JOIN (
            SELECT DISTINCT ingredient_id
            FROM user_ingredient_feedback
            WHERE user_id = :u_id
              AND reaction_type = 'negative'
              AND severity >= 3
        ) neg ON neg.ingredient_id = i.ingredient_id

        WHERE LOWER(i.ingredient_name) LIKE :ing_name
        LIMIT 1
    """)

    results = []

    for ing_name in raw_ingredients:
        raw_lower = ing_name.lower()

        # 1. Veritabanında ara (kişiselleştirilmiş SQL)
        result = db.execute(db_query, {
            "u_id": data.user_id,
            "ing_name": f"%{raw_lower}%",
            "comedogenic_limit": comedogenic_limit,
            "irritation_limit": irritation_limit,
        }).fetchone()

        if result:
            status = result.status
            reason = result.reason

            # Cilt tipi kural tabanlı kontrolü (eğer veritabanı 'safe' verdiyse ama cilt tipi kuralı 'tehlikeli' diyorsa eziyoruz)
            rule_reason = check_skin_type_rule(raw_lower, skin_type)
            if rule_reason and status == "safe":
                status = "warning"
                reason = rule_reason

            results.append({
                "ingredient_name": result.ingredient_name,
                "status": status,
                "reason": reason,
                "comedogenic_score": result.comodogenic_score,
                "irritation_score": result.irritation_score,
                "found_in_db": True,
                "has_severe_reaction": bool(result.has_severe_reaction),
                "is_allergen": bool(result.is_allergen),
            })
            continue

        # 2. Fuzzy matching (Yazım Hatası Kontrolü)
        match_found = False
        if db_names:
            best_match_name, score = process.extractOne(
                raw_lower, db_names, scorer=fuzz.token_sort_ratio
            )
            if score >= 90:
                fuzzy_result = db.execute(db_query, {
                    "u_id": data.user_id,
                    "ing_name": f"%{best_match_name.lower()}%",
                    "comedogenic_limit": comedogenic_limit,
                    "irritation_limit": irritation_limit,
                }).fetchone()

                if fuzzy_result:
                    status = fuzzy_result.status
                    reason = fuzzy_result.reason + f" (Sistem bunu algıladı: {best_match_name})"

                    rule_reason = check_skin_type_rule(raw_lower, skin_type)
                    if rule_reason and status == "safe":
                        status = "warning"
                        reason = rule_reason

                    results.append({
                        "ingredient_name": ing_name,
                        "status": status,
                        "reason": reason,
                        "comedogenic_score": fuzzy_result.comodogenic_score,
                        "irritation_score": fuzzy_result.irritation_score,
                        "found_in_db": True,
                        "has_severe_reaction": bool(fuzzy_result.has_severe_reaction),
                        "is_allergen": bool(fuzzy_result.is_allergen),
                    })
                    match_found = True

        if match_found:
            continue

        # 3. Kök kelime kontrolü (Paraben, Sülfat vs.)
        root_result = check_root_keywords(raw_lower)
        if root_result:
            rule_reason = check_skin_type_rule(raw_lower, skin_type)
            if rule_reason and root_result["status"] == "safe":
                root_result["status"] = "warning"
                root_result["reason"] = rule_reason
            
            results.append({
                "ingredient_name": ing_name,
                "found_in_db": False,
                **root_result,
            })
            continue

        # 4. Kural tabanlı cilt tipi kontrolü (son şans - yukarıdakilerin hiçbirine takılmazsa)
        rule_reason = check_skin_type_rule(raw_lower, skin_type)
        if rule_reason:
            results.append({
                "ingredient_name": ing_name,
                "status": "warning",
                "reason": rule_reason,
                "comedogenic_score": None,
                "irritation_score": None,
                "found_in_db": False,
            })
            continue

        # 5. Hiçbir şey bulunamadı
        results.append({
            "ingredient_name": ing_name,
            "status": "unknown",
            "reason": "Veritabanında veya kurallarda eşleşme bulunamadı.",
            "comedogenic_score": None,
            "irritation_score": None,
            "found_in_db": False,
        })

    return results


# --- İÇERİK ÇAKIŞMA ANALİZİ ---
class ConflictCheckRequest(PydanticBase):
    ingredients_text: str  # Virgülle ayrılmış içerik listesi


@router.post("/check-conflicts")
def check_ingredient_conflicts(data: ConflictCheckRequest, db: Session = Depends(get_db)):
    """
    v_ingredient_conflict_detail view'ını kullanarak verilen içerik
    listesindeki çakışan çiftleri bulur.

    """
    try:
        # Gelen metni ingredientlara böl
        raw_list = [i.strip().lower() for i in data.ingredients_text.split(",") if i.strip()]

        if len(raw_list) < 2:
            return {"conflict_count": 0, "conflicts": []}

        # Veritabanındaki ingredient isimlerini çek
        db_names_result = db.execute(
            text("SELECT ingredient_id, ingredient_name FROM ingredients")
        ).fetchall()
        db_map = {row.ingredient_name.lower(): row.ingredient_id for row in db_names_result}

        # Gelen listedeki ingredientları DB'deki ID'lerle eşleştir
        matched_ids = []
        for raw in raw_list:
            # Tam eşleşme
            if raw in db_map:
                matched_ids.append(db_map[raw])
                continue
            # Kısmi eşleşme (LIKE mantığı)
            for db_name, db_id in db_map.items():
                if raw in db_name or db_name in raw:
                    matched_ids.append(db_id)
                    break

        if len(matched_ids) < 2:
            return {"conflict_count": 0, "conflicts": []}

        # v_ingredient_conflict_detail view'ından çakışmaları çek
        query = text("""
            SELECT
                ingredient_a_name,
                ingredient_b_name,
                conflict_description,
                severity
            FROM v_ingredient_conflict_detail
            WHERE ingredient_a_id = ANY(:ids)
              AND ingredient_b_id = ANY(:ids)
            ORDER BY severity DESC
        """)

        conflicts_result = db.execute(query, {"ids": matched_ids}).fetchall()

        conflicts = [
            {
                "ingredient_a": row.ingredient_a_name,
                "ingredient_b": row.ingredient_b_name,
                "description": row.conflict_description,
                "severity": row.severity,
                "severity_label": (
                    "Yüksek" if row.severity >= 4
                    else "Orta" if row.severity >= 2
                    else "Düşük"
                ),
            }
            for row in conflicts_result
        ]

        return {
            "conflict_count": len(conflicts),
            "conflicts": conflicts,
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))