import numpy as np
import pandas as pd
from pathlib import Path
from sklearn.preprocessing import StandardScaler, RobustScaler

# ── Config ────────────────────────────────────────────────────────────────────
BASE     = Path("data/tlvmc-parkinsons-freezing-gait-prediction")
OUT_DIR  = Path("data/prepared")

# Dataset is sampled at 128 Hz; 2-second windows = 256 samples
FS          = 128
WINDOW_SIZE = 256
STEP_SIZE   = 128   # 50% overlap

SENSOR_COLS  = ["AccV", "AccML", "AccAP"]
FOG_COLS     = ["StartHesitation", "Turn", "Walking"]
# ─────────────────────────────────────────────────────────────────────────────


def load_tdcsfog(meta: pd.DataFrame) -> pd.DataFrame:
    """Load all tdcsfog train CSVs and attach subject ID."""
    frames = []
    for _, row in meta.iterrows():
        path = BASE / "train" / "tdcsfog" / f"{row['Id']}.csv"
        if not path.exists():
            continue
        df = pd.read_csv(path)
        df["Id"]      = row["Id"]
        df["Subject"] = row["Subject"]
        # All rows are annotated in tdcsfog
        df["valid"]   = True
        frames.append(df)
    return pd.concat(frames, ignore_index=True)


def load_defog(meta: pd.DataFrame) -> pd.DataFrame:
    """Load all defog train CSVs, keeping only Valid=True rows."""
    frames = []
    for _, row in meta.iterrows():
        path = BASE / "train" / "defog" / f"{row['Id']}.csv"
        if not path.exists():
            continue
        df = pd.read_csv(path)
        df["Id"]      = row["Id"]
        df["Subject"] = row["Subject"]
        # Only Valid rows have reliable annotations
        df = df[df["Valid"] == True].copy()
        frames.append(df)
    return pd.concat(frames, ignore_index=True)


def make_fog_label(df: pd.DataFrame) -> pd.DataFrame:
    """Merge the 3 FoG event types into one binary label."""
    df["fog"] = (df[FOG_COLS].sum(axis=1) > 0).astype(int)
    return df


def impute(df: pd.DataFrame) -> pd.DataFrame:
    """Linear interpolation within each recording, fallback fill with 0."""
    df[SENSOR_COLS] = (
        df.groupby("Id")[SENSOR_COLS]
        .transform(lambda s: s.interpolate(method="linear",
                                           limit_direction="both")
                              .ffill().bfill().fillna(0.0))
    )
    return df


def normalize_per_subject(df: pd.DataFrame) -> pd.DataFrame:
    """Z-score each subject independently to remove sensor placement bias."""
    def _scale(block):
        return pd.DataFrame(
            StandardScaler().fit_transform(block),
            index=block.index, columns=block.columns,
        )
    df[SENSOR_COLS] = (
        df.groupby("Subject")[SENSOR_COLS]
        .apply(_scale)
        .droplevel(0)
        .sort_index()
    )
    return df


def compute_freq_features(window: np.ndarray) -> np.ndarray:
    """Per-channel spectral features for one (T, C) window.

    Returns 6*C values (6 features per channel):
      - freeze index    : FoG band power / total power
      - fog band power  : mean power in 3-8 Hz
      - loco band power : mean power in 0.5-3 Hz
      - freeze ratio    : FoG band / loco band — high during FoG, low during fast walking
      - dominant freq   : frequency of peak power (normalised by Nyquist)
      - signal energy   : log total power — distinguishes movement from rest
    """
    freqs = np.fft.rfftfreq(window.shape[0], d=1.0 / FS)
    mag   = np.abs(np.fft.rfft(window, axis=0)) ** 2   # (bins, C)

    fog_mask  = (freqs >= 3)   & (freqs <= 8)
    loco_mask = (freqs >= 0.5) & (freqs <  3)
    total_pow = mag.sum(axis=0) + 1e-8

    freeze_idx    = mag[fog_mask].sum(axis=0) / total_pow
    fog_pow       = mag[fog_mask].mean(axis=0)
    loco_pow      = mag[loco_mask].mean(axis=0)
    freeze_ratio  = fog_pow / (loco_pow + 1e-8)
    dominant_freq = freqs[np.argmax(mag, axis=0)] / (FS / 2)  # normalised 0-1
    log_energy    = np.log1p(total_pow)                        # distinguishes active walking from stillness/freeze

    return np.concatenate([
        freeze_idx, fog_pow, loco_pow,
        freeze_ratio, dominant_freq, log_energy,
    ]).astype(np.float32)


