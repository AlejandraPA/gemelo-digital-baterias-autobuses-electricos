
from pathlib import Path
from datetime import datetime
import io

import folium
import geopandas as gpd
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import streamlit as st

from folium import FeatureGroup
from shapely.geometry import LineString, MultiLineString, Point
from streamlit_folium import st_folium

# --- Rutas del proyecto ---
BASE_DIR = Path(__file__).resolve().parent

AUX_DIR = BASE_DIR / "datos_auxiliares"
JALTEST_DIR = BASE_DIR / "datos_entrada" / "jaltest"
FULL_SOC_DIR = BASE_DIR / "datos_entrada" / "full_soc"

# --- Configuración de la página ---
st.set_page_config(layout="wide")

# --- Parámetros ---
umbral_distancia = 20       # metros
umbral_parada = 0           # km/h
min_gap_segundos = 180      # segundos mínimos entre paradas distintas
min_duracion_segundos = 5   # segundos mínimos detenido

# --- Funciones auxiliares ---
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
                if (ultima_parada_time is None) or (
                    (inicio_parada - ultima_parada_time).total_seconds() >= min_gap_s
                ):
                    num += 1
                    ultima_parada_time = inicio_parada
            parada_activa = False
    if parada_activa:
        duracion = (df_tmp["t"].iloc[-1] - inicio_parada).total_seconds()
        if duracion >= min_duracion_s:
            if (ultima_parada_time is None) or (
                (inicio_parada - ultima_parada_time).total_seconds() >= min_gap_s
            ):
                num += 1
    return num

def get_speed_color(speed):
    if speed <= 10: return "green"
    elif speed <= 20: return "yellow"
    elif speed <= 40: return "orange"
    else: return "red"

def get_soc_color(soc):
    try:
        soc = float(soc)
    except:
        return "gray"
    if soc >= 80: return "green"
    elif soc >= 60: return "yellowgreen"
    elif soc >= 40: return "orange"
    elif soc >= 20: return "red"
    else: return "darkred"

def get_soc_stage(soc):
    if soc >= 80: return "≥80%"
    elif soc >= 60: return "60–79%"
    elif soc >= 40: return "40–59%"
    elif soc >= 20: return "20–39%"
    else: return "<20%"

# --- Archivos ---
ruta_teorica_file = AUX_DIR / "linea11.geojson"
stops_file = AUX_DIR / "stops.csv"

jaltest_files = sorted(JALTEST_DIR.glob("jaltest_sample_*.xlsx"))
soc_files = sorted(FULL_SOC_DIR.glob("FULL_SOC_*.xlsx"))

# --- Cargar límites de velocidad ---
tramos_df = pd.read_csv(AUX_DIR / "velocidades_tramos.csv", sep=";")
tramos_gdf = gpd.GeoDataFrame(
    tramos_df,
    geometry=[LineString([(row["lon1"], row["lat1"]), (row["lon2"], row["lat2"])]) for _, row in tramos_df.iterrows()],
    crs="EPSG:4326"
)
tramos_gdf_m = tramos_gdf.to_crs(epsg=25830)

def get_speed_limit(lat, lon):
    p_m = (
        gpd.GeoSeries([Point(lon, lat)], crs="EPSG:4326")
        .to_crs(epsg=25830)
        .iloc[0]
    )
    nearest_idx = tramos_gdf_m.distance(p_m).idxmin()
    return tramos_gdf_m.loc[nearest_idx, "vel_max"]

st.sidebar.title("Controles")
modo = st.sidebar.radio("Modo de visualización", ["Velocidad", "VE"])

# Listar archivos Jaltest. Los archivos enriquecidos con altitud se asocian
# al mismo día que su archivo original.
jaltest_files = sorted(JALTEST_DIR.glob("jaltest_sample_*.xlsx"))
dias_raw = sorted({
    f.stem.replace("jaltest_sample_", "").replace("_con_altitud", "")
    for f in jaltest_files
})

# Map de meses en español a número
meses = {"ene": 1, "feb": 2, "mar": 3, "abr": 4, "may": 5, "jun": 6,
         "jul": 7, "ago": 8, "sep": 9, "oct": 10, "nov": 11, "dic": 12}

