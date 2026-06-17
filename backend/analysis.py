from thefuzz import process, fuzz

def smart_analyze_ingredient(raw_ingredient: str, db_ingredients: list) -> dict:
    raw_lower = raw_ingredient.lower().strip()

    # 1. BİREBİR EŞLEŞME
    for db_item in db_ingredients:
        # db_item bir dictionary olarak gelmeli (SQLAlchemy modeliyse uyarlaman gerekebilir)
        if db_item["name"].lower() == raw_lower:
            return {
                "ingredient_name": raw_ingredient,
                "status": db_item["status"],
                "reason": db_item["reason"],
                "comedogenic_score": db_item.get("comedogenic_score"),
                "irritation_score": db_item.get("irritation_score")
            }

    # 2. KÖK KELİME KONTROLÜ
    if "paraben" in raw_lower:
        return {"ingredient_name": raw_ingredient, "status": "danger", "reason": "Paraben grubu koruyucu (Sistem Tespiti)"}
    if "sulfate" in raw_lower or "sülfat" in raw_lower:
        return {"ingredient_name": raw_ingredient, "status": "warning", "reason": "Sert sürfaktan/temizleyici (Sistem Tespiti)"}
    if "siloxane" in raw_lower or "methicone" in raw_lower:
        return {"ingredient_name": raw_ingredient, "status": "safe", "reason": "Silikon türevi (Sistem Tespiti)"}
    if "fragrance" in raw_lower or "parfum" in raw_lower or "parfüm" in raw_lower:
         return {"ingredient_name": raw_ingredient, "status": "warning", "reason": "Koku verici/Alerjen potansiyeli (Sistem Tespiti)"}

    # 3. FUZZY MATCHING (Yazım hatalarını toleranse eden kısım)
    db_names = [item["name"] for item in db_ingredients]
    
    if db_names: # Veritabanı boş değilse
        best_match_name, score = process.extractOne(raw_lower, db_names, scorer=fuzz.token_sort_ratio)

        if score >= 82: # %82 ve üzeri benzerliği kabul ediyoruz
            matched_db_item = next(item for item in db_ingredients if item["name"] == best_match_name)
            return {
                "ingredient_name": raw_ingredient,
                "status": matched_db_item["status"],
                "reason": matched_db_item["reason"] + f" (Buna benzetildi: {best_match_name})",
                "comedogenic_score": matched_db_item.get("comedogenic_score"),
                "irritation_score": matched_db_item.get("irritation_score")
            }

    # 4. HİÇBİR ŞEY BULUNAMADIYSA
    return {
        "ingredient_name": raw_ingredient,
        "status": "unknown",
        "reason": "Veritabanında bulunamadı"
    }