def make_windows(df: pd.DataFrame):
    """Slide windows over each recording, return arrays and subject labels."""
    X_list, Xf_list, y_list, groups_list = [], [], [], []

    for rec_id, group in df.groupby("Id"):
        group  = group.reset_index(drop=True)
        values = group[SENSOR_COLS].values   # (T, 3)
        labels = group["fog"].values         # (T,)
        subj   = group["Subject"].iloc[0]

        n_windows = (len(group) - WINDOW_SIZE) // STEP_SIZE + 1
        if n_windows <= 0:
            continue

        for i in range(n_windows):
            start  = i * STEP_SIZE
            end    = start + WINDOW_SIZE
            window = values[start:end]
            label  = int(labels[start:end].mean() >= 0.5)

            X_list.append(window)
            Xf_list.append(compute_freq_features(window))
            y_list.append(label)
            groups_list.append(subj)

    X      = np.stack(X_list).astype(np.float32)    # (N, W, 3)
    Xf     = np.stack(Xf_list).astype(np.float32)   # (N, 9)
    y      = np.array(y_list,      dtype=np.int64)
    groups = np.array(groups_list, dtype=object)     # subject ID strings
    return X, Xf, y, groups


def split_by_subject(X, Xf, y, groups, val_subjects, test_subjects):
    val_mask   = np.isin(groups, val_subjects)
    test_mask  = np.isin(groups, test_subjects)
    train_mask = ~val_mask & ~test_mask
    return (
        X[train_mask],  Xf[train_mask],  y[train_mask],  groups[train_mask],
        X[val_mask],    Xf[val_mask],    y[val_mask],
        X[test_mask],   Xf[test_mask],   y[test_mask],
    )


def normalize_freq_features(Xf_train, Xf_val, Xf_test):
    """Robust-scale Xf using train statistics only.

    RobustScaler (median/IQR) handles the heavy-tailed freeze_ratio distribution
    better than StandardScaler, and prevents test-subject outliers from dominating.
    Fitted on train only so val/test are truly unseen.
    """
    scaler = RobustScaler()
    Xf_train = scaler.fit_transform(Xf_train)
    Xf_val   = scaler.transform(Xf_val)
    Xf_test  = scaler.transform(Xf_test)
    return Xf_train.astype(np.float32), Xf_val.astype(np.float32), Xf_test.astype(np.float32), scaler


