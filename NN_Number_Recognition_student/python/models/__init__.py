"""
All models that the system knows. To add a model, write one file in this folder
with MODEL_ID, NAME and build_torch(), and add it to MODELS below.
"""

from . import mlp_784_32_10

MODELS = {m.NAME: m for m in [mlp_784_32_10]}


def get_model(name):
    if name not in MODELS:
        raise SystemExit(f"Unknown model '{name}'. Known models: {', '.join(MODELS)}")
    return MODELS[name]