# Convertir a datetime con año ficticio 2025
dias_dt = []
for d in dias_raw:
    try:
        dia = int(d[:2])
        mes = meses[d[2:].lower()]  # toma las tres letras del mes
        dt = datetime(2025, mes, dia)
        dias_dt.append(dt)
    except:
        pass

# Validar que haya días válidos
if not dias_dt:
    st.warning(
        "No se encontraron datos de operación. "
        "Los archivos Jaltest originales no se distribuyen con el repositorio. "
        "Para ejecutar la aplicación deben colocarse en "
        "'datos_entrada/jaltest/'."
    )
    st.stop()

# Orden cronológico
dias_dt = sorted(dias_dt)

# Diccionario inverso para mostrar nombre del mes en español
meses_inv = {v: k for k, v in meses.items()}

# Selectbox: mostrar como dd/mmm en español
dia_dt = st.sidebar.selectbox(
    "Día",
    dias_dt,
    format_func=lambda d: f"{d.day:02d}/{meses_inv[d.month]}"
)

# Convertir a formato archivo (DDmmm, ej: '18ene')
dia_sel = f"{dia_dt.day:02d}{meses_inv[dia_dt.month]}"

# Slider de hora
hora_sel = st.sidebar.slider("Hora", 0, 23, 12)

# Buscar archivo correspondiente. Si existe una versión enriquecida con
# altitud, se prioriza para poder utilizar esa variable en el análisis VE.
matching_files = [f for f in jaltest_files if dia_sel.lower() in f.name.lower()]
if not matching_files:
    st.warning(f"No se encontró ningún archivo para el día seleccionado ({dia_sel}).")
    st.stop()

archivo = next(
    (f for f in matching_files if "_con_altitud" in f.stem.lower()),
    matching_files[0]
)

# --- Cargar ruta teórica ---
linea_gdf = gpd.read_file(ruta_teorica_file)
if linea_gdf.crs is None:
    linea_gdf.set_crs(epsg=4326, inplace=True)
linea_gdf = linea_gdf.to_crs(epsg=4326)
linea_gdf_m = linea_gdf.to_crs(epsg=25830)

# --- Cargar paradas ---
stops_df = pd.read_csv(stops_file, sep=";")
stops_gdf = gpd.GeoDataFrame(stops_df, geometry=gpd.points_from_xy(stops_df.lon, stops_df.lat), crs="EPSG:4326")
stops_gdf_m = stops_gdf.to_crs(epsg=25830)

# --- Cargar datos del día ---
real_df = pd.read_excel(archivo, usecols=["lat", "lon", "speed", "date"])
real_df["date"] = pd.to_datetime(real_df["date"])
real_df = real_df.sort_values("date").reset_index(drop=True)
real_df["speed_suav"] = real_df["speed"].rolling(window=3, center=True, min_periods=1).mean()
real_df = real_df[~real_df["date"].duplicated()].copy()
real_df.set_index("date", inplace=True)
real_df = real_df.resample("5s").interpolate()
real_df = real_df.ffill().bfill().reset_index()

# --- Filtrar por hora ---
df_hora = real_df[real_df["date"].dt.hour == hora_sel]
if df_hora.empty:
    st.warning("No hay datos para esta hora.")
    st.stop()
df_hora_gdf = gpd.GeoDataFrame(
    df_hora.copy(),
    geometry=gpd.points_from_xy(df_hora["lon"], df_hora["lat"]),
    crs="EPSG:4326"
)

df_hora_gdf_m = df_hora_gdf.to_crs(epsg=25830)

# --- Cargar SOC ---
soc_df = pd.DataFrame()
if modo == "VE":
    # Buscar archivo SOC exacto para el día seleccionado
    soc_file = [f for f in soc_files if dia_sel.lower() in f.name.lower()]
    if soc_file:
        soc_df = pd.read_excel(soc_file[0], usecols=["lat", "lon", "date", "SOC", "autonomia"])
        soc_df = soc_df.replace("---", pd.NA).dropna()
        soc_df["SOC"] = soc_df["SOC"].astype(float)
        soc_df["autonomia"] = soc_df["autonomia"].astype(float)
        soc_df["date"] = pd.to_datetime(soc_df["date"])
    else:
        st.info(
            "No se encontró un archivo FULL_SOC para el día seleccionado. "
            "El modo VE requiere archivos en 'datos_entrada/full_soc/'."
        )

