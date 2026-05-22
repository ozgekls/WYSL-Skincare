from pydantic import BaseModel
from typing import List, Optional

class IngredientAnalysis(BaseModel):
    ingredient_name: str
    status: str
    reason: str
    comedogenic_score: int
    irritation_score: int

class ProductRecommendation(BaseModel):
    product_name: str
    brand_name: str
    compatibility_score: int
    label: str
    note: str