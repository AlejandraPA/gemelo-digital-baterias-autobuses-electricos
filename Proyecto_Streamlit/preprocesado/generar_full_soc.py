
import pandas as pd
from pathlib import Path

# Carpetas
BASE_DIR = Path(__file__).resolve().parents[1]

carpeta_soc = BASE_DIR / "datos_entrada" / "soc"
carpeta_jaltest = BASE_DIR / "datos_entrada" / "jaltest"
carpeta_full_soc = BASE_DIR / "datos_entrada" / "full_soc"

carpeta_full_soc.mkdir(parents=True, exist_ok=True)

# Listar archivos SOC y Jaltest
soc_files = sorted(carpeta_soc.glob("SOC_*.xlsx"))
jaltest_files = sorted(
    f for f in carpeta_jaltest.glob("jaltest_sample_*.xlsx")
    if "_con_altitud" not in f.stem.lower()
)

# Comprobar que existen los datos de entrada necesarios
if not soc_files:
    raise SystemExit(
        "No se encontraron archivos SOC_*.xlsx en "
        "'datos_entrada/soc/'. Los datos originales no se distribuyen "
        "con la versión pública del repositorio."
    )

if not jaltest_files:
    raise SystemExit(
        "No se encontraron archivos jaltest_sample_*.xlsx en "
        "'datos_entrada/jaltest/'. Los datos originales no se distribuyen "
        "con la versión pública del repositorio."
    )

# Procesar cada SOC
for soc_file in soc_files:
    df_soc = pd.read_excel(soc_file)
    df_soc['date'] = pd.to_datetime(df_soc['date'])  # Mantener hora original
    df_soc = df_soc.sort_values('date').reset_index(drop=True)
    
    # Buscar Jaltest correspondiente por XXjul
    xxjul = soc_file.stem.split("_")[1].lower()
    jal_file_match = [f for f in jaltest_files if xxjul in f.name.lower()]
    
    if not jal_file_match:
        print(f"No se encontró Jaltest para {soc_file}, se omite.")
        continue
    
    df_jal = pd.read_excel(jal_file_match[0])
    df_jal['date'] = pd.to_datetime(df_jal['date'])  # Mantener hora
    df_jal = df_jal.sort_values('date').reset_index(drop=True)
    
    # Merge_asof: empareja cada fecha SOC con la última disponible en Jaltest
    df_completo = pd.merge_asof(df_soc, df_jal[['date','lat','lon']], on='date', direction='backward')
    
    # Guardar resultado
    output_file = carpeta_full_soc / f"FULL_{soc_file.name}"
    df_completo.to_excel(output_file, index=False)
    print(f"Archivo completado: {output_file}")