# --- Crear mapa ---
m = folium.Map(location=[stops_df.lat.mean(), stops_df.lon.mean()], zoom_start=13, control_scale=True)

# --- Ruta teórica ---
fg_teorica = FeatureGroup(name="Ruta Teórica", show=True)
for geom in linea_gdf.geometry:
    if isinstance(geom, LineString):
        coords = [[lat, lon] for lon, lat in geom.coords]
        folium.PolyLine(coords, color="gray", weight=3, opacity=0.6).add_to(fg_teorica)
    elif isinstance(geom, MultiLineString):
        for part in geom.geoms:
            coords = [[lat, lon] for lon, lat in part.coords]
            folium.PolyLine(coords, color="gray", weight=3, opacity=0.6).add_to(fg_teorica)
m.add_child(fg_teorica)

# --- Función para obtener SOC más cercano en el tiempo ---
def get_closest_soc(df, timestamp):
    if df.empty:
        return None
    # Encuentra la fila con la fecha más cercana al timestamp
    idx = (df["date"] - timestamp).abs().idxmin()
    return df.loc[idx]

# --- Dibujar tramos reales ---
coords = list(zip(df_hora["lat"], df_hora["lon"], df_hora["speed_suav"], df_hora["date"]))
for i in range(1, len(coords)):
    lat1, lon1, v1, t1 = coords[i - 1]
    lat2, lon2, v2, t2 = coords[i]

    if modo == "Velocidad":
        v = (v1 + v2) / 2
        color = get_speed_color(v)
        vel_max = get_speed_limit(lat1, lon1)
        info = f"Velocidad: {v:.1f} km/h<br>Límite: {vel_max} km/h<br>{t1.strftime('%H:%M:%S')} - {t2.strftime('%H:%M:%S')}"
        if v > vel_max:
            color = "blue"
    else:
        # SOC: buscar los puntos más cercanos
        soc_row1 = get_closest_soc(soc_df, t1)
        soc_row2 = get_closest_soc(soc_df, t2)

        if soc_row1 is not None and soc_row2 is not None:
            soc_medio = (float(soc_row1["SOC"]) + float(soc_row2["SOC"])) / 2
            aut_medio = (float(soc_row1["autonomia"]) + float(soc_row2["autonomia"])) / 2
            color = get_soc_color(soc_medio)
            info = f"SOC: {soc_medio:.1f}%<br>Autonomía: {aut_medio:.1f} km<br>{t1.strftime('%H:%M:%S')}"
        else:
            color = "gray"
            info = t1.strftime("%H:%M:%S")

    folium.PolyLine([(lat1, lon1), (lat2, lon2)], color=color, weight=5, opacity=0.9, tooltip=info).add_to(m)

# --- Paradas ---
for idx, stop in stops_gdf.iterrows():
    stop_m = stops_gdf_m.loc[idx, "geometry"]
    distancias = df_hora_gdf_m.distance(stop_m)
    dentro = df_hora.loc[distancias <= umbral_distancia]

    if not dentro.empty:
        num_eventos = contar_eventos_parada(
            dentro["speed_suav"],
            dentro["date"],
            umbral_parada,
            min_gap_segundos,
            min_duracion_segundos
        )
        color = "green" if num_eventos > 0 else "orange"
    else:
        color = "red"

    stop_name = stop["stop_name"] if "stop_name" in stops_df.columns else stop["stop_id"]

    folium.CircleMarker(
        location=[stop.lat, stop.lon],
        radius=6,
        color=color,
        fill=True,
        fill_color=color,
        tooltip=f"{stop_name}"
    ).add_to(m)

# --- Desvíos (solo en modo Velocidad) ---
if modo == "Velocidad":
    linea_union_m = linea_gdf_m.geometry.union_all()

    for idx, row in df_hora.iterrows():
        p_m = df_hora_gdf_m.loc[idx, "geometry"]
        dist_m = p_m.distance(linea_union_m)

        if dist_m > umbral_distancia:
            folium.CircleMarker(
                location=[row["lat"], row["lon"]],
                radius=4,
                color="purple",
                fill=True,
                fill_color="purple",
                tooltip=f"Desvío {dist_m:.1f} m<br>{row['date'].strftime('%H:%M:%S')}"
            ).add_to(m)

