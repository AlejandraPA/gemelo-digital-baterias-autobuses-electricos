
import pandas as pd
import requests
import time
from pathlib import Path

# Carpeta donde están los archivos
BASE_DIR = Path(__file__).resolve().parents[1]
folder = BASE_DIR / "datos_entrada" / "jaltest"

# Buscar únicamente los archivos Jaltest originales
files = sorted(
    f for f in folder.glob("jaltest_sample_*.xlsx")
    if "_con_altitud" not in f.stem.lower()
)

if not files:
    raise SystemExit(
        "No se encontraron archivos jaltest_sample_*.xlsx en "
        "'datos_entrada/jaltest/'. Los datos originales no se distribuyen "
        "con la versión pública del repositorio."
    )

print(f"Archivos encontrados: {len(files)}")

# Función para obtener altitud
def obtener_altitud(lat, lon):
    url = f"https://api.open-elevation.com/api/v1/lookup?locations={lat},{lon}"
    try:
        r = requests.get(url, timeout=10)
        r.raise_for_status()
        return r.json()["results"][0]["elevation"]
    except Exception as e:
        print(f"⚠️ Error con {lat}, {lon}: {e}")
        return None

# Procesar cada archivo
for file in files:
    print(f"Procesando {file}...")
    df = pd.read_excel(file)
    
    if not {"lat", "lon"}.issubset(df.columns):
        print(f"❌ El archivo {file} no tiene columnas 'lat' y 'lon'. Se salta.")
        continue

    altitudes = []
    for i, row in df.iterrows():
        alt = obtener_altitud(row["lat"], row["lon"])
        altitudes.append(alt)
        if i % 20 == 0:
            print(f"{i}/{len(df)} puntos procesados en {file}...")
            time.sleep(1)  # Pausa para no saturar la API

    df["altitude"] = altitudes

    output_file = file.with_name(file.stem + "_con_altitud.xlsx")
    df.to_excel(output_file, index=False)
    print(f"✅ Guardado: {output_file}\n")
