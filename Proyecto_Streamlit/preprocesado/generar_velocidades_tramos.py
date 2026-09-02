
import osmnx as ox
import geopandas as gpd
import pandas as pd
from shapely.geometry import LineString, MultiLineString
from pathlib import Path

# --- Archivos ---
BASE_DIR = Path(__file__).resolve().parents[1]
AUX_DIR = BASE_DIR / "datos_auxiliares"

ruta_teorica_file = AUX_DIR / "linea11.geojson"
salida_csv = AUX_DIR / "velocidades_tramos.csv"

# --- Cargar tu ruta ---
linea_gdf = gpd.read_file(ruta_teorica_file)
linea_gdf = linea_gdf.to_crs(epsg=4326)

# --- Hacer buffer de 50 metros alrededor de la línea ---
# Proyectar a ETRS89 / UTM zona 30N para trabajar en metros
linea_m = linea_gdf.to_crs(epsg=25830)
buffer = linea_m.buffer(50)  # 50 m a cada lado
buffer = buffer.to_crs(epsg=4326)

# --- Descargar red vial SOLO dentro del buffer ---
# ox.graph_from_polygon hace la consulta a Overpass
G = ox.graph_from_polygon(buffer.union_all(), network_type="drive")

# Pasar a GeoDataFrame
edges = ox.graph_to_gdfs(G, nodes=False, edges=True)

# --- Preparar filas para CSV ---
rows = []
id_tramo = 1
for _, row in edges.iterrows():
    geom = row.geometry
    maxspeed = row.get("maxspeed", None)

    # Si maxspeed es lista (varios valores), tomar el primero
    if isinstance(maxspeed, list):
        maxspeed = maxspeed[0]

    # Convertir a número si es posible, si no → valor por defecto
    try:
        vel = int(str(maxspeed).split()[0])
    except:
        vel = 50  # valor por defecto

    if isinstance(geom, LineString):
        coords = list(geom.coords)
        for i in range(1, len(coords)):
            lon1, lat1 = coords[i-1]
            lon2, lat2 = coords[i]
            rows.append({
                "id_tramo": id_tramo,
                "lat1": lat1, "lon1": lon1,
                "lat2": lat2, "lon2": lon2,
                "vel_max": vel
            })
            id_tramo += 1
    elif isinstance(geom, MultiLineString):
        for part in geom.geoms:
            coords = list(part.coords)
            for i in range(1, len(coords)):
                lon1, lat1 = coords[i-1]
                lon2, lat2 = coords[i]
                rows.append({
                    "id_tramo": id_tramo,
                    "lat1": lat1, "lon1": lon1,
                    "lat2": lat2, "lon2": lon2,
                    "vel_max": vel
                })
                id_tramo += 1

# --- Guardar a CSV ---
df = pd.DataFrame(rows)
df.to_csv(salida_csv, sep=";", index=False)

print(f"✅ CSV generado: {salida_csv} con {len(df)} tramos")
