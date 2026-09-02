

import pandas as pd 
import geopandas as gpd
import folium
from shapely.geometry import LineString, MultiLineString
from pathlib import Path

# --- Parámetros ---
umbral_distancia = 15       # metros
umbral_parada = 0           # km/h -> considera detenido si va <= 0 km/h
min_gap_segundos = 180      # segundos mínimos entre paradas distintas
min_duracion_segundos = 5   # segundos mínimos detenido para contar como parada

# --- Rutas del proyecto ---
BASE_DIR = Path(__file__).resolve().parents[1]

AUX_DIR = BASE_DIR / "datos_auxiliares"
JALTEST_DIR = BASE_DIR / "datos_entrada" / "jaltest"
RESULTADOS_DIR = BASE_DIR / "resultados" / "analisis_ruta"

RESULTADOS_DIR.mkdir(parents=True, exist_ok=True)

# --- Archivos ---
ruta_teorica_file = AUX_DIR / "linea11.geojson"
stops_file = AUX_DIR / "stops.csv"
vel_tramos_file = AUX_DIR / "velocidades_tramos.csv"

jaltest_files = sorted(
    f for f in JALTEST_DIR.glob("jaltest_sample_*.xlsx")
    if "_con_altitud" not in f.stem.lower()
)

if not jaltest_files:
    raise SystemExit(
        "No se encontraron archivos Jaltest en datos_entrada/jaltest/. "
        "Los datos originales no se distribuyen con el repositorio."
    )

# --- Función auxiliar: contar eventos de parada ---
def contar_eventos_parada(velocidades, tiempos, umbral_vel, min_gap_s, min_duracion_s=5):
    df_tmp = pd.DataFrame({"v": velocidades, "t": tiempos}).sort_values("t")
    parado_mask = df_tmp["v"] <= umbral_vel

    num = 0
    parada_activa = False
    inicio_parada = None
    ultima_parada_time = None

    for actual, t_actual in zip(parado_mask, df_tmp["t"]):
        if actual and not parada_activa:
            inicio_parada = t_actual
            parada_activa = True
        elif not actual and parada_activa:
            duracion = (t_actual - inicio_parada).total_seconds()
            if duracion >= min_duracion_s:
                if (ultima_parada_time is None) or ((inicio_parada - ultima_parada_time).total_seconds() >= min_gap_s):
                    num += 1
                    ultima_parada_time = inicio_parada
            parada_activa = False

    # Caso: si termina aún parado
    if parada_activa:
        duracion = (df_tmp["t"].iloc[-1] - inicio_parada).total_seconds()
        if duracion >= min_duracion_s:
            if (ultima_parada_time is None) or ((inicio_parada - ultima_parada_time).total_seconds() >= min_gap_s):
                num += 1

    return num, num > 0

# --- Colores según velocidad (invertidos: verde = lento, rojo = rápido) ---
def get_speed_color(speed):
    if speed <= 10: return "green"
    elif speed <= 20: return "yellow"
    elif speed <= 40: return "orange"
    else: return "red"

# --- Cargar ruta teórica ---
linea_gdf = gpd.read_file(ruta_teorica_file)
if linea_gdf.crs is None:
    linea_gdf.set_crs(epsg=4326, inplace=True)
linea_gdf = linea_gdf.to_crs(epsg=4326)
linea_gdf_m = linea_gdf.to_crs(epsg=25830)

# --- Cargar paradas ---
stops_df = pd.read_csv(stops_file, sep=';')
stops_gdf = gpd.GeoDataFrame(
    stops_df,
    geometry=gpd.points_from_xy(stops_df.lon, stops_df.lat),
    crs="EPSG:4326"
)
stops_gdf_m = stops_gdf.to_crs(epsg=25830)

# --- Cargar límites de velocidad por tramo ---
tramos_vel_df = pd.read_csv(vel_tramos_file, sep=';')

tramos_vel_gdf = gpd.GeoDataFrame(
    tramos_vel_df.copy(),
    geometry=[
        LineString([
            (row["lon1"], row["lat1"]),
            (row["lon2"], row["lat2"])
        ])
        for _, row in tramos_vel_df.iterrows()
    ],
    crs="EPSG:4326"
)

