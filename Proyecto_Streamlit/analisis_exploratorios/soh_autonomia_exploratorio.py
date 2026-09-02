
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
from pathlib import Path

# --- CONFIG ---
BASE_DIR = Path(__file__).resolve().parents[1]
FULL_SOC_DIR = BASE_DIR / "datos_entrada" / "full_soc"

soh_files = sorted(FULL_SOC_DIR.glob("FULL_SOC_*.xlsx"))

if not soh_files:
    raise SystemExit(
        "No se encontraron archivos FULL_SOC en datos_entrada/full_soc/. "
        "Los datos originales no se distribuyen con el repositorio."
    )

DATE_COL = "date"
SOC_COL = "SOC"
AUTONOMIA_COL = "autonomia"
AUTONOMIA_NOMINAL = 350.0
SOC_MIN_VALID = 90.0  # SOC mínimo para considerar válido

periods = {
    "Invierno": ("2025-01-15", "2025-01-31"),
    "Verano": ("2025-07-15", "2025-07-31")
}

colors = {
    "Invierno": "blue",
    "Verano": "orange"
}

# --- LEER TODOS LOS ARCHIVOS ---
df_list = [pd.read_excel(f) for f in soh_files]
df = pd.concat(df_list, ignore_index=True)

# --- LIMPIEZA ---
df[DATE_COL] = pd.to_datetime(df[DATE_COL], errors="coerce")
df[SOC_COL] = pd.to_numeric(df[SOC_COL], errors="coerce")
df[AUTONOMIA_COL] = pd.to_numeric(df[AUTONOMIA_COL], errors="coerce")
df = df.dropna(subset=[DATE_COL, SOC_COL, AUTONOMIA_COL])
df = df[(df[SOC_COL] >= 1) & (df[SOC_COL] <= 100)]
df = df[df[AUTONOMIA_COL] <= AUTONOMIA_NOMINAL]  # eliminar valores > nominal
df["day"] = df[DATE_COL].dt.date

# --- CALCULO DE SOH Y RANGO DIARIO ---
def soh_stats_per_day(subdf):
    df_valid = subdf[subdf[SOC_COL] >= SOC_MIN_VALID]
    df_valid = df_valid[df_valid[AUTONOMIA_COL] <= AUTONOMIA_NOMINAL]
    if not df_valid.empty:
        median_soh = df_valid[AUTONOMIA_COL].median() / AUTONOMIA_NOMINAL * 100
        min_soh = df_valid[AUTONOMIA_COL].min() / AUTONOMIA_NOMINAL * 100
        max_soh = df_valid[AUTONOMIA_COL].max() / AUTONOMIA_NOMINAL * 100
        return pd.Series({"SOH_median": median_soh, "SOH_min": min_soh, "SOH_max": max_soh})
    else:
        return pd.Series({"SOH_median": np.nan, "SOH_min": np.nan, "SOH_max": np.nan})

daily_stats = (
    df.groupby("day")[[SOC_COL, AUTONOMIA_COL]]
    .apply(soh_stats_per_day)
    .reset_index()
)
daily_stats["day_dt"] = pd.to_datetime(daily_stats["day"])

# --- FIGURA CON SUBPLOTS (todos los días del periodo) ---
fig, axes = plt.subplots(nrows=2, ncols=1, figsize=(14,10), sharey=True)

for ax, (label, (start, end)) in zip(axes, periods.items()):
    start_dt = pd.to_datetime(start)
    end_dt = pd.to_datetime(end)
    
    # Crear rango completo de días
    all_days = pd.date_range(start=start_dt, end=end_dt, freq='D')
    
    # Filtrar datos del periodo y reindexar para incluir todos los días
    mask = (daily_stats["day_dt"] >= start_dt) & (daily_stats["day_dt"] <= end_dt)
    sub = daily_stats.loc[mask].set_index("day_dt").reindex(all_days).reset_index()
    sub.rename(columns={"index":"day_dt"}, inplace=True)
    
    # Rolling median suavizado 3 días
    sub["SOH_smooth"] = sub["SOH_median"].rolling(window=3, center=True, min_periods=1).median()
    
    color = colors[label]
    
    # Línea y puntos del SOH suavizado
    ax.plot(
        sub["day_dt"], sub["SOH_smooth"],
        marker="o", linestyle="-", color=color, label="Mediana diaria del SOH"
    )
    
    # # Sombreado: rango diario (min-max)
    # ax.fill_between(
    #     sub["day_dt"],
    #     sub["SOH_min"],
    #     sub["SOH_max"],
    #     color=color, alpha=0.2, label="Rango SOH diario"
    # )
    
    # Etiquetas en puntos y extremos del sombreado
    for x, y in zip(sub["day_dt"], sub["SOH_smooth"]):
        if not np.isnan(y):
            ax.text(x, y+0.5, f"{y:.1f}", ha="center", va="bottom", fontsize=8, color=color, fontweight="bold")
    # for x, ymin, ymax in zip(sub["day_dt"], sub["SOH_min"], sub["SOH_max"]):
    #     if not np.isnan(ymax) and not np.isnan(ymin):
    #         ax.text(x, ymax+0.5, f"{ymax:.1f}", ha="center", va="bottom", fontsize=7, color=color)
    #         ax.text(x, ymin-0.5, f"{ymin:.1f}", ha="center", va="top", fontsize=7, color=color)
    
    # Eje X: todos los días del periodo
    ax.set_xticks(all_days)
    ax.set_xticklabels([d.day for d in all_days], rotation=45)
    
    ax.set_title(f"{label} ({start} a {end})")
    ax.set_ylabel("SOH relativo exploratorio (%)")
    ax.grid(True, linestyle='--', alpha=0.5)
    ax.legend()

axes[-1].set_xlabel("Día del periodo")
plt.tight_layout()
plt.show()