# --- Leyendas ---
if modo == "Velocidad":
    legend_html1 = """
    <div style="position: fixed; bottom: 50px; left: 50px; width: 230px; height: 150px; 
                border:2px solid grey; z-index:9999; font-size:14px; background-color:white; 
                opacity:0.9; padding: 10px; overflow:auto;">
    <b>Leyenda Velocidad</b><br>
    <div style="display:flex; align-items:center;"><div style="width:40px; border-top:4px solid green; margin-right:6px;"></div>0-10 km/h</div>
    <div style="display:flex; align-items:center;"><div style="width:40px; border-top:4px solid yellow; margin-right:6px;"></div>11-20 km/h</div>
    <div style="display:flex; align-items:center;"><div style="width:40px; border-top:4px solid orange; margin-right:6px;"></div>21-40 km/h</div>
    <div style="display:flex; align-items:center;"><div style="width:40px; border-top:4px solid red; margin-right:6px;"></div>>40 km/h</div>
    <div style="display:flex; align-items:center;"><div style="width:40px; border-top:4px solid blue; margin-right:6px;"></div>Exceso de velocidad</div>
    </div>
    """

    legend_html2 = """
    <div style="position: fixed; bottom: 50px; left: 300px; width: 180px; height: 150px; 
                border:2px solid grey; z-index:9999; font-size:14px; background-color:white; 
                opacity:0.9; padding: 10px; overflow:auto;">
    <b>Leyenda Paradas</b><br>
    <i class="fa fa-map-marker" style="color:green; font-size:24px;"></i> Paró<br>
    <i class="fa fa-map-marker" style="color:orange; font-size:24px;"></i> Pasó sin parar<br>
    <i class="fa fa-map-marker" style="color:red; font-size:24px;"></i> No pasó<br>
    <i class="fa fa-circle" style="color:purple; font-size:20px;"></i> Desvío
    </div>
    """

    m.get_root().html.add_child(folium.Element(legend_html1))
    m.get_root().html.add_child(folium.Element(legend_html2))

else:
    # Leyenda SOC (círculos)
    legend_html = """
    <div style="position: fixed; bottom: 50px; left: 50px;
                border:2px solid grey; z-index:9999; font-size:14px; 
                background-color:white; opacity:0.95; padding: 10px;">
    <b>Leyenda SOC</b><br>
    <div style="margin:5px;">
        <span style="display:inline-block;width:14px;height:14px;background-color:green;border-radius:50%;margin-right:6px;"></span>SOC ≥ 80%
    </div>
    <div style="margin:5px;">
        <span style="display:inline-block;width:14px;height:14px;background-color:yellowgreen;border-radius:50%;margin-right:6px;"></span>60–79%
    </div>
    <div style="margin:5px;">
        <span style="display:inline-block;width:14px;height:14px;background-color:orange;border-radius:50%;margin-right:6px;"></span>40–59%
    </div>
    <div style="margin:5px;">
        <span style="display:inline-block;width:14px;height:14px;background-color:red;border-radius:50%;margin-right:6px;"></span>20–39%
    </div>
    <div style="margin:5px;">
        <span style="display:inline-block;width:14px;height:14px;background-color:darkred;border-radius:50%;margin-right:6px;"></span><20%
    </div>
    </div>
    """
    m.get_root().html.add_child(folium.Element(legend_html))

# --- Detectar cambios de rango SOC y añadir marcadores al mapa ---
cambios = []
if modo == "VE" and not soc_df.empty:
    soc_df_dia = soc_df.copy().sort_values("date").reset_index(drop=True)
    soc_df_dia["stage"] = soc_df_dia["SOC"].apply(get_soc_stage)

    etapa_prev = soc_df_dia.iloc[0]["stage"]

    for _, row in soc_df_dia.iterrows():
        if row["stage"] != etapa_prev:
            cambios.append({
                "Hora": row["date"].strftime("%H:%M:%S"),
                "De": etapa_prev,
                "A": row["stage"]
            })
            # marcador en el mapa
            folium.CircleMarker(
                location=[row["lat"], row["lon"]],
                radius=8,
                color="black",
                weight=2,
                fill=True,
                fill_color=get_soc_color(row["SOC"]),
                tooltip=f"Cambio SOC {etapa_prev} → {row['stage']} ({row['date'].strftime('%H:%M:%S')})"
            ).add_to(m)

            etapa_prev = row["stage"]