tramos_vel_gdf_m = tramos_vel_gdf.to_crs(epsg=25830)

# --- Mapa base ---
m = folium.Map(location=[stops_df.lat.mean(), stops_df.lon.mean()], zoom_start=13)

# --- Capa de ruta teórica (gris) ---
fg_teorica = folium.FeatureGroup(name="Ruta Teórica", show=True)
for geom in linea_gdf.geometry:
    if isinstance(geom, LineString):
        coords = [[lat, lon] for lon, lat in geom.coords]
        folium.PolyLine(coords, color="gray", weight=3, opacity=0.6, tooltip="Ruta teórica").add_to(fg_teorica)
    elif isinstance(geom, MultiLineString):
        for part in geom.geoms:
            coords = [[lat, lon] for lon, lat in part.coords]
            folium.PolyLine(coords, color="gray", weight=3, opacity=0.6, tooltip="Ruta teórica").add_to(fg_teorica)
m.add_child(fg_teorica)

# --- Procesar cada día (archivo) ---
for file in jaltest_files:
    dia_nombre = file.stem.replace("jaltest_sample_", "")
    try:
        real_df = pd.read_excel(file, usecols=['lat', 'lon', 'speed', 'date'])
    except Exception as e:
        print(f"Error leyendo {file}: {e}")
        continue

    real_df['date'] = pd.to_datetime(real_df['date'])
    real_df = real_df.sort_values('date').reset_index(drop=True)

    # --- suavizar velocidad ---
    real_df['speed_suav'] = real_df['speed'].rolling(window=3, center=True, min_periods=1).mean()

    # --- Re-muestreo cada 4 segundos ---
    real_df = real_df[~real_df['date'].duplicated()].copy()
    real_df.set_index('date', inplace=True)
    real_df = real_df.resample('4s').interpolate()
    real_df['lat'] = real_df['lat'].ffill().bfill()
    real_df['lon'] = real_df['lon'].ffill().bfill()
    real_df['speed'] = real_df['speed'].ffill().bfill()
    real_df['speed_suav'] = real_df['speed_suav'].ffill().bfill()
    real_df.reset_index(inplace=True)

    real_gdf = gpd.GeoDataFrame(real_df, geometry=gpd.points_from_xy(real_df.lon, real_df.lat), crs="EPSG:4326")
    real_gdf_m = real_gdf.to_crs(epsg=25830)

    fg_day = folium.FeatureGroup(name=dia_nombre, show=False)
    excesos_rows = []
    
    # --- Dibujar tramos de la ruta real con color por velocidad ---
    coords = list(zip(real_df['lat'], real_df['lon'], real_df['speed_suav'], real_df['date']))
    for i in range(1, len(coords)):
        lat1, lon1, v1, t1 = coords[i-1]
        lat2, lon2, v2, t2 = coords[i]
        v = (v1 + v2) / 2
        color = get_speed_color(v)
        info = f"Velocidad: {v:.1f} km/h<br>{t1.strftime('%H:%M:%S')} - {t2.strftime('%H:%M:%S')}"
        folium.PolyLine(
            [(lat1, lon1), (lat2, lon2)],
            color=color, weight=5, opacity=0.9,
            tooltip=info,
            popup=info
        ).add_to(fg_day)

    # --- Paradas ---
    parada_status = []
    for idx, stop in stops_gdf.iterrows():
        stop_m = stops_gdf_m.geometry.iloc[idx]
        distancias = real_gdf_m.distance(stop_m)
        cerca_mask = distancias <= umbral_distancia

        num_paradas, ha_parado = 0, False
        if cerca_mask.any():
            velocidades_cerca = real_df.loc[cerca_mask, 'speed_suav']
            tiempos_cerca = real_df.loc[cerca_mask, 'date']
            num_paradas, ha_parado = contar_eventos_parada(
                velocidades_cerca, tiempos_cerca,
                umbral_parada, min_gap_segundos,
                min_duracion_segundos
            )

        if ha_parado:
            icon_color, status = "green", "Paró"
        elif cerca_mask.any():
            icon_color, status = "orange", "Pasó sin parar"
        else:
            icon_color, status = "red", "No pasó"

        parada_status.append({
            "stop_id": stop.stop_id,
            "stop_name": stop.stop_name,
            "status": status,
            "veces_paro": num_paradas
        })

        folium.Marker(
            location=[stop.lat, stop.lon],
            tooltip=stop.stop_name,
            popup=f"{stop.stop_name} - {status} ({num_paradas} veces)",
            icon=folium.Icon(color=icon_color, icon="bus", prefix='fa')
        ).add_to(fg_day)

    pd.DataFrame(parada_status).to_excel(
        RESULTADOS_DIR / f"paradas_estado_{dia_nombre}.xlsx",
        index=False
    )

    # --- Desvíos del día ---
    desvios_rows = []
    for i, p_m in enumerate(real_gdf_m.geometry):
        dist_ruta = linea_gdf_m.distance(p_m).min()
        if dist_ruta > umbral_distancia:
            p = real_gdf.geometry.iloc[i]
            desvios_rows.append({"lat": p.y, "lon": p.x, "distancia_m": float(dist_ruta)})
            folium.CircleMarker(
                location=[p.y, p.x],
                radius=4,
                color="purple",
                fill=True,
                fill_opacity=0.8,
                tooltip=f"Desvío: {dist_ruta:.1f} m",
                popup=f"Desvío: {dist_ruta:.1f} m"
            ).add_to(fg_day)

    pd.DataFrame(desvios_rows).to_excel(
        RESULTADOS_DIR / f"desvios_{dia_nombre}.xlsx",
        index=False
    )
    m.add_child(fg_day)

    # --- Capas por HORA ---
    for hora, df_hora in real_df.groupby(real_df['date'].dt.hour):
        df_hora = df_hora.sort_values('date')
        gdf_hora = gpd.GeoDataFrame(df_hora, geometry=gpd.points_from_xy(df_hora.lon, df_hora.lat), crs="EPSG:4326")
        gdf_hora_m = gdf_hora.to_crs(epsg=25830)

        fg_hora = folium.FeatureGroup(name=f"{dia_nombre} - {hora:02d}:00", show=False)

        coords_h = list(zip(df_hora['lat'], df_hora['lon'], df_hora['speed_suav'], df_hora['date']))
        for i in range(1, len(coords_h)):
            lat1, lon1, v1, t1 = coords_h[i-1]
            lat2, lon2, v2, t2 = coords_h[i]
            v = (v1 + v2) / 2

            # --- Comprobar exceso de velocidad según tramo ---
            vel_max = 50  # por defecto

            # Punto real del autobús en coordenadas métricas
            p_m = gdf_hora_m.geometry.iloc[i - 1]

            # Buscar el tramo vial más cercano utilizando toda su geometría
            distancias_tramos = tramos_vel_gdf_m.distance(p_m)

            if not distancias_tramos.empty:
                nearest_idx = distancias_tramos.idxmin()
                vel_max = tramos_vel_gdf_m.loc[nearest_idx, "vel_max"]

            # --- Color según si se marca exceso de velocidad ---
            exceso = v > vel_max
            if exceso:
                color = "blue"  # exceso de velocidad
                info = f'<i class="fa fa-exclamation-triangle" style="color:red"></i> Velocidad: {v:.1f} km/h (Límite: {vel_max} km/h)<br>{t1.strftime("%H:%M:%S")} - {t2.strftime("%H:%M:%S")}'
            else:
                color = get_speed_color(v)
                info = f"Velocidad: {v:.1f} km/h (Límite: {vel_max} km/h)<br>{t1.strftime('%H:%M:%S')} - {t2.strftime('%H:%M:%S')}"

            # --- Registrar exceso de velocidad ---
            if v > vel_max:
                excesos_rows.append({
                    "hora": t1,
                    "lat": lat1,
                    "lon": lon1,
                    "velocidad": v,
                    "limite": vel_max
                })

            folium.PolyLine(
                [(lat1, lon1), (lat2, lon2)],
                color=color, weight=4, opacity=0.85,
                tooltip=info,
                popup=info
            ).add_to(fg_hora)

        # --- Paradas ---
        for idx, stop in stops_gdf.iterrows():
            stop_m = stops_gdf_m.geometry.iloc[idx]
            distancias_h = gdf_hora_m.distance(stop_m)
            cerca_mask_h = distancias_h <= umbral_distancia

            num_paradas_h, ha_parado_h = 0, False
            if cerca_mask_h.any():
                v_cerca_h = df_hora.loc[cerca_mask_h, 'speed_suav']
                t_cerca_h = df_hora.loc[cerca_mask_h, 'date']
                num_paradas_h, ha_parado_h = contar_eventos_parada(
                    v_cerca_h, t_cerca_h,
                    umbral_parada, min_gap_segundos,
                    min_duracion_segundos
                )

            if ha_parado_h:
                icon_color = "green"; status_txt = "Paró"
            elif cerca_mask_h.any():
                icon_color = "orange"; status_txt = "Pasó sin parar"
            else:
                icon_color = "red"; status_txt = "No pasó"

            folium.Marker(
                location=[stop.lat, stop.lon],
                tooltip=stop.stop_name,
                popup=f"{stop.stop_name} - {status_txt} ({num_paradas_h} veces)",
                icon=folium.Icon(color=icon_color, icon="bus", prefix='fa')
            ).add_to(fg_hora)

        # --- Desvíos ---
        for i, p_m in enumerate(gdf_hora_m.geometry):
            dist_ruta_h = linea_gdf_m.distance(p_m).min()
            if dist_ruta_h > umbral_distancia:
                p = gdf_hora.geometry.iloc[i]
                folium.CircleMarker(
                    location=[p.y, p.x],
                    radius=4,
                    color="purple",
                    fill=True,
                    fill_opacity=0.8,
                    tooltip=f"Desvío: {dist_ruta_h:.1f} m",
                    popup=f"Desvío: {dist_ruta_h:.1f} m"
                ).add_to(fg_hora)

        m.add_child(fg_hora)

    # --- Guardar Excel de excesos de velocidad del día ---
    if excesos_rows:
        df_excesos = pd.DataFrame(excesos_rows)
        df_excesos.to_excel(
            RESULTADOS_DIR / f"excesos_velocidad_{dia_nombre}.xlsx",
            index=False
        )

