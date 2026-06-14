"""
Run this in Colab after training to export the model for the Flutter app.

Usage:
    # After training your model:
    export_for_flutter(model)          # CNN-BiLSTM or Transformer-BiLSTM
    # Files saved: fog_model.tflite
    # Then download and drop into aria/assets/models/
"""

import tensorflow as tf
import numpy as np
from google.colab import files


def export_for_flutter(model, output_path="fog_model.tflite"):
    """Convert a trained Keras model to TFLite and download it."""
    converter = tf.lite.TFLiteConverter.from_keras_model(model)

    # Optional: quantize to reduce size (comment out if accuracy drops)
    # converter.optimizations = [tf.lite.Optimize.DEFAULT]

    tflite_model = converter.convert()

    with open(output_path, "wb") as f:
        f.write(tflite_model)

    size_kb = len(tflite_model) / 1024
    print(f"Saved {output_path} ({size_kb:.1f} KB)")
    print("Input shape expected:", model.input_shape)
    print("Output shape:", model.output_shape)

    files.download(output_path)
    print("Download started — drop the file into aria/assets/models/fog_model.tflite")


def verify_tflite(tflite_path="fog_model.tflite", window_size=120, n_features=18):
    """Quick sanity check: run one random window through the exported model."""
    interpreter = tf.lite.Interpreter(model_path=tflite_path)
    interpreter.allocate_tensors()

    inp = interpreter.get_input_details()
    out = interpreter.get_output_details()
    print("Input details: ", inp[0]["shape"], inp[0]["dtype"])
    print("Output details:", out[0]["shape"], out[0]["dtype"])

    dummy = np.random.rand(1, window_size, n_features).astype(np.float32)
    interpreter.set_tensor(inp[0]["index"], dummy)
    interpreter.invoke()
    result = interpreter.get_tensor(out[0]["index"])
    print(f"Test output (FoG probability): {result[0][0]:.4f}  ✓")


# ── Example usage ────────────────────────────────────────────────────────────
# After training CNN_BiLSTM.py or Transformer_BiLSTM2.py:
#
#   export_for_flutter(model)
#   verify_tflite()