# --- Analizar variaciones y aumentos de SOC ---
if modo == "VE" and not soc_df.empty:
    if cambios:
        cambios_df = pd.DataFrame(cambios)
        cambios_df["Causa estimada"] = ""

        # --- Función para extraer valor numérico del tramo SOC ---
        def soc_val(stage):
            if stage.startswith("≥"):
                return int(stage[1:].replace("%", ""))
            elif stage.startswith("<"):
                return int(stage[1:].replace("%", ""))
            elif "–" in stage:
                return int(stage.split("–")[0])
            else:
                return int(stage.replace("%", ""))

        # --- Añadir columnas internas (solo para cálculo de aumentos) ---
        cambios_df["SOC_prev"] = cambios_df["De"].apply(soc_val)
        cambios_df["SOC_curr"] = cambios_df["A"].apply(soc_val)

        # --- Cargar datos originales del Jaltest del día ---
        try:
            jal_raw = pd.read_excel(archivo)
        except Exception:
            st.warning("⚠️ No se pudo cargar el archivo Jaltest del día seleccionado.")
            jal_raw = pd.DataFrame()

        if not jal_raw.empty:
            # Normalizar y ordenar fechas
            jal_raw["date"] = pd.to_datetime(jal_raw["date"], errors="coerce")
            jal_raw = jal_raw.sort_values("date").reset_index(drop=True)

        # --- Umbral de velocidad ---
        umbral_speed_change = 0.5  # km/h

        # --- Analizar cada variación ---
        for idx, row in cambios_df.iterrows():
            timestamp = pd.to_datetime(f"{dia_dt.date()} {row['Hora']}")

            causa = ""

            if not jal_raw.empty:
                # Buscar anterior y posterior en Jaltest
                antes = jal_raw[jal_raw["date"] < timestamp].tail(1)
                despues = jal_raw[jal_raw["date"] > timestamp].head(1)

                if not antes.empty and not despues.empty:
                    rec_before = antes.iloc[0]
                    rec_after = despues.iloc[0]

                    # Seleccionar columna de velocidad disponible
                    if "speed_suav" in jal_raw.columns:
                        speed_before = rec_before["speed_suav"]
                        speed_after = rec_after["speed_suav"]
                    else:
                        speed_before = rec_before.get("speed", np.nan)
                        speed_after = rec_after.get("speed", np.nan)

                    delta_speed = float(speed_after) - float(speed_before) if pd.notna(speed_before) and pd.notna(speed_after) else None

                    # Calcular altitud si está disponible
                    if "altitude" in jal_raw.columns:
                        alt_before = rec_before["altitude"]
                        alt_after = rec_after["altitude"]
                        delta_alt = float(alt_after) - float(alt_before) if pd.notna(alt_before) and pd.notna(alt_after) else None
                    else:
                        delta_alt = None

                    # --- Determinar causa del aumento ---
                    if row["SOC_curr"] > row["SOC_prev"]:
                        if pd.notna(delta_speed):
                            if speed_before == 0 and speed_after == 0:
                                causa = "Parado completo / freno regenerativo"
                            elif delta_alt is not None and delta_alt < -0.5:
                                causa = "Pendiente descendente"
                            elif delta_speed < -umbral_speed_change:
                                causa = "Freno regenerativo"
                            elif delta_speed > umbral_speed_change:
                                causa = "Pendiente descendente"
                            else:
                                causa = "Velocidad constante / parada parcial"
                        else:
                            causa = "Desconocida / sin datos"

            # Si no hay datos en Jaltest, probar con df_hora
            if causa == "" and not df_hora.empty and row["SOC_curr"] > row["SOC_prev"]:
                antes2 = df_hora[df_hora["date"] <= timestamp].tail(1)
                despues2 = df_hora[df_hora["date"] > timestamp].head(1)

                if not antes2.empty and not despues2.empty:
                    speed_before = antes2["speed_suav"].iloc[0]
                    speed_after = despues2["speed_suav"].iloc[0]
                    delta_speed = speed_after - speed_before

                    if "altitude" in df_hora.columns:
                        delta_alt = despues2["altitude"].iloc[0] - antes2["altitude"].iloc[0]
                    else:
                        delta_alt = None

                    if speed_before == 0 and speed_after == 0:
                        causa = "Parado completo / freno regenerativo"
                    elif delta_alt is not None and delta_alt < -0.5:
                        causa = "Pendiente descendente"
                    elif delta_speed < -umbral_speed_change:
                        causa = "Freno regenerativo"
                    elif delta_speed > umbral_speed_change:
                        causa = "Pendiente descendente"
                    else:
                        causa = "Velocidad constante / parada parcial"
                else:
                    causa = "Desconocida / sin datos"

            # Registrar causa
            cambios_df.at[idx, "Causa estimada"] = causa

            # --- Añadir marcador al mapa ---
            if row["SOC_curr"] > row["SOC_prev"]:
                closest_soc = get_closest_soc(soc_df, timestamp)
                if closest_soc is not None:
                    color = {
                        "Freno regenerativo": "blue",
                        "Pendiente descendente": "green",
                        "Parado completo / freno regenerativo": "purple"
                    }.get(causa, "gray")

                    icon = {
                        "Freno regenerativo": "arrow-down",
                        "Pendiente descendente": "arrow-up",
                        "Parado completo / freno regenerativo": "pause"
                    }.get(causa, "circle")

                    folium.Marker(
                        location=[closest_soc["lat"], closest_soc["lon"]],
                        icon=folium.Icon(color=color, icon=icon, prefix="fa"),
                        tooltip=f"SOC ↑ {row['De']} → {row['A']} ({causa})"
                    ).add_to(m)

        # --- Limpiar columnas internas ---
        cambios_df = cambios_df.drop(columns=["SOC_prev", "SOC_curr"], errors="ignore")

        # --- Mostrar tabla de variaciones ---
        st.subheader(f"Variaciones de SOC {dia_sel}")

        def color_causa(val):
            if val == "Freno regenerativo":
                return "color: blue;"
            elif val == "Pendiente descendente":
                return "color: green;"
            elif val == "Parado completo / freno regenerativo":
                return "color: purple;"
            elif val == "Velocidad constante / parada parcial":
                return "color: gray;"
            else:
                return ""

        st.dataframe(
            cambios_df.style.map(color_causa, subset=["Causa estimada"])
        )
    else:
        st.info("No se detectaron cambios de rango de SOC en el día seleccionado.")