def compute_class_weight(y_train: np.ndarray) -> np.ndarray:
    counts    = np.bincount(y_train)
    weights   = len(y_train) / (len(counts) * counts)
    return weights.astype(np.float32)


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    meta_t = pd.read_csv(BASE / "tdcsfog_metadata.csv")
    meta_d = pd.read_csv(BASE / "defog_metadata.csv")

    print("Loading tdcsfog...")
    tdcs = load_tdcsfog(meta_t)
    print(f"  {len(tdcs):,} rows, {tdcs['Subject'].nunique()} subjects")

    print("Loading defog (Valid rows only)...")
    defog = load_defog(meta_d)
    print(f"  {len(defog):,} rows, {defog['Subject'].nunique()} subjects")

    # Combine — keep only shared columns
    shared_cols = ["Id", "Subject", "Time"] + SENSOR_COLS + FOG_COLS
    df = pd.concat([tdcs[shared_cols], defog[shared_cols]], ignore_index=True)
    print(f"\nCombined: {len(df):,} rows, {df['Subject'].nunique()} unique subjects")

    print("Creating binary FoG label...")
    df = make_fog_label(df)
    print(f"  FoG rate: {df['fog'].mean():.1%}")

    print("Imputing missing values...")
    df = impute(df)
    print(f"  NaNs remaining: {df[SENSOR_COLS].isnull().sum().sum()}")

    print("Normalizing per subject...")
    df = normalize_per_subject(df)

    print(f"Creating windows (size={WINDOW_SIZE} @ {FS}Hz = 2s, step={STEP_SIZE})...")
    X, Xf, y, groups = make_windows(df)
    print(f"  Windows: {X.shape}  |  Freq features: {Xf.shape}  |  FoG rate: {y.mean():.1%}")

    # Split by subject — stratified by each subject's FoG rate so train/val/test
    # have similar FoG prevalence (random shuffle got unlucky otherwise).
    all_subjects = np.unique(groups)
    subj_fog_rate = np.array([y[groups == s].mean() for s in all_subjects])
    # Sort subjects by FoG rate, then interleave into test/val/train buckets
    sorted_idx = np.argsort(subj_fog_rate)
    sorted_subjects = all_subjects[sorted_idx]
    n = len(sorted_subjects)
    n_test = max(1, int(n * 0.10))
    n_val  = max(1, int(n * 0.10))
    # Take every ~10th subject for test, every ~10th for val (spread across rate range)
    test_subjects = sorted_subjects[::n // n_test][:n_test]
    val_subjects  = sorted_subjects[1::n // n_val][:n_val]
    # Ensure no overlap
    val_subjects = np.array([s for s in val_subjects if s not in test_subjects])

    (X_train, Xf_train, y_train, groups_train,
     X_val,   Xf_val,   y_val,
     X_test,  Xf_test,  y_test) = split_by_subject(
        X, Xf, y, groups, val_subjects, test_subjects
    )

    val_mask  = np.isin(groups, val_subjects)
    test_mask = np.isin(groups, test_subjects)
    groups_val  = groups[val_mask]
    groups_test = groups[test_mask]

    print("Normalizing frequency features (RobustScaler fitted on train)...")
    Xf_train, Xf_val, Xf_test, xf_scaler = normalize_freq_features(
        Xf_train, Xf_val, Xf_test)
    print(f"  Xf_train: min={Xf_train.min():.2f} max={Xf_train.max():.2f}")

    class_weights = compute_class_weight(y_train)

    print("\nSplit summary:")
    for name, ys in [("train", y_train), ("val", y_val), ("test", y_test)]:
        print(f"  {name:5s}: {ys.shape[0]:6,} windows  FoG={ys.mean():.1%}")
    print(f"\nVal subjects  ({len(val_subjects)}):  {sorted(val_subjects)[:5]}...")
    print(f"Test subjects ({len(test_subjects)}): {sorted(test_subjects)[:5]}...")
    print(f"Class weights (non-FoG / FoG): {class_weights}")

    print(f"\nSaving to {OUT_DIR}/...")
    np.save(OUT_DIR / "X_train.npy",       X_train)
    np.save(OUT_DIR / "y_train.npy",       y_train)
    np.save(OUT_DIR / "X_val.npy",         X_val)
    np.save(OUT_DIR / "y_val.npy",         y_val)
    np.save(OUT_DIR / "X_test.npy",        X_test)
    np.save(OUT_DIR / "y_test.npy",        y_test)
    np.save(OUT_DIR / "Xf_train.npy",      Xf_train)
    np.save(OUT_DIR / "Xf_val.npy",        Xf_val)
    np.save(OUT_DIR / "Xf_test.npy",       Xf_test)
    import joblib
    joblib.dump(xf_scaler, OUT_DIR / "xf_scaler.pkl")
    np.save(OUT_DIR / "class_weights.npy", class_weights)
    np.save(OUT_DIR / "groups_train.npy",  groups_train)
    np.save(OUT_DIR / "groups_val.npy",   groups_val)
    np.save(OUT_DIR / "groups_test.npy",  groups_test)
    np.save(OUT_DIR / "val_subjects.npy",  val_subjects)
    np.save(OUT_DIR / "test_subjects.npy", test_subjects)
    print("Done.")


if __name__ == "__main__":
    main()