# --- Leyenda personalizada (dividida en dos para que quepa) ---
legend_html1 = """
<div style="position: fixed; bottom: 50px; left: 50px; width: 230px; height: 150px; border:2px solid grey; z-index:9999; font-size:14px; background-color:white; opacity:0.9; padding: 10px; overflow:auto;">
<b>Leyenda Velocidad</b><br>
<div style="display:flex; align-items:center;"><div style="width:30px; border-top:4px solid green; margin-right:6px;"></div>0-10 km/h</div>
<div style="display:flex; align-items:center;"><div style="width:30px; border-top:4px solid yellow; margin-right:6px;"></div>11-20 km/h</div>
<div style="display:flex; align-items:center;"><div style="width:30px; border-top:4px solid orange; margin-right:6px;"></div>21-40 km/h</div>
<div style="display:flex; align-items:center;"><div style="width:30px; border-top:4px solid red; margin-right:6px;"></div>>40 km/h</div>
<div style="display:flex; align-items:center;"><div style="width:30px; border-top:4px solid blue; margin-right:6px;"></div>Exceso de velocidad</div>
</div>
"""

legend_html2 = """
<div style="position: fixed; bottom: 50px; left: 300px; width: 180px; height: 150px; border:2px solid grey; z-index:9999; font-size:14px; background-color:white; opacity:0.9; padding: 10px; overflow:auto;">
<b>Leyenda Paradas</b><br>
<i class="fa fa-map-marker" style="color:green; font-size:24px;"></i> Paró<br>
<i class="fa fa-map-marker" style="color:orange; font-size:24px;"></i> Pasó sin parar<br>
<i class="fa fa-map-marker" style="color:red; font-size:24px;"></i> No pasó<br>
<i class="fa fa-circle" style="color:purple; font-size:20px;"></i> Desvío
</div>
"""


m.get_root().html.add_child(folium.Element(legend_html1))
m.get_root().html.add_child(folium.Element(legend_html2))

# --- Control de capas y guardado ---
folium.LayerControl().add_to(m)

mapa_salida = RESULTADOS_DIR / "analisis_paradas_linea11.html"

m.save(str(mapa_salida))
print(f"Mapa generado: {mapa_salida}")