else:
    st.info("No se detectaron variaciones de SOC en el día seleccionado o no estás en modo VE.")

# --- Mostrar mapa una vez, después de añadir todos los elementos ---
st_folium(m, width="100%", height=600, key="mapa_principal")

# --- Calcular SOH por periodos (enero y julio) ---
if soc_files:
    with st.spinner("Calculando indicador exploratorio de SOH por periodos..."):
        DATE_COL = "date"
        SOC_COL = "SOC"
        AUTONOMIA_COL = "autonomia"
        AUTONOMIA_NOMINAL = 350.0
        SOC_MIN_VALID = 90.0  # SOC mínimo para considerar válido

        periods = {
            "Enero": ("2025-01-15", "2025-01-31"),
            "Julio": ("2025-07-15", "2025-07-31")
        }

        colors = {
            "Enero": "blue",
            "Julio": "orange"
        }

        df_list = [pd.read_excel(f) for f in soc_files]
        df = pd.concat(df_list, ignore_index=True)

        df[DATE_COL] = pd.to_datetime(df[DATE_COL], errors="coerce")
        df[SOC_COL] = pd.to_numeric(df[SOC_COL], errors="coerce")
        df[AUTONOMIA_COL] = pd.to_numeric(df[AUTONOMIA_COL], errors="coerce")
        df = df.dropna(subset=[DATE_COL, SOC_COL, AUTONOMIA_COL])
        df = df[(df[SOC_COL] >= 1) & (df[SOC_COL] <= 100)]
        df = df[df[AUTONOMIA_COL] <= AUTONOMIA_NOMINAL]

        if df.empty:
            st.sidebar.info(
                "No hay datos FULL_SOC válidos para calcular el indicador exploratorio de SOH."
            )
        else:
            df["day"] = df[DATE_COL].dt.date

            def soh_stats_per_day(subdf):
                df_valid = subdf[subdf[SOC_COL] >= SOC_MIN_VALID]
                df_valid = df_valid[df_valid[AUTONOMIA_COL] <= AUTONOMIA_NOMINAL]
                if not df_valid.empty:
                    median_soh = df_valid[AUTONOMIA_COL].median() / AUTONOMIA_NOMINAL * 100
                    min_soh = df_valid[AUTONOMIA_COL].min() / AUTONOMIA_NOMINAL * 100
                    max_soh = df_valid[AUTONOMIA_COL].max() / AUTONOMIA_NOMINAL * 100
                    return pd.Series({
                        "SOH_median": median_soh,
                        "SOH_min": min_soh,
                        "SOH_max": max_soh
                    })
                return pd.Series({
                    "SOH_median": np.nan,
                    "SOH_min": np.nan,
                    "SOH_max": np.nan
                })

            daily_stats = (
                df.groupby("day")[[SOC_COL, AUTONOMIA_COL]]
                .apply(soh_stats_per_day)
                .reset_index()
            )
            daily_stats["day_dt"] = pd.to_datetime(daily_stats["day"])

            fig, axes = plt.subplots(nrows=2, ncols=1, figsize=(14, 10), sharey=True)

            for ax, (label, (start, end)) in zip(axes, periods.items()):
                start_dt = pd.to_datetime(start)
                end_dt = pd.to_datetime(end)
                all_days = pd.date_range(start=start_dt, end=end_dt, freq="D")

                mask = (
                    (daily_stats["day_dt"] >= start_dt)
                    & (daily_stats["day_dt"] <= end_dt)
                )
                sub = (
                    daily_stats.loc[mask]
                    .set_index("day_dt")
                    .reindex(all_days)
                    .reset_index()
                )
                sub.rename(columns={"index": "day_dt"}, inplace=True)

                sub["SOH_smooth"] = sub["SOH_median"].rolling(
                    window=3, center=True, min_periods=1
                ).median()

                color = colors[label]
                ax.plot(
                    sub["day_dt"],
                    sub["SOH_smooth"],
                    marker="o",
                    linestyle="-",
                    color=color,
                    label=f"Mediana del SOH {label}"
                )

                for x, y in zip(sub["day_dt"], sub["SOH_smooth"]):
                    if not np.isnan(y):
                        ax.text(
                            x,
                            y + 0.5,
                            f"{y:.1f}",
                            ha="center",
                            va="bottom",
                            fontsize=8,
                            color=color,
                            fontweight="bold"
                        )

                ax.set_ylim(0, 100)
                ax.set_xticks(all_days)
                ax.set_xticklabels([d.day for d in all_days], rotation=45)
                ax.set_title(f"{label} ({start} a {end})")
                ax.set_ylabel("SOH relativo exploratorio (%)")
                ax.grid(True, linestyle="--", alpha=0.5)
                ax.legend()

            axes[-1].set_xlabel("Día del mes")
            plt.tight_layout()

            with st.sidebar:
                st.subheader("SOH exploratorio basado en autonomía")
                st.caption(
                    "Indicador exploratorio calculado a partir de la autonomía registrada "
                    "respecto a una autonomía nominal de referencia de 350 km. "
                    "No constituye una estimación física del estado de salud de la batería."
                )
                st.pyplot(fig)

                buf = io.BytesIO()
                fig.savefig(buf, format="png", dpi=150, bbox_inches="tight")
                buf.seek(0)
                st.download_button(
                    label="📥 Descargar gráfico como PNG",
                    data=buf,
                    file_name="SOH_autonomia_exploratorio.png",
                    mime="image/png"
                )
else:
    st.sidebar.info(
        "El análisis exploratorio de SOH requiere archivos FULL_SOC en "
        "'datos_entrada/full_soc/'."
    )
