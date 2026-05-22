from fastapi import FastAPI
from routers import recommendations, products, users # Diğer dosyaları buraya ekliyoruz

app = FastAPI(title="Skincare App API")

# Yazdığımız router'ları FastAPI'ye tanıtıyoruz
app.include_router(recommendations.router)
app.include_router(products.router)
app.include_router(users.router)
# Diğer routerları da (products, users vb.) hazır olduğunda buraya ekleyeceksin

@app.get("/")
def home():
    return {"message": "Skincare Backend Çalışıyor!